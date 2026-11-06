//
//  AddWorkoutView.swift
//  Forma
//
//  Created by João Pedro on 10/27/26.
//

import SwiftUI
import SwiftData

struct AddWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title: String = ""
    @State private var selectedType: WorkoutType = .bodybuilding
    @State private var durationMinutes: Double = 50.0
    @State private var caloriesBurned: Double = 350.0
    @State private var notes: String = ""
    
    private var defaultCaloriesForType: Double {
        switch selectedType {
        case .bodybuilding: return durationMinutes * 7.0
        case .running: return durationMinutes * 11.0
        case .walking: return durationMinutes * 4.5
        case .cycling: return durationMinutes * 9.0
        case .functional: return durationMinutes * 8.5
        case .swimming: return durationMinutes * 10.0
        case .other: return durationMinutes * 6.0
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo de Treino") {
                    Picker("Modalidade", selection: $selectedType) {
                        ForEach(WorkoutType.allCases) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedType) { _, _ in
                        caloriesBurned = defaultCaloriesForType
                    }
                    
                    TextField("Nome do Treino (ex: Peito e Tríceps)", text: $title)
                }
                
                Section("Duração e Intensidade") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Duração")
                            Spacer()
                            Text("\(Int(durationMinutes)) min")
                                .fontWeight(.bold)
                                .foregroundColor(Color("AccentColor"))
                        }
                        Slider(value: $durationMinutes, in: 10...180, step: 5)
                            .tint(Color("AccentColor"))
                            .onChange(of: durationMinutes) { _, _ in
                                caloriesBurned = defaultCaloriesForType
                            }
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Calorias Estimadas")
                            Spacer()
                            Text("\(Int(caloriesBurned)) kcal")
                                .fontWeight(.bold)
                                .foregroundColor(Color("AccentGreen"))
                        }
                        Slider(value: $caloriesBurned, in: 50...1200, step: 10)
                            .tint(Color("AccentGreen"))
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Observações e Cargas") {
                    TextField("Ex: Supino 4x10 (30kg cada lado), agachamento...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .withDoneKeyboardToolbar()
            .navigationTitle("Registrar Treino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        let finalTitle = title.trimmingCharacters(in: .whitespaces).isEmpty ? selectedType.rawValue : title
                        let workout = WorkoutEntry(
                            title: finalTitle,
                            workoutType: selectedType,
                            durationMinutes: Int(durationMinutes),
                            caloriesBurned: caloriesBurned,
                            date: Date(),
                            notes: notes
                        )
                        try? FormaDataStore.shared.insertWorkoutEntry(workout)
                        dismiss()
                    }
                }
            }
        }
    }
}
