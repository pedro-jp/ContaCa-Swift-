//
//  NutritionViewModel.swift
//  ContaCa
//
//  Created by João Pedro on 10/27/26.
//

import Foundation
import Combine

@MainActor
class NutritionViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var searchResults: [NutritionalFoodItem] = []
    @Published var isSearchingRemote: Bool = false
    @Published var selectedFood: NutritionalFoodItem?
    @Published var portionGrams: Double = 100.0
    @Published var selectedMealType: MealType = .lunch
    
    private let nutritionService = NutritionService.shared
    private var searchTask: Task<Void, Never>?
    
    init() {
        self.searchResults = nutritionService.popularFoods
    }
    
    func onSearchQueryChanged(_ newQuery: String) {
        searchTask?.cancel()
        
        let trimmed = newQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            self.searchResults = nutritionService.popularFoods
            self.isSearchingRemote = false
            return
        }
        
        // 1. RESPOSTA INSTANTÂNEA (0ms): Filtra na base local imediatamente
        let localMatches = nutritionService.searchLocal(query: trimmed)
        self.searchResults = localMatches
        
        // Se achou na base local ("de primeira"), exibe de imediato e NÃO aciona a nuvem
        if !localMatches.isEmpty {
            self.isSearchingRemote = false
            return
        }
        
        // 2. FALLBACK: Apenas se NÃO encontrou na base local
        self.isSearchingRemote = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            
            let remoteResults = await nutritionService.searchFoods(query: trimmed)
            if Task.isCancelled { return }
            
            if !remoteResults.isEmpty {
                self.searchResults = remoteResults
            }
            self.isSearchingRemote = false
        }
    }
    
    static func calculateTotals(for entries: [FoodEntry]) -> (calories: Double, protein: Double, carbs: Double, fat: Double) {
        let calories = entries.reduce(0.0) { $0 + $1.calories }
        let protein = entries.reduce(0.0) { $0 + $1.protein }
        let carbs = entries.reduce(0.0) { $0 + $1.carbohydrates }
        let fat = entries.reduce(0.0) { $0 + $1.fat }
        return (calories, protein, carbs, fat)
    }
}
