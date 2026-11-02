//
//  LogWorkoutIntent.swift
//  ContaCa
//
//  Created by João Pedro on 10/29/26.
//

import AppIntents
import SwiftData
import WidgetKit

/// Intent da Siri para registrar treinos e gasto calórico de forma direta
public struct LogWorkoutIntent: AppIntent {
    public static var title: LocalizedStringResource = "Registrar Treino no ContaCa"
    public static var description = IntentDescription("Registra seu treino e calcula as calorias gastas automaticamente no ContaCa.")
    public static var openAppWhenRun: Bool = false
    
    @Parameter(
        title: "Tipo de Treino",
        description: "Ex: Musculação, Corrida, Ciclismo, Caminhada, Funcional",
        default: "Musculação"
    )
    public var workoutType: String
    
    @Parameter(
        title: "Duração (minutos)",
        description: "Tempo total do treino em minutos. Ex: 45",
        default: 45
    )
    public var durationMinutes: Int
    
    public init() {}
    
    public init(workoutType: String, durationMinutes: Int) {
        self.workoutType = workoutType
        self.durationMinutes = durationMinutes
    }
    
    @MainActor
    public func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let validDuration = max(5, durationMinutes)
        let resolvedType = resolveWorkoutType(from: workoutType)
        var caloriesBurned = estimateCalories(for: resolvedType, duration: validDuration)
        var feedback = "Registrado com sucesso"
        
        // Se a IA do Gemini estiver configurada, faz a análise fisiológica avançada
        if GeminiConfig.shared.hasValidKey {
            if let aiResult = try? await GeminiAIService.shared.analyzeWorkout(description: "\(workoutType) por \(validDuration) minutos") {
                caloriesBurned = aiResult.caloriesBurned
                feedback = aiResult.aiFeedback
            }
        }
        
        let entry = WorkoutEntry(
            title: resolvedType.rawValue,
            workoutType: resolvedType,
            durationMinutes: validDuration,
            caloriesBurned: caloriesBurned,
            date: Date(),
            notes: feedback
        )
        
        // Ação Direta: persiste no SwiftData e sincroniza widgets imediatamente
        try ContaCaDataStore.shared.insertWorkoutEntry(entry)
        
        let calInt = Int(caloriesBurned.rounded())
        let confirmation = "Treino de \(resolvedType.rawValue) de \(validDuration) minutos registrado! Queima estimada de \(calInt) kcal."
        
        return .result(
            value: confirmation,
            dialog: IntentDialog(stringLiteral: confirmation)
        )
    }
    
    // MARK: - Mapeamento e Estimativa de Gasto Calórico
    
    private func resolveWorkoutType(from text: String) -> WorkoutType {
        let lower = text.lowercased()
        if lower.contains("corrida") || lower.contains("correr") || lower.contains("trote") {
            return .running
        }
        if lower.contains("caminhada") || lower.contains("andar") || lower.contains("caminhar") {
            return .walking
        }
        if lower.contains("ciclismo") || lower.contains("bicicleta") || lower.contains("pedal") || lower.contains("bike") {
            return .cycling
        }
        if lower.contains("funcional") || lower.contains("hiit") || lower.contains("crossfit") || lower.contains("circuito") {
            return .functional
        }
        if lower.contains("natação") || lower.contains("natacao") || lower.contains("nadar") {
            return .swimming
        }
        if lower.contains("musculação") || lower.contains("musculacao") || lower.contains("academia") || lower.contains("peso") || lower.contains("força") {
            return .bodybuilding
        }
        return .other
    }
    
    private func estimateCalories(for type: WorkoutType, duration: Int) -> Double {
        // Taxa média de queima em kcal por minuto
        let calPerMinute: Double
        switch type {
        case .running:
            calPerMinute = 11.0
        case .cycling:
            calPerMinute = 8.5
        case .functional:
            calPerMinute = 10.0
        case .swimming:
            calPerMinute = 9.0
        case .bodybuilding:
            calPerMinute = 7.0
        case .walking:
            calPerMinute = 4.5
        case .other:
            calPerMinute = 6.5
        }
        
        return (calPerMinute * Double(duration)).rounded()
    }
}
