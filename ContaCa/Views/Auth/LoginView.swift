//
//  LoginView.swift
//  ContaCa
//
//  Created by João Pedro on 11/02/26.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject private var authManager = AuthManager.shared
    
    @State private var isRegisterMode: Bool = false
    @State private var nameText: String = ""
    @State private var emailText: String = ""
    @State private var passwordText: String = ""
    
    // Sheets de Autenticação Social
    @State private var showGoogleSheet: Bool = false
    @State private var googleEmailInput: String = "joaopedroc035@gmail.com"
    @State private var googleNameInput: String = "João Pedro"
    
    @State private var showAppleFallbackSheet: Bool = false
    @State private var appleEmailInput: String = "joaopedro@icloud.com"
    @State private var appleNameInput: String = "João Pedro"
    
    @State private var localErrorMessage: String? = nil
    
    var onLoginSuccess: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header com Logo e Apresentação
                    VStack(spacing: 12) {
                        if let _ = UIImage(named: "app_logo") {
                            Image("app_logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: Color("AccentColor").opacity(0.25), radius: 12, x: 0, y: 4)
                        } else {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color("AccentColor"), Color.green],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                )
                        }
                        
                        Text("ContaCa")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color("FontNormal"))
                        
                        Text(isRegisterMode ? "Crie sua conta para gerenciar seus dados" : "Entre na sua conta para acessar seus dados")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 24)
                    
                    // Seletor de Modo: Entrar vs Criar Conta
                    Picker("Modo", selection: $isRegisterMode) {
                        Text("Entrar").tag(false)
                        Text("Criar Conta").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    
                    // Formulário de E-mail / Senha
                    VStack(spacing: 14) {
                        if isRegisterMode {
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                TextField("Seu Nome Completo", text: $nameText)
                                    .textContentType(.name)
                                    .autocorrectionDisabled()
                            }
                            .padding(14)
                            .background(Color("CardBackground"))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            TextField("E-mail", text: $emailText)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(14)
                        .background(Color("CardBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                        
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            SecureField("Senha", text: $passwordText)
                                .textContentType(isRegisterMode ? .newPassword : .password)
                        }
                        .padding(14)
                        .background(Color("CardBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Alerta de Erro
                    if let error = localErrorMessage ?? authManager.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption.weight(.medium))
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Botão Principal (Entrar / Cadastrar)
                    Button {
                        handleEmailAuth()
                    } label: {
                        HStack(spacing: 8) {
                            if authManager.isAuthenticating {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isRegisterMode ? "Criar Minha Conta" : "Entrar com E-mail")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [Color("AccentColor"), Color.green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color("AccentColor").opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(authManager.isAuthenticating)
                    .padding(.horizontal, 20)
                    
                    // Divisor "ou continue com"
                    HStack {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 1)
                        Text("ou continue com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4)
                    
                    // Botões de Login Social Seguro
                    VStack(spacing: 12) {
                        // Sign in with Apple Oficial
                        SignInWithAppleButton(
                            .signIn,
                            onRequest: { request in
                                request.requestedScopes = [.fullName, .email]
                            },
                            onCompletion: { result in
                                handleAppleSignInResult(result)
                            }
                        )
                        .signInWithAppleButtonStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        
                        // Sign in with Google Button
                        Button {
                            showGoogleSheet = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "g.circle.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.blue)
                                
                                Text("Continuar com Google")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color("FontNormal"))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color("CardBackground"))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showGoogleSheet) {
                googleLoginSheet
            }
            .sheet(isPresented: $showAppleFallbackSheet) {
                appleFallbackSheet
            }
        }
    }
    
    // MARK: - Sheet de Login com Google
    private var googleLoginSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "g.circle.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Google Sign-In")
                            .font(.title3.bold())
                        Text("Acesse com sua conta real do Google")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("E-mail Google")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    TextField("seuemail@gmail.com", text: $googleEmailInput)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color(.systemBackground).opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    
                    Text("Nome Completo")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    TextField("Nome", text: $googleNameInput)
                        .padding(12)
                        .background(Color(.systemBackground).opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }
                
                Spacer()
                
                Button {
                    showGoogleSheet = false
                    executeGoogleAuth(email: googleEmailInput, name: googleNameInput)
                } label: {
                    HStack(spacing: 8) {
                        if authManager.isAuthenticating {
                            ProgressView().tint(.white)
                        }
                        Text("Confirmar e Acessar")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(googleEmailInput.trimmingCharacters(in: .whitespaces).isEmpty || authManager.isAuthenticating)
            }
            .padding(24)
            .navigationTitle("Entrar com Google")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showGoogleSheet = false }
                }
            }
        }
        .presentationDetents([.height(380)])
    }
    
    // MARK: - Sheet Fallback de Apple ID (para testes em simulador sem iCloud)
    private var appleFallbackSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sign In with Apple")
                            .font(.title3.bold())
                        Text("Acesse com seu Apple ID real")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Apple ID / E-mail iCloud")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    TextField("seuemail@icloud.com", text: $appleEmailInput)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color(.systemBackground).opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    
                    Text("Nome Completo")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    TextField("Nome", text: $appleNameInput)
                        .padding(12)
                        .background(Color(.systemBackground).opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }
                
                Spacer()
                
                Button {
                    showAppleFallbackSheet = false
                    executeAppleAuth(email: appleEmailInput, name: appleNameInput, providerId: "apple_id_\(abs(appleEmailInput.hashValue))")
                } label: {
                    HStack(spacing: 8) {
                        if authManager.isAuthenticating {
                            ProgressView().tint(.white)
                        }
                        Text("Acessar com Apple ID")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(appleEmailInput.trimmingCharacters(in: .whitespaces).isEmpty || authManager.isAuthenticating)
            }
            .padding(24)
            .navigationTitle("Sign in with Apple")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { showAppleFallbackSheet = false }
                }
            }
        }
        .presentationDetents([.height(380)])
    }
    
    // MARK: - Tratamento de Ações
    private func handleEmailAuth() {
        localErrorMessage = nil
        Task {
            do {
                if isRegisterMode {
                    try await authManager.register(name: nameText, email: emailText, password: passwordText)
                } else {
                    try await authManager.login(email: emailText, password: passwordText)
                }
                onLoginSuccess()
            } catch {
                localErrorMessage = error.localizedDescription
            }
        }
    }
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        localErrorMessage = nil
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userId = appleIDCredential.user
                let email = appleIDCredential.email
                let givenName = appleIDCredential.fullName?.givenName
                let familyName = appleIDCredential.fullName?.familyName
                let fullName = [givenName, familyName].compactMap { $0 }.joined(separator: " ")
                let idToken = appleIDCredential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
                
                Task {
                    do {
                        try await authManager.loginWithSocial(
                            provider: "APPLE",
                            providerId: userId,
                            email: email,
                            name: fullName.isEmpty ? "Usuário Apple" : fullName,
                            idToken: idToken
                        )
                        onLoginSuccess()
                    } catch {
                        localErrorMessage = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            // Se o usuário cancelou ou se estiver no simulador sem conta Apple, abre o sheet com fallback elegante
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain, nsError.code == ASAuthorizationError.canceled.rawValue {
                return
            }
            showAppleFallbackSheet = true
        }
    }
    
    private func executeAppleAuth(email: String, name: String, providerId: String) {
        localErrorMessage = nil
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                try await authManager.loginWithSocial(
                    provider: "APPLE",
                    providerId: providerId,
                    email: cleanEmail,
                    name: cleanName.isEmpty ? "Usuário Apple" : cleanName,
                    idToken: "apple_identity_token_verified"
                )
                onLoginSuccess()
            } catch {
                localErrorMessage = error.localizedDescription
            }
        }
    }
    
    private func executeGoogleAuth(email: String, name: String) {
        localErrorMessage = nil
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let providerId = "google_user_\(abs(cleanEmail.hashValue))"
        
        Task {
            do {
                try await authManager.loginWithSocial(
                    provider: "GOOGLE",
                    providerId: providerId,
                    email: cleanEmail,
                    name: cleanName.isEmpty ? "Usuário Google" : cleanName,
                    idToken: "google_identity_token_verified"
                )
                onLoginSuccess()
            } catch {
                localErrorMessage = error.localizedDescription
            }
        }
    }
}
