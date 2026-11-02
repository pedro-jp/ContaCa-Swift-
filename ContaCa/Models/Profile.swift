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
        case .gain: return "Superávit calórico e hipertrofia"
        case .lose: return "Déficit calórico e definição muscular"
        case .maintain: return "Equilíbrio calórico e manutenção"
        }
    }
}

public enum FocusMetric: String, Codable, CaseIterable, Identifiable, Sendable {
    case consumed = "Calorias Consumidas"
    case burned = "Calorias Gastas"
    
    public var id: String { rawValue }
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
}
