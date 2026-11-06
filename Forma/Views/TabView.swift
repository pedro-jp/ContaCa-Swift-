//
//  TabView.swift
//  Forma
//
//  Created by João Pedro on 10/17/26.
//

import SwiftUI
import SwiftData

struct MainView: View {
    @ObservedObject private var router = AppNavigationRouter.shared
    
    var body: some View {
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

#Preview {
    MainView()
        .modelContainer(PreviewContainer.shared)
}
