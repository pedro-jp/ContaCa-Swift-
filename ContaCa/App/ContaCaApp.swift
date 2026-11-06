//
//  ContaCaApp.swift
//  ContaCa
//
//  Created by João Pedro on 10/13/26.
//

import SwiftUI
import SwiftData
import ActivityKit

@main
struct ContaCaApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var syncManager = BackendSyncManager.shared
    @State private var isShowingSplash: Bool = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isShowingSplash {
                    SplashScreenView {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            isShowingSplash = false
                        }
                    }
                    .zIndex(2)
                    .transition(.opacity)
                } else if !authManager.isAuthenticated {
                    LoginView {
                        triggerSync()
                    }
                    .zIndex(1)
                    .transition(.opacity)
                } else {
                    MainView()
                        .zIndex(0)
                        .transition(.opacity)
                }
            }
            .onOpenURL { url in
                AppNavigationRouter.shared.handleDeepLink(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                ContaCaDataStore.shared.syncTodayData()
                ContaCaDataStore.shared.syncExternalHealthWorkoutsInBackground()
                checkPendingWorkout()
                cleanupLegacyCalorieLiveActivities()
                triggerSync()
            }
            .task {
                cleanupLegacyCalorieLiveActivities()
                WorkoutNotificationManager.shared.setup()
                ContaCaDataStore.shared.setupBackgroundHealthObserver()
                ContaCaDataStore.shared.syncTodayData()
                checkPendingWorkout()
                triggerSync()
            }
        }
        .modelContainer(ContaCaDataStore.shared.container)
    }
    
    private func triggerSync() {
        Task { @MainActor in
            await BackendSyncManager.shared.sync(context: ContaCaDataStore.shared.mainContext)
        }
    }
    
    private func cleanupLegacyCalorieLiveActivities() {
        Task { @MainActor in
            for activity in Activity<CalorieActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    
    private func checkPendingWorkout() {
        if let pending = SharedWorkoutSessionManager.shared.consumePendingWorkout() {
            let workout = WorkoutEntry(
                title: pending.title,
                workoutType: WorkoutType(rawValue: pending.workoutTypeRaw) ?? .bodybuilding,
                durationMinutes: pending.durationMinutes,
                caloriesBurned: pending.caloriesBurned,
                date: pending.date,
                notes: pending.notes
            )
            try? ContaCaDataStore.shared.insertWorkoutEntry(workout)
        }
    }
}
