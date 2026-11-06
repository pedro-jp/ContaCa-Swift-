//
//  CalorieActivityAttributes.swift
//  Forma
//
//  Created by João Pedro on 10/29/26.
//

import Foundation
import ActivityKit

nonisolated public struct CalorieActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var caloriesConsumed: Double
        public var caloriesTarget: Double
        public var caloriesBurned: Double
        public var proteinConsumed: Double
        public var proteinTarget: Double
        public var carbsConsumed: Double
        public var carbsTarget: Double
        public var fatConsumed: Double
        public var fatTarget: Double
        public var goalRaw: String
        public var lastFoodName: String?
        public var lastFoodCalories: Double?
        public var updatedAt: Date
        
        public init(
            caloriesConsumed: Double,
            caloriesTarget: Double,
            caloriesBurned: Double,
            proteinConsumed: Double,
            proteinTarget: Double,
            carbsConsumed: Double,
            carbsTarget: Double,
            fatConsumed: Double,
            fatTarget: Double,
            goalRaw: String,
            lastFoodName: String? = nil,
            lastFoodCalories: Double? = nil,
            updatedAt: Date = Date()
        ) {
            self.caloriesConsumed = caloriesConsumed
            self.caloriesTarget = caloriesTarget
            self.caloriesBurned = caloriesBurned
            self.proteinConsumed = proteinConsumed
            self.proteinTarget = proteinTarget
            self.carbsConsumed = carbsConsumed
            self.carbsTarget = carbsTarget
            self.fatConsumed = fatConsumed
            self.fatTarget = fatTarget
            self.goalRaw = goalRaw
            self.lastFoodName = lastFoodName
            self.lastFoodCalories = lastFoodCalories
            self.updatedAt = updatedAt
        }
        
        public var remainingCalories: Double {
            max(0, caloriesTarget - caloriesConsumed)
        }
        
        public var progressRatio: Double {
            guard caloriesTarget > 0 else { return 0 }
            return min(1.0, max(0.0, caloriesConsumed / caloriesTarget))
        }
    }
    
    public var userName: String
    
    public init(userName: String = "Você") {
        self.userName = userName
    }
}
