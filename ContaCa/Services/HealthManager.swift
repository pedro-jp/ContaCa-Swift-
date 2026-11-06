//
//  HealthManager.swift
//  ContaCa
//
//  Created by João Pedro on 10/13/26.
//

import Foundation
import HealthKit

nonisolated struct ExternalWorkoutSample: Sendable {
    let workoutType: WorkoutType
    let title: String
    let sourceName: String
    let durationMinutes: Int
    let caloriesBurned: Double
    let startDate: Date
}

class HealthManager {
    static let shared = HealthManager()
    let healthStore = HKHealthStore()
    private var isObservingWorkouts: Bool = false
    
    private(set) var isHealthDataAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    
    // Verifica se está rodando no ambiente de Xcode Previews
    private var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    private init() {}
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        // No Xcode Previews, o HealthKit modal causa congelamento/crash
        if isRunningForPreviews {
            completion(true, nil)
            return
        }
        
        guard isHealthDataAvailable else {
            completion(false, nil)
            return
        }
        
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let basalEnergyType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned),
              let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
              let exerciseTimeType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
            completion(false, nil)
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            stepType,
            activeEnergyType,
            basalEnergyType,
            distanceType,
            exerciseTimeType,
            HKWorkoutType.workoutType()
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            activeEnergyType,
            HKWorkoutType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            completion(success, error)
        }
    }
    
    // MARK: - Salvar Treino e Calorias no Apple Health
    
    func saveWorkout(
        title: String,
        workoutType: WorkoutType,
        caloriesBurned: Double,
        durationMinutes: Int,
        date: Date = Date(),
        completion: ((Bool, Error?) -> Void)? = nil
    ) {
        if isRunningForPreviews || !isHealthDataAvailable {
            completion?(true, nil)
            return
        }
        
        let hkActivityType: HKWorkoutActivityType
        switch workoutType {
        case .bodybuilding:
            hkActivityType = .traditionalStrengthTraining
        case .running:
            hkActivityType = .running
        case .walking:
            hkActivityType = .walking
        case .cycling:
            hkActivityType = .cycling
        case .functional:
            hkActivityType = .functionalStrengthTraining
        case .swimming:
            hkActivityType = .swimming
        case .other:
            hkActivityType = .other
        }
        
        let validDuration = max(1, durationMinutes)
        let startDate = date.addingTimeInterval(-Double(validDuration) * 60)
        let endDate = date
        let energyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: caloriesBurned)
        
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = hkActivityType
        configuration.locationType = .indoor
        
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        builder.beginCollection(withStart: startDate) { success, error in
            guard success else {
                completion?(false, error)
                return
            }
            
            let metadata: [String: Any] = [
                HKMetadataKeyWorkoutBrandName: "Forma",
                HKMetadataKeyIndoorWorkout: true
            ]
            
            var samples: [HKSample] = []
            if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                samples.append(
                    HKQuantitySample(
                        type: energyType,
                        quantity: energyBurned,
                        start: startDate,
                        end: endDate
                    )
                )
            }
            
            let finalizeCollection = {
                builder.endCollection(withEnd: endDate) { endSuccess, endError in
                    guard endSuccess else {
                        completion?(false, endError)
                        return
                    }
                    builder.finishWorkout { workout, finishError in
                        completion?(workout != nil, finishError)
                    }
                }
            }
            
            builder.addMetadata(metadata) { _, _ in
                if samples.isEmpty {
                    finalizeCollection()
                } else {
                    builder.add(samples) { _, _ in
                        finalizeCollection()
                    }
                }
            }
        }
    }
    
    nonisolated static func activeEnergyKilocalories(for workout: HKWorkout) -> Double {
        if let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           let sumQuantity = workout.statistics(for: activeEnergyType)?.sumQuantity() {
            let value = sumQuantity.doubleValue(for: .kilocalorie())
            if value > 0 {
                return value
            }
        }
        let durationMinutes = max(1, Int(workout.duration / 60.0))
        return Double(durationMinutes * 8)
    }

    nonisolated func activeEnergyBurnedKilocalories(for workout: HKWorkout) -> Double {
        Self.activeEnergyKilocalories(for: workout)
    }
    
    func fetchTodaySteps(completion: @escaping (Double) -> Void) {
        if isRunningForPreviews {
            completion(6420)
            return
        }
        
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(0.0)
            return
        }
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0.0)
                return
            }
            completion(sum.doubleValue(for: HKUnit.count()))
        }
        
        healthStore.execute(query)
    }
    
    func fetchTodayCalories(completion: @escaping (Double) -> Void) {
        if isRunningForPreviews {
            completion(520)
            return
        }
        
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(0.0)
            return
        }
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0.0)
                return
            }
            completion(sum.doubleValue(for: HKUnit.kilocalorie()))
        }
        
        healthStore.execute(query)
    }
    
    func fetchTodayBasalCalories(completion: @escaping (Double) -> Void) {
        if isRunningForPreviews {
            completion(1750)
            return
        }
        
        guard let basalType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else {
            completion(0.0)
            return
        }
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: basalType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0.0)
                return
            }
            completion(sum.doubleValue(for: HKUnit.kilocalorie()))
        }
        
        healthStore.execute(query)
    }
    
    func fetchTodayDistance(completion: @escaping (Double) -> Void) {
        if isRunningForPreviews {
            completion(4.6)
            return
        }
        
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            completion(0.0)
            return
        }
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: distanceType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0.0)
                return
            }
            completion(sum.doubleValue(for: HKUnit.meter()) / 1000.0)
        }
        
        healthStore.execute(query)
    }
    
    func fetchTodayExerciseTime(completion: @escaping (Double) -> Void) {
        if isRunningForPreviews {
            completion(50)
            return
        }
        
        guard let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else {
            completion(0.0)
            return
        }
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: exerciseType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0.0)
                return
            }
            completion(sum.doubleValue(for: HKUnit.minute()))
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Leitura e Sincronização de Treinos Externos (Strava, Apple Watch, Garmin, etc.)

    nonisolated private static func mapExternalSample(_ hkWorkout: HKWorkout) -> ExternalWorkoutSample {
        let durationMinutes = max(1, Int(hkWorkout.duration / 60.0))
        let caloriesBurned = activeEnergyKilocalories(for: hkWorkout)
        let sourceName = hkWorkout.sourceRevision.source.name

        let workoutType: WorkoutType
        let title: String
        switch hkWorkout.workoutActivityType {
        case .cycling:
            workoutType = .cycling
            title = "Pedalada / Bike (\(sourceName))"
        case .running:
            workoutType = .running
            title = "Corrida (\(sourceName))"
        case .walking:
            workoutType = .walking
            title = "Caminhada (\(sourceName))"
        case .swimming:
            workoutType = .swimming
            title = "Natação (\(sourceName))"
        case .traditionalStrengthTraining:
            workoutType = .bodybuilding
            title = "Musculação (\(sourceName))"
        default:
            workoutType = .other
            title = "Treino (\(sourceName))"
        }

        return ExternalWorkoutSample(
            workoutType: workoutType,
            title: title,
            sourceName: sourceName,
            durationMinutes: durationMinutes,
            caloriesBurned: caloriesBurned,
            startDate: hkWorkout.startDate
        )
    }

    func fetchExternalWorkoutSamples(
        days: Int = 7,
        completion: @escaping @MainActor ([ExternalWorkoutSample]) -> Void
    ) {
        if isRunningForPreviews || !isHealthDataAvailable {
            completion([])
            return
        }

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(
            sampleType: HKWorkoutType.workoutType(),
            predicate: predicate,
            limit: 100,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, _ in
            guard let workouts = samples as? [HKWorkout] else {
                Task { @MainActor in
                    completion([])
                }
                return
            }
            // Filtra treinos externos (Strava, Bike, Apple Watch, etc.), ignorando os salvos pelo próprio Forma
            let externalSamples = workouts.compactMap { workout -> ExternalWorkoutSample? in
                let brand = workout.metadata?[HKMetadataKeyWorkoutBrandName] as? String
                guard brand != "Forma" && brand != "ContaCa" else { return nil }
                return Self.mapExternalSample(workout)
            }
            Task { @MainActor in
                completion(externalSamples)
            }
        }

        healthStore.execute(query)
    }
    
    /// Observa novos treinos no Apple Saúde (Strava, Apple Watch, etc.) em segundo plano e notifica imediatamente.
    func startObservingExternalWorkouts(onNewWorkout: @escaping @Sendable () -> Void) {
        guard !isRunningForPreviews, isHealthDataAvailable, !isObservingWorkouts else { return }
        isObservingWorkouts = true
        
        let workoutType = HKWorkoutType.workoutType()
        let observerQuery = HKObserverQuery(sampleType: workoutType, predicate: nil) { _, completionHandler, error in
            defer { completionHandler() }
            guard error == nil else { return }
            onNewWorkout()
        }
        healthStore.execute(observerQuery)
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in }
    }
}
