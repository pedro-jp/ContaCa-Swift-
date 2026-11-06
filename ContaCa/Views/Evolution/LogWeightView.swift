//
//  LogWeightView.swift
//  ContaCa
//
//  Registro de nova pesagem corporal com recálculo contextual instantâneo de TMB, TDEE e metas.
//

import SwiftUI
import SwiftData

struct LogWeightView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [Profile]

    @State private var weight: Double = 72.0
    @State private var weightText: String = "72.0"
    @FocusState private var isWeightFieldFocused: Bool
    @State private var date: Date = Date()
    @State private var notes: String = ""

    private var previewMetrics: ContextualGoalMetrics {
        let ctx = ContaCaDataStore.shared.buildRecalculationContext(in: modelContext)
        if let p = profiles.first {
            return p.contextualMetrics(for: weight, context: ctx)
        }
        return Profile.computeContextualTargets(
            weight: weight,
            height: 1.78,
            targetWeight: 80.0,
            goal: .gain,
            targetCalorieBurn: 600.0,
            targetSteps: 8000.0,
            context: ctx
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Registro de Peso") {
                    HStack {
                        Text("Peso atual")
                        Spacer()
                        Button {
                            updateWeight(weight - 0.1, syncText: true)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(FormaTheme.Colors.brand)
                        }
                        .buttonStyle(.plain)

                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            TextField("72.0", text: $weightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($isWeightFieldFocused)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(FormaTheme.Colors.brand)
                                .frame(width: 80)
                                .onChange(of: weightText) { _, newValue in
                                    if let parsed = ProfileInputValidator.parseFlexibleWeight(newValue) {
                                        weight = parsed
                                    }
                                }
                            Text("kg")
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            updateWeight(weight + 0.1, syncText: true)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(FormaTheme.Colors.brand)
                        }
                        .buttonStyle(.plain)
                    }

                    Slider(
                        value: Binding(
                            get: { min(160.0, max(35.0, weight)) },
                            set: { updateWeight($0, syncText: true) }
                        ),
                        in: 35...160,
                        step: 0.1
                    )
                    .tint(FormaTheme.Colors.brand)

                    HStack(spacing: 6) {
                        Image(systemName: "bolt.heart.fill")
                            .font(.caption)
                            .foregroundStyle(FormaTheme.Colors.brand)
                        Text("Gasto em repouso: \(Int(previewMetrics.tmb)) kcal • Nova Meta Forma: \(Int(previewMetrics.suggestedCalories)) kcal/dia")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    DatePicker("Data da pesagem", selection: $date, displayedComponents: [.date])
                }

                Section("Observações") {
                    TextField("Ex: Em jejum pela manhã, pós-treino...", text: $notes)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .withDoneKeyboardToolbar()
            .navigationTitle("Nova Pesagem")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let p = profiles.first, p.currentWeight > 0 {
                    weight = p.currentWeight
                    weightText = String(format: "%.1f", p.currentWeight)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        if let parsed = ProfileInputValidator.parseFlexibleWeight(weightText) {
                            weight = parsed
                        }

                        let entry = WeightEntry(weight: weight, date: date, notes: notes)
                        modelContext.insert(entry)
                        AppActivityLogManager.shared.logWeight(id: entry.id.uuidString, weightKg: weight, date: date, notes: notes)

                        let profile = ContaCaDataStore.shared.ensureSingleProfile(in: modelContext)
                        profile.currentWeight = weight
                        profile.autoRecalculateGoals = true
                        ContaCaDataStore.shared.recalculateProfileWithFullContext(for: weight, profile: profile, in: modelContext)
                        try? modelContext.save()
                        ContaCaDataStore.shared.syncTodayData()
                        Task { @MainActor in
                            await BackendSyncManager.shared.sync(context: modelContext)
                        }
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func updateWeight(_ newValue: Double, syncText: Bool) {
        let clamped = max(30.0, min(300.0, (newValue * 10.0).rounded() / 10.0))
        weight = clamped
        if syncText {
            weightText = String(format: "%.1f", clamped)
        }
    }
}
