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
        loadLatest()
    }
    
    public func loadLatest() -> EvolutionAIAnalysis? {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let analysis = try? JSONDecoder().decode(EvolutionAIAnalysis.self, from: data) {
            self.latestAnalysis = analysis
            return analysis
        }
        return nil
    }
    
    public func save(_ analysis: EvolutionAIAnalysis) {
        self.latestAnalysis = analysis
        if let data = try? JSONEncoder().encode(analysis) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
