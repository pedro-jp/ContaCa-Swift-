//
//  WorkoutNotificationManager.swift
//  ContaCa
//
//  Created by João Pedro on 10/29/26.
//

import Foundation
import UserNotifications
import UIKit
import AudioToolbox

/// Gerenciador de alertas sonoros, táteis (vibração) e notificações Time-Sensitive
/// Garante que o celular vibre e acenda a tela ao fim do descanso (ligado ou bloqueado/desligado)
public final class WorkoutNotificationManager: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    public static let shared = WorkoutNotificationManager()
    
    private let restNotificationId = "forma_workout_rest_timer"
    
    private override init() {
        super.init()
    }
    
    /// Inicializa delegate e solicita permissões necessárias
    public func setup() {
        UNUserNotificationCenter.current().delegate = self
        requestAuthorization()
    }
    
    /// Solicita autorização para alertas, sons e avisos Time-Sensitive
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .timeSensitive]
        ) { granted, error in
            if granted {
                print("✅ Permissão de Notificações Time-Sensitive concedida para treinos.")
            } else if let error = error {
                print("⚠️ Erro ao solicitar permissões de notificação: \(error.localizedDescription)")
            }
        }
    }
    
    /// Agenda notificação Time-Sensitive que acorda e acende a tela mesmo com a tela bloqueada/desligada
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
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Erro ao agendar notificação de descanso: \(error.localizedDescription)")
            } else {
                print("⏱️ Notificação de descanso agendada para daqui a \(seconds)s (Acenderá a tela).")
            }
        }
    }
    
    /// Cancela qualquer notificação de descanso pendente ou entregue
    public func cancelRestNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restNotificationId])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [restNotificationId])
    }
    
    /// Dispara sequência de vibrações intensas e som de alarme quando o app está aberto / celular em uso
    public func triggerRestFinishedHapticsAndSound() {
        // 1. Vibração de hardware pelo motor tátil (AudioServices)
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        
        // 2. Toque sonoro de campainha do temporizador nativo do iOS (System Sound 1005)
        AudioServicesPlaySystemSound(1005)
        
        // 3. Sequência de pulsos pesados (Heavy Haptics) no Taptic Engine
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        let success = UINotificationFeedbackGenerator()
        heavy.prepare()
        success.prepare()
        
        heavy.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            heavy.impactOccurred()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            success.notificationOccurred(.success)
            AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Quando a notificação chega com o app em primeiro plano: vibra intensamente e mostra banner
        triggerRestFinishedHapticsAndSound()
        completionHandler([.banner, .sound, .list])
    }
}
