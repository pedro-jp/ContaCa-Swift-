//
//  EvolutionViewModel.swift
//  ContaCa
//
//  Created by João Pedro on 10/27/26.
//

import Foundation

public struct EvolutionStats {
    public let imc: Double
    public let imcClassification: String
    public let tmb: Double
    public let tdee: Double
    public let suggestedCalorieIntake: Double
    public let remainingWeightToGoal: Double
    public let isGoalAchieved: Bool
}

public class EvolutionCalculator {
    public static func calculate(
        weight: Double,
        height: Double,
        goal: FitnessGoal,
        targetWeight: Double
    ) -> EvolutionStats {
        let validWeight = max(30.0, weight)
        let validHeight = max(1.0, height)
        
        // IMC = peso / (altura^2)
        let imc = validWeight / (validHeight * validHeight)
        
        let classification: String
        switch imc {
        case ..<18.5:
            classification = "Abaixo do peso ideal"
        case 18.5..<24.9:
            classification = "Peso saudável / normal"
        case 25.0..<29.9:
            classification = "Sobrepeso leve"
        case 30.0..<34.9:
            classification = "Obesidade Grau I"
        default:
            classification = "Obesidade Grau II+"
        }
        
        // TMB (Mifflin-St Jeor): 10 * peso(kg) + 6.25 * altura(cm) - 5 * idade(25) + 5
        let heightCm = validHeight * 100.0
        let tmb = (10.0 * validWeight) + (6.25 * heightCm) - (5.0 * 25.0) + 5.0
        
        // Gasto diário estimado com atividade moderada (Fator 1.45)
        let tdee = tmb * 1.45
        
        let suggestedCalorieIntake: Double
        switch goal {
        case .gain:
            // Superávit calórico de +400 kcal para ganho de peso / hipertrofia limpa
            suggestedCalorieIntake = tdee + 400.0
        case .lose:
            // Déficit calórico de -450 kcal para queima de gordura preservando massa
            suggestedCalorieIntake = max(1200.0, tdee - 450.0)
        case .maintain:
            suggestedCalorieIntake = tdee
        }
        
        let remainingWeightToGoal: Double
        let isAchieved: Bool
        if goal == .gain {
            remainingWeightToGoal = max(0, targetWeight - validWeight)
            isAchieved = validWeight >= targetWeight && targetWeight > 0
        } else if goal == .lose {
            remainingWeightToGoal = max(0, validWeight - targetWeight)
            isAchieved = validWeight <= targetWeight && targetWeight > 0
        } else {
            remainingWeightToGoal = abs(targetWeight - validWeight)
            isAchieved = abs(targetWeight - validWeight) < 0.5
        }
        
        return EvolutionStats(
            imc: imc,
            imcClassification: classification,
            tmb: tmb,
            tdee: tdee,
            suggestedCalorieIntake: suggestedCalorieIntake,
            remainingWeightToGoal: remainingWeightToGoal,
            isGoalAchieved: isAchieved
        )
    }
}
