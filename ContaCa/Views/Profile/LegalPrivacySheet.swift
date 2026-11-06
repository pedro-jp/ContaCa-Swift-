//
//  LegalPrivacySheet.swift
//  ContaCa
//
//  Política de Privacidade, aviso de saúde/nutrição e fluxos de redefinição e troca de senha.
//

import SwiftUI

struct LegalPrivacySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    FormaCard(padding: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.raised.shield.fill")
                                    .foregroundStyle(FormaTheme.Colors.brand)
                                Text("Privacidade & Dados Pessoais")
                                    .font(.headline)
                                    .foregroundStyle(FormaTheme.Colors.primaryText)
                            }
                            Text("O Forma coleta apenas os dados necessários para calcular suas metas diárias e sincronizar seu progresso: nome, e-mail, refeições (incluindo fotos ou áudio enviados por você para identificação de alimentos), ingestão de água, treinos, fichas e pesagens.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Seus dados nunca são vendidos a terceiros nem usados para publicidade ou rastreamento entre aplicativos.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(FormaTheme.Colors.brand)
                        }
                    }

                    FormaCard(padding: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.text.square.fill")
                                    .foregroundStyle(FormaTheme.Colors.energyGreen)
                                Text("Integração com o Apple Saúde")
                                    .font(.headline)
                                    .foregroundStyle(FormaTheme.Colors.primaryText)
                            }
                            Text("Com sua autorização explícita no iOS, o Forma lê seus passos, calorias em movimento e treinos registrados no Apple Saúde, além de salvar os treinos concluídos no app. Você pode gerenciar ou revogar essas permissões a qualquer momento nos Ajustes do iPhone > Saúde.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    FormaCard(padding: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "stethoscope")
                                    .foregroundStyle(FormaTheme.Colors.warning)
                                Text("Aviso de Saúde, Nutrição e Bem-Estar")
                                    .font(.headline)
                                    .foregroundStyle(FormaTheme.Colors.primaryText)
                            }
                            Text("As estimativas calóricas, metas diárias e recomendações da Inteligência Forma têm caráter exclusivamente informativo e educacional, baseadas em referências públicas de fisiologia e nutrição (como a fórmula de Mifflin-St Jeor e a Tabela Brasileira de Composição de Alimentos).")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("O Forma não realiza diagnóstico médico e não substitui a orientação de médico, nutricionista ou profissional de educação física. Consulte um profissional de saúde antes de iniciar dietas restritivas ou rotinas intensas de treino.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    FormaCard(padding: 18) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "trash.slash.fill")
                                    .foregroundStyle(FormaTheme.Colors.danger)
                                Text("Controle Total & Exclusão de Conta")
                                    .font(.headline)
                                    .foregroundStyle(FormaTheme.Colors.primaryText)
                            }
                            Text("Você pode excluir permanentemente sua conta e todos os dados armazenados nos nossos servidores e neste aparelho a qualquer momento acessando Perfil > Conta > Excluir Minha Conta.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, FormaTheme.Spacing.screenHorizontal)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .background(FormaTheme.Colors.pageBackground.ignoresSafeArea())
            .navigationTitle("Privacidade & Saúde")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct PasswordRecoverySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthManager.shared

    @State private var emailText: String
    @State private var codeText: String = ""
    @State private var newPasswordText: String = ""
    @State private var stepSentCode: Bool = false
    @State private var statusMessage: String? = nil
    @State private var errorMessage: String? = nil
    @State private var isSubmitting: Bool = false

    var onRecoverySuccess: () -> Void

    init(initialEmail: String = "", onRecoverySuccess: @escaping () -> Void) {
        _emailText = State(initialValue: initialEmail)
        self.onRecoverySuccess = onRecoverySuccess
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(stepSentCode
                         ? "Digite o código de 6 dígitos enviado para seu e-mail e escolha uma nova senha."
                         : "Informe o e-mail da sua conta para receber um código de 6 dígitos e criar uma nova senha.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            TextField("Seu e-mail cadastrado", text: $emailText)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(14)
                        .background(FormaTheme.Colors.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        if stepSentCode {
                            HStack(spacing: 12) {
                                Image(systemName: "number")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                TextField("Código de 6 dígitos", text: $codeText)
                                    .keyboardType(.numberPad)
                            }
                            .padding(14)
                            .background(FormaTheme.Colors.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                SecureField("Nova senha (mín. 6 caracteres)", text: $newPasswordText)
                                    .textContentType(.newPassword)
                            }
                            .padding(14)
                            .background(FormaTheme.Colors.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    if let statusMessage {
                        FormaBanner(message: statusMessage, style: .info)
                    }
                    if let errorMessage {
                        FormaBanner(message: errorMessage, style: .error)
                    }

                    Button {
                        if stepSentCode {
                            confirmReset()
                        } else {
                            sendCode()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            }
                            Text(stepSentCode ? "Redefinir Senha e Entrar" : "Enviar Código de Recuperação")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(FormaTheme.Colors.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isSubmitting)

                    if !stepSentCode {
                        Button {
                            stepSentCode = true
                        } label: {
                            Text("Já tenho um código de 6 dígitos")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(FormaTheme.Colors.brand)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, FormaTheme.Spacing.screenHorizontal)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
            .background(FormaTheme.Colors.pageBackground.ignoresSafeArea())
            .navigationTitle("Recuperar Senha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func sendCode() {
        errorMessage = nil
        statusMessage = nil
        isSubmitting = true
        Task {
            do {
                let message = try await authManager.requestPasswordReset(email: emailText)
                statusMessage = message
                stepSentCode = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    private func confirmReset() {
        errorMessage = nil
        isSubmitting = true
        Task {
            do {
                try await authManager.resetPassword(
                    email: emailText,
                    code: codeText,
                    newPassword: newPasswordText
                )
                isSubmitting = false
                dismiss()
                onRecoverySuccess()
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}

struct ChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthManager.shared

    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var errorMessage: String? = nil
    @State private var isSaving: Bool = false

    var onSaved: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Atualize a senha de acesso da sua conta Forma.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    SecureField("Senha atual", text: $currentPassword)
                        .textContentType(.password)
                        .padding(14)
                        .background(FormaTheme.Colors.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    SecureField("Nova senha (mín. 6 caracteres)", text: $newPassword)
                        .textContentType(.newPassword)
                        .padding(14)
                        .background(FormaTheme.Colors.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if let errorMessage {
                        FormaBanner(message: errorMessage, style: .error)
                    }

                    Button {
                        saveNewPassword()
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView().tint(.white)
                            }
                            Text("Salvar Nova Senha")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(FormaTheme.Colors.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isSaving)
                }
                .padding(.horizontal, FormaTheme.Spacing.screenHorizontal)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
            .background(FormaTheme.Colors.pageBackground.ignoresSafeArea())
            .navigationTitle("Alterar Senha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    private func saveNewPassword() {
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await authManager.changePassword(
                    currentPassword: currentPassword,
                    newPassword: newPassword
                )
                isSaving = false
                dismiss()
                onSaved()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}
