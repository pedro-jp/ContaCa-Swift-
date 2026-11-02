//
//  WorkoutRoutine.swift
//  ContaCa
//
//  Created by João Pedro on 10/29/26.
//

import Foundation
import SwiftData

/// Item de exercício individual dentro de uma rotina ou ficha de treino
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
        case id
        case name
        case sets
        case reps
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? "Exercício"
        let rawSets = (try? container.decodeIfPresent(Int.self, forKey: .sets)) ?? 3
        self.sets = max(1, rawSets)
        self.reps = (try? container.decodeIfPresent(String.self, forKey: .reps)) ?? "10-12"
        self.suggestedWeight = (try? container.decodeIfPresent(String.self, forKey: .suggestedWeight)) ?? ""
        self.targetMuscle = (try? container.decodeIfPresent(String.self, forKey: .targetMuscle)) ?? ""
        self.executionTip = (try? container.decodeIfPresent(String.self, forKey: .executionTip)) ?? ""
        let rawRest = (try? container.decodeIfPresent(Int.self, forKey: .restSeconds)) ?? 90
        self.restSeconds = rawRest > 0 ? rawRest : 90
        self.animationId = try? container.decodeIfPresent(String.self, forKey: .animationId)
        
        if let decodedSets = try? container.decodeIfPresent([Bool].self, forKey: .completedSets) {
            self.completedSets = decodedSets
        } else {
            self.completedSets = Array(repeating: false, count: self.sets)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(sets, forKey: .sets)
        try container.encode(reps, forKey: .reps)
        try container.encode(suggestedWeight, forKey: .suggestedWeight)
        try container.encode(targetMuscle, forKey: .targetMuscle)
        try container.encode(executionTip, forKey: .executionTip)
        try container.encode(restSeconds, forKey: .restSeconds)
        try container.encode(completedSets, forKey: .completedSets)
        try container.encodeIfPresent(animationId, forKey: .animationId)
    }
    
    public var isAllSetsCompleted: Bool {
        !completedSets.isEmpty && completedSets.allSatisfy { $0 }
    }
    
    public var completedCount: Int {
        completedSets.filter { $0 }.count
    }
}

/// Ficha ou Rotina de Treino persistida no SwiftData
@Model
final class WorkoutRoutine {
    var id: UUID = UUID()
    var title: String = ""
    var workoutTypeRaw: String = "Musculação"
    var targetMuscles: String = ""
    var hypertrophyFocus: String = ""
    var estimatedDurationMinutes: Int = 50
    var estimatedCalories: Double = 350.0
    var recommendedRestSeconds: Int = 90
    var isFavorite: Bool = false
    var exercisesJson: String = "[]"
    var notes: String = ""
    var createdAt: Date = Date()
    var lastTrainedAt: Date? = nil
    
    var workoutType: WorkoutType {
        get { WorkoutType(rawValue: workoutTypeRaw) ?? .bodybuilding }
        set { workoutTypeRaw = newValue.rawValue }
    }
    
    var exercises: [WorkoutExerciseItem] {
        get {
            guard let data = exercisesJson.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([WorkoutExerciseItem].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                exercisesJson = json
            } else {
                exercisesJson = "[]"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        workoutType: WorkoutType = .bodybuilding,
        targetMuscles: String = "",
        hypertrophyFocus: String = "",
        estimatedDurationMinutes: Int = 50,
        estimatedCalories: Double = 350.0,
        recommendedRestSeconds: Int = 90,
        isFavorite: Bool = false,
        exercises: [WorkoutExerciseItem] = [],
        notes: String = "",
        createdAt: Date = Date(),
        lastTrainedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.workoutTypeRaw = workoutType.rawValue
        self.targetMuscles = targetMuscles
        self.hypertrophyFocus = hypertrophyFocus
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.estimatedCalories = estimatedCalories
        self.recommendedRestSeconds = recommendedRestSeconds
        self.isFavorite = isFavorite
        self.notes = notes
        self.createdAt = createdAt
        self.lastTrainedAt = lastTrainedAt
        
        if let data = try? JSONEncoder().encode(exercises),
           let json = String(data: data, encoding: .utf8) {
            self.exercisesJson = json
        } else {
            self.exercisesJson = "[]"
        }
    }
}
