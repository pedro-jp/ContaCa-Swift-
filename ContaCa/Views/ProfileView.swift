//
//  ProfileView.swift
//  ContaCa
//
//  Created by João Pedro on 10/17/26.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [Profile]
    @Query private var healthRecords: [Health]
    
    @FocusState private var isHeightFocused: Bool
    @FocusState private var isWeightFocused: Bool
    @State private var showSavedAlert: Bool = false
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var syncManager = BackendSyncManager.shared
    @ObservedObject private var liveActivityManager = LiveActivityManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = profiles.first {
                    @Bindable var bindableProfile = profile
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Header com Foto e Nome (Estilo Apple / Airbnb)
                        HStack(spacing: 16) {
                            Image("profile")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1.5))
                            
                            VStack(alignment: .leading, spacing: 3) {
                                TextField("Seu Nome", text: $bindableProfile.nome)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color("FontNormal"))
                                
                                Text(bindableProfile.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color("CardBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                        
                        // SEÇÃO 1: OBJETIVO FITNESS (GANHAR / PERDER / MANTER)
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "target")
                                    .foregroundColor(Color("AccentColor"))
                                Text("Objetivo Corporal")
                                    .font(.headline)
                                    .foregroundColor(Color("FontNormal"))
                            }
                            
                            Picker("Objetivo", selection: $bindableProfile.goal) {
                                ForEach(FitnessGoal.allCases) { goal in
                                    Text(goal.rawValue).tag(goal)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Text(bindableProfile.goal.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Divider()
                                .background(Color.primary.opacity(0.06))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Foco na Tela Inicial")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Color("FontNormal"))
                                
                                Picker("Foco", selection: Binding(
                                    get: { bindableProfile.effectiveFocus },
                                    set: { bindableProfile.preferredFocus = $0 }
                                )) {
                                    ForEach(FocusMetric.allCases) { focus in
                                        Text(focus.rawValue).tag(focus)
                                    }
                                }
                                .pickerStyle(.segmented)
                                
                                if bindableProfile.goal == .gain {
                                    Text("Recomendamos manter o foco em **Consumidas** para garantir o superávit diário.")
                                        .font(.caption)
                                        .foregroundColor(Color("AccentColor"))
                                }
                            }
                        }
                        .padding(20)
                        .background(Color("CardBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                        
                        // SEÇÃO 2: METAS DIÁRIAS (CONSUMIR, GASTAR, PASSOS, PESO ALVO)
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(Color("AccentColor"))
                                Text("Metas Diárias")
                                    .font(.headline)
                                    .foregroundColor(Color("FontNormal"))
                            }
                            
                            // Meta de Calorias a Consumir
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Calorias a Consumir")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(bindableProfile.targetCalorieIntake)) kcal")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(Color("AccentColor"))
                                }
                                Slider(value: $bindableProfile.targetCalorieIntake, in: 1200...4500, step: 50)
                                    .tint(Color("AccentColor"))
                            }
                            
                            // Meta de Calorias a Gastar
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Gasto Ativo em Treinos")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(bindableProfile.targetCalorieBurn)) kcal")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(Color("AccentGreen"))
                                }
                                Slider(value: $bindableProfile.targetCalorieBurn, in: 200...1500, step: 25)
                                    .tint(Color("AccentGreen"))
                            }
                            
                            // Meta de Passos
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Passos Diários")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(bindableProfile.targetSteps)) passos")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(Color("FontNormal"))
                                }
                                Slider(value: $bindableProfile.targetSteps, in: 3000...20000, step: 500)
                                    .tint(.blue)
                            }
                            
                            // Meta de Peso
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Peso Alvo")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "%.1f kg", bindableProfile.targetWeight))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(Color("AccentColor"))
                                }
                                Slider(value: $bindableProfile.targetWeight, in: 40...140, step: 0.5)
                                    .tint(Color("AccentColor"))
                            }
                            
                            // Meta de Ingestão de Água
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    HStack(spacing: 4) {
                                        Image(systemName: "drop.fill")
                                            .font(.caption)
                                            .foregroundColor(.cyan)
                                        Text("Meta de Água")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("\(bindableProfile.targetWaterMilliliters) ml")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(.cyan)
                                }
                                Slider(
                                    value: Binding(
                                        get: { Double(bindableProfile.targetWaterMilliliters) },
                                        set: { bindableProfile.targetWaterMilliliters = Int($0) }
                                    ),
                                    in: 1000...5000,
                                    step: 250
                                )
                                .tint(.cyan)
                            }
                        }
                        .padding(20)
                        .background(Color("CardBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                        
                        // SEÇÃO 3: DADOS BIOMÉTRICOS
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "figure.arms.open")
                                    .foregroundColor(Color("AccentColor"))
                                Text("Dados Biométricos")
                                    .font(.headline)
                                    .foregroundColor(Color("FontNormal"))
                            }
                            
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Altura")
                                        .font(.caption2.weight(.medium))
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 3) {
                                        TextField("1.78", value: $bindableProfile.height, format: .number.precision(.fractionLength(2)))
                                            .textFieldStyle(.plain)
                                            .keyboardType(.decimalPad)
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                        Text("m")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(14)
                                .background(Color(.systemBackground).opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Peso Atual")
                                        .font(.caption2.weight(.medium))
                                        .foregroundColor(.secondary)
                                    HStack(spacing: 3) {
                                        TextField("72.0", value: $bindableProfile.currentWeight, format: .number.precision(.fractionLength(1)))
                                            .textFieldStyle(.plain)
                                            .keyboardType(.decimalPad)
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                        Text("kg")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(14)
                                .background(Color(.systemBackground).opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                        .padding(20)
                        .background(Color("CardBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                        
                        // SEÇÃO 4: METAS DE MACRONUTRIENTES
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "chart.pie.fill")
                                    .foregroundColor(Color("AccentColor"))
                                Text("Metas de Macronutrientes")
                                    .font(.headline)
                                    .foregroundColor(Color("FontNormal"))
                                Spacer()
                                
                                Button("Sugerir") {
                                    suggestOptimalMacros(profile: bindableProfile)
                                }
                                .font(.caption.weight(.bold))
                                .foregroundColor(Color("AccentColor"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color("AccentMinor"))
                                .clipShape(Capsule())
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Proteína")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(bindableProfile.targetProtein)) g")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(Color("AccentGreen"))
                                }
                                Slider(value: $bindableProfile.targetProtein, in: 50...350, step: 5)
                                    .tint(Color("AccentGreen"))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Carboidratos")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(bindableProfile.targetCarbohydrates)) g")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(Color("AccentColor"))
                                }
                                Slider(value: $bindableProfile.targetCarbohydrates, in: 50...600, step: 5)
                                    .tint(Color("AccentColor"))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Gorduras")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(bindableProfile.targetFat)) g")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(.orange)
                                }
                                Slider(value: $bindableProfile.targetFat, in: 20...200, step: 2)
                                    .tint(.orange)
                            }
                        }
                        .padding(20)
                        .background(Color("CardBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                        
                        // SEÇÃO: CONTA DO USUÁRIO
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundColor(Color("AccentColor"))
                                Text("Conta")
                                    .font(.headline)
                                    .foregroundColor(Color("FontNormal"))
                                Spacer()
                                if authManager.isAuthenticated {
                                    Text("Ativa")
                                        .font(.caption2.weight(.bold))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.green.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                            
                            HStack(spacing: 14) {
                                Circle()
                                    .fill(Color("AccentColor").opacity(0.15))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Image(systemName: authManager.currentAuthProvider == "APPLE" ? "applelogo" : (authManager.currentAuthProvider == "GOOGLE" ? "g.circle.fill" : "person.fill"))
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundColor(Color("AccentColor"))
                                    )
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(authManager.currentUserName ?? "Usuário ContaCa")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Color("FontNormal"))
                                    
                                    if let email = authManager.currentUserEmail, !email.isEmpty {
                                        Text(email)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            
                            Divider()
                                .padding(.vertical, 2)
                            
                            // Botão de Sair da Conta
                            Button(role: .destructive) {
                                authManager.logout()
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Sair da Conta")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                        .padding(20)
                        .background(Color("CardBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                        
                        // SEÇÃO 7: INTEGRAÇÕES & PLUGINS
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "puzzlepiece.extension.fill")
                                    .foregroundColor(Color("AccentColor"))
                                Text("Integrações & Plugins")
                                    .font(.headline)
                                    .foregroundColor(Color("FontNormal"))
                            }
                            
                            // Card Strava (Futuro Plugin)
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    HStack(spacing: -2) {
                                        Image(systemName: "figure.run")
                                            .font(.system(size: 13, weight: .bold))
                                        Image(systemName: "figure.outdoor.cycle")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .foregroundColor(.orange)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text("Strava")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Color("FontNormal"))
                                        
                                        Text("FUTURO PLUGIN")
                                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.14))
                                            .clipShape(Capsule())
                                    }
                                    
                                    Text("Sincronização de corridas, pedaladas e atividades esportivas outdoor.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(14)
                            .background(Color(.systemBackground).opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .padding(20)
                        .background(Color("CardBackground"))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                        
                        // BOTÃO SALVAR (Estilo Apple / Airbnb)
                        Button {
                            try? modelContext.save()
                            ContaCaDataStore.shared.syncTodayData()
                            Task {
                                await syncManager.sync(context: modelContext)
                            }
                            showSavedAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Salvar Configurações")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color("AccentColor"))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                        .padding(.bottom, 30)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                } else {
                    ProgressView()
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .alert("Configurações Salvas", isPresented: $showSavedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Suas metas e preferências foram atualizadas com sucesso!")
            }
            .task {
                if profiles.isEmpty {
                    let newProfile = Profile()
                    modelContext.insert(newProfile)
                    try? modelContext.save()
                }
            }
        }
    }
    
    // Sugere distribuição científica de macros
    private func suggestOptimalMacros(profile: Profile) {
        let weight = max(45.0, profile.currentWeight)
        let goal = profile.goal
        
        switch goal {
        case .gain:
            let protein = (weight * 2.0).rounded()
            let fat = (weight * 1.0).rounded()
            let remainingCalories = profile.targetCalorieIntake - (protein * 4.0) - (fat * 9.0)
            let carbs = max(100.0, (remainingCalories / 4.0).rounded())
            profile.macros = Macros(protein: protein, fat: fat, carbohydrates: carbs)
            
        case .lose:
            let protein = (weight * 2.2).rounded()
            let fat = (weight * 0.8).rounded()
            let remainingCalories = profile.targetCalorieIntake - (protein * 4.0) - (fat * 9.0)
            let carbs = max(60.0, (remainingCalories / 4.0).rounded())
            profile.macros = Macros(protein: protein, fat: fat, carbohydrates: carbs)
            
        case .maintain:
            let protein = (weight * 1.8).rounded()
            let fat = (weight * 0.9).rounded()
            let remainingCalories = profile.targetCalorieIntake - (protein * 4.0) - (fat * 9.0)
            let carbs = max(80.0, (remainingCalories / 4.0).rounded())
            profile.macros = Macros(protein: protein, fat: fat, carbohydrates: carbs)
        }
        
        try? modelContext.save()
    }
}

#Preview {
    ProfileView()
        .modelContainer(PreviewContainer.shared)
}
