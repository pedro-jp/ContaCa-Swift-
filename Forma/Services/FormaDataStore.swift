//
//  FormaDataStore.swift
//  Forma
//
//  Created by João Pedro on 10/29/26.
//

import Foundation
import SwiftData
import WidgetKit
import HealthKit

/// Gerenciador centralizado de dados SwiftData e sincronização em tempo real com Widgets e Live Activities
@MainActor
public final class FormaDataStore {
    public static let shared = FormaDataStore(inMemory: false)
    
    public let container: ModelContainer
    private let isInMemoryStore: Bool
    
    public var mainContext: ModelContext {
        container.mainContext
    }
    
    public init(inMemory: Bool = false) {
        self.isInMemoryStore = inMemory
        let schema = Schema([
            Profile.self,
            Health.self,
            FoodEntry.self,
            WorkoutEntry.self,
            WeightEntry.self,
            WorkoutRoutine.self,
            WaterEntry.self
        ])
        
        if inMemory {
            let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            self.container = try! ModelContainer(for: schema, configurations: [memConfig])
            return
        }
        
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            print("⚠️ Erro ao abrir container com schema atual: \(error). Recriando store limpo...")
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let defaultStore = appSupport.appendingPathComponent("default.store")
                let defaultShm = appSupport.appendingPathComponent("default.store-shm")
                let defaultWal = appSupport.appendingPathComponent("default.store-wal")
                try? FileManager.default.removeItem(at: defaultStore)
                try? FileManager.default.removeItem(at: defaultShm)
                try? FileManager.default.removeItem(at: defaultWal)
            }
            
            do {
                let freshConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                self.container = try ModelContainer(for: schema, configurations: [freshConfig])
            } catch {
                let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                self.container = try! ModelContainer(for: schema, configurations: [memConfig])
            }
        }
    }

    /// Garante que exista exatamente um Profile no contexto, consolidando eventuais duplicatas.
    @discardableResult
    func ensureSingleProfile(in context: ModelContext? = nil) -> Profile {
        let ctx = context ?? mainContext
        let profiles = (try? ctx.fetch(FetchDescriptor<Profile>())) ?? []
        if let primary = profiles.first {
            if profiles.count > 1 {
                for duplicate in profiles.dropFirst() {
                    ctx.delete(duplicate)
                }
            }
            if !primary.autoRecalculateGoals {
                primary.autoRecalculateGoals = true
            }
            try? ctx.save()
            return primary
        }
        let fresh = Profile(
            nome: AuthManager.shared.currentUserName ?? "Usuário",
            email: AuthManager.shared.currentUserEmail ?? ""
        )
        ctx.insert(fresh)
        try? ctx.save()
        return fresh
    }
    
    // MARK: - Inserção e Exclusão de Refeições
    
    func insertFoodEntries(_ entries: [FoodEntry]) throws {
        guard !entries.isEmpty else { return }
        for entry in entries {
            mainContext.insert(entry)
            if !isInMemoryStore {
                AppActivityLogManager.shared.logMeal(
                    id: entry.id.uuidString,
                    name: entry.name,
                    mealType: entry.mealType.rawValue,
                    calories: entry.calories,
                    protein: entry.protein,
                    carbs: entry.carbohydrates,
                    fat: entry.fat,
                    isSnack: entry.mealType == .snacks,
                    date: entry.date
                )
            }
        }
        recalculateProfileWithFullContext(in: mainContext)
        try mainContext.save()
        
        let last = entries.last
        syncTodayData(lastFoodName: last?.name, lastFoodCalories: last?.calories)
    }

    func deleteFoodEntry(_ entry: FoodEntry, in context: ModelContext? = nil) {
        deleteFoodEntries([entry], in: context)
    }

    func deleteFoodEntries(_ entries: [FoodEntry], in context: ModelContext? = nil) {
        guard !entries.isEmpty else { return }
        let ctx = context ?? mainContext
        let deletedIds = entries.map(\.id)
        if !isInMemoryStore {
            BackendSyncManager.shared.recordDeletedFoodIds(deletedIds)
            AppActivityLogManager.shared.removeRecords(ids: deletedIds.map(\.uuidString))
        }
        for entry in entries {
            ctx.delete(entry)
        }
        recalculateProfileWithFullContext(in: ctx)
        try? ctx.save()
        syncTodayData()
    }
    
    // MARK: - Motor de Contexto Completo para Recálculo Fisiológico
    
    func buildRecalculationContext(in context: ModelContext? = nil) -> RecalculationContext {
        let ctx = context ?? mainContext
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let twentyOneDaysAgo = calendar.date(byAdding: .day, value: -21, to: now) ?? now
        
        // 1. Treinos reais (7d / 14d)
        let workoutDescriptor = FetchDescriptor<WorkoutEntry>(
            predicate: #Predicate { entry in
                entry.date >= fourteenDaysAgo
            }
        )
        let workouts14d = (try? ctx.fetch(workoutDescriptor)) ?? []
        let sum14d = workouts14d.reduce(0.0) { $0 + $1.caloriesBurned }
        let sum7d = workouts14d.filter { $0.date >= sevenDaysAgo }.reduce(0.0) { $0 + $1.caloriesBurned }
        let avgDailyWorkoutBurn = max(sum14d / 14.0, sum7d / 7.0)
        
        // 2. Fichas de treino salvas
        let routines = (try? ctx.fetch(FetchDescriptor<WorkoutRoutine>())) ?? []
        let routineEstimatedDailyBurn: Double
        if !routines.isEmpty {
            let avgPerSession = routines.reduce(0.0) { $0 + $1.estimatedCalories } / Double(routines.count)
            let sessionsPerWeek = Double(min(5, max(3, routines.count)))
            routineEstimatedDailyBurn = (avgPerSession * sessionsPerWeek) / 7.0
        } else {
            routineEstimatedDailyBurn = 0.0
        }
        
        // 3. Passos reais do Apple Saúde / Widget
        let recentSteps = Double(WidgetDataManager.shared.loadWidgetData().stepsCount)
        
        // 4. Tendência real de peso (últimos 21 dias)
        let weightDescriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { entry in
                entry.date >= twentyOneDaysAgo
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let recentWeights = (try? ctx.fetch(weightDescriptor)) ?? []
        var weeklyWeightTrendKg: Double? = nil
        if let first = recentWeights.first, let last = recentWeights.last, recentWeights.count >= 2 {
            let daysSpan = last.date.timeIntervalSince(first.date) / 86400.0
            if daysSpan >= 4.0 {
                weeklyWeightTrendKg = ((last.weight - first.weight) / daysSpan) * 7.0
            }
        }
        
        // 5. Média de ingestão calórica nos dias registrados (últimos 7 dias)
        let foodDescriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { entry in
                entry.date >= sevenDaysAgo
            }
        )
        let recentFoods = (try? ctx.fetch(foodDescriptor)) ?? []
        var recentAvgIntake: Double? = nil
        if !recentFoods.isEmpty {
            var byDay: [Date: Double] = [:]
            for food in recentFoods {
                let day = calendar.startOfDay(for: food.date)
                byDay[day, default: 0.0] += food.calories
            }
            if !byDay.isEmpty {
                recentAvgIntake = byDay.values.reduce(0.0, +) / Double(byDay.count)
            }
        }
        
        return RecalculationContext(
            workoutsLast14DaysCount: workouts14d.count,
            avgDailyWorkoutBurn: avgDailyWorkoutBurn,
            routineEstimatedDailyBurn: routineEstimatedDailyBurn,
            recentAvgSteps: recentSteps,
            weeklyWeightTrendKg: weeklyWeightTrendKg,
            recentAvgCalorieIntake: recentAvgIntake
        )
    }
    
    func recalculateProfileWithFullContext(
        for weight: Double? = nil,
        profile overrideProfile: Profile? = nil,
        in context: ModelContext? = nil
    ) {
        let ctx = context ?? mainContext
        guard let targetProfile = overrideProfile ?? (try? ctx.fetch(FetchDescriptor<Profile>()).first) else {
            return
        }
        let recalcContext = buildRecalculationContext(in: ctx)
        targetProfile.recalculateDailyGoals(for: weight, context: recalcContext)
    }
    
    // MARK: - Inserção e Exclusão de Treinos
    
    func insertWorkoutEntry(_ entry: WorkoutEntry) throws {
        mainContext.insert(entry)
        recalculateProfileWithFullContext(in: mainContext)
        try mainContext.save()
        syncTodayData()
        
        guard !isInMemoryStore else { return }
        
        // Registra no arquivo físico de atividades
        AppActivityLogManager.shared.logWorkout(
            id: entry.id.uuidString,
            title: entry.title,
            workoutType: entry.workoutType.rawValue,
            durationMinutes: entry.durationMinutes,
            caloriesBurned: entry.caloriesBurned,
            date: entry.date,
            details: entry.notes
        )
        
        // Salva no Apple Health
        HealthManager.shared.saveWorkout(
            title: entry.title,
            workoutType: entry.workoutType,
            caloriesBurned: entry.caloriesBurned,
            durationMinutes: entry.durationMinutes,
            date: entry.date
        )
    }

    func deleteWorkoutEntry(_ entry: WorkoutEntry, in context: ModelContext? = nil) {
        let ctx = context ?? mainContext
        let deletedId = entry.id
        if !isInMemoryStore {
            BackendSyncManager.shared.recordDeletedWorkoutIds([deletedId])
            AppActivityLogManager.shared.removeRecords(ids: [deletedId.uuidString])
        }
        ctx.delete(entry)
        recalculateProfileWithFullContext(in: ctx)
        try? ctx.save()
        syncTodayData()
    }

    // MARK: - Sincronização Automática em Segundo Plano (Apple Saúde / Strava)

    func setupBackgroundHealthObserver() {
        guard !isInMemoryStore else { return }
        HealthManager.shared.requestAuthorization { success, _ in
            guard success else { return }
            Task { @MainActor in
                HealthManager.shared.startObservingExternalWorkouts {
                    Task { @MainActor in
                        FormaDataStore.shared.syncExternalHealthWorkoutsInBackground()
                    }
                }
                FormaDataStore.shared.syncExternalHealthWorkoutsInBackground()
            }
        }
    }

    func syncExternalHealthWorkoutsInBackground(days: Int = 7, in _: ModelContext? = nil) {
        guard !isInMemoryStore else { return }

        HealthManager.shared.requestAuthorization { [weak self] success, _ in
            guard success else { return }
            Task { @MainActor in
                guard let self else { return }
                HealthManager.shared.fetchExternalWorkoutSamples(days: days) { [weak self] samples in
                    guard let self, !samples.isEmpty else { return }
                    let targetContext = self.mainContext
                    let existingWorkouts = (try? targetContext.fetch(FetchDescriptor<WorkoutEntry>())) ?? []
                    var existingKeys = Set(existingWorkouts.map { "\($0.title)_\(Int($0.date.timeIntervalSince1970))" })
                    var importedCount = 0

                    for sample in samples {
                        let uniqueKey = "\(sample.title)_\(Int(sample.startDate.timeIntervalSince1970))"
                        guard !existingKeys.contains(uniqueKey) else { continue }
                        existingKeys.insert(uniqueKey)

                        let entry = WorkoutEntry(
                            title: sample.title,
                            workoutType: sample.workoutType,
                            durationMinutes: sample.durationMinutes,
                            caloriesBurned: sample.caloriesBurned,
                            date: sample.startDate,
                            notes: "Sincronizado automaticamente (\(sample.sourceName))"
                        )
                        targetContext.insert(entry)
                        AppActivityLogManager.shared.logWorkout(
                            id: entry.id.uuidString,
                            title: entry.title,
                            workoutType: entry.workoutType.rawValue,
                            durationMinutes: entry.durationMinutes,
                            caloriesBurned: entry.caloriesBurned,
                            date: entry.date,
                            details: entry.notes
                        )
                        importedCount += 1
                    }

                    if importedCount > 0 {
                        self.recalculateProfileWithFullContext(in: targetContext)
                        try? targetContext.save()
                        self.syncTodayData()
                    }
                }
            }
        }
    }
    
    // MARK: - Sincronização Geral de Métricas Hoje
    
    // MARK: - Ingestão de Água e Sincronização de Fila
    
    func syncPendingWater() {
        let pending = WidgetDataManager.shared.drainPendingWater()
        if pending > 0 {
            let entry = WaterEntry(milliliters: pending, date: Date())
            mainContext.insert(entry)
            try? mainContext.save()
            AppActivityLogManager.shared.logWater(
                id: entry.id.uuidString,
                milliliters: entry.milliliters,
                date: entry.date
            )
        }
    }

    func syncTodayData(
        lastFoodName: String? = nil,
        lastFoodCalories: Double? = nil,
        activeCaloriesOverride: Double? = nil,
        stepsOverride: Int? = nil,
        skipCloudSyncTrigger: Bool = false
    ) {
        guard !isInMemoryStore else { return }
        syncPendingWater()
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        
        // 1. Busca todos os alimentos registrados hoje
        let foodDescriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { entry in
                entry.date >= startOfDay && entry.date < endOfDay
            }
        )
        let foods = (try? mainContext.fetch(foodDescriptor)) ?? []
        
        let totalCalories = foods.reduce(0.0) { $0 + $1.calories }
        let totalProtein = foods.reduce(0.0) { $0 + $1.protein }
        let totalCarbs = foods.reduce(0.0) { $0 + $1.carbohydrates }
        let totalFat = foods.reduce(0.0) { $0 + $1.fat }
        
        // 2. Busca treinos registrados hoje no app
        let workoutDescriptor = FetchDescriptor<WorkoutEntry>(
            predicate: #Predicate { entry in
                entry.date >= startOfDay && entry.date < endOfDay
            }
        )
        let workouts = (try? mainContext.fetch(workoutDescriptor)) ?? []
        let workoutBurned = workouts.reduce(0.0) { $0 + $1.caloriesBurned }
        
        // 3. Busca água registrada hoje
        let waterDescriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { entry in
                entry.date >= startOfDay && entry.date < endOfDay
            }
        )
        let waters = (try? mainContext.fetch(waterDescriptor)) ?? []
        let waterConsumed = waters.reduce(0) { $0 + $1.milliliters }
        
        // 4. Busca metas e preferências do Perfil
        let profileDescriptor = FetchDescriptor<Profile>()
        let profiles = (try? mainContext.fetch(profileDescriptor)) ?? []
        let profile = profiles.first ?? Profile()
        
        let baseTargetCalories = profile.targetCalorieIntake > 0 ? profile.targetCalorieIntake : 2800.0
        let targetProtein = profile.targetProtein > 0 ? profile.targetProtein : 160.0
        let targetCarbs = profile.targetCarbohydrates > 0 ? profile.targetCarbohydrates : 380.0
        let targetFat = profile.targetFat > 0 ? profile.targetFat : 70.0
        let waterTarget = profile.targetWaterMilliliters > 0 ? profile.targetWaterMilliliters : 2500
        let goalRaw = profile.goalRaw
        
        // Determina calorias ativas gastas (treinos do app + passos/atividades do Apple Health)
        let activeBurned: Double
        if let override = activeCaloriesOverride, override > 0 {
            activeBurned = max(workoutBurned, override)
        } else {
            activeBurned = workoutBurned
        }
        
        // Total de calorias gastas: Taxa Metabólica Basal (TMB) + Calorias Ativas Gastas
        let totalBurned = profile.tmb + activeBurned
        
        // Meta de Calorias Ajustada: Meta Base + Calorias Ativas Gastas (aumenta progressivamente conforme gasta)
        let adjustedTargetCalories = baseTargetCalories + activeBurned
        
        // 5. Salva nos Widgets através do WidgetDataManager compartilhado
        let widgetData = WidgetCalorieData(
            caloriesConsumed: totalCalories,
            caloriesTarget: adjustedTargetCalories,
            baseCaloriesTarget: baseTargetCalories,
            caloriesBurned: totalBurned,
            activeCaloriesBurned: activeBurned,
            stepsCount: stepsOverride ?? 0,
            proteinConsumed: totalProtein,
            proteinTarget: targetProtein,
            carbsConsumed: totalCarbs,
            carbsTarget: targetCarbs,
            fatConsumed: totalFat,
            fatTarget: targetFat,
            waterConsumed: waterConsumed,
            waterTarget: waterTarget,
            goalRaw: goalRaw,
            lastUpdated: Date()
        )
        WidgetDataManager.shared.saveWidgetData(widgetData)
        
        // Se foi chamado sem override do HealthKit, dispara leitura em background para atualizar com os passos/calorias do Saúde
        if activeCaloriesOverride == nil {
            HealthManager.shared.fetchTodayCalories { [weak self] healthCalories in
                HealthManager.shared.fetchTodaySteps { healthSteps in
                    Task { @MainActor in
                        guard self != nil else { return }
                        let currentActive = max(workoutBurned, healthCalories)
                        let newTotalBurned = profile.tmb + currentActive
                        let newAdjustedTarget = baseTargetCalories + currentActive
                        
                        let updatedWidgetData = WidgetCalorieData(
                            caloriesConsumed: totalCalories,
                            caloriesTarget: newAdjustedTarget,
                            baseCaloriesTarget: baseTargetCalories,
                            caloriesBurned: newTotalBurned,
                            activeCaloriesBurned: currentActive,
                            stepsCount: Int(healthSteps),
                            proteinConsumed: totalProtein,
                            proteinTarget: targetProtein,
                            carbsConsumed: totalCarbs,
                            carbsTarget: targetCarbs,
                            fatConsumed: totalFat,
                            fatTarget: targetFat,
                            waterConsumed: waterConsumed,
                            waterTarget: waterTarget,
                            goalRaw: goalRaw,
                            lastUpdated: Date()
                        )
                        WidgetDataManager.shared.saveWidgetData(updatedWidgetData)
                    }
                }
            }
        }
        
        // 6. Atualiza lembretes insistentes de água (06h-22h) e refeições com o saldo atual do dia
        let hasBreakfast = foods.contains { $0.mealType == .breakfast }
        let hasLunch = foods.contains { $0.mealType == .lunch }
        let hasDinner = foods.contains { $0.mealType == .dinner }
        WorkoutNotificationManager.shared.scheduleDailyHydrationAndMealReminders(
            waterConsumedMl: waterConsumed,
            waterTargetMl: waterTarget,
            hasLoggedBreakfast: hasBreakfast,
            hasLoggedLunch: hasLunch,
            hasLoggedDinner: hasDinner
        )

        // 7. Dispara sincronização automática e silenciosa com a nuvem (Supabase) em segundo plano
        if !skipCloudSyncTrigger {
            Task { @MainActor in
                BackendSyncManager.shared.triggerAutoSync()
            }
        }
    }
    
    // MARK: - Isolamento Multi-Usuário (Limpeza Total Local na Troca de Conta / Logout)
    
    public func resetLocalDataForUserSwitch(userName: String?, userEmail: String?) {
        // 1. Limpa fila pendente do widget
        if !isInMemoryStore {
            _ = WidgetDataManager.shared.drainPendingWater()
        }
        
        // 2. Remove todos os registros da conta anterior no SwiftData
        if let foods = try? mainContext.fetch(FetchDescriptor<FoodEntry>()) {
            for item in foods { mainContext.delete(item) }
        }
        if let workouts = try? mainContext.fetch(FetchDescriptor<WorkoutEntry>()) {
            for item in workouts { mainContext.delete(item) }
        }
        if let waters = try? mainContext.fetch(FetchDescriptor<WaterEntry>()) {
            for item in waters { mainContext.delete(item) }
        }
        if let weights = try? mainContext.fetch(FetchDescriptor<WeightEntry>()) {
            for item in weights { mainContext.delete(item) }
        }
        if let routines = try? mainContext.fetch(FetchDescriptor<WorkoutRoutine>()) {
            for item in routines { mainContext.delete(item) }
        }
        if let profiles = try? mainContext.fetch(FetchDescriptor<Profile>()) {
            for item in profiles { mainContext.delete(item) }
        }
        if let healths = try? mainContext.fetch(FetchDescriptor<Health>()) {
            for item in healths { mainContext.delete(item) }
        }
        
        // 3. Insere perfil limpo para a nova sessão (será preenchido pelo pull da nuvem se já tiver histórico)
        let cleanName = (userName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? userName! : "Usuário"
        let cleanEmail = (userEmail?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? userEmail! : ""
        let freshProfile = Profile(nome: cleanName, email: cleanEmail)
        mainContext.insert(freshProfile)
        mainContext.insert(Health())
        
        try? mainContext.save()
        
        // 4. Limpa diagnósticos da IA e logs físicos locais da conta anterior
        if !isInMemoryStore {
            EvolutionAnalysisStore.shared.clear()
            AppActivityLogManager.shared.clearAll()
            
            // 5. Atualiza dados dos widgets zerados sem disparar push para nuvem
            syncTodayData(skipCloudSyncTrigger: true)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    // MARK: - Rotinas e Fichas de Treino
    
    func insertWorkoutRoutine(_ routine: WorkoutRoutine) throws {
        mainContext.insert(routine)
        recalculateProfileWithFullContext(in: mainContext)
        try mainContext.save()
        syncTodayData()
    }
    
    func deleteWorkoutRoutine(_ routine: WorkoutRoutine, in context: ModelContext? = nil) throws {
        let ctx = context ?? mainContext
        let routineId = routine.id
        if !isInMemoryStore {
            BackendSyncManager.shared.recordDeletedRoutineIds([routineId])
        }
        ctx.delete(routine)
        recalculateProfileWithFullContext(in: ctx)
        try ctx.save()
        syncTodayData()
    }
    
    func toggleFavoriteRoutine(_ routine: WorkoutRoutine) throws {
        routine.isFavorite.toggle()
        try mainContext.save()
        Task { @MainActor in
            BackendSyncManager.shared.triggerAutoSync()
        }
    }
    
    // MARK: - Ingestão de Água e Pesagens
    
    func insertWaterEntry(_ entry: WaterEntry) throws {
        mainContext.insert(entry)
        try mainContext.save()
        if !isInMemoryStore {
            AppActivityLogManager.shared.logWater(
                id: entry.id.uuidString,
                milliliters: entry.milliliters,
                date: entry.date
            )
        }
        syncTodayData()
    }

    func deleteWaterEntry(_ entry: WaterEntry, in context: ModelContext? = nil) {
        let ctx = context ?? mainContext
        let waterId = entry.id
        if !isInMemoryStore {
            BackendSyncManager.shared.recordDeletedWaterIds([waterId])
            AppActivityLogManager.shared.removeRecords(ids: [waterId.uuidString])
        }
        ctx.delete(entry)
        try? ctx.save()
        syncTodayData()
    }

    func deleteWeightEntry(_ entry: WeightEntry, in context: ModelContext? = nil) {
        let ctx = context ?? mainContext
        let weightId = entry.id
        if !isInMemoryStore {
            BackendSyncManager.shared.recordDeletedWeightIds([weightId])
            AppActivityLogManager.shared.removeRecords(ids: [weightId.uuidString])
        }
        ctx.delete(entry)

        let remainingDesc = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let remaining = (try? ctx.fetch(remainingDesc)) ?? []
        if let latest = remaining.first(where: { $0.id != weightId }),
           let profile = (try? ctx.fetch(FetchDescriptor<Profile>()).first) {
            profile.currentWeight = latest.weight
            recalculateProfileWithFullContext(for: latest.weight, profile: profile, in: ctx)
        } else {
            recalculateProfileWithFullContext(in: ctx)
        }

        try? ctx.save()
        syncTodayData()
    }
}
