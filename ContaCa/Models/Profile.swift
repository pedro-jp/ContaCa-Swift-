//
//  Profile.swift
//  ContaCa
//
//  Created by João Pedro on 10/18/26.
//

import Foundation
import SwiftData

public enum FitnessGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case gain = "Ganhar peso"
    case lose = "Perder peso"
    case maintain = "Manter peso"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .gain: return "arrow.up.circle.fill"
        case .lose: return "arrow.down.circle.fill"
        case .maintain: return "equal.circle.fill"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .gain: return "Ganho de massa muscular e peso"
        case .lose: return "Queima de gordura e definição"
        case .maintain: return "Manter o peso e a forma atual"
        }
    }
}

public enum FocusMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    case consumed = "Calorias Consumidas"
    case burned = "Calorias Gastas"
    
    public var id: String { rawValue }
}

/// Contexto fisiológico e comportamental completo (treinos, rotinas, passos, tendência de peso e ingestão)
public struct RecalculationContext: Sendable {
    public var workoutsLast14DaysCount: Int
    public var avgDailyWorkoutBurn: Double
    public var routineEstimatedDailyBurn: Double
    public var recentAvgSteps: Double
    public var weeklyWeightTrendKg: Double?
    public var recentAvgCalorieIntake: Double?
    
    public init(
        workoutsLast14DaysCount: Int = 0,
        avgDailyWorkoutBurn: Double = 0.0,
        routineEstimatedDailyBurn: Double = 0.0,
        recentAvgSteps: Double = 0.0,
        weeklyWeightTrendKg: Double? = nil,
        recentAvgCalorieIntake: Double? = nil
    ) {
        self.workoutsLast14DaysCount = workoutsLast14DaysCount
        self.avgDailyWorkoutBurn = avgDailyWorkoutBurn
        self.routineEstimatedDailyBurn = routineEstimatedDailyBurn
        self.recentAvgSteps = recentAvgSteps
        self.weeklyWeightTrendKg = weeklyWeightTrendKg
        self.recentAvgCalorieIntake = recentAvgCalorieIntake
    }
}

/// Resultado completo do cálculo fisiológico contextual unificado
public struct ContextualGoalMetrics: Sendable {
    public let tmb: Double
    public let contextualTdee: Double
    public let dailyExerciseBurn: Double
    public let suggestedCalories: Double
    public let proteinGrams: Double
    public let carbsGrams: Double
    public let fatGrams: Double
    public let waterMilliliters: Int
}

@Model
final class Profile {
    var nome: String = "João Pedro"
    var email: String = "joao@email.com"
    var goalRaw: String = "Ganhar peso"
    var preferredFocusRaw: String? = nil
    var targetCalorieIntake: Double = 2800.0 // Meta de ingestão diária (consumir)
    var targetCalorieBurn: Double = 600.0   // Meta de queima diária (gastar)
    var targetSteps: Double = 8000.0        // Meta de passos diários
    var currentWeight: Double = 72.0       // Peso atual em kg
    var targetWeight: Double = 80.0        // Peso meta em kg
    var height: Double = 1.78              // Altura em metros
    var targetProtein: Double = 160.0
    var targetFat: Double = 70.0
    var targetCarbohydrates: Double = 380.0
    var targetWaterMilliliters: Int = 2500
    var autoRecalculateGoals: Bool = true
    
    /// Taxa Metabólica Basal (TMB - Mifflin-St Jeor)
    var tmb: Double {
        let validWeight = max(30.0, currentWeight)
        let validHeight = max(1.0, height)
        let heightCm = validHeight * 100.0
        return (10.0 * validWeight) + (6.25 * heightCm) - (5.0 * 25.0) + 5.0
    }
    
    var macros: Macros {
        get {
            Macros(protein: targetProtein, fat: targetFat, carbohydrates: targetCarbohydrates)
        }
        set {
            targetProtein = newValue.protein
            targetFat = newValue.fat
            targetCarbohydrates = newValue.carbohydrates
        }
    }
    
    var goal: FitnessGoal {
        get { FitnessGoal(rawValue: goalRaw) ?? .gain }
        set { goalRaw = newValue.rawValue }
    }
    
    var preferredFocus: FocusMetric? {
        get {
            guard let raw = preferredFocusRaw else { return nil }
            return FocusMetric(rawValue: raw)
        }
        set { preferredFocusRaw = newValue?.rawValue }
    }
    
    var effectiveFocus: FocusMetric {
        if let preferredFocus {
            return preferredFocus
        }
        return goal == .gain ? .consumed : .burned
    }
    
    init(
        nome: String = "João Pedro",
        email: String = "joao@email.com",
        goal: FitnessGoal = .gain,
        preferredFocus: FocusMetric? = nil,
        targetCalorieIntake: Double = 2800.0,
        targetCalorieBurn: Double = 600.0,
        targetSteps: Double = 8000.0,
        currentWeight: Double = 72.0,
        targetWeight: Double = 80.0,
        height: Double = 1.78,
        macros: Macros = Macros(protein: 160.0, fat: 70.0, carbohydrates: 380.0)
    ) {
        self.nome = nome
        self.email = email
        self.goalRaw = goal.rawValue
        self.preferredFocusRaw = preferredFocus?.rawValue
        self.targetCalorieIntake = targetCalorieIntake
        self.targetCalorieBurn = targetCalorieBurn
        self.targetSteps = targetSteps
        self.currentWeight = currentWeight
        self.targetWeight = targetWeight
        self.height = height
        self.targetProtein = macros.protein
        self.targetFat = macros.fat
        self.targetCarbohydrates = macros.carbohydrates
    }
    
    func atualizarNome(_ novoNome: String) {
        self.nome = novoNome.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var emailEhValido: Bool {
        let emailLimpo = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return emailLimpo.contains("@") && emailLimpo.contains(".")
    }
    
    /// Motor unificado de cálculo fisiológico usando todo o contexto (biometria, meta de peso, passos, gasto ativo, treinos, fichas e tendência real)
    public static func computeContextualTargets(
        weight: Double,
        height: Double,
        targetWeight: Double,
        goal: FitnessGoal,
        targetCalorieBurn: Double,
        targetSteps: Double,
        context: RecalculationContext? = nil
    ) -> ContextualGoalMetrics {
        let validWeight = min(300.0, max(30.0, weight))
        let validHeight: Double
        if height >= 100.0 && height <= 250.0 {
            validHeight = min(2.5, max(1.0, height / 100.0))
        } else {
            validHeight = min(2.5, max(1.0, height))
        }
        let heightCm = validHeight * 100.0
        let imc = validWeight / (validHeight * validHeight)
        let baseTmb = (10.0 * validWeight) + (6.25 * heightCm) - (5.0 * 25.0) + 5.0
        
        // 1. NEAT real (passos medidos + meta diária de passos)
        let safeTargetSteps = max(3000.0, targetSteps)
        let effectiveSteps = max(context?.recentAvgSteps ?? 0.0, safeTargetSteps * 0.85)
        let neatFactor = 1.25 + min(0.25, max(0.08, (effectiveSteps / 10000.0) * 0.15))
        
        // 2. Gasto ativo diário amortizado (treinos reais de 7/14d, fichas salvas e meta de gasto ativo)
        let loggedWorkoutBurn = max(0.0, context?.avgDailyWorkoutBurn ?? 0.0)
        let routineBurn = max(0.0, context?.routineEstimatedDailyBurn ?? 0.0)
        let targetBurnBaseline = max(0.0, targetCalorieBurn) * 0.65
        let dailyExerciseBurn = max(loggedWorkoutBurn, max(routineBurn, targetBurnBaseline))
        
        // 3. TDEE Contextual Real
        let contextualTdee = (baseTmb * neatFactor) + dailyExerciseBurn
        
        // 4. Superávit/Déficit ajustado pela distância até o peso-alvo, IMC e tendência real de evolução
        let highTrainingLoad = dailyExerciseBurn >= 320.0 || (context?.workoutsLast14DaysCount ?? 0) >= 8
        let rawCalories: Double
        let proteinFactor: Double
        let fatFactor: Double
        let minCarbs: Double
        
        switch goal {
        case .gain:
            let weightGap = max(0.0, targetWeight - validWeight)
            let gapBonus = min(150.0, max(0.0, (weightGap - 4.0) * 10.0))
            let lowBmiBonus = imc < 20.0 ? 50.0 : 0.0
            var trendBonus = 0.0
            if let trend = context?.weeklyWeightTrendKg {
                if trend < 0.10 {
                    trendBonus = 100.0
                } else if trend > 0.75 {
                    trendBonus = -75.0
                }
            }
            rawCalories = contextualTdee + 400.0 + gapBonus + lowBmiBonus + trendBonus
            proteinFactor = highTrainingLoad ? 2.1 : 2.0
            fatFactor = 1.0
            minCarbs = 120.0
            
        case .lose:
            let loseGap = max(0.0, validWeight - targetWeight)
            let gapDeficit = min(100.0, max(0.0, (loseGap - 6.0) * 6.0))
            var trendAdjust = 0.0
            if let trend = context?.weeklyWeightTrendKg {
                if trend > -0.10 {
                    trendAdjust = -75.0
                } else if trend < -1.0 {
                    trendAdjust = 75.0
                }
            }
            let safeFloor = max(1300.0, baseTmb * 1.05)
            rawCalories = max(safeFloor, contextualTdee - 450.0 - gapDeficit + trendAdjust)
            proteinFactor = highTrainingLoad ? 2.3 : 2.2
            fatFactor = 0.8
            minCarbs = 60.0
            
        case .maintain:
            var trendAdjust = 0.0
            if let trend = context?.weeklyWeightTrendKg {
                if trend > 0.35 {
                    trendAdjust = -60.0
                } else if trend < -0.35 {
                    trendAdjust = 60.0
                }
            }
            rawCalories = max(1300.0, contextualTdee + trendAdjust)
            proteinFactor = highTrainingLoad ? 2.0 : 1.9
            fatFactor = 0.9
            minCarbs = 80.0
        }
        
        let suggestedCalories = (rawCalories / 10.0).rounded() * 10.0
        let proteinGrams = (validWeight * proteinFactor).rounded()
        let fatGrams = (validWeight * fatFactor).rounded()
        let caloriesRemaining = max(0.0, suggestedCalories - (proteinGrams * 4.0 + fatGrams * 9.0))
        let carbsGrams = max(minCarbs, (caloriesRemaining / 4.0).rounded())
        
        let stepHydrationBonus = effectiveSteps > 8000.0 ? (effectiveSteps - 8000.0) * 0.04 : 0.0
        let rawWater = (validWeight * 35.0) + (dailyExerciseBurn * 0.85) + stepHydrationBonus
        let waterMl = max(1750, Int((rawWater / 250.0).rounded()) * 250)
        
        return ContextualGoalMetrics(
            tmb: baseTmb,
            contextualTdee: contextualTdee,
            dailyExerciseBurn: dailyExerciseBurn,
            suggestedCalories: suggestedCalories,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            waterMilliliters: waterMl
        )
    }
    
    public func contextualMetrics(for weight: Double? = nil, context: RecalculationContext? = nil) -> ContextualGoalMetrics {
        Self.computeContextualTargets(
            weight: weight ?? currentWeight,
            height: height,
            targetWeight: targetWeight,
            goal: goal,
            targetCalorieBurn: targetCalorieBurn,
            targetSteps: targetSteps,
            context: context
        )
    }
    
    /// Recalcula dinamicamente TMB, TDEE contextual, meta calórica, macros e água usando todo o contexto
    public func recalculateDailyGoals(for weight: Double? = nil, context: RecalculationContext? = nil) {
        let activeWeight = weight ?? currentWeight
        guard activeWeight > 30.0 else { return }
        
        let metrics = contextualMetrics(for: activeWeight, context: context)
        self.targetCalorieIntake = metrics.suggestedCalories
        self.targetProtein = metrics.proteinGrams
        self.targetFat = metrics.fatGrams
        self.targetCarbohydrates = metrics.carbsGrams
        self.targetWaterMilliliters = metrics.waterMilliliters
    }
}
