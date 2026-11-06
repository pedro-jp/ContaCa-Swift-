//
//  TabView.swift
//  Forma
//
//  Created by João Pedro on 10/17/26.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [Profile]
    @ObservedObject private var router = AppNavigationRouter.shared
    @ObservedObject private var syncManager = BackendSyncManager.shared
    @ObservedObject private var authManager = AuthManager.shared

    private var primaryProfile: Profile? {
        profiles.first
    }

    private var isAwaitingFirstSessionPull: Bool {
        guard authManager.isAuthenticated else { return false }
        if let p = primaryProfile, p.onboardingCompleted && !p.requiresInitialSetup {
            return false
        }
        return !syncManager.hasCompletedInitialSessionPull
    }

    private var shouldPresentInitialSetup: Bool {
        guard authManager.isAuthenticated, !isAwaitingFirstSessionPull else { return false }
        guard let p = primaryProfile else { return true }
        return p.requiresInitialSetup
    }

    var body: some View {
        Group {
            if isAwaitingFirstSessionPull {
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(FormaTheme.Colors.brand)
                    Text("Carregando sua conta...")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(FormaTheme.Colors.pageBackground.ignoresSafeArea())
            } else {
                TabView(selection: $router.selectedTab) {
                    Tab("Início", systemImage: "house.fill", value: "inicio") {
                        HomeView()
                    }

                    Tab("Alimentação", systemImage: "fork.knife", value: "alimentacao") {
                        NutritionView()
                    }

                    Tab("Treinos", systemImage: "dumbbell.fill", value: "treinos") {
                        WorkoutsView()
                    }

                    Tab("Evolução", systemImage: "chart.line.uptrend.xyaxis", value: "evolucao") {
                        EvolutionView()
                    }

                    Tab("Perfil", systemImage: "person.fill", value: "perfil") {
                        ProfileView()
                    }
                }
                .tint(Color("AccentColor"))
            }
        }
        .task(id: authManager.currentUserId) {
            guard authManager.isAuthenticated else { return }
            if !(primaryProfile?.onboardingCompleted ?? false) && !syncManager.hasCompletedInitialSessionPull {
                await syncManager.sync(context: modelContext, forcePull: true)
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { shouldPresentInitialSetup },
                set: { _ in }
            )
        ) {
            InitialOnboardingModalView()
                .interactiveDismissDisabled(true)
        }
    }
}

#Preview {
    MainView()
        .modelContainer(PreviewContainer.shared)
}
