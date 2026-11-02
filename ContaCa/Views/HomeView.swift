//
//  HomeView.swift
//  ContaCa
//
//  Created by João Pedro on 10/13/26.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Dados persistidos via SwiftData
    @Query private var profiles: [Profile]
    @Query private var healthRecords: [Health]
    @Query(sort: \FoodEntry.createdAt, order: .reverse) private var allFoods: [FoodEntry]
    @Query(sort: \WorkoutEntry.date, order: .reverse) private var allWorkouts: [WorkoutEntry]
    @Query(sort: \WaterEntry.date, order: .reverse) private var allWaterEntries: [WaterEntry]
    
    @StateObject private var healthVM = HealthViewModel()
    @ObservedObject private var router = AppNavigationRouter.shared
    @ObservedObject private var liveActivityManager = LiveActivityManager.shared
    
    // Controle da métrica em exibição no círculo principal
    @State private var activeMetric: FocusMetric = .consumed
    
    // Sheets de ação rápida
    @State private var showAddWorkoutSheet: Bool = false
    @State private var showLogWeightSheet: Bool = false
    @State private var showClearConfirmAlert: Bool = false
    
    // Perfil do usuário
    private var profile: Profile? {
        profiles.first
    }
    
    private var nomeUsuario: String {
        profile?.nome ?? "João Pedro"
    }
    
    private var objetivo: FitnessGoal {
        profile?.goal ?? .gain
    }
    
    // Metas
    private var metaCaloriasConsumir: Double {
        profile?.targetCalorieIntake ?? 2800.0
    }
    
    private var metaCaloriasGastar: Double {
        profile?.targetCalorieBurn ?? 600.0
    }
    
    private var metaPassos: Double {
        profile?.targetSteps ?? 8000.0
    }
    
    private var metaProtein: Double {
        if let p = profile, p.targetProtein > 0 { return p.targetProtein }
        return healthRecords.first?.protein ?? 160.0
    }
    
    private var metaFat: Double {
        if let p = profile, p.targetFat > 0 { return p.targetFat }
        return healthRecords.first?.fat ?? 70.0
    }
    
    private var metaCarbo: Double {
        if let p = profile, p.targetCarbohydrates > 0 { return p.targetCarbohydrates }
        return healthRecords.first?.carbohydrates ?? 380.0
    }
    
    // Alimentos consumidos hoje
    private var foodsToday: [FoodEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return allFoods.filter { entry in
            calendar.isDateInToday(entry.date) ||
            calendar.isDate(entry.date, inSameDayAs: Date()) ||
            calendar.startOfDay(for: entry.date) == today
        }
    }
    
    private var caloriasConsumidasHoje: Double {
        foodsToday.reduce(0.0) { $0 + $1.calories }
    }
    
    private var proteinasConsumidasHoje: Double {
        foodsToday.reduce(0.0) { $0 + $1.protein }
    }
    
    private var carbosConsumidosHoje: Double {
        foodsToday.reduce(0.0) { $0 + $1.carbohydrates }
    }
    
    private var gordurasConsumidasHoje: Double {
        foodsToday.reduce(0.0) { $0 + $1.fat }
    }
    
    // Treinos de hoje
    private var workoutsToday: [WorkoutEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return allWorkouts.filter {
            calendar.isDateInToday($0.date) || calendar.startOfDay(for: $0.date) == today
        }
    }
    
    // Calorias gastas em treinos hoje
    private var caloriasTreinosHoje: Double {
        workoutsToday.reduce(0.0) { $0 + $1.caloriesBurned }
    }
    
    // Total de calorias ativas gastas (Apple Health + treinos registrados no app)
    private var caloriasGastasAtivas: Double {
        max(healthVM.activeCalories, caloriasTreinosHoje)
    }
    
    // Total de calorias gastas (Taxa Metabólica Basal TMB + Treinos/Atividades)
    private var caloriasGastasTotal: Double {
        (profile?.tmb ?? 1800.0) + caloriasGastasAtivas
    }
    
    private var metaCaloriasGastarTotal: Double {
        (profile?.tmb ?? 1800.0) + metaCaloriasGastar
    }
    
    // Água registrada hoje
    private var waterToday: [WaterEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return allWaterEntries.filter {
            calendar.isDateInToday($0.date) || calendar.startOfDay(for: $0.date) == today
        }
    }
    
    private var waterConsumedToday: Int {
        waterToday.reduce(0) { $0 + $1.milliliters }
    }
    
    private var waterTarget: Int {
        profile?.targetWaterMilliliters ?? 2500
    }
    
    private func addWater(milliliters: Int) {
        let entry = WaterEntry(milliliters: milliliters, date: Date())
        try? ContaCaDataStore.shared.insertWaterEntry(entry)
    }
    
    // Meta de consumo diário ajustada (as calorias do treino somam na meta permitida/necessária)
    private var metaCaloriasConsumirAjustada: Double {
        metaCaloriasConsumir + caloriasTreinosHoje
    }
    
    // Saldo / Calorias restantes no dia
    private var caloriasRestantesHoje: Double {
        metaCaloriasConsumirAjustada - caloriasConsumidasHoje
    }
    
    // Percentual para o círculo principal
    private var percentualPrincipal: Int {
        if activeMetric == .consumed {
            guard metaCaloriasConsumirAjustada > 0 else { return 0 }
            return Int((caloriasConsumidasHoje / metaCaloriasConsumirAjustada) * 100)
        } else {
            guard metaCaloriasGastar > 0 else { return 0 }
            return Int((caloriasGastasAtivas / metaCaloriasGastar) * 100)
        }
    }
    
    func saudacao(nome: String) -> String {
        let hora = Calendar.current.component(.hour, from: .now)
        switch hora {
        case 5..<12: return "Bom dia, \(nome)"
        case 12..<18: return "Boa tarde, \(nome)"
        default: return "Boa noite, \(nome)"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header de Perfil & Saudação (Apple / Airbnb Clean)
                    HStack(spacing: 14) {
                        Image("profile")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1.5))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(saudacao(nome: nomeUsuario))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Color("FontNormal"))
                                .lineLimit(1)
                            
                            Text(
                                Date.now.formatted(
                                    .dateTime
                                        .weekday(.wide)
                                        .day()
                                        .month(.wide)
                                        .locale(Locale(identifier: "pt_BR"))
                                )
                                .capitalized
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // Badge do Objetivo (Ganho / Perda)
                        HStack(spacing: 4) {
                            Image(systemName: objetivo.icon)
                                .font(.system(size: 11))
                            Text(objetivo == .gain ? "Ganho" : (objetivo == .lose ? "Perda" : "Manutenção"))
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(Color("AccentColor"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color("AccentMinor"))
                        .clipShape(Capsule())
                    }
                    
                    // CARD PRINCIPAL: BALANÇO DIÁRIO COM SELETOR CONSUMIDA / GASTA
                    VStack(alignment: .leading, spacing: 18) {
                        // Header do Card
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(activeMetric == .consumed ? "Balanço Calórico" : "Queima Ativa")
                                    .font(.headline)
                                    .foregroundColor(Color("FontNormal"))
                                Text(activeMetric == .consumed ? "Calorias do treino somadas à sua meta" : "Calorias ativas registradas")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Badge de percentual
                            Text("\(percentualPrincipal)%")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .foregroundColor(Color("AccentColor"))
                                .font(.subheadline.weight(.bold))
                                .background(Color("AccentMinor"))
                                .clipShape(Capsule())
                        }
                        
                        // Segmented Control Apple Clean
                        Picker("Foco", selection: $activeMetric) {
                            Text("Consumidas").tag(FocusMetric.consumed)
                            Text("Gastas").tag(FocusMetric.burned)
                        }
                        .pickerStyle(.segmented)
                        
                        // Círculo de Progresso Principal
                        HStack(alignment: .center) {
                            if activeMetric == .consumed {
                                CircularProgress(
                                    count: caloriasConsumidasHoje,
                                    meta: metaCaloriasConsumirAjustada,
                                    color: Color("AccentColor"),
                                    lineWidth: 12,
                                    metricLabel: "consumidas",
                                    isBulkingMode: objetivo == .gain
                                )
                                .frame(width: 170, height: 170)
                            } else {
                                CircularProgress(
                                    count: caloriasGastasAtivas,
                                    meta: metaCaloriasGastar,
                                    color: Color("AccentGreen"),
                                    lineWidth: 12,
                                    metricLabel: "gastas",
                                    isBulkingMode: false
                                )
                                .frame(width: 170, height: 170)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        
                        // Balanço lado a lado: Consumidas, Treino (Saúde) e Saldo Disponível
                        HStack(spacing: 10) {
                            BalanceMetricBox(
                                title: "Consumidas",
                                value: "\(Int(caloriasConsumidasHoje))",
                                meta: "meta \(Int(metaCaloriasConsumirAjustada))",
                                color: Color("AccentColor"),
                                icon: "fork.knife"
                            )
                            
                            BalanceMetricBox(
                                title: "Treino (Saúde)",
                                value: "+\(Int(caloriasGastasAtivas))",
                                meta: "somado",
                                color: Color("AccentGreen"),
                                icon: "flame.fill"
                            )
                            
                            BalanceMetricBox(
                                title: "Disponível",
                                value: "\(Int(caloriasRestantesHoje))",
                                meta: "kcal",
                                color: caloriasRestantesHoje >= 0 ? Color("AccentColor") : .orange,
                                icon: "sparkle"
                            )
                        }
                        
                        Divider()
                            .background(Color.primary.opacity(0.06))
                        
                        // Macronutrientes consumidos hoje vs Metas
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Macronutrientes")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Color("FontNormal"))
                                Spacer()
                                Text("Consumido / Meta")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 12) {
                                Macro(
                                    count: carbosConsumidosHoje,
                                    meta: metaCarbo,
                                    color: Color("AccentColor"),
                                    type: "Carboidratos"
                                )
                                Macro(
                                    count: proteinasConsumidasHoje,
                                    meta: metaProtein,
                                    color: Color("AccentGreen"),
                                    type: "Proteínas"
                                )
                                Macro(
                                    count: gordurasConsumidasHoje,
                                    meta: metaFat,
                                    color: .orange,
                                    type: "Gorduras"
                                )
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
                    
                    // CARD NOVO: Ingestão de Água com Gráfico Redondo
                    waterCardView
                    
                    // CARD: REFEIÇÕES DE HOJE (DETALHAMENTO DOS ALIMENTOS REGISTRADOS)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "fork.knife")
                                .foregroundColor(Color("AccentColor"))
                            Text("Refeições de Hoje (\(foodsToday.count))")
                                .font(.headline)
                                .foregroundColor(Color("FontNormal"))
                            
                            Spacer()
                            
                            if !foodsToday.isEmpty {
                                Button("Limpar") {
                                    showClearConfirmAlert = true
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.trailing, 6)
                            }
                            
                            Button {
                                router.showVoiceFoodSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 11))
                                    Text("Refeição")
                                        .font(.caption.weight(.bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color("AccentColor"))
                                .clipShape(Capsule())
                            }
                        }
                        
                        if foodsToday.isEmpty {
                            VStack(spacing: 6) {
                                Text("Nenhuma refeição registrada hoje.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Toque em '+ Refeição' para falar ou digitar o que você comeu!")
                                    .font(.caption)
                                    .foregroundColor(Color("AccentColor"))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(foodsToday) { food in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(food.name)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(Color("FontNormal"))
                                                Text("(\(food.mealType.rawValue))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            HStack(spacing: 6) {
                                                Text("\(Int(food.portionGrams))g")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Text("•")
                                                    .foregroundColor(.secondary.opacity(0.5))
                                                Text("P: \(Int(food.protein))g  C: \(Int(food.carbohydrates))g  G: \(Int(food.fat))g")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(Int(food.calories)) kcal")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(Color("FontNormal"))
                                        
                                        Button {
                                            modelContext.delete(food)
                                            try? modelContext.save()
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 12))
                                                .foregroundColor(.red.opacity(0.6))
                                                .padding(.leading, 6)
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    .padding(.vertical, 2)
                                    
                                    if food.id != foodsToday.last?.id {
                                        Divider()
                                            .background(Color.primary.opacity(0.05))
                                    }
                                }
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
                    
                    // CARD: PASSOS E ATIVIDADE (HEALTHKIT)
                    VStack(spacing: 14) {
                        HStack {
                            Image(systemName: "figure.walk")
                                .frame(width: 44, height: 44)
                                .foregroundColor(Color("AccentColor"))
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color("AccentMinor"))
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("Passos de hoje")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                    Spacer()
                                    Text("/ \(Int(metaPassos))")
                                        .foregroundColor(.secondary)
                                        .fontWeight(.bold)
                                        .font(.caption)
                                }
                                
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text("\(Int(healthVM.steps))")
                                        .font(.system(size: 26, weight: .bold, design: .rounded))
                                        .foregroundColor(Color("FontNormal"))
                                    
                                    if healthVM.distanceKm > 0 {
                                        Text(String(format: "%.1f km", healthVM.distanceKm))
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        HorizontalProgress(count: healthVM.steps, meta: metaPassos)
                    }
                    .padding(20)
                    .background(Color("CardBackground"))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
                    
                    // CARD: TREINOS REALIZADOS HOJE (SINCRONIZADOS COM APPLE HEALTH)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "dumbbell.fill")
                                .foregroundColor(Color("AccentColor"))
                            Text("Treinos de Hoje")
                                .font(.headline)
                                .foregroundColor(Color("FontNormal"))
                            
                            Spacer()
                            
                            Button {
                                showAddWorkoutSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Treino")
                                        .font(.caption.weight(.bold))
                                }
                                .foregroundColor(Color("AccentColor"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color("AccentMinor"))
                                .clipShape(Capsule())
                            }
                        }
                        
                        if workoutsToday.isEmpty {
                            Text("Nenhum treino registrado hoje. Toque em '+ Treino' para registrar!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(workoutsToday) { workout in
                                    HStack {
                                        Image(systemName: workout.workoutType.icon)
                                            .foregroundColor(Color("AccentColor"))
                                        Text(workout.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color("FontNormal"))
                                        Spacer()
                                        Text("\(workout.durationMinutes) min")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("• +\(Int(workout.caloriesBurned)) kcal")
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(Color("AccentGreen"))
                                    }
                                    .padding(.vertical, 2)
                                }
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
                    
                    // BOTÕES DE AÇÕES RÁPIDAS
                    HStack(spacing: 10) {
                        QuickActionButton(
                            title: "+ Refeição",
                            icon: "mic.fill",
                            color: Color("AccentColor")
                        ) {
                            router.showVoiceFoodSheet = true
                        }
                        
                        QuickActionButton(
                            title: "+ Treino",
                            icon: "dumbbell.fill",
                            color: Color("AccentGreen")
                        ) {
                            showAddWorkoutSheet = true
                        }
                        
                        QuickActionButton(
                            title: "+ Pesagem",
                            icon: "scalemass.fill",
                            color: .blue
                        ) {
                            showLogWeightSheet = true
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .id(allFoods.count)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .alert("Limpar Alimentos de Hoje?", isPresented: $showClearConfirmAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Limpar Tudo", role: .destructive) {
                    for food in foodsToday {
                        modelContext.delete(food)
                    }
                    try? modelContext.save()
                    syncWidgetsAndLiveActivity()
                }
            } message: {
                Text("Isso removerá todos os alimentos registrados hoje para que você possa começar novamente.")
            }
            .onAppear {
                healthVM.loadHealthData()
                if let p = profile {
                    activeMetric = p.effectiveFocus
                }
                syncWidgetsAndLiveActivity()
            }
            .onChange(of: allFoods.count) { _, _ in
                syncWidgetsAndLiveActivity()
            }
            .task {
                if profiles.isEmpty {
                    let newProfile = Profile()
                    modelContext.insert(newProfile)
                    try? modelContext.save()
                }
                if healthRecords.isEmpty {
                    modelContext.insert(Health())
                    try? modelContext.save()
                }
                syncWidgetsAndLiveActivity()
            }
            .sheet(isPresented: $router.showAddFoodSheet) {
                VoiceAddFoodView { newEntry in
                    syncWidgetsAndLiveActivity(lastAddedName: newEntry.name, lastAddedCalories: newEntry.calories)
                }
                .environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $router.showVoiceFoodSheet) {
                VoiceAddFoodView { newEntry in
                    syncWidgetsAndLiveActivity(lastAddedName: newEntry.name, lastAddedCalories: newEntry.calories)
                }
                .environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $showAddWorkoutSheet) {
                AddWorkoutView()
                    .environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $showLogWeightSheet) {
                LogWeightView()
                    .environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $router.showAIFoodSheet) {
                AIFoodLoggerView {
                    syncWidgetsAndLiveActivity()
                }
                .environment(\.modelContext, modelContext)
            }
            .sheet(isPresented: $router.showAIWorkoutSheet) {
                AIWorkoutLoggerView {
                    syncWidgetsAndLiveActivity()
                }
                .environment(\.modelContext, modelContext)
            }
        }
    }
    
    // MARK: - Card de Ingestão de Água com Gráfico Redondo
    private var waterCardView: some View {
        let waterProgress = waterTarget > 0 ? min(1.0, Double(waterConsumedToday) / Double(waterTarget)) : 0.0
        let waterRemaining = max(0, waterTarget - waterConsumedToday)
        
        return HStack(spacing: 14) {
            // Gráfico Redondo de Água (Circular Ring com Ícone Centralizado)
            ZStack {
                Circle()
                    .stroke(Color.cyan.opacity(0.18), lineWidth: 5)
                
                Circle()
                    .trim(from: 0, to: waterProgress)
                    .stroke(
                        Color.cyan,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.35), value: waterProgress)
                
                Image(systemName: "drop.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.cyan)
            }
            .frame(width: 48, height: 48)
            
            // Textos Informativos
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Água")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color("FontNormal"))
                    
                    Text("\(Int(waterProgress * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(waterConsumedToday)")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(Color("FontNormal"))
                    Text("/ \(waterTarget) ml")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(waterRemaining > 0 ? "Faltam \(waterRemaining) ml" : "Meta batida com sucesso! 💧")
                    .font(.caption2)
                    .foregroundColor(waterRemaining > 0 ? .secondary : .cyan)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            // Botão Único de +250ml
            Button {
                addWater(milliliters: 250)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("250ml")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.cyan)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Sincronização com o Widget do iOS
    private func syncWidgetsAndLiveActivity(lastAddedName: String? = nil, lastAddedCalories: Double? = nil) {
        ContaCaDataStore.shared.syncTodayData(lastFoodName: lastAddedName, lastFoodCalories: lastAddedCalories)
    }
}

// Card de métrica no balanço diário (Estilo Apple / Airbnb)
struct BalanceMetricBox: View {
    let title: String
    let value: String
    let meta: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color("FontNormal"))
            
            Text(meta)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.systemBackground).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// Botão de ação rápida na parte inferior da Home (Estilo Apple / Airbnb)
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: color.opacity(0.2), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// Círculo de Progresso customizado para Calorias Consumidas / Gastas
struct CircularProgress: View {
    var count: Double
    var meta: Double
    var color: Color = Color(red: 84/255, green: 225/255, blue: 195/255)
    var lineWidth: CGFloat = 10
    var metricLabel: String = "kcal"
    var isBulkingMode: Bool = true
    
    var progress: Double {
        guard meta > 0 else { return 0 }
        return count / meta
    }
    
    private var normalizedProgress: Double {
        min(max(progress, 0), 1)
    }
    
    private var diff: Double {
        meta - count
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: normalizedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: normalizedProgress)
            
            VStack(spacing: 2) {
                Text("\(Int(count))")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(Color("FontNormal"))
                
                Text("de \(Int(meta)) \(metricLabel)")
                    .foregroundColor(.gray)
                    .font(.system(size: 11, weight: .medium))
                
                if isBulkingMode {
                    if diff > 0 {
                        Text("Faltam \(Int(diff)) kcal")
                            .foregroundColor(Color("AccentColor"))
                            .font(.system(size: 11, weight: .bold))
                    } else {
                        Text("Superávit batido! 🔥")
                            .foregroundColor(Color("AccentGreen"))
                            .font(.system(size: 11, weight: .bold))
                    }
                } else {
                    if diff > 0 {
                        Text("Restam \(Int(diff)) kcal")
                            .foregroundColor(Color("AccentGreen"))
                            .font(.system(size: 11, weight: .semibold))
                    } else {
                        Text("Meta superada! 🚀")
                            .foregroundColor(Color("AccentGreen"))
                            .font(.system(size: 11, weight: .bold))
                    }
                }
            }
        }
    }
}

// Barra de Progresso Horizontal
struct HorizontalProgress: View {
    var count: Double
    var meta: Double
    var color: Color = Color(red: 84/255, green: 225/255, blue: 195/255)
    var height: CGFloat = 6
    
    private var progress: Double {
        guard meta > 0 else { return 0 }
        return min(max(count / meta, 0), 1)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.2))
                
                Capsule()
                    .fill(color)
                    .frame(width: geometry.size.width * progress)
                    .animation(.easeInOut(duration: 0.4), value: progress)
            }
        }
        .frame(height: height)
    }
}

// Item de Macronutriente na Home
struct Macro: View {
    var count: Double
    var meta: Double
    var color: Color
    var type: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(type)
                .foregroundColor(.gray)
                .font(.system(size: 11, weight: .regular))
            HStack(spacing: 2) {
                Text("\(Int(count))")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color("FontNormal"))
                Text("/ \(Int(meta))g")
                    .foregroundColor(.gray)
                    .font(.system(size: 10))
                    .offset(y: 2)
            }
            HorizontalProgress(
                count: count,
                meta: meta,
                color: color
            )
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HomeView()
        .modelContainer(PreviewContainer.shared)
}
