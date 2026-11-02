//
//  LogWeightView.swift
//  ContaCa
//
//  Created by João Pedro on 10/27/26.
//

import SwiftUI
import SwiftData

struct LogWeightView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [Profile]
    
    @State private var weight: Double = 72.0
    @State private var date: Date = Date()
    @State private var notes: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Registro de Peso") {
                    HStack {
                        Text("Peso")
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", weight))
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color("AccentColor"))
                            Text("kg")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Slider(value: $weight, in: 40...160, step: 0.1)
                        .tint(Color("AccentColor"))
                    
                    DatePicker("Data da pesagem", selection: $date, displayedComponents: [.date])
                }
                
                Section("Observações") {
                    TextField("Ex: Em jejum pela manhã, após treino...", text: $notes)
                }
            }
            .navigationTitle("Nova Pesagem")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let p = profiles.first, p.currentWeight > 0 {
                    weight = p.currentWeight
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        let entry = WeightEntry(weight: weight, date: date, notes: notes)
                        modelContext.insert(entry)
                        AppActivityLogManager.shared.logWeight(weightKg: weight, date: date, notes: notes)
                        
                        // Atualiza peso atual no perfil
                        if let profile = profiles.first {
                            profile.currentWeight = weight
                        }
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
