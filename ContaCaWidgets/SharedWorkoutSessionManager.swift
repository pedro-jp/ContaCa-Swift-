//
//  SharedWorkoutSessionManager.swift
//  ContaCaWidgets
//
//  Created by João Pedro on 10/29/26.
//

import Foundation
import ActivityKit

public struct WorkoutExerciseItem: Codable, Identifiable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var sets: Int
    public var reps: String
    public var suggestedWeight: String
    public var targetMuscle: String
    public var executionTip: String
    public var restSeconds: Int
    public var completedSets: [Bool]
    public var animationId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, sets, reps
        case suggestedWeight = "suggested_weight"
        case targetMuscle = "target_muscle"
        case executionTip = "execution_tip"
        case restSeconds = "rest_seconds"
        case completedSets = "completed_sets"
        case animationId = "animation_id"
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        sets: Int = 3,
        reps: String = "10-12",
        suggestedWeight: String = "",
        targetMuscle: String = "",
        executionTip: String = "",
        restSeconds: Int = 90,
        completedSets: [Bool]? = nil,
        animationId: String? = nil
    ) {
        self.id = id
        self.name = name
        let safeSets = max(1, sets)
        self.sets = safeSets
        self.reps = reps.isEmpty ? "10-12" : reps
        self.suggestedWeight = suggestedWeight
        self.targetMuscle = targetMuscle
        self.executionTip = executionTip
        self.restSeconds = restSeconds > 0 ? restSeconds : 90
        self.completedSets = completedSets ?? Array(repeating: false, count: safeSets)
        self.animationId = animationId
    }
    
    public var isAllSetsCompleted: Bool {
        !completedSets.isEmpty && completedSets.allSatisfy { $0 }
    }
    
    public var completedCount: Int {
        completedSets.filter { $0 }.count
    }
}

public struct SharedWorkoutState: Codable, Sendable {
    public var title: String
    public var workoutTypeRaw: String
    public var exercises: [WorkoutExerciseItem]
    public var currentExerciseIndex: Int
    public var currentSetIndex: Int
    public var sessionStartDate: Date
    public var baseCalories: Double
    public var baseDurationMinutes: Int
    public var isResting: Bool
    public var restStartDate: Date?
    public var restEndDate: Date?
    public var restDurationSeconds: Int
    public var isAllCompleted: Bool
    public var isFinished: Bool
    
    public init(
        title: String,
        workoutTypeRaw: String = "Musculação",
        exercises: [WorkoutExerciseItem] = [],
        currentExerciseIndex: Int = 0,
        currentSetIndex: Int = 0,
        sessionStartDate: Date = Date(),
        baseCalories: Double = 350.0,
        baseDurationMinutes: Int = 50,
        isResting: Bool = false,
        restStartDate: Date? = nil,
        restEndDate: Date? = nil,
        restDurationSeconds: Int = 90,
        isAllCompleted: Bool = false,
        isFinished: Bool = false
    ) {
        self.title = title
        self.workoutTypeRaw = workoutTypeRaw
        self.exercises = exercises
        self.currentExerciseIndex = currentExerciseIndex
        self.currentSetIndex = currentSetIndex
        self.sessionStartDate = sessionStartDate
        self.baseCalories = baseCalories
        self.baseDurationMinutes = baseDurationMinutes
        self.isResting = isResting
        self.restStartDate = restStartDate
        self.restEndDate = restEndDate
        self.restDurationSeconds = restDurationSeconds
        self.isAllCompleted = isAllCompleted
        self.isFinished = isFinished
    }
    
    public var totalSetsCount: Int {
        exercises.reduce(0) { $0 + $1.sets }
    }
    
    public var completedSetsCount: Int {
        exercises.reduce(0) { $0 + $1.completedCount }
    }
    
    public var liveCalories: Double {
        let elapsed = max(1.0, Date().timeIntervalSince(sessionStartDate) / 60.0)
        let rate = baseCalories / max(10.0, Double(baseDurationMinutes))
        return (elapsed * rate).rounded()
    }
    
    public var currentExercise: WorkoutExerciseItem? {
        guard currentExerciseIndex < exercises.count else { return exercises.last }
        return exercises[currentExerciseIndex]
    }
}

public final class SharedWorkoutSessionManager: @unchecked Sendable {
    public static let shared = SharedWorkoutSessionManager()
    
    private let appGroupSuite = "group.jota.ContaCa"
    private let sessionKey = "active_workout_session_state"
    private let pendingWorkoutKey = "pending_finished_workout"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupSuite)
    }
    
    private init() {}
    
    public func loadSession() -> SharedWorkoutState? {
        guard let data = sharedDefaults?.data(forKey: sessionKey) else { return nil }
        return try? JSONDecoder().decode(SharedWorkoutState.self, from: data)
    }
    
    public func saveSession(_ session: SharedWorkoutState) {
        if let data = try? JSONEncoder().encode(session) {
            sharedDefaults?.set(data, forKey: sessionKey)
        }
    }
    
    public func clearSession() {
        sharedDefaults?.removeObject(forKey: sessionKey)
    }
    
    public func completeCurrentSetFromLiveActivity() async {
        guard var session = loadSession() else { return }
        
        let exIndex = session.currentExerciseIndex
        guard exIndex < session.exercises.count else { return }
        
        var ex = session.exercises[exIndex]
        var sets = ex.completedSets
        while sets.count < ex.sets { sets.append(false) }
        
        let sIndex = min(session.currentSetIndex, ex.sets - 1)
        sets[sIndex] = true
        ex.completedSets = sets
        session.exercises[exIndex] = ex
        
        let allDone = session.exercises.allSatisfy { $0.isAllSetsCompleted }
        session.isAllCompleted = allDone
        
        if allDone {
            session.isResting = false
            session.restStartDate = nil
            session.restEndDate = nil
            WorkoutNotificationManager.shared.cancelRestNotification()
        } else {
            let targetRest = ex.restSeconds > 0 ? ex.restSeconds : session.restDurationSeconds
            let now = Date()
            session.isResting = true
            session.restStartDate = now
            session.restEndDate = now.addingTimeInterval(Double(targetRest))
            session.restDurationSeconds = targetRest
            
            if sIndex + 1 < ex.sets {
                session.currentSetIndex = sIndex + 1
            } else if exIndex + 1 < session.exercises.count {
                session.currentExerciseIndex = exIndex + 1
                session.currentSetIndex = 0
            }
            
            let nextEx = session.currentExercise ?? ex
            let nextSet = min(session.currentSetIndex + 1, nextEx.sets)
            WorkoutNotificationManager.shared.scheduleRestNotification(
                seconds: targetRest,
                exerciseName: nextEx.name,
                nextSet: nextSet
            )
        }
        
        saveSession(session)
        await syncLiveActivityState(from: session)
    }
    
    public func skipRestFromLiveActivity() async {
        guard var session = loadSession() else { return }
        session.isResting = false
        session.restStartDate = nil
        session.restEndDate = nil
        WorkoutNotificationManager.shared.cancelRestNotification()
        saveSession(session)
        await syncLiveActivityState(from: session)
    }
    
    public func addRestSecondsFromLiveActivity(seconds: Int = 30) async {
        guard var session = loadSession(), session.isResting else { return }
        let currentEnd = session.restEndDate ?? Date()
        let newEnd = currentEnd.addingTimeInterval(Double(seconds))
        session.restEndDate = newEnd
        session.restDurationSeconds += seconds
        
        let rem = max(1, Int(newEnd.timeIntervalSinceNow))
        let curEx = session.currentExercise
        let curSet = min(session.currentSetIndex + 1, curEx?.sets ?? 3)
        WorkoutNotificationManager.shared.scheduleRestNotification(
            seconds: rem,
            exerciseName: curEx?.name ?? "Treino",
            nextSet: curSet
        )
        
        saveSession(session)
        await syncLiveActivityState(from: session)
    }
    
    public func finishWorkoutFromLiveActivity() async {
        guard var session = loadSession() else { return }
        session.isFinished = true
        WorkoutNotificationManager.shared.cancelRestNotification()
        
        let pending = PendingWorkoutRecord(
            title: session.title,
            workoutTypeRaw: session.workoutTypeRaw,
            durationMinutes: max(1, Int(Date().timeIntervalSince(session.sessionStartDate) / 60)),
            caloriesBurned: session.liveCalories,
            notes: "Treino operado e concluído via Ilha Dinâmica (\(session.completedSetsCount)/\(session.totalSetsCount) séries).",
            date: Date()
        )
        if let data = try? JSONEncoder().encode(pending) {
            sharedDefaults?.set(data, forKey: pendingWorkoutKey)
        }
        
        clearSession()
        
        for activity in Activity<WorkoutActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
    
    public func syncLiveActivityState(from session: SharedWorkoutState) async {
        let curEx = session.currentExercise
        let curExName = curEx?.name ?? "Treino"
        let curSetNumber = min(session.currentSetIndex + 1, curEx?.sets ?? 3)
        let totalSetsForEx = curEx?.sets ?? 3
        
        let state = WorkoutActivityAttributes.ContentState(
            workoutTitle: session.title,
            currentExerciseName: curExName,
            currentSetNumber: curSetNumber,
            totalSetsForExercise: totalSetsForEx,
            completedSetsTotal: session.completedSetsCount,
            totalSetsTotal: session.totalSetsCount,
            caloriesBurned: session.liveCalories,
            workoutStartDate: session.sessionStartDate,
            isResting: session.isResting,
            restStartDate: session.restStartDate,
            restEndDate: session.restEndDate,
            restDurationSeconds: session.restDurationSeconds,
            isAllCompleted: session.isAllCompleted
        )
        
        for activity in Activity<WorkoutActivityAttributes>.activities {
            await activity.update(ActivityContent(state: state, staleDate: nil, relevanceScore: 100.0))
        }
    }
}

public struct PendingWorkoutRecord: Codable, Sendable {
    public var title: String
    public var workoutTypeRaw: String
    public var durationMinutes: Int
    public var caloriesBurned: Double
    public var notes: String
    public var date: Date
}
