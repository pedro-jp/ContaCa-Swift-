//
//  WorkoutLiveActivityIntents.swift
//  FormaWidgets
//
//  Created by João Pedro on 10/29/26.
//

import AppIntents

/// Intent para concluir a série atual diretamente pela Ilha Dinâmica ou Tela Bloqueada sem abrir o app
public struct CompleteSetLiveIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Concluir Série"
    public static var isDiscoverable: Bool = false
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        await SharedWorkoutSessionManager.shared.completeCurrentSetFromLiveActivity()
        return .result()
    }
}

/// Intent para pular o descanso e iniciar a próxima série imediatamente pela Ilha Dinâmica
public struct SkipRestLiveIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Iniciar Série"
    public static var isDiscoverable: Bool = false
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        await SharedWorkoutSessionManager.shared.skipRestFromLiveActivity()
        return .result()
    }
}

/// Intent para estender o descanso em +30 segundos pela Ilha Dinâmica
public struct AddRestTimeLiveIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "+30s Descanso"
    public static var isDiscoverable: Bool = false
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        await SharedWorkoutSessionManager.shared.addRestSecondsFromLiveActivity(seconds: 30)
        return .result()
    }
}

/// Intent para finalizar e registrar o treino completo pela Ilha Dinâmica
public struct FinishWorkoutLiveIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Finalizar Treino"
    public static var isDiscoverable: Bool = false
    public static var openAppWhenRun: Bool = false
    
    public init() {}
    
    public func perform() async throws -> some IntentResult {
        await SharedWorkoutSessionManager.shared.finishWorkoutFromLiveActivity()
        return .result()
    }
}
