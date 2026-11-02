//
//  ContaCaDataStore.swift
//  ContaCa
//
//  Created by João Pedro on 10/29/26.
//

import Foundation
import SwiftData
import WidgetKit

/// Gerenciador centralizado de dados SwiftData e sincronização em tempo real com Widgets e Live Activities
@MainActor
final class ContaCaDataStore {
    static let shared = ContaCaDataStore()
    
    let container: ModelContainer
    
    var mainContext: ModelContext {
        container.mainContext
    }
    
    private init() {
        let schema = Schema([
            Profile.self,
            Health.self,
            FoodEntry.self,
            WorkoutEntry.self,
            WeightEntry.self,
            WorkoutRoutine.self,
            WaterEntry.self
        ])
        
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
    
    // MARK: - Inserção de Refeições
    
    func insertFoodEntries(_ entries: [FoodEntry]) throws {
        guard !entries.isEmpty else { return }
        for entry in entries {
            mainContext.insert(entry)
            AppActivityLogManager.shared.logMeal(
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
        try mainContext.save()
        
        let last = entries.last
        syncTodayData(lastFoodName: last?.name, lastFoodCalories: last?.calories)
    }
    
    // MARK: - Inserção de Treinos
    
    func insertWorkoutEntry(_ entry: WorkoutEntry) throws {
        mainContext.insert(entry)
        try mainContext.save()
        syncTodayData()
        
        // Registra no arquivo físico de atividades
        AppActivityLogManager.shared.logWorkout(
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
    
    // MARK: - Sincronização Geral de Métricas Hoje
    
    // MARK: - Ingestão de Água e Sincronização de Fila
    
    func syncPendingWater() {
        let pending = WidgetDataManager.shared.drainPendingWater()
        if pending > 0 {
            let entry = WaterEntry(milliliters: pending, date: Date())
            mainContext.insert(entry)
            try? mainContext.save()
            AppActivityLogManager.shared.logWater(
                milliliters: entry.milliliters,
                date: entry.date
            )
        }
    }

    func syncTodayData(lastFoodName: String? = nil, lastFoodCalories: Double? = nil) {
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
        
        // 2. Busca treinos registrados hoje
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
        
        let targetCalories = profile.targetCalorieIntake > 0 ? profile.targetCalorieIntake : 2800.0
        let targetProtein = profile.targetProtein > 0 ? profile.targetProtein : 160.0
        let targetCarbs = profile.targetCarbohydrates > 0 ? profile.targetCarbohydrates : 380.0
        let targetFat = profile.targetFat > 0 ? profile.targetFat : 70.0
        let waterTarget = profile.targetWaterMilliliters > 0 ? profile.targetWaterMilliliters : 2500
        let goalRaw = profile.goalRaw
        
        // Total de calorias gastas: Taxa Metabólica Basal (TMB) + treinos realizados
        let totalBurned = profile.tmb + workoutBurned
        
        // 5. Salva nos Widgets através do WidgetDataManager
        let widgetData = WidgetCalorieData(
            caloriesConsumed: totalCalories,
            caloriesTarget: targetCalories,
            caloriesBurned: totalBurned,
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
    }
    
    // MARK: - Rotinas e Fichas de Treino
    
    func insertWorkoutRoutine(_ routine: WorkoutRoutine) throws {
        mainContext.insert(routine)
        try mainContext.save()
    }
    
    func deleteWorkoutRoutine(_ routine: WorkoutRoutine) throws {
        mainContext.delete(routine)
        try mainContext.save()
    }
    
    func toggleFavoriteRoutine(_ routine: WorkoutRoutine) throws {
        routine.isFavorite.toggle()
        try mainContext.save()
    }
    
    // MARK: - Ingestão de Água
    
    func insertWaterEntry(_ entry: WaterEntry) throws {
        mainContext.insert(entry)
        try mainContext.save()
        AppActivityLogManager.shared.logWater(
            milliliters: entry.milliliters,
            date: entry.date
        )
        syncTodayData()
    }
}
