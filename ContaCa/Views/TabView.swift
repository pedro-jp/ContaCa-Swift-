//
//  TabView.swift
//  ContaCa
//
//  Created by João Pedro on 10/17/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Início", systemImage: "house.fill") {
                HomeView()
            }
            
            Tab("Atividade", systemImage: "figure.walk") {
                Text("Atividade")
            }
            
            Tab("Perfil", systemImage: "person.fill") {
                ProfileView()
            }
        }
        .tint(Color("AccentColor"))
    }
}

#Preview {
    ContentView()
}
