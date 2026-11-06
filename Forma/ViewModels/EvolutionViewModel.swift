//
//  EvolutionViewModel.swift
//  Forma
//
//  Created by João Pedro on 10/27/26.
//

import Foundation

public struct EvolutionStats: Sendable, Equatable {
    public let imc: Double
    public let imcClassification: String
    public let tmb: Double
    public let tdee: Double
    public let suggestedCalorieIntake: Double
    public let suggestedProtein: Double
    public let remainingWeightToGoal: Double
    public let isGoalAchieved: Bool
}

public enum ProfileInputValidator {
    /// Aceita vírgula ou ponto e restringe peso humano válido entre 30 kg e 300 kg com 1 casa decimal.
    public static func parseFlexibleWeight(_ raw: String) -> Double? {
        let cleaned = raw
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              let value = Double(cleaned),
              value.isFinite,
              value >= 30.0,
              value <= 300.0 else {
            return nil
        }
        return (value * 10.0).rounded() / 10.0
    }

    /// Aceita altura em metros (ex: "1,78") ou centímetros (ex: "178") e converte para metros [1.00, 2.50].
    public static func parseFlexibleHeight(_ raw: String) -> Double? {
        let cleaned = raw
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, var value = Double(cleaned), value.isFinite else {
            return nil
        }
        if value >= 100.0 && value <= 250.0 {
            value /= 100.0
        }
        guard value >= 1.0, value <= 2.5 else {
            return nil
        }
        return (value * 100.0).rounded() / 100.0
    }
}

public final class EvolutionCalculator {
    public static func classifyIMC(_ imc: Double) -> String {
        switch imc {
        case ..<18.5:
            return "Abaixo do peso ideal"
        case 18.5..<25.0:
            return "Peso saudável"
        case 25.0..<30.0:
            return "Sobrepeso leve"
        case 30.0..<35.0:
            return "Obesidade Grau I"
        default:
            return "Obesidade Grau II+"
        }
    }

    public static func calculate(
        weight: Double,
        height: Double,
        goal: FitnessGoal,
        targetWeight: Double,
        targetCalorieBurn: Double = 600.0,
        targetSteps: Double = 8000.0,
        context: RecalculationContext? = nil
    ) -> EvolutionStats {
        let validWeight = max(30.0, weight)
        let validHeight: Double
        if height >= 100.0 && height <= 250.0 {
            validHeight = min(2.5, max(1.0, height / 100.0))
        } else {
            validHeight = min(2.5, max(1.0, height))
        }

        let imc = validWeight / (validHeight * validHeight)
        let classification = classifyIMC(imc)

        let metrics = Profile.computeContextualTargets(
            weight: validWeight,
            height: validHeight,
            targetWeight: targetWeight,
            goal: goal,
            targetCalorieBurn: targetCalorieBurn,
            targetSteps: targetSteps,
            context: context
        )

        let remainingWeightToGoal: Double
        let isAchieved: Bool
        switch goal {
        case .gain:
            remainingWeightToGoal = max(0, targetWeight - validWeight)
            isAchieved = validWeight >= targetWeight && targetWeight > 0
        case .lose:
            remainingWeightToGoal = max(0, validWeight - targetWeight)
            isAchieved = validWeight <= targetWeight && targetWeight > 0
        case .maintain:
            remainingWeightToGoal = abs(targetWeight - validWeight)
            isAchieved = abs(targetWeight - validWeight) < 0.5
        }

        return EvolutionStats(
            imc: imc,
            imcClassification: classification,
            tmb: metrics.tmb,
            tdee: metrics.contextualTdee,
            suggestedCalorieIntake: metrics.suggestedCalories,
            suggestedProtein: metrics.proteinGrams,
            remainingWeightToGoal: remainingWeightToGoal,
            isGoalAchieved: isAchieved
        )
    }
}
