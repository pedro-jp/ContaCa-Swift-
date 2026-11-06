//
//  WorkoutNotificationManager.swift
//  FormaWidgets
//
//  Created by João Pedro on 10/29/26.
//

import Foundation
import UserNotifications

/// Gerenciador de notificações a partir do Widget Extension / App Intents
public final class WorkoutNotificationManager: @unchecked Sendable {
    public static let shared = WorkoutNotificationManager()
    
    private let restNotificationId = "forma_workout_rest_timer"
    
    private init() {}
    
    /// Agenda a notificação Time-Sensitive de fim de descanso que acende a tela
    public func scheduleRestNotification(
        seconds: Int,
        exerciseName: String,
        nextSet: Int
    ) {
        cancelRestNotification()
        
        guard seconds > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Descanso Concluído! ⏱️"
        content.body = "Hora de iniciar a Série \(nextSet) de \(exerciseName)!"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1.0
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: restNotificationId,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { _ in }
    }
    
    /// Cancela notificação de descanso pendente
    public func cancelRestNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restNotificationId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [restNotificationId])
    }
}
