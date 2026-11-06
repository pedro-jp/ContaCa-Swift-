//
//  WorkoutEntry.swift
//  Forma
//
//  Created by João Pedro on 10/27/26.
//

import Foundation
import SwiftData

public enum WorkoutType: String, Codable, CaseIterable, Identifiable, Sendable {
    case bodybuilding = "Musculação"
    case running = "Corrida"
    case walking = "Caminhada"
    case cycling = "Ciclismo"
    case functional = "Funcional / HIIT"
    case swimming = "Natação"
    case other = "Outro"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .bodybuilding: return "dumbbell.fill"
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .functional: return "figure.cross.training"
        case .swimming: return "figure.pool.swim"
        case .other: return "flame.fill"
        }
    }
}

@Model
final class WorkoutEntry {
    var id: UUID = UUID()
    var title: String = ""
    var workoutTypeRaw: String = "Musculação"
    var durationMinutes: Int = 45
    var caloriesBurned: Double = 350.0
    var date: Date = Date()
    var notes: String = ""
    var createdAt: Date = Date()
    
    var workoutType: WorkoutType {
        get { WorkoutType(rawValue: workoutTypeRaw) ?? .bodybuilding }
        set { workoutTypeRaw = newValue.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        workoutType: WorkoutType = .bodybuilding,
        durationMinutes: Int = 45,
        caloriesBurned: Double = 350.0,
        date: Date = Date(),
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.workoutTypeRaw = workoutType.rawValue
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.date = date
        self.notes = notes
        self.createdAt = createdAt
    }
}
