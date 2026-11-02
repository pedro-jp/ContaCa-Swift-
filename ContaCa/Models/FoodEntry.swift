//
//  FoodEntry.swift
//  ContaCa
//
//  Created by João Pedro on 10/27/26.
//

import Foundation
import SwiftData

public enum MealType: String, Codable, CaseIterable, Identifiable, Sendable {
    case breakfast = "Café da Manhã"
    case lunch = "Almoço"
    case dinner = "Jantar"
    case snacks = "Lanches"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snacks: return "cup.and.saucer.fill"
        }
    }
}

@Model
final class FoodEntry {
    var id: UUID = UUID()
    var name: String = ""
    var brand: String = ""
    var mealTypeRaw: String = "Almoço"
    var portionGrams: Double = 100.0
    var calories: Double = 0.0
    var protein: Double = 0.0
    var carbohydrates: Double = 0.0
    var fat: Double = 0.0
    var date: Date = Date()
    var createdAt: Date = Date()
    
    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .lunch }
        set { mealTypeRaw = newValue.rawValue }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        brand: String = "",
        mealType: MealType = .lunch,
        portionGrams: Double = 100.0,
        calories: Double,
        protein: Double,
        carbohydrates: Double,
        fat: Double,
        date: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.mealTypeRaw = mealType.rawValue
        self.portionGrams = portionGrams
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.date = date
        self.createdAt = createdAt
    }
}
