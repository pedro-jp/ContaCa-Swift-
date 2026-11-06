//
//  AuthManager.swift
//  Forma
//
//  Created by João Pedro on 11/02/26.
//

import Foundation
import Combine
import SwiftUI
import AuthenticationServices

@MainActor
public final class AuthManager: ObservableObject {
    public static let shared = AuthManager()

    // MARK: - Chaves de Armazenamento Seguro (mantidas para compatibilidade de sessão)
    private let tokenKey = "forma_jwt_token"
    private let userIdKey = "forma_user_id"
    private let userEmailKey = "forma_user_email"
    private let userNameKey = "forma_user_name"
    private let authProviderKey = "forma_auth_provider"

    // MARK: - Endereços de Rede Local / Bonjour / Simulador
    #if targetEnvironment(simulator)
    public static let defaultServerUrl = "http://localhost:8085"
    #else
    public static let defaultServerUrl = "http://10.0.0.106:8085"
    #endif
    public static let fallbackBonjourUrl = "http://MacBook-Pro-de-Joao-2.local:8085"
    public static let fallbackCurrentLanUrl = "http://10.0.0.106:8085"
    public static let fallbackSecondaryLanUrl = "http://192.168.1.23:8085"
    public static let fallbackLocalUrl = "http://localhost:8085"
    public static let fallbackLoopbackUrl = "http://127.0.0.1:8085"
    public static let fallbackLanUrl = "http://192.168.10.15:8085"

    private static let deprecatedSubnetHosts: Set<String> = [
        "http://10.0.0.105:8085",
        "http://10.0.0.103:8085",
        "http://192.0.0.2:8085",
        "http://192.168.1.13:8085"
    ]

    public var candidateServerUrls: [String] {
        var list: [String] = []
        let current = serverBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines)

        #if targetEnvironment(simulator)
        if !current.isEmpty { list.append(current) }
        list.append(Self.fallbackLocalUrl)
        list.append(Self.fallbackLoopbackUrl)
        list.append(Self.fallbackBonjourUrl)
        list.append(Self.fallbackCurrentLanUrl)
        list.append(Self.fallbackSecondaryLanUrl)
        #else
        if !current.isEmpty && !Self.deprecatedSubnetHosts.contains(current) {
            list.append(current)
        }
        list.append(Self.fallbackCurrentLanUrl)
        list.append(Self.fallbackBonjourUrl)
        list.append(Self.fallbackSecondaryLanUrl)
        list.append(Self.fallbackLocalUrl)
        list.append(Self.fallbackLoopbackUrl)
        #endif
        list.append(Self.fallbackLanUrl)

        var seen = Set<String>()
        return list.filter { seen.insert($0).inserted }
    }

    // MARK: - Estados Publicados
    @Published public var isAuthenticated: Bool = false
    @Published public var isGuest: Bool = false
    @Published public var currentUserId: String? = nil
    @Published public var currentUserEmail: String? = nil
    @Published public var currentUserName: String? = nil
    @Published public var currentAuthProvider: String? = nil
    @Published public var jwtToken: String? = nil
    @Published public var isAuthenticating: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var serverBaseUrl: String

    private init() {
        self.serverBaseUrl = Self.defaultServerUrl
        restoreSession()
    }

    // MARK: - Restauração de Sessão Segura via Keychain
    public func restoreSession() {
        let token = KeychainHelper.shared.loadString(key: tokenKey) ?? UserDefaults.standard.string(forKey: tokenKey)
        let userId = KeychainHelper.shared.loadString(key: userIdKey) ?? UserDefaults.standard.string(forKey: userIdKey)

        if let token, !token.isEmpty, let userId, !userId.isEmpty {
            self.jwtToken = token
            self.currentUserId = userId
            self.currentUserEmail = KeychainHelper.shared.loadString(key: userEmailKey) ?? UserDefaults.standard.string(forKey: userEmailKey)
            self.currentUserName = KeychainHelper.shared.loadString(key: userNameKey) ?? UserDefaults.standard.string(forKey: userNameKey)
            self.currentAuthProvider = KeychainHelper.shared.loadString(key: authProviderKey) ?? UserDefaults.standard.string(forKey: authProviderKey)
            self.isAuthenticated = true
            self.isGuest = false
        } else {
            self.jwtToken = nil
            self.currentUserId = nil
            self.currentUserEmail = nil
            self.currentUserName = nil
            self.currentAuthProvider = nil
            self.isAuthenticated = false
            self.isGuest = false
        }
    }

    // MARK: - Login com E-mail e Senha
    public func login(email: String, password: String) async throws {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanEmail.isEmpty, !cleanPassword.isEmpty else {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Preencha e-mail e senha."])
        }

        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        let data = try await FormaAPIClient.shared.requestData(
            path: "/api/auth/login",
            method: "POST",
            jsonBody: ["email": cleanEmail, "password": cleanPassword],
            authenticated: false,
            timeout: 8.0,
            interceptAccountStatus: false
        )
        try handleAuthSuccess(data: data, defaultProvider: "EMAIL")
    }

    // MARK: - Cadastro com E-mail e Senha
    public func register(name: String, email: String, password: String) async throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty, !cleanEmail.isEmpty, !cleanPassword.isEmpty else {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Preencha todos os campos."])
        }
        guard cleanPassword.count >= 6 else {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "A senha deve ter pelo menos 6 caracteres."])
        }

        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        let data = try await FormaAPIClient.shared.requestData(
            path: "/api/auth/register",
            method: "POST",
            jsonBody: ["name": cleanName, "email": cleanEmail, "password": cleanPassword],
            authenticated: false,
            timeout: 8.0,
            interceptAccountStatus: false
        )
        try handleAuthSuccess(data: data, defaultProvider: "EMAIL")
    }

    // MARK: - Login Social Seguro (Google ou Apple ID)
    public func loginWithSocial(
        provider: String,
        providerId: String,
        email: String?,
        name: String?,
        idToken: String?,
        nonce: String? = nil
    ) async throws {
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        var body: [String: Any] = [
            "provider": provider.uppercased(),
            "providerId": providerId
        ]
        if let email, !email.isEmpty { body["email"] = email }
        if let name, !name.isEmpty { body["name"] = name }
        if let idToken, !idToken.isEmpty { body["idToken"] = idToken }
        if let nonce, !nonce.isEmpty { body["nonce"] = nonce }

        let data = try await FormaAPIClient.shared.requestData(
            path: "/api/auth/social",
            method: "POST",
            jsonBody: body,
            authenticated: false,
            timeout: 10.0,
            interceptAccountStatus: false
        )
        try handleAuthSuccess(data: data, defaultProvider: provider.uppercased())
    }

    // MARK: - Recuperação, Alteração de Senha e Exclusão de Conta
    public func requestPasswordReset(email: String) async throws -> String {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanEmail.isEmpty else {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Informe o e-mail da sua conta."])
        }

        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        let data = try await FormaAPIClient.shared.requestData(
            path: "/api/auth/forgot-password",
            method: "POST",
            jsonBody: ["email": cleanEmail],
            authenticated: false,
            timeout: 10.0,
            interceptAccountStatus: false
        )

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let msg = json["message"] as? String, !msg.isEmpty {
            return msg
        }
        return "Se o e-mail estiver cadastrado, enviamos o código de 6 dígitos para redefinir sua senha."
    }

    public func resetPassword(email: String, code: String, newPassword: String) async throws {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanEmail.isEmpty, cleanCode.count == 6 else {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Informe o e-mail e o código de 6 dígitos."])
        }
        guard cleanPassword.count >= 6 else {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "A nova senha deve ter pelo menos 6 caracteres."])
        }

        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        let data = try await FormaAPIClient.shared.requestData(
            path: "/api/auth/reset-password",
            method: "POST",
            jsonBody: [
                "email": cleanEmail,
                "code": cleanCode,
                "newPassword": cleanPassword
            ],
            authenticated: false,
            timeout: 10.0,
            interceptAccountStatus: false
        )
        try handleAuthSuccess(data: data, defaultProvider: "EMAIL")
    }

    public func changePassword(currentPassword: String, newPassword: String) async throws {
        let cleanCurrent = currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNew = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanNew.count >= 6 else {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "A nova senha deve ter pelo menos 6 caracteres."])
        }

        _ = try await FormaAPIClient.shared.requestData(
            path: "/api/auth/change-password",
            method: "POST",
            jsonBody: [
                "currentPassword": cleanCurrent,
                "newPassword": cleanNew
            ],
            authenticated: true,
            timeout: 10.0
        )
    }

    public func deleteAccount() async throws {
        BackendSyncManager.shared.cancelPendingSyncs()
        _ = try await FormaAPIClient.shared.requestData(
            path: "/api/auth/account",
            method: "DELETE",
            authenticated: true,
            timeout: 15.0,
            interceptAccountStatus: false
        )
        logout()
    }

    // MARK: - Logout Seguro
    public func logout() {
        self.isAuthenticated = false
        self.isGuest = false
        self.jwtToken = nil
        self.currentUserId = nil
        self.currentUserEmail = nil
        self.currentUserName = nil
        self.currentAuthProvider = nil

        KeychainHelper.shared.delete(key: tokenKey)
        KeychainHelper.shared.delete(key: userIdKey)
        KeychainHelper.shared.delete(key: userEmailKey)
        KeychainHelper.shared.delete(key: userNameKey)
        KeychainHelper.shared.delete(key: authProviderKey)

        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: authProviderKey)
        UserDefaults.standard.removeObject(forKey: "forma_is_guest")
        UserDefaults.standard.removeObject(forKey: BackendSyncManager.activeLocalUserIdKey)
        UserDefaults.standard.removeObject(forKey: "forma_last_sync_timestamp")

        BackendSyncManager.shared.cancelPendingSyncs()
        BackendSyncManager.shared.markRequiresInitialPull(false)
        FormaDataStore.shared.resetLocalDataForUserSwitch(userName: nil, userEmail: nil)
    }

    // MARK: - Sucesso de Autenticação & Gravação Segura
    private func handleAuthSuccess(data: Data, defaultProvider: String) throws {
        struct AuthResponseModel: Decodable {
            let token: String
            let userId: String
            let email: String?
            let name: String?
            let authProvider: String?
        }

        let result = try JSONDecoder().decode(AuthResponseModel.self, from: data)
        let previousLocalUserId = UserDefaults.standard.string(forKey: BackendSyncManager.activeLocalUserIdKey)
        BackendSyncManager.shared.cancelPendingSyncs()

        if previousLocalUserId != result.userId {
            FormaDataStore.shared.resetLocalDataForUserSwitch(userName: result.name, userEmail: result.email)
            BackendSyncManager.shared.markRequiresInitialPull(true)
            UserDefaults.standard.set(result.userId, forKey: BackendSyncManager.activeLocalUserIdKey)
        }

        self.jwtToken = result.token
        self.currentUserId = result.userId
        self.currentUserEmail = result.email
        self.currentUserName = result.name
        self.currentAuthProvider = result.authProvider ?? defaultProvider
        self.isAuthenticated = true
        self.isGuest = false

        KeychainHelper.shared.save(key: tokenKey, string: result.token)
        KeychainHelper.shared.save(key: userIdKey, string: result.userId)
        if let email = result.email, !email.isEmpty {
            KeychainHelper.shared.save(key: userEmailKey, string: email)
        }
        if let name = result.name, !name.isEmpty {
            KeychainHelper.shared.save(key: userNameKey, string: name)
        }
        if let provider = self.currentAuthProvider, !provider.isEmpty {
            KeychainHelper.shared.save(key: authProviderKey, string: provider)
        }

        UserDefaults.standard.set(result.userId, forKey: userIdKey)
        UserDefaults.standard.set(result.email, forKey: userEmailKey)
        UserDefaults.standard.set(result.name, forKey: userNameKey)
        UserDefaults.standard.set(self.currentAuthProvider, forKey: authProviderKey)
        UserDefaults.standard.removeObject(forKey: "forma_is_guest")
    }
}
