//
//  AIFoodLoggerView.swift
//  ContaCa
//
//  Created by João Pedro on 10/29/26.
//

import SwiftUI
import SwiftData

/// Interface moderna para registro inteligente de refeições utilizando o Google Gemini AI
struct AIFoodLoggerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @ObservedObject private var geminiService = GeminiAIService.shared
    
    @State private var inputText: String = ""
    @State private var analyzedMeal: AIExtractedMeal? = nil
    @State private var errorMessage: String? = nil
    @State private var isSuccess: Bool = false
    
    var onMealLogged: (() -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Card de Cabeçalho com Status do Gemini AI
                        headerStatusCard
                        
                        // Campo de Entrada do Usuário
                        inputCard
                        
                        // Sugestões Rápidas de Exemplos
                        examplePromptsSection
                        
                        // Resultado da Análise da IA
                        if let meal = analyzedMeal {
                            analyzedResultCard(meal: meal)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Descrever Refeição")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Componentes de Interface
    
    private var headerStatusCard: some View {
        HStack {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color("AccentColor"))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Cálculo Automático de Refeição")
                    .font(.system(size: 14, weight: .bold))
                Text("Descreva seus alimentos e porções em texto livre")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(14)
        .background(Color("CardBackground"))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.15), lineWidth: 1))
    }
    
    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("O QUE VOCÊ CONSUMIU?")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            
            HStack(alignment: .top) {
                TextField("Ex: 100g de M&M's, ou um pratão de arroz, feijão e 2 bifes de alcatra...", text: $inputText, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                
                if !inputText.isEmpty {
                    Button {
                        inputText = ""
                        analyzedMeal = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
            
            Button {
                analyzeWithGemini()
            } label: {
                HStack(spacing: 8) {
                    if geminiService.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                        Text("Calcular Nutrientes")
                    }
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.4) : Color("AccentColor"))
                .cornerRadius(12)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || geminiService.isLoading)
        }
        .padding(16)
        .background(Color("CardBackground"))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.15), lineWidth: 1))
    }
    
    private var examplePromptsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sugestões para testar:")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    exampleChip("4 colheres de sopa de arroz e 2 de feijão")
                    exampleChip("400 ml de shake hipercalórico growth")
                    exampleChip("Dois pães franceses com manteiga e 1 copo grande de leite com toddy")
                    exampleChip("100g de M&M's")
                }
            }
        }
    }
    
    private func exampleChip(_ text: String) -> some View {
        Button {
            inputText = text
            analyzeWithGemini()
        } label: {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color("AccentColor"))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color("AccentColor").opacity(0.1))
                .cornerRadius(20)
        }
    }
    
    private func analyzedResultCard(meal: AIExtractedMeal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.items.count > 1 ? "PRATO RECONHECIDO (\(meal.items.count) ALIMENTOS)" : "ALIMENTO RECONHECIDO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color("AccentColor"))
                    Text(meal.mealType)
                        .font(.system(size: 18, weight: .bold))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(Color("AccentColor"))
                        Text("\(Int(meal.totalCalories.rounded()))")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color("AccentColor"))
                    }
                    Text("kcal totais")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            
            // Pílulas com Totais de Macros
            HStack(spacing: 8) {
                macroBox(title: "Proteína", value: "\(Int(meal.totalProtein))g", color: Color("AccentGreen"))
                macroBox(title: "Carbos", value: "\(Int(meal.totalCarbs))g", color: Color("AccentCarb"))
                macroBox(title: "Gorduras", value: "\(Int(meal.totalFat))g", color: Color("AccentFat"))
            }
            
            Divider()
            
            // Lista de Itens do Prato com Controles de Porção (ml para líquidos, g para sólidos)
            VStack(alignment: .leading, spacing: 10) {
                Text("Alimentos no Prato (ajuste a porção se desejar):")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                ForEach(meal.items) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 14, weight: .bold))
                                Text("\(Int(item.calories)) kcal • \(Int(item.protein))g P • \(Int(item.carbohydrates))g C • \(Int(item.fat))g G")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            // Controles de ML para líquidos e G para sólidos
                            HStack(spacing: 6) {
                                if item.isLiquid || item.unit == "ml" {
                                    Button("-50ml") {
                                        adjustItemPortion(itemId: item.id, delta: -50)
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundColor(.blue)
                                    .cornerRadius(6)
                                    .buttonStyle(.borderless)
                                    
                                    Text("\(Int(item.portionValue)) ml")
                                        .font(.system(size: 13, weight: .heavy))
                                        .frame(minWidth: 48)
                                    
                                    Button("+50ml") {
                                        adjustItemPortion(itemId: item.id, delta: 50)
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundColor(.blue)
                                    .cornerRadius(6)
                                    .buttonStyle(.borderless)
                                } else {
                                    Button("-25g") {
                                        adjustItemPortion(itemId: item.id, delta: -25)
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(6)
                                    .buttonStyle(.borderless)
                                    
                                    Text("\(Int(item.portionValue)) g")
                                        .font(.system(size: 13, weight: .heavy))
                                        .frame(minWidth: 48)
                                    
                                    Button("+25g") {
                                        adjustItemPortion(itemId: item.id, delta: 25)
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(6)
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemBackground).opacity(0.7))
                    .cornerRadius(10)
                }
            }
            
            if !meal.aiSummary.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 10))
                        .foregroundColor(Color("AccentColor"))
                    Text(meal.aiSummary)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color("AccentColor").opacity(0.06))
                .cornerRadius(8)
            }
            
            // Botão Confirmar e Inserir no Banco
            Button {
                saveMealToSwiftData(meal: meal)
            } label: {
                HStack {
                    if isSuccess {
                        Image(systemName: "checkmark")
                        Text("Refeição Adicionada!")
                    } else {
                        Image(systemName: "plus.circle.fill")
                        Text(meal.items.count > 1 ? "Registrar Prato (\(meal.items.count) itens)" : "Registrar Alimento no App")
                    }
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isSuccess ? Color.green : Color("AccentGreen"))
                .cornerRadius(12)
            }
        }
        .padding(18)
        .background(Color("CardBackground"))
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color("AccentColor").opacity(0.3), lineWidth: 1.5))
    }
    
    private func adjustItemPortion(itemId: UUID, delta: Double) {
        guard var meal = analyzedMeal else { return }
        if let idx = meal.items.firstIndex(where: { $0.id == itemId }) {
            let item = meal.items[idx]
            let oldPortion = max(1.0, item.portionValue)
            let newPortion = max(item.isLiquid ? 25.0 : 5.0, oldPortion + delta)
            let factor = newPortion / oldPortion
            
            meal.items[idx].portionValue = newPortion
            meal.items[idx].calories = ((item.calories * factor) * 10).rounded() / 10
            meal.items[idx].protein = ((item.protein * factor) * 10).rounded() / 10
            meal.items[idx].carbohydrates = ((item.carbohydrates * factor) * 10).rounded() / 10
            meal.items[idx].fat = ((item.fat * factor) * 10).rounded() / 10
            
            meal.totalCalories = meal.items.reduce(0.0) { $0 + $1.calories }
            meal.totalProtein = meal.items.reduce(0.0) { $0 + $1.protein }
            meal.totalCarbs = meal.items.reduce(0.0) { $0 + $1.carbohydrates }
            meal.totalFat = meal.items.reduce(0.0) { $0 + $1.fat }
            
            self.analyzedMeal = meal
        }
    }
    
    private func macroBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.12))
        .cornerRadius(10)
    }
    
    // MARK: - Ações
    
    private func analyzeWithGemini() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        errorMessage = nil
        
        Task {
            do {
                let result = try await geminiService.analyzeMeal(description: inputText)
                withAnimation(.spring(duration: 0.35)) {
                    self.analyzedMeal = result
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func saveMealToSwiftData(meal: AIExtractedMeal) {
        let mealType = MealType(rawValue: meal.mealType) ?? .lunch
        var createdEntries: [FoodEntry] = []
        
        for item in meal.items {
            let entry = FoodEntry(
                name: item.name,
                brand: "",
                mealType: mealType,
                portionGrams: item.portionValue,
                calories: item.calories,
                protein: item.protein,
                carbohydrates: item.carbohydrates,
                fat: item.fat,
                date: Date()
            )
            modelContext.insert(entry)
            AppActivityLogManager.shared.logMeal(
                name: item.name,
                mealType: mealType.rawValue,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbohydrates,
                fat: item.fat,
                isSnack: mealType == .snacks,
                date: Date()
            )
            createdEntries.append(entry)
        }
        
        try? modelContext.save()
        let last = createdEntries.last
        ContaCaDataStore.shared.syncTodayData(lastFoodName: last?.name, lastFoodCalories: last?.calories)
        
        withAnimation {
            isSuccess = true
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            onMealLogged?()
            dismiss()
        }
    }
}
