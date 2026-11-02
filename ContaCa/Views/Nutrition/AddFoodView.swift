//
//  AddFoodView.swift
//  ContaCa
//
//  Created by João Pedro on 10/27/26.
//

import SwiftUI
import SwiftData

struct AddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var viewModel = NutritionViewModel()
    @State private var selectedMeal: MealType
    @State private var expandedFoodId: String? = nil
    @State private var toastMessage: String? = nil
    @State private var isProcessingAdd: Bool = false
    @State private var showVoiceSheet: Bool = false
    
    var onFoodAdded: ((FoodEntry) -> Void)? = nil
    
    init(preselectedMeal: MealType = AIFoodParserService.shared.inferPrimaryMealType(), onFoodAdded: ((FoodEntry) -> Void)? = nil) {
        _selectedMeal = State(initialValue: preselectedMeal)
        self.onFoodAdded = onFoodAdded
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Toast de Confirmação Rápida no Topo
                if let message = toastMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text(message)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color("AccentGreen"))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Seletor de Refeição Automático pelo Horário + Pergunta de Lanche
                VStack(alignment: .leading, spacing: 6) {
                    let primaryMeal = AIFoodParserService.shared.inferPrimaryMealType()
                    let isSnack = selectedMeal == .snacks
                    
                    HStack {
                        Text("Refeição pelo Horário:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        // Pergunta se é Lanche
                        HStack(spacing: 6) {
                            Text("É lanche?")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Button {
                                selectedMeal = isSnack ? primaryMeal : .snacks
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: isSnack ? "checkmark" : "clock")
                                        .font(.system(size: 9, weight: .bold))
                                    Text(isSnack ? "Sim (Lanche)" : "Não (\(primaryMeal.rawValue))")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(isSnack ? .white : Color("AccentColor"))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(isSnack ? Color.orange : Color("AccentColor").opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Picker("Refeição", selection: $selectedMeal) {
                        ForEach(MealType.allCases) { meal in
                            Label(meal.rawValue, systemImage: meal.icon)
                                .tag(meal)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)
                
                // Barra de Busca Instantânea
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Buscar alimento (ex: frango, arroz, banana, whey...)", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onChange(of: viewModel.searchQuery) { _, newValue in
                            viewModel.onSearchQueryChanged(newValue)
                        }
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.searchQuery = ""
                            viewModel.onSearchQueryChanged("")
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    Button {
                        showVoiceSheet = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .foregroundColor(Color("AccentColor"))
                    }
                    .buttonStyle(.borderless)
                }
                .padding(12)
                .background(Color("CardBackground"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
                
                // Indicador de fontes conectadas (Base TACO + USDA + Open Food Facts)
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle().fill(Color("AccentGreen")).frame(width: 6, height: 6)
                        Text("Base Nacional")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.blue).frame(width: 6, height: 6)
                        Text("USDA Central")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(Color.orange).frame(width: 6, height: 6)
                        Text("Open Food Facts")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if viewModel.isSearchingRemote {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                
                // Lista de Alimentos com Adição Instantânea em 1 Toque
                List {
                    if viewModel.searchResults.isEmpty && !viewModel.isSearchingRemote {
                        VStack(spacing: 12) {
                            Image(systemName: "fork.knife.circle")
                                .font(.system(size: 44))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Nenhum alimento encontrado")
                                .font(.headline)
                            Text("Tente buscar por termos como frango, arroz, ovo, banana ou aveia.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 30)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        Section {
                            ForEach(viewModel.searchResults) { item in
                                FoodInteractiveRow(
                                    item: item,
                                    isExpanded: expandedFoodId == item.id,
                                    onToggleExpand: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if expandedFoodId == item.id {
                                                expandedFoodId = nil
                                            } else {
                                                expandedFoodId = item.id
                                            }
                                        }
                                    },
                                    onAddGrams: { grams in
                                        addFoodDirectly(food: item, grams: grams)
                                    }
                                )
                            }
                        } header: {
                            Text(viewModel.searchQuery.isEmpty ? "Alimentos Frequentes / Populares" : "\(viewModel.searchResults.count) Alimentos Encontrados")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Adicionar Alimento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Pronto") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold))
                }
            }
            .sheet(isPresented: $showVoiceSheet) {
                VoiceAddFoodView { newEntry in
                    onFoodAdded?(newEntry)
                    dismiss()
                }
                .environment(\.modelContext, modelContext)
            }
        }
    }
    
    // Adiciona o alimento exatamente UMA vez ao SwiftData com proteção contra disparos simultâneos
    private func addFoodDirectly(food: NutritionalFoodItem, grams: Double) {
        guard !isProcessingAdd else { return }
        isProcessingAdd = true
        
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isProcessingAdd = false
            }
        }
        
        let macros = food.values(for: grams)
        
        let entry = FoodEntry(
            name: food.name,
            brand: food.brand,
            mealType: selectedMeal,
            portionGrams: grams,
            calories: macros.calories,
            protein: macros.protein,
            carbohydrates: macros.carbs,
            fat: macros.fat,
            date: Date(),
            createdAt: Date()
        )
        
        modelContext.insert(entry)
        do {
            try modelContext.save()
            print("✅ 1 item inserido no SwiftData: \(entry.name) (\(entry.portionGrams)g)")
            ContaCaDataStore.shared.syncTodayData(lastFoodName: entry.name, lastFoodCalories: entry.calories)
        } catch {
            print("Erro ao salvar no SwiftData: \(error)")
        }
        
        // Haptic feedback nativo
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        onFoodAdded?(entry)
        
        // Exibe toast de confirmação
        withAnimation {
            toastMessage = "+ \(Int(grams))g \(food.name) (\(Int(macros.calories)) kcal, \(Int(macros.protein))g P)"
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                if toastMessage?.contains(food.name) == true {
                    toastMessage = nil
                }
            }
        }
    }
}

// Linha de cada Alimento com isolamento rigoroso de botões (.borderless)
struct FoodInteractiveRow: View {
    let item: NutritionalFoodItem
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onAddGrams: (Double) -> Void
    
    @State private var customGrams: Double = 100.0
    
    private var badgeColor: Color {
        if item.sourceTag.contains("TACO") || item.sourceTag.contains("Nacional") {
            return Color("AccentGreen")
        } else if item.sourceTag.contains("USDA") {
            return Color.blue
        } else {
            return Color.orange
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header do Alimento com toque para expandir ajuste fino
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color("FontNormal"))
                            .lineLimit(1)
                        
                        Text(item.sourceTag)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(badgeColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badgeColor.opacity(0.12))
                            .cornerRadius(6)
                    }
                    
                    if !item.brand.isEmpty {
                        Text(item.brand)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    // Valores por 100g destacados
                    HStack(spacing: 8) {
                        Text("\(Int(item.caloriesPer100g)) kcal")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(Color("AccentColor"))
                        Text("•")
                            .foregroundColor(.gray)
                        Text("P: \(String(format: "%.1f", item.proteinPer100g))g")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color("AccentGreen"))
                        Text("C: \(String(format: "%.1f", item.carbsPer100g))g")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.blue)
                        Text("G: \(String(format: "%.1f", item.fatPer100g))g")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                // Botão de expandir/recolher
                Button {
                    onToggleExpand()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "slider.horizontal.3")
                        .font(.system(size: 22))
                        .foregroundColor(Color("AccentColor"))
                        .padding(6)
                }
                .buttonStyle(.borderless)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleExpand()
            }
            
            // Botões de Adição Rápida Independentes (.buttonStyle(.borderless) obrigatório)
            HStack(spacing: 8) {
                Text("Adicionar:")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                
                ForEach([50, 100, 150, 200], id: \.self) { grams in
                    Button("+ \(grams)g") {
                        onAddGrams(Double(grams))
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color("FontNormal"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color("CardBackground"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.top, 2)
            
            // Painel Expandido para Porção Customizada
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .background(Color.gray.opacity(0.2))
                    
                    HStack {
                        Text("Quantidade exata:")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(customGrams))")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color("AccentColor"))
                            Text("g")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Slider(value: $customGrams, in: 10...500, step: 5)
                        .tint(Color("AccentColor"))
                    
                    let calculated = item.values(for: customGrams)
                    HStack(spacing: 10) {
                        Text("\(Int(calculated.calories)) kcal")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color("AccentColor"))
                        Text("P: \(String(format: "%.1f", calculated.protein))g")
                            .font(.system(size: 12))
                            .foregroundColor(Color("AccentGreen"))
                        Text("C: \(String(format: "%.1f", calculated.carbs))g")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        Text("G: \(String(format: "%.1f", calculated.fat))g")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                    
                    Button {
                        onAddGrams(customGrams)
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Confirmar + \(Int(customGrams))g")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color("AccentColor"))
                        .cornerRadius(10)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    AddFoodView()
        .modelContainer(PreviewContainer.shared)
}
