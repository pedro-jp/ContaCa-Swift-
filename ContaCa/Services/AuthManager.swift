//
//  AuthManager.swift
//  ContaCa
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
    
    // MARK: - Chaves de Armazenamento Seguro
    private let tokenKey = "contaca_jwt_token"
    private let userIdKey = "contaca_user_id"
    private let userEmailKey = "contaca_user_email"
    private let userNameKey = "contaca_user_name"
    private let authProviderKey = "contaca_auth_provider"
    
    // IP padrão configurado para a rede Wi-Fi local do Mac desenvolvedor
    public static let defaultServerUrl = "http://192.168.1.12:8085"
    public static let fallbackLocalUrl = "http://localhost:8085"
    
    // MARK: - Estados Publicados
    @Published public var isAuthenticated: Bool = false
    @Published public var isGuest: Bool = false // Sempre false no app real
    @Published public var currentUserId: String? = nil
    @Published public var currentUserEmail: String? = nil
    @Published public var currentUserName: String? = nil
    @Published public var currentAuthProvider: String? = nil
    @Published public var jwtToken: String? = nil
    @Published public var isAuthenticating: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var serverBaseUrl: String
    
    private init() {
        self.serverBaseUrl = AuthManager.defaultServerUrl
        restoreSession()
    }
    
    // MARK: - Restauração de Sessão Segura via Keychain
    public func restoreSession() {
        // Tenta carregar token seguro do Keychain (com fallback retrocompatível)
        let token = KeychainHelper.shared.loadString(key: tokenKey) ?? UserDefaults.standard.string(forKey: tokenKey)
        let userId = UserDefaults.standard.string(forKey: userIdKey)
        
        if let token = token, !token.isEmpty, let userId = userId, !userId.isEmpty {
            self.jwtToken = token
            self.currentUserId = userId
            self.currentUserEmail = UserDefaults.standard.string(forKey: userEmailKey)
            self.currentUserName = UserDefaults.standard.string(forKey: userNameKey)
            self.currentAuthProvider = UserDefaults.standard.string(forKey: authProviderKey)
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
        
        let body = ["email": cleanEmail, "password": cleanPassword]
        let data = try await performNetworkRequest(path: "/api/auth/login", method: "POST", body: body)
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
        
        if cleanPassword.count < 6 {
            throw NSError(domain: "Auth", code: 400, userInfo: [NSLocalizedDescriptionKey: "A senha deve ter pelo menos 6 caracteres."])
        }
        
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }
        
        let body = ["name": cleanName, "email": cleanEmail, "password": cleanPassword]
        let data = try await performNetworkRequest(path: "/api/auth/register", method: "POST", body: body)
        try handleAuthSuccess(data: data, defaultProvider: "EMAIL")
    }
    
    // MARK: - Login Social Seguro (Google ou Apple ID)
    public func loginWithSocial(
        provider: String,
        providerId: String,
        email: String?,
        name: String?,
        idToken: String?
    ) async throws {
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }
        
        var body: [String: Any] = [
            "provider": provider.uppercased(),
            "providerId": providerId
        ]
        if let email = email, !email.isEmpty { body["email"] = email }
        if let name = name, !name.isEmpty { body["name"] = name }
        if let idToken = idToken, !idToken.isEmpty { body["idToken"] = idToken }
        
        let data = try await performNetworkRequest(path: "/api/auth/social", method: "POST", body: body)
        try handleAuthSuccess(data: data, defaultProvider: provider.uppercased())
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
        
        // Remove do Keychain com criptografia
        KeychainHelper.shared.delete(key: tokenKey)
        
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: authProviderKey)
        UserDefaults.standard.removeObject(forKey: "contaca_is_guest")
    }
    
    // MARK: - Requisição de Rede com Resiliência Automática de IP
    private func performNetworkRequest(path: String, method: String, body: [String: Any]) async throws -> Data {
        let candidateHosts = [serverBaseUrl, AuthManager.defaultServerUrl, AuthManager.fallbackLocalUrl]
        var lastError: Error = NSError(domain: "Auth", code: 500, userInfo: [NSLocalizedDescriptionKey: "Não foi possível conectar ao servidor."])
        
        for base in candidateHosts {
            var cleanBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanBase.hasSuffix("/") { cleanBase = String(cleanBase.dropLast()) }
            
            guard let url = URL(string: "\(cleanBase)\(path)") else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 8.0
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    if http.statusCode == 200 {
                        // Salva o host que funcionou como base principal
                        if self.serverBaseUrl != cleanBase {
                            self.serverBaseUrl = cleanBase
                        }
                        return data
                    } else {
                        let errStr = parseErrorMessage(from: data, defaultMessage: "Falha na autenticação (\(http.statusCode)).")
                        throw NSError(domain: "Auth", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: errStr])
                    }
                }
            } catch let err as NSError where err.domain == "Auth" {
                throw err // Erro de credenciais/validação emitido pelo backend
            } catch {
                lastError = error
                // Tenta próximo host candidato (ex: Wi-Fi vs Localhost)
                continue
            }
        }
        
        throw lastError
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
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(AuthResponseModel.self, from: data)
        
        self.jwtToken = result.token
        self.currentUserId = result.userId
        self.currentUserEmail = result.email
        self.currentUserName = result.name
        self.currentAuthProvider = result.authProvider ?? defaultProvider
        self.isAuthenticated = true
        self.isGuest = false
        
        // Gravação Criptografada no Keychain
        KeychainHelper.shared.save(key: tokenKey, string: result.token)
        
        UserDefaults.standard.set(result.userId, forKey: userIdKey)
        UserDefaults.standard.set(result.email, forKey: userEmailKey)
        UserDefaults.standard.set(result.name, forKey: userNameKey)
        UserDefaults.standard.set(self.currentAuthProvider, forKey: authProviderKey)
        UserDefaults.standard.removeObject(forKey: "contaca_is_guest")
    }
    
    private func parseErrorMessage(from data: Data, defaultMessage: String) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = json["error"] as? String { return error }
            if let message = json["message"] as? String { return message }
        }
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }
        return defaultMessage
    }
}
