//
//  DataStoreIsolationTests.swift
//  FormaTests
//

import XCTest
import SwiftData
@testable import Forma

@MainActor
final class DataStoreIsolationTests: XCTestCase {

    func testEnsureSingleProfileDeduplicatesMultipleProfiles() throws {
        let store = FormaDataStore(inMemory: true)
        let ctx = store.mainContext

        ctx.insert(Profile(nome: "Perfil 1", email: "um@forma.app"))
        ctx.insert(Profile(nome: "Perfil 2", email: "dois@forma.app"))
        ctx.insert(Profile(nome: "Perfil 3", email: "tres@forma.app"))
        try ctx.save()

        let consolidated = store.ensureSingleProfile(in: ctx)
        let remaining = try ctx.fetch(FetchDescriptor<Profile>())

        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, consolidated.id)
    }

    func testMultiUserSwitchWipesPreviousAccountRecordsCleanly() throws {
        let store = FormaDataStore(inMemory: true)
        let ctx = store.mainContext

        let profileA = store.ensureSingleProfile(in: ctx)
        profileA.nome = "Atleta A"
        profileA.email = "atleta.a@forma.app"
        profileA.currentWeight = 78.0
        profileA.targetWeight = 86.0

        try store.insertFoodEntries([
            FoodEntry(name: "Arroz e Frango", mealType: .lunch, portionGrams: 320, calories: 540, protein: 45, carbohydrates: 62, fat: 8)
        ])
        try store.insertWorkoutEntry(
            WorkoutEntry(title: "Treino A", workoutType: .bodybuilding, durationMinutes: 60, caloriesBurned: 430)
        )
        try store.insertWaterEntry(WaterEntry(milliliters: 600))
        ctx.insert(WeightEntry(weight: 78.0))
        try store.insertWorkoutRoutine(
            WorkoutRoutine(title: "Ficha Hipertrofia A", workoutType: .bodybuilding, targetMuscles: "Peito", estimatedDurationMinutes: 55, estimatedCalories: 380)
        )

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<FoodEntry>()).count, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WorkoutEntry>()).count, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WaterEntry>()).count, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WeightEntry>()).count, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WorkoutRoutine>()).count, 1)

        // Troca de usuário deve limpar 100% dos registros anteriores e criar perfil limpo para Atleta B
        store.resetLocalDataForUserSwitch(userName: "Atleta B", userEmail: "atleta.b@forma.app")

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<FoodEntry>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WorkoutEntry>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WaterEntry>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WeightEntry>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WorkoutRoutine>()).count, 0)

        let profilesAfterSwitch = try ctx.fetch(FetchDescriptor<Profile>())
        XCTAssertEqual(profilesAfterSwitch.count, 1)
        XCTAssertEqual(profilesAfterSwitch.first?.nome, "Atleta B")
        XCTAssertEqual(profilesAfterSwitch.first?.email, "atleta.b@forma.app")
        XCTAssertEqual(profilesAfterSwitch.first?.autoRecalculateGoals, true)
    }

    func testDeletionsRecordSyncTombstonesAndAlwaysKeepFullContextRecalculationEnabled() throws {
        BackendSyncManager.shared.clearAllPendingDeletions()
        let store = FormaDataStore(inMemory: true)
        let ctx = store.mainContext

        let profile = store.ensureSingleProfile(in: ctx)
        profile.autoRecalculateGoals = false
        let ensured = store.ensureSingleProfile(in: ctx)
        XCTAssertTrue(ensured.autoRecalculateGoals)

        let food = FoodEntry(name: "Coxinha", mealType: .snacks, portionGrams: 140, calories: 364, protein: 14, carbohydrates: 36, fat: 18)
        let workout = WorkoutEntry(title: "Treino de Costas", workoutType: .bodybuilding, durationMinutes: 45, caloriesBurned: 260)
        ctx.insert(food)
        ctx.insert(workout)
        try ctx.save()

        let foodId = food.id.uuidString.lowercased()
        let workoutId = workout.id.uuidString.lowercased()

        store.deleteFoodEntry(food, in: ctx)
        store.deleteWorkoutEntry(workout, in: ctx)

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<FoodEntry>()).count, 0)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WorkoutEntry>()).count, 0)

        BackendSyncManager.shared.recordDeletedFoodIds([UUID(uuidString: foodId)!])
        BackendSyncManager.shared.recordDeletedWorkoutIds([UUID(uuidString: workoutId)!])
        XCTAssertTrue(BackendSyncManager.shared.pendingDeletedFoodIds().contains(foodId))
        XCTAssertTrue(BackendSyncManager.shared.pendingDeletedWorkoutIds().contains(workoutId))

        BackendSyncManager.shared.clearAllPendingDeletions()
        XCTAssertFalse(BackendSyncManager.shared.pendingDeletedFoodIds().contains(foodId))
        XCTAssertFalse(BackendSyncManager.shared.pendingDeletedWorkoutIds().contains(workoutId))
    }
}
