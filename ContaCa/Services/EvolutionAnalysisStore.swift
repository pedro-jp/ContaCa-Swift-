//
//  EvolutionAnalysisStore.swift
//  ContaCa
//
//  Created by João Pedro on 11/02/26.
//

import Foundation
import Combine

@MainActor
public final class EvolutionAnalysisStore: ObservableObject {
    public static let shared = EvolutionAnalysisStore()

    private let storageKey = "contaca_saved_evolution_analysis"

    @Published public var latestAnalysis: EvolutionAIAnalysis? = nil

    private init() {
        _ = loadLatest()
    }

    @discardableResult
    public func loadLatest() -> EvolutionAIAnalysis? {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let rawAnalysis = try? JSONDecoder().decode(EvolutionAIAnalysis.self, from: data) {
            let clean = Self.sanitizeBranding(rawAnalysis)
            self.latestAnalysis = clean
            return clean
        }
        return nil
    }

    public func save(_ analysis: EvolutionAIAnalysis) {
        let clean = Self.sanitizeBranding(analysis)
        self.latestAnalysis = clean
        if let data = try? JSONEncoder().encode(clean) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    public func clear() {
        self.latestAnalysis = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private static func sanitizeBranding(_ analysis: EvolutionAIAnalysis) -> EvolutionAIAnalysis {
        func fix(_ text: String) -> String {
            text.replacingOccurrences(of: "ContaCa", with: "Forma")
                .replacingOccurrences(of: "Contaca", with: "Forma")
        }

        var sanitizedTargets = analysis.suggestedTargets
        if let t = sanitizedTargets {
            sanitizedTargets = SuggestedNutritionTargets(
                dailyCalories: t.dailyCalories,
                proteinGrams: t.proteinGrams,
                carbsGrams: t.carbsGrams,
                fatGrams: t.fatGrams,
                waterMilliliters: t.waterMilliliters,
                explanation: fix(t.explanation)
            )
        }

        return EvolutionAIAnalysis(
            statusSummary: fix(analysis.statusSummary),
            calorieDiagnostic: fix(analysis.calorieDiagnostic),
            macroDiagnostic: fix(analysis.macroDiagnostic),
            hydrationDiagnostic: fix(analysis.hydrationDiagnostic),
            workoutSuggestions: analysis.workoutSuggestions.map(fix),
            nutritionSuggestions: analysis.nutritionSuggestions.map(fix),
            weeklyActionPlan: fix(analysis.weeklyActionPlan),
            suggestedTargets: sanitizedTargets,
            recommendedRoutine: analysis.recommendedRoutine,
            generatedAt: analysis.generatedAt
        )
    }
}
