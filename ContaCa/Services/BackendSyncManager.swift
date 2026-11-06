//
//  BackendSyncManager.swift
//  ContaCa
//
//  Created by João Pedro on 11/02/26.
//

import Foundation
import SwiftData
import Combine

@MainActor
public final class BackendSyncManager: ObservableObject {
    public static let shared = BackendSyncManager()
    public static let activeLocalUserIdKey = "contaca_active_local_user_id"
    
    private let lastSyncKey = "contaca_last_sync_timestamp"
    private let requiresInitialPullKey = "contaca_requires_initial_pull"
    private let deletedFoodIdsKey = "contaca_deleted_food_ids"
    private let deletedWorkoutIdsKey = "contaca_deleted_workout_ids"
    private let deletedWaterIdsKey = "contaca_deleted_water_ids"
    private let deletedWeightIdsKey = "contaca_deleted_weight_ids"
    private let deletedRoutineIdsKey = "contaca_deleted_routine_ids"
    private var debouncedSyncTask: Task<Void, Never>? = nil
    
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncDate: Date? = nil
    @Published public var lastSyncError: String? = nil
    
    private init() {
        if let timestamp = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            self.lastSyncDate = timestamp
        }
    }
    
    public func cancelPendingSyncs() {
        debouncedSyncTask?.cancel()
        debouncedSyncTask = nil
    }
    
    public func markRequiresInitialPull(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: requiresInitialPullKey)
    }

    // MARK: - Rastreamento Persistente de Exclusões Locais (Tombstones)

    public func recordDeletedFoodIds(_ ids: [UUID]) {
        appendDeletedIds(ids, forKey: deletedFoodIdsKey)
    }

    public func recordDeletedWorkoutIds(_ ids: [UUID]) {
        appendDeletedIds(ids, forKey: deletedWorkoutIdsKey)
    }

    public func recordDeletedWaterIds(_ ids: [UUID]) {
        appendDeletedIds(ids, forKey: deletedWaterIdsKey)
    }

    public func recordDeletedWeightIds(_ ids: [UUID]) {
        appendDeletedIds(ids, forKey: deletedWeightIdsKey)
    }

    public func recordDeletedRoutineIds(_ ids: [UUID]) {
        appendDeletedIds(ids, forKey: deletedRoutineIdsKey)
    }

    public func pendingDeletedFoodIds() -> Set<String> {
        loadDeletedIdsSet(forKey: deletedFoodIdsKey)
    }

    public func pendingDeletedWorkoutIds() -> Set<String> {
        loadDeletedIdsSet(forKey: deletedWorkoutIdsKey)
    }

    public func clearAllPendingDeletions() {
        for key in [deletedFoodIdsKey, deletedWorkoutIdsKey, deletedWaterIdsKey, deletedWeightIdsKey, deletedRoutineIdsKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func appendDeletedIds(_ ids: [UUID], forKey key: String) {
        guard !ids.isEmpty else { return }
        var current = loadDeletedIdsSet(forKey: key)
        for id in ids {
            current.insert(id.uuidString.lowercased())
        }
        UserDefaults.standard.set(Array(current), forKey: key)
    }

    private func loadDeletedIdsSet(forKey key: String) -> Set<String> {
        let raw = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(raw.map { $0.lowercased() })
    }

    private func acknowledgeDeletedIds(_ sentLowercasedIds: Set<String>, forKey key: String) {
        guard !sentLowercasedIds.isEmpty else { return }
        var current = loadDeletedIdsSet(forKey: key)
        current.subtract(sentLowercasedIds)
        if current.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(Array(current), forKey: key)
        }
    }
    
    /// Agenda uma sincronização automática silenciosa em segundo plano após alterações locais (com debounce de 2 segundos)
    public func triggerAutoSync() {
        guard AuthManager.shared.isAuthenticated else { return }
        
        debouncedSyncTask?.cancel()
        debouncedSyncTask = Task { @MainActor [weak self] in
            // Aguarda 2 segundos para agrupar múltiplas inserções rápidas sem onerar a rede ou travar a UI
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled, let self = self else { return }
            await self.sync(context: ContaCaDataStore.shared.mainContext)
        }
    }
    
    // MARK: - Sincronização Completa (Isolamento Multi-Usuário: Pull Inicial ou Push + Pull)
    public func sync(context: ModelContext) async {
        guard AuthManager.shared.isAuthenticated,
              let token = AuthManager.shared.jwtToken,
              let userId = AuthManager.shared.currentUserId else {
            // Em modo visitante ou offline, não tenta sincronizar com nuvem
            return
        }
        
        // Barreira de segurança multi-usuário: garante que dados locais pertençam exclusivamente ao userId autenticado
        let activeLocalUserId = UserDefaults.standard.string(forKey: Self.activeLocalUserIdKey)
        if let activeLocalUserId, activeLocalUserId != userId {
            clearAllPendingDeletions()
            ContaCaDataStore.shared.resetLocalDataForUserSwitch(
                userName: AuthManager.shared.currentUserName,
                userEmail: AuthManager.shared.currentUserEmail
            )
            UserDefaults.standard.set(userId, forKey: Self.activeLocalUserIdKey)
            markRequiresInitialPull(true)
        } else if activeLocalUserId == nil {
            UserDefaults.standard.set(userId, forKey: Self.activeLocalUserIdKey)
        }
        
        isSyncing = true
        lastSyncError = nil
        defer { isSyncing = false }
        
        do {
            let needsInitialPull = UserDefaults.standard.bool(forKey: requiresInitialPullKey)
            if needsInitialPull {
                // Em novo login / troca de conta: SEMPRE faz PULL primeiro para restaurar os dados da conta na nuvem
                // sem sobrescrever o perfil salvo com valores padrão nem vazar dados antigos.
                try await pullRemoteData(context: context, token: token, userId: userId)
                markRequiresInitialPull(false)
            } else {
                // 1. PUSH: Envia dados locais do usuário atual para o Backend / Supabase
                try await pushLocalData(context: context, token: token)
                
                // 2. PULL: Baixa novidades do Backend
                try await pullRemoteData(context: context, token: token, userId: userId)
            }
            
            ContaCaDataStore.shared.syncTodayData(skipCloudSyncTrigger: true)
            
            let now = Date()
            self.lastSyncDate = now
            UserDefaults.standard.set(now, forKey: lastSyncKey)
            print("☁️ [Forma Sync] Sincronização completa com Supabase concluída com sucesso.")
        } catch {
            self.lastSyncError = error.localizedDescription
            print("⚠️ [Forma Sync] Erro na sincronização: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Push (Local -> Backend / Supabase)
    private func pushLocalData(context: ModelContext, token: String) async throws {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // 1. Perfil e Metas
        let profileDesc = FetchDescriptor<Profile>()
        let localProfile = try? context.fetch(profileDesc).first
        
        var profileDict: [String: Any]? = nil
        if let p = localProfile {
            profileDict = [
                "goal": p.goalRaw,
                "targetCalorieIntake": p.targetCalorieIntake,
                "targetCalorieBurn": p.targetCalorieBurn,
                "targetSteps": p.targetSteps,
                "targetWeight": p.targetWeight,
                "targetProtein": p.targetProtein,
                "targetCarbohydrates": p.targetCarbohydrates,
                "targetFat": p.targetFat,
                "targetWaterMilliliters": p.targetWaterMilliliters,
                "heightMeters": p.height,
                "currentWeight": p.currentWeight
            ]
        }
        
        // 2. Alimentos Consumidos
        let foodDesc = FetchDescriptor<FoodEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let localFoods = (try? context.fetch(foodDesc)) ?? []
        let foodsArray = localFoods.map { f in
            [
                "id": f.id.uuidString,
                "name": f.name,
                "brand": f.brand,
                "mealType": f.mealTypeRaw,
                "portionGrams": f.portionGrams,
                "calories": f.calories,
                "protein": f.protein,
                "carbohydrates": f.carbohydrates,
                "fat": f.fat,
                "consumedAt": isoFormatter.string(from: f.date)
            ] as [String : Any]
        }
        
        // 3. Treinos Realizados
        let workoutDesc = FetchDescriptor<WorkoutEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let localWorkouts = (try? context.fetch(workoutDesc)) ?? []
        let workoutsArray = localWorkouts.map { w in
            [
                "id": w.id.uuidString,
                "title": w.title,
                "workoutType": w.workoutTypeRaw,
                "durationMinutes": w.durationMinutes,
                "caloriesBurned": w.caloriesBurned,
                "notes": w.notes,
                "workoutDate": isoFormatter.string(from: w.date)
            ] as [String : Any]
        }
        
        // 4. Ingestão de Água
        let waterDesc = FetchDescriptor<WaterEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let localWaters = (try? context.fetch(waterDesc)) ?? []
        let watersArray = localWaters.map { wa in
            [
                "id": wa.id.uuidString,
                "milliliters": wa.milliliters,
                "entryDate": isoFormatter.string(from: wa.date)
            ] as [String : Any]
        }
        
        // 5. Histórico de Peso
        let weightDesc = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let localWeights = (try? context.fetch(weightDesc)) ?? []
        let weightsArray = localWeights.map { we in
            [
                "id": we.id.uuidString,
                "weight": we.weight,
                "entryDate": isoFormatter.string(from: we.date)
            ] as [String : Any]
        }
        
        // 6. Fichas e Rotinas de Treino (WorkoutRoutine)
        let routineDesc = FetchDescriptor<WorkoutRoutine>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let localRoutines = (try? context.fetch(routineDesc)) ?? []
        let routinesArray = localRoutines.map { r in
            var dict: [String: Any] = [
                "id": r.id.uuidString,
                "title": r.title,
                "workoutType": r.workoutTypeRaw,
                "targetMuscles": r.targetMuscles,
                "hypertrophyFocus": r.hypertrophyFocus,
                "estimatedDurationMinutes": r.estimatedDurationMinutes,
                "estimatedCalories": r.estimatedCalories,
                "recommendedRestSeconds": r.recommendedRestSeconds,
                "isFavorite": r.isFavorite,
                "exercisesJson": r.exercisesJson,
                "notes": r.notes,
                "createdAt": isoFormatter.string(from: r.createdAt)
            ]
            if let lastTrained = r.lastTrainedAt {
                dict["lastTrainedAt"] = isoFormatter.string(from: lastTrained)
            }
            return dict
        }
        
        // 7. Análises e Diagnósticos da IA (EvolutionAIAnalysis)
        var analysesArray: [[String: Any]] = []
        if let analysis = EvolutionAnalysisStore.shared.latestAnalysis {
            let encoder = JSONEncoder()
            let workoutSugg = (try? String(data: encoder.encode(analysis.workoutSuggestions), encoding: .utf8)) ?? "[]"
            let nutrSugg = (try? String(data: encoder.encode(analysis.nutritionSuggestions), encoding: .utf8)) ?? "[]"
            let targetsJson = analysis.suggestedTargets != nil ? (try? String(data: encoder.encode(analysis.suggestedTargets!), encoding: .utf8)) : nil
            let routineJson = analysis.recommendedRoutine != nil ? (try? String(data: encoder.encode(analysis.recommendedRoutine!), encoding: .utf8)) : nil
            
            var aDict: [String: Any] = [
                "id": UUID().uuidString,
                "statusSummary": analysis.statusSummary,
                "calorieDiagnostic": analysis.calorieDiagnostic,
                "macroDiagnostic": analysis.macroDiagnostic,
                "hydrationDiagnostic": analysis.hydrationDiagnostic,
                "workoutSuggestionsJson": workoutSugg,
                "nutritionSuggestionsJson": nutrSugg,
                "weeklyActionPlan": analysis.weeklyActionPlan,
                "createdAt": isoFormatter.string(from: analysis.generatedAt)
            ]
            if let tj = targetsJson { aDict["suggestedTargetsJson"] = tj }
            if let rj = routineJson { aDict["recommendedRoutineJson"] = rj }
            analysesArray.append(aDict)
        }
        
        // 8. Log Completo de Atividades (user_activity_logs)
        let rawLogs = AppActivityLogManager.shared.getAllRecords()
        let activityLogsArray = rawLogs.map { l -> [String: Any] in
            var logDict: [String: Any] = [
                "id": l.id,
                "category": l.category,
                "title": l.title,
                "caloriesChange": l.caloriesChange,
                "timestamp": l.timestamp
            ]
            if let isSnack = l.isSnack { logDict["isSnack"] = isSnack }
            if let prot = l.proteinGrams { logDict["proteinGrams"] = prot }
            if let carbs = l.carbsGrams { logDict["carbsGrams"] = carbs }
            if let fat = l.fatGrams { logDict["fatGrams"] = fat }
            if let water = l.waterMilliliters { logDict["waterMilliliters"] = water }
            if let weight = l.weightKg { logDict["weightKg"] = weight }
            if let details = l.details { logDict["details"] = details }
            return logDict
        }
        
        let currentUserId = AuthManager.shared.currentUserId ?? ""
        let resetAckKey = "contaca_reset_ack_\(currentUserId)"
        let clientResetAck = UserDefaults.standard.object(forKey: resetAckKey) as? Int64 ?? 0

        let sentFoodDeletes = loadDeletedIdsSet(forKey: deletedFoodIdsKey)
        let sentWorkoutDeletes = loadDeletedIdsSet(forKey: deletedWorkoutIdsKey)
        let sentWaterDeletes = loadDeletedIdsSet(forKey: deletedWaterIdsKey)
        let sentWeightDeletes = loadDeletedIdsSet(forKey: deletedWeightIdsKey)
        let sentRoutineDeletes = loadDeletedIdsSet(forKey: deletedRoutineIdsKey)
        
        var payload: [String: Any] = [
            "foods": foodsArray,
            "workouts": workoutsArray,
            "waters": watersArray,
            "weights": weightsArray,
            "routines": routinesArray,
            "analyses": analysesArray,
            "activityLogs": activityLogsArray,
            "clientResetAckEpochMs": clientResetAck,
            "deletedFoodIds": Array(sentFoodDeletes),
            "deletedWorkoutIds": Array(sentWorkoutDeletes),
            "deletedWaterIds": Array(sentWaterDeletes),
            "deletedWeightIds": Array(sentWeightDeletes),
            "deletedRoutineIds": Array(sentRoutineDeletes)
        ]
        if let profileDict = profileDict {
            payload["profile"] = profileDict
        }
        
        let respData: Data
        do {
            respData = try await FormaAPIClient.shared.requestData(
                path: "/api/sync/push",
                method: "POST",
                jsonBody: payload,
                authenticated: true,
                timeout: 15.0
            )
        } catch FormaAPIError.accountDeleted {
            return
        }

        if let respJson = try? JSONSerialization.jsonObject(with: respData) as? [String: Any],
           let status = respJson["status"] as? String, status == "reset_required" {
            let resetEpoch = (respJson["forceResetEpochMs"] as? NSNumber)?.int64Value ?? Int64(Date().timeIntervalSince1970 * 1000)
            clearAllPendingDeletions()
            ContaCaDataStore.shared.resetLocalDataForUserSwitch(
                userName: AuthManager.shared.currentUserName,
                userEmail: AuthManager.shared.currentUserEmail
            )
            UserDefaults.standard.set(resetEpoch, forKey: resetAckKey)
            return
        }

        acknowledgeDeletedIds(sentFoodDeletes, forKey: deletedFoodIdsKey)
        acknowledgeDeletedIds(sentWorkoutDeletes, forKey: deletedWorkoutIdsKey)
        acknowledgeDeletedIds(sentWaterDeletes, forKey: deletedWaterIdsKey)
        acknowledgeDeletedIds(sentWeightDeletes, forKey: deletedWeightIdsKey)
        acknowledgeDeletedIds(sentRoutineDeletes, forKey: deletedRoutineIdsKey)
    }
    
    // MARK: - Pull (Backend / Supabase -> Local)
    private func pullRemoteData(context: ModelContext, token: String, userId: String) async throws {
        let data: Data
        do {
            let encodedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? userId
            data = try await FormaAPIClient.shared.requestData(
                path: "/api/sync/pull?userId=\(encodedUserId)",
                method: "GET",
                authenticated: true,
                timeout: 15.0
            )
        } catch FormaAPIError.accountDeleted {
            return
        } catch {
            return
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        // Se a conta foi zerada pelo administrador desde o último ack local, limpa dados locais antes de restaurar
        let resetAckKey = "contaca_reset_ack_\(userId)"
        let localAck = UserDefaults.standard.object(forKey: resetAckKey) as? Int64 ?? 0
        if let forceResetNum = json["forceResetEpochMs"] as? NSNumber {
            let serverResetEpoch = forceResetNum.int64Value
            if serverResetEpoch > localAck {
                ContaCaDataStore.shared.resetLocalDataForUserSwitch(
                    userName: AuthManager.shared.currentUserName,
                    userEmail: AuthManager.shared.currentUserEmail
                )
                UserDefaults.standard.set(serverResetEpoch, forKey: resetAckKey)
            }
        }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackIso = ISO8601DateFormatter()
        
        // 1. Restaura Profile e sincroniza nome/e-mail da conta autenticada
        let profileDesc = FetchDescriptor<Profile>()
        let allProfiles = (try? context.fetch(profileDesc)) ?? []
        if allProfiles.count > 1 {
            for extra in allProfiles.dropFirst() {
                context.delete(extra)
            }
        }
        let targetProfile: Profile
        if let existing = allProfiles.first {
            targetProfile = existing
        } else {
            let fresh = Profile(
                nome: AuthManager.shared.currentUserName ?? "Usuário",
                email: AuthManager.shared.currentUserEmail ?? ""
            )
            context.insert(fresh)
            targetProfile = fresh
        }
        if let authName = AuthManager.shared.currentUserName, !authName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            targetProfile.nome = authName
        }
        if let authEmail = AuthManager.shared.currentUserEmail, !authEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            targetProfile.email = authEmail
        }
        if let profileDict = json["profile"] as? [String: Any] {
            if let g = profileDict["goal"] as? String { targetProfile.goalRaw = g }
            if let ci = profileDict["targetCalorieIntake"] as? Double { targetProfile.targetCalorieIntake = ci }
            if let cb = profileDict["targetCalorieBurn"] as? Double { targetProfile.targetCalorieBurn = cb }
            if let ts = profileDict["targetSteps"] as? Double { targetProfile.targetSteps = ts }
            if let tw = profileDict["targetWeight"] as? Double { targetProfile.targetWeight = tw }
            if let tp = profileDict["targetProtein"] as? Double { targetProfile.targetProtein = tp }
            if let tc = profileDict["targetCarbohydrates"] as? Double { targetProfile.targetCarbohydrates = tc }
            if let tf = profileDict["targetFat"] as? Double { targetProfile.targetFat = tf }
            if let twm = profileDict["targetWaterMilliliters"] as? Int { targetProfile.targetWaterMilliliters = twm }
            if let hm = profileDict["heightMeters"] as? Double { targetProfile.height = hm }
            if let cw = profileDict["currentWeight"] as? Double { targetProfile.currentWeight = cw }
        }
        
        let pendingFoodDeletes = loadDeletedIdsSet(forKey: deletedFoodIdsKey)
        let pendingWorkoutDeletes = loadDeletedIdsSet(forKey: deletedWorkoutIdsKey)
        let pendingWaterDeletes = loadDeletedIdsSet(forKey: deletedWaterIdsKey)
        let pendingWeightDeletes = loadDeletedIdsSet(forKey: deletedWeightIdsKey)
        let pendingRoutineDeletes = loadDeletedIdsSet(forKey: deletedRoutineIdsKey)

        // 2. Restaura Foods
        if let foods = json["foods"] as? [[String: Any]] {
            let existingDesc = FetchDescriptor<FoodEntry>()
            let existingFoods = (try? context.fetch(existingDesc)) ?? []
            let existingIds = Set(existingFoods.map { $0.id.uuidString.lowercased() })
            
            for f in foods {
                guard let idStr = f["id"] as? String,
                      let id = UUID(uuidString: idStr),
                      !existingIds.contains(idStr.lowercased()),
                      !pendingFoodDeletes.contains(idStr.lowercased()) else {
                    continue
                }
                let name = f["name"] as? String ?? "Alimento"
                let brand = f["brand"] as? String ?? ""
                let mealTypeRaw = f["mealType"] as? String ?? "Almoço"
                let portion = f["portionGrams"] as? Double ?? 100.0
                let cal = f["calories"] as? Double ?? 0.0
                let prot = f["protein"] as? Double ?? 0.0
                let carbs = f["carbohydrates"] as? Double ?? 0.0
                let fat = f["fat"] as? Double ?? 0.0
                let dateStr = f["consumedAt"] as? String ?? ""
                let date = isoFormatter.date(from: dateStr) ?? fallbackIso.date(from: dateStr) ?? Date()
                
                let entry = FoodEntry(
                    id: id,
                    name: name,
                    brand: brand,
                    mealType: MealType(rawValue: mealTypeRaw) ?? .lunch,
                    portionGrams: portion,
                    calories: cal,
                    protein: prot,
                    carbohydrates: carbs,
                    fat: fat,
                    date: date,
                    createdAt: date
                )
                context.insert(entry)
            }
        }
        
        // 3. Restaura Workouts
        if let workouts = json["workouts"] as? [[String: Any]] {
            let existingDesc = FetchDescriptor<WorkoutEntry>()
            let existingWorkouts = (try? context.fetch(existingDesc)) ?? []
            let existingIds = Set(existingWorkouts.map { $0.id.uuidString.lowercased() })
            
            for w in workouts {
                guard let idStr = w["id"] as? String,
                      let id = UUID(uuidString: idStr),
                      !existingIds.contains(idStr.lowercased()),
                      !pendingWorkoutDeletes.contains(idStr.lowercased()) else {
                    continue
                }
                let title = w["title"] as? String ?? "Treino"
                let workoutTypeRaw = w["workoutType"] as? String ?? "Musculação"
                let duration = w["durationMinutes"] as? Int ?? 45
                let cals = w["caloriesBurned"] as? Double ?? 300.0
                let notes = w["notes"] as? String ?? ""
                let dateStr = w["workoutDate"] as? String ?? ""
                let date = isoFormatter.date(from: dateStr) ?? fallbackIso.date(from: dateStr) ?? Date()
                
                let entry = WorkoutEntry(
                    id: id,
                    title: title,
                    workoutType: WorkoutType(rawValue: workoutTypeRaw) ?? .bodybuilding,
                    durationMinutes: duration,
                    caloriesBurned: cals,
                    date: date,
                    notes: notes,
                    createdAt: date
                )
                context.insert(entry)
            }
        }
        
        // 4. Restaura Waters
        if let waters = json["waters"] as? [[String: Any]] {
            let existingDesc = FetchDescriptor<WaterEntry>()
            let existingWaters = (try? context.fetch(existingDesc)) ?? []
            let existingIds = Set(existingWaters.map { $0.id.uuidString.lowercased() })
            
            for wa in waters {
                guard let idStr = wa["id"] as? String,
                      let id = UUID(uuidString: idStr),
                      !existingIds.contains(idStr.lowercased()),
                      !pendingWaterDeletes.contains(idStr.lowercased()) else {
                    continue
                }
                let ml = wa["milliliters"] as? Int ?? 250
                let dateStr = wa["entryDate"] as? String ?? ""
                let date = isoFormatter.date(from: dateStr) ?? fallbackIso.date(from: dateStr) ?? Date()
                
                let entry = WaterEntry(id: id, milliliters: ml, date: date, createdAt: date)
                context.insert(entry)
            }
        }
        
        // 5. Restaura Weights
        if let weights = json["weights"] as? [[String: Any]] {
            let existingDesc = FetchDescriptor<WeightEntry>()
            let existingWeights = (try? context.fetch(existingDesc)) ?? []
            let existingIds = Set(existingWeights.map { $0.id.uuidString.lowercased() })
            
            for we in weights {
                guard let idStr = we["id"] as? String,
                      let id = UUID(uuidString: idStr),
                      !existingIds.contains(idStr.lowercased()),
                      !pendingWeightDeletes.contains(idStr.lowercased()) else {
                    continue
                }
                let weight = we["weight"] as? Double ?? 70.0
                let notes = we["notes"] as? String ?? ""
                let dateStr = we["entryDate"] as? String ?? ""
                let date = isoFormatter.date(from: dateStr) ?? fallbackIso.date(from: dateStr) ?? Date()
                
                let entry = WeightEntry(id: id, weight: weight, date: date, notes: notes)
                context.insert(entry)
            }
        }
        
        // 6. Restaura Fichas e Rotinas de Treino (WorkoutRoutine)
        if let routines = json["routines"] as? [[String: Any]] {
            let existingDesc = FetchDescriptor<WorkoutRoutine>()
            let existingRoutines = (try? context.fetch(existingDesc)) ?? []
            let existingIds = Set(existingRoutines.map { $0.id.uuidString.lowercased() })
            
            for r in routines {
                guard let idStr = r["id"] as? String,
                      let id = UUID(uuidString: idStr),
                      !existingIds.contains(idStr.lowercased()),
                      !pendingRoutineDeletes.contains(idStr.lowercased()) else {
                    continue
                }
                let title = r["title"] as? String ?? "Ficha de Treino"
                let workoutTypeRaw = r["workoutType"] as? String ?? "Musculação"
                let targetMuscles = r["targetMuscles"] as? String ?? ""
                let hypertrophyFocus = r["hypertrophyFocus"] as? String ?? ""
                let duration = r["estimatedDurationMinutes"] as? Int ?? 50
                let cals = r["estimatedCalories"] as? Double ?? 350.0
                let rest = r["recommendedRestSeconds"] as? Int ?? 90
                let isFav = r["isFavorite"] as? Bool ?? false
                let exercisesJson = r["exercisesJson"] as? String ?? "[]"
                let notes = r["notes"] as? String ?? ""
                let createdAtStr = r["createdAt"] as? String ?? ""
                let createdAt = isoFormatter.date(from: createdAtStr) ?? fallbackIso.date(from: createdAtStr) ?? Date()
                
                let lastTrainedStr = r["lastTrainedAt"] as? String
                let lastTrained = lastTrainedStr != nil ? (isoFormatter.date(from: lastTrainedStr!) ?? fallbackIso.date(from: lastTrainedStr!)) : nil
                
                let routine = WorkoutRoutine(
                    id: id,
                    title: title,
                    workoutType: WorkoutType(rawValue: workoutTypeRaw) ?? .bodybuilding,
                    targetMuscles: targetMuscles,
                    hypertrophyFocus: hypertrophyFocus,
                    estimatedDurationMinutes: duration,
                    estimatedCalories: cals,
                    recommendedRestSeconds: rest,
                    isFavorite: isFav,
                    exercises: [],
                    notes: notes,
                    createdAt: createdAt,
                    lastTrainedAt: lastTrained
                )
                routine.exercisesJson = exercisesJson
                context.insert(routine)
            }
        }
        
        // 7. Restaura Análise de IA mais recente
        if let analyses = json["analyses"] as? [[String: Any]], let latest = analyses.first {
            let summary = latest["statusSummary"] as? String ?? "Diagnóstico Concluído"
            let calDiag = latest["calorieDiagnostic"] as? String ?? ""
            let macroDiag = latest["macroDiagnostic"] as? String ?? ""
            let hydDiag = latest["hydrationDiagnostic"] as? String ?? ""
            let plan = latest["weeklyActionPlan"] as? String ?? ""
            let createdStr = latest["createdAt"] as? String ?? ""
            let created = isoFormatter.date(from: createdStr) ?? fallbackIso.date(from: createdStr) ?? Date()
            
            let decoder = JSONDecoder()
            var workoutSugg: [String] = []
            if let wj = latest["workoutSuggestionsJson"] as? String, let d = wj.data(using: .utf8) {
                workoutSugg = (try? decoder.decode([String].self, from: d)) ?? []
            }
            var nutrSugg: [String] = []
            if let nj = latest["nutritionSuggestionsJson"] as? String, let d = nj.data(using: .utf8) {
                nutrSugg = (try? decoder.decode([String].self, from: d)) ?? []
            }
            var targets: SuggestedNutritionTargets? = nil
            if let tj = latest["suggestedTargetsJson"] as? String, let d = tj.data(using: .utf8) {
                targets = try? decoder.decode(SuggestedNutritionTargets.self, from: d)
            }
            var routine: AIRecommendedRoutine? = nil
            if let rj = latest["recommendedRoutineJson"] as? String, let d = rj.data(using: .utf8) {
                routine = try? decoder.decode(AIRecommendedRoutine.self, from: d)
            }
            
            let restoredAnalysis = EvolutionAIAnalysis(
                statusSummary: summary,
                calorieDiagnostic: calDiag,
                macroDiagnostic: macroDiag,
                hydrationDiagnostic: hydDiag,
                workoutSuggestions: workoutSugg,
                nutritionSuggestions: nutrSugg,
                weeklyActionPlan: plan,
                suggestedTargets: targets,
                recommendedRoutine: routine,
                generatedAt: created
            )
            EvolutionAnalysisStore.shared.save(restoredAnalysis)
        } else if let analyses = json["analyses"] as? [[String: Any]], analyses.isEmpty {
            EvolutionAnalysisStore.shared.clear()
        }
        
        // 8. Restaura Logs de Atividades no AppActivityLogManager
        if let activityLogs = json["activityLogs"] as? [[String: Any]] {
            let allPendingDeletes = pendingFoodDeletes
                .union(pendingWorkoutDeletes)
                .union(pendingWaterDeletes)
                .union(pendingWeightDeletes)
            var recordsToMerge: [ActivityLogRecord] = []
            for l in activityLogs {
                guard let id = l["id"] as? String,
                      !allPendingDeletes.contains(id.lowercased()) else { continue }
                let cat = l["category"] as? String ?? "activity"
                let title = l["title"] as? String ?? ""
                let isSnack = l["isSnack"] as? Bool
                let cals = l["caloriesChange"] as? Double ?? 0.0
                let prot = l["proteinGrams"] as? Double
                let carbs = l["carbsGrams"] as? Double
                let fat = l["fatGrams"] as? Double
                let water = l["waterMilliliters"] as? Int
                let weight = l["weightKg"] as? Double
                let details = l["details"] as? String
                let timeStr = l["timestamp"] as? String ?? ""
                let timestamp = isoFormatter.date(from: timeStr) ?? fallbackIso.date(from: timeStr) ?? Date()
                
                let rec = ActivityLogRecord(
                    id: id,
                    timestamp: timestamp,
                    category: cat,
                    title: title,
                    isSnack: isSnack,
                    caloriesChange: cals,
                    proteinGrams: prot,
                    carbsGrams: carbs,
                    fatGrams: fat,
                    waterMilliliters: water,
                    weightKg: weight,
                    details: details
                )
                recordsToMerge.append(rec)
            }
            if !recordsToMerge.isEmpty {
                AppActivityLogManager.shared.mergeRemoteRecords(recordsToMerge)
            }
        }
        
        try? context.save()
    }
}
