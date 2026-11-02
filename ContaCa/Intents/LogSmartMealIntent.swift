//
//  LogSmartMealIntent.swift
//  ContaCa
//
//  Created by João Pedro on 10/29/26.
//

import AppIntents
import SwiftData
import WidgetKit

/// Intent da Siri para registrar refeições completas em linguagem natural usando IA
public struct LogSmartMealIntent: AppIntent {
    public static var title: LocalizedStringResource = "Registrar Refeição no ContaCa"
    public static var description = IntentDescription("Registra alimentos consumidos usando inteligência artificial no ContaCa.")
    public static var openAppWhenRun: Bool = false
    
    @Parameter(
        title: "O que você comeu?",
        description: "Ex: Comi um pratão de arroz, feijão e frango",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    public var userDescription: String
    
    public init() {}
    
    public init(userDescription: String) {
        self.userDescription = userDescription
    }
    
    @MainActor
    public func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let trimmed = userDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let msg = "Você não informou o que comeu. Tente dizer: Comi arroz, feijão e frango."
            return .result(value: msg, dialog: IntentDialog(stringLiteral: msg))
        }
        
        // 1. Processa a fala usando o parser semântico de alimentos
        let parseResult = await AIFoodParserService.shared.parseMeal(description: trimmed)
        
        guard !parseResult.items.isEmpty else {
            let msg = "Não consegui identificar os itens da refeição. Tente dizer por exemplo: Comi dois ovos mexidos."
            return .result(value: msg, dialog: IntentDialog(stringLiteral: msg))
        }
        
        // 2. Converte itens em modelos FoodEntry
        var foodEntries: [FoodEntry] = []
        for item in parseResult.items {
            let entry = FoodEntry(
                name: item.matchedFoodName,
                brand: item.brand,
                mealType: parseResult.mealType,
                portionGrams: item.portionGrams,
                calories: item.calories,
                protein: item.protein,
                carbohydrates: item.carbohydrates,
                fat: item.fat,
                date: Date()
            )
            foodEntries.append(entry)
        }
        
        // 3. Ação Direta: salva imediatamente no SwiftData e dispara atualização de widgets
        try ContaCaDataStore.shared.insertFoodEntries(foodEntries)
        
        // 4. Formata resposta em linguagem natural para a Siri
        let itemsNames = parseResult.items.map { $0.matchedFoodName }.joined(separator: ", ")
        let caloriesInt = Int(parseResult.totalCalories.rounded())
        let proteinInt = Int(parseResult.totalProtein.rounded())
        
        let confirmation: String
        if parseResult.items.count == 1 {
            confirmation = "Pronto! Registrei \(itemsNames) no seu \(parseResult.mealType.rawValue). Aprox. \(caloriesInt) kcal e \(proteinInt)g de proteína."
        } else {
            confirmation = "Refeição registrada no ContaCa! \(parseResult.items.count) itens salvos no \(parseResult.mealType.rawValue), somando cerca de \(caloriesInt) kcal e \(proteinInt)g de proteína."
        }
        
        return .result(
            value: confirmation,
            dialog: IntentDialog(stringLiteral: confirmation)
        )
    }
}
