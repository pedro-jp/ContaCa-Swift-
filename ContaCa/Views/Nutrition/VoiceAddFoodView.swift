//
//  VoiceAddFoodView.swift
//  ContaCa
//
//  Created by João Pedro on 10/29/26.
//

import SwiftUI
import SwiftData

struct VoiceAddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var voiceService = VoiceRecognitionService.shared
    
    // Suporte a refeição pré-selecionada
    var preselectedMeal: MealType? = nil
    var onFoodSaved: ((FoodEntry) -> Void)? = nil
    
    // Controles de entrada de texto e voz
    @State private var inputText: String = ""
    @State private var isSavedSuccessfully: Bool = false
    @State private var isFieldFocused: Bool = false
    @State private var textDebounceTask: Task<Void, Never>? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if isSavedSuccessfully {
                        successView
                    } else {
                        mainContent
                    }
                }
            }
            .navigationTitle("Adicionar Refeição")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        voiceService.stopListening()
                        dismiss()
                    }
                    .font(.body)
                }
            }
            .onAppear {
                let defaultMeal = preselectedMeal ?? AIFoodParserService.shared.inferPrimaryMealType()
                voiceService.updateMealType(defaultMeal)
                startVoiceFlow()
            }
            .onDisappear {
                voiceService.stopListening()
                textDebounceTask?.cancel()
            }
            // Sincroniza o texto transcrito por voz no campo de texto editável
            .onChange(of: voiceService.recognizedText) { _, newText in
                if !newText.isEmpty && voiceService.isRecording {
                    self.inputText = newText
                }
            }
        }
    }
    
    // MARK: - Conteúdo Principal (Estilo Apple / Airbnb)
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Card de Entrada: Voz + Digitação Manual
                inputCard
                
                // Card do Prato Reconhecido (com itens e macros consolidados)
                if let intent = voiceService.currentIntent, !intent.items.isEmpty {
                    plateResultCard(intent: intent)
                }
                
                // Sugestões Práticas de Fala ou Digitação
                suggestionsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .withDoneKeyboardToolbar()
    }
    
    // MARK: - Card de Entrada com Microfone & Edição por Escrito
    
    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(voiceService.isRecording ? "Ouvindo você..." : "O que você comeu?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(voiceService.isRecording ? Color("AccentColor") : .secondary)
                
                Spacer()
                
                if voiceService.isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !inputText.isEmpty {
                    Button {
                        inputText = ""
                        voiceService.currentIntent = nil
                        voiceService.recognizedText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Campo de Texto Editável com Botão de Microfone Integrado
            HStack(alignment: .top, spacing: 10) {
                TextField("Fale ou digite (ex: 4 colheres de arroz e 2 de feijão)", text: $inputText, axis: .vertical)
                    .lineLimit(2...5)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color("FontNormal"))
                    .onChange(of: inputText) { _, newValue in
                        handleTextChange(newValue)
                    }
                
                // Botão de Gravação de Voz Estilo Apple
                Button {
                    toggleRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(voiceService.isRecording ? Color("AccentColor") : Color.primary.opacity(0.06))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: voiceService.isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(voiceService.isRecording ? .white : Color("AccentColor"))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(voiceService.isRecording ? Color("AccentColor") : Color.primary.opacity(0.08), lineWidth: voiceService.isRecording ? 1.5 : 0.5)
            )
            
            HStack {
                Image(systemName: "hand.tap")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("Você pode falar pelo microfone ou tocar para editar o texto.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
    
    // MARK: - Card do Prato Reconhecido
    
    private func plateResultCard(intent: VoiceFoodIntent) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Cabeçalho: Título e Seletor de Refeição
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(intent.items.count > 1 ? "Prato Consolidado" : "Alimento")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(intent.totalCalories))")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(Color("FontNormal"))
                        Text("kcal")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Menu Elegante para Seleção de Refeição
                Menu {
                    ForEach(MealType.allCases) { meal in
                        Button {
                            voiceService.updateMealType(meal)
                        } label: {
                            Label(meal.rawValue, systemImage: meal.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: intent.mealType.icon)
                            .font(.system(size: 12))
                        Text(intent.mealType.rawValue)
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(Color("AccentColor"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color("AccentMinor"))
                    .clipShape(Capsule())
                }
            }
            
            // Pergunta Rápida: É um lanche?
            let primaryMeal = AIFoodParserService.shared.inferPrimaryMealType()
            let isSnack = intent.mealType == .snacks
            
            HStack(spacing: 8) {
                Text("É um lanche?")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Opção 1: Não (mantém a principal pelo horário)
                Button {
                    voiceService.updateMealType(primaryMeal)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: primaryMeal.icon)
                            .font(.system(size: 10))
                        Text("Não (\(primaryMeal.rawValue))")
                            .font(.system(size: 11, weight: !isSnack ? .bold : .medium))
                    }
                    .foregroundColor(!isSnack ? .white : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(!isSnack ? Color("AccentColor") : Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                // Opção 2: Sim (marca como Lanche)
                Button {
                    voiceService.updateMealType(.snacks)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 10))
                        Text("Sim (Lanche)")
                            .font(.system(size: 11, weight: isSnack ? .bold : .medium))
                    }
                    .foregroundColor(isSnack ? .white : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(isSnack ? Color.orange : Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
            
            // Pílulas de Macros no Padrão Apple
            HStack(spacing: 8) {
                CleanMacroBadge(label: "Proteína", value: "\(Int(intent.totalProtein))g", color: Color("AccentGreen"))
                CleanMacroBadge(label: "Carboidratos", value: "\(Int(intent.totalCarbs))g", color: Color("AccentColor"))
                CleanMacroBadge(label: "Gordura", value: "\(Int(intent.totalFat))g", color: .orange)
            }
            
            Divider()
                .background(Color.primary.opacity(0.06))
            
            // Lista de Itens do Prato com Ajustes Individuais
            VStack(alignment: .leading, spacing: 12) {
                Text("Alimentos no Prato")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
                
                ForEach(intent.items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color("FontNormal"))
                                
                                Text("\(Int(item.calories)) kcal • \(Int(item.protein))g P • \(Int(item.carbs))g C • \(Int(item.fat))g G")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if intent.items.count > 1 {
                                Button {
                                    withAnimation(.spring(duration: 0.25)) {
                                        voiceService.removeItem(id: item.id)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13))
                                        .foregroundColor(.red.opacity(0.7))
                                        .padding(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Controles de Quantidade Inteligentes (ml para líquidos, g para sólidos)
                        HStack(spacing: 10) {
                            Text("Quantidade")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if item.isLiquid || item.unit == "ml" {
                                Button {
                                    voiceService.adjustItemPortion(id: item.id, delta: -50)
                                } label: {
                                    Text("-50 ml")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(Color("FontNormal"))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.primary.opacity(0.06))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                
                                Text("\(Int(item.portionValue)) ml")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color("FontNormal"))
                                    .frame(minWidth: 55)
                                
                                Button {
                                    voiceService.adjustItemPortion(id: item.id, delta: 50)
                                } label: {
                                    Text("+50 ml")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(Color("FontNormal"))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.primary.opacity(0.06))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    voiceService.adjustItemPortion(id: item.id, delta: -25)
                                } label: {
                                    Text("-25 g")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(Color("FontNormal"))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.primary.opacity(0.06))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                
                                Text("\(Int(item.portionValue)) g")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(Color("FontNormal"))
                                    .frame(minWidth: 55)
                                
                                Button {
                                    voiceService.adjustItemPortion(id: item.id, delta: 25)
                                } label: {
                                    Text("+25 g")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(Color("FontNormal"))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.primary.opacity(0.06))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(.systemBackground).opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            
            // Botão Principal de Confirmação (Estilo Airbnb / Apple)
            Button {
                confirmFoodEntry()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                    Text(intent.items.count > 1 ? "Registrar Refeição (\(intent.items.count) itens)" : "Registrar Refeição")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color("AccentColor"))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
    
    // MARK: - Seção de Exemplos Práticos
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sugestões para experimentar:")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                suggestionRow(text: "4 colheres de sopa de arroz e 2 de feijão")
                suggestionRow(text: "400 ml de shake hipercalórico growth")
                suggestionRow(text: "2 pães franceses com manteiga e 1 copo de leite com toddy")
                suggestionRow(text: "150g de peito de frango grelhado e 100g de batata doce")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }
    
    private func suggestionRow(text: String) -> some View {
        Button {
            inputText = text
            voiceService.stopListening()
            voiceService.analyzeIntent(from: text)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 11))
                    .foregroundColor(Color("AccentColor"))
                Text(text)
                    .font(.caption)
                    .foregroundColor(Color("FontNormal"))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color("CardBackground"))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tela de Sucesso
    
    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color("AccentGreen").opacity(0.15))
                    .frame(width: 90, height: 90)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(Color("AccentGreen"))
            }
            
            VStack(spacing: 6) {
                Text("Refeição Registrada")
                    .font(.title2.weight(.bold))
                    .foregroundColor(Color("FontNormal"))
                
                if let intent = voiceService.currentIntent, !intent.items.isEmpty {
                    Text("\(intent.items.count) \(intent.items.count == 1 ? "item adicionado" : "itens somados") ao \(intent.mealType.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("+\(Int(intent.totalCalories)) kcal")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Color("AccentColor"))
                        .padding(.top, 4)
                }
            }
            
            Spacer()
            
            Button("Concluir") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color("AccentColor"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Ações e Lógica
    
    private func handleTextChange(_ newText: String) {
        textDebounceTask?.cancel()
        guard !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Se a mudança não veio da gravação ativa (isto é, o usuário está digitando/editando):
        if !voiceService.isRecording {
            textDebounceTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                voiceService.analyzeIntent(from: newText)
            }
        }
    }
    
    private func startVoiceFlow() {
        Task {
            let authorized = await voiceService.requestPermissions()
            if authorized {
                voiceService.startListening()
            }
        }
    }
    
    private func toggleRecording() {
        if voiceService.isRecording {
            voiceService.stopListening()
            if !inputText.isEmpty {
                voiceService.analyzeIntent(from: inputText)
            }
        } else {
            voiceService.startListening()
        }
    }
    
    private func confirmFoodEntry() {
        guard let intent = voiceService.currentIntent, !intent.items.isEmpty else { return }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        var lastFoodName = ""
        var lastFoodCal = 0.0
        
        for item in intent.items {
            let newEntry = FoodEntry(
                name: item.name,
                brand: item.brand,
                mealType: intent.mealType,
                portionGrams: item.portionValue,
                calories: item.calories,
                protein: item.protein,
                carbohydrates: item.carbs,
                fat: item.fat,
                date: Date()
            )
            modelContext.insert(newEntry)
            AppActivityLogManager.shared.logMeal(
                name: item.name,
                mealType: intent.mealType.rawValue,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                isSnack: intent.mealType == .snacks,
                date: Date()
            )
            lastFoodName = item.name
            lastFoodCal = item.calories
            onFoodSaved?(newEntry)
        }
        
        try? modelContext.save()
        ContaCaDataStore.shared.syncTodayData(lastFoodName: lastFoodName, lastFoodCalories: lastFoodCal)
        
        withAnimation(.spring(duration: 0.35)) {
            isSavedSuccessfully = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
}

// MARK: - Badges Limpos de Macronutrientes (Estilo Apple)

struct CleanMacroBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

#Preview {
    VoiceAddFoodView()
        .modelContainer(PreviewContainer.shared)
}
