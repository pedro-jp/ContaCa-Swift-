//
//  ContaCaShortcutsProvider.swift
//  ContaCa
//
//  Created by João Pedro on 10/29/26.
//

import AppIntents

/// Provedor de atalhos automáticos do Forma para a Siri e App Atalhos
public struct ContaCaShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogSmartMealIntent(),
            phrases: [
                "Registrar refeição no \(.applicationName)",
                "Comi no \(.applicationName)",
                "Adicionar alimento no \(.applicationName)",
                "Registrar comida no \(.applicationName)",
                "Registrar prato no \(.applicationName)"
            ],
            shortTitle: "Registrar Refeição",
            systemImageName: "fork.knife"
        )
        
        AppShortcut(
            intent: LogWorkoutIntent(),
            phrases: [
                "Registrar treino no \(.applicationName)",
                "Treinei no \(.applicationName)",
                "Adicionar treino no \(.applicationName)",
                "Marcar treino no \(.applicationName)"
            ],
            shortTitle: "Registrar Treino",
            systemImageName: "dumbbell.fill"
        )
    }
}
