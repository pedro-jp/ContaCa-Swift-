//
//  SmartFoodSuggestionEngine.swift
//  Forma
//
//  Motor inteligente de recomendações alimentares personalizadas por tipo de refeição,
//  dia da semana atual e histórico recente de consumo do usuário.
//

import Foundation

public struct SmartFoodSuggestion: Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let brand: String
    public let mealType: MealType
    public let portionValue: Double
    public let unit: String
    public let isLiquid: Bool
    public let calories: Double
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    public let reasonBadge: String
    public let isFromHistory: Bool

    public func toPlateItem() -> VoicePlateItem {
        VoicePlateItem(
            name: name,
            brand: brand,
            portionValue: portionValue,
            unit: unit,
            isLiquid: isLiquid,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            source: isFromHistory ? "Histórico" : "TACO Brasil"
        )
    }
}

enum SmartFoodSuggestionEngine {

    private struct AggregatedFood {
        let key: String
        var latestEntry: FoodEntry
        var totalPortion: Double = 0
        var totalCount: Int = 0
        var weekdayCount: Int = 0
        var last7DaysCount: Int = 0
        var last14DaysCount: Int = 0
    }

    /// Gera recomendações personalizadas priorizando:
    /// 1) O que o usuário mais consome nesta refeição neste mesmo dia da semana (ex: Almoço de Quarta)
    /// 2) O que o usuário mais vem consumindo recentemente nesta mesma refeição
    /// 3) Sugestões base por refeição apenas quando ainda há pouco histórico
    static func suggestions(
        from entries: [FoodEntry],
        for mealType: MealType,
        referenceDate: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 5
    ) -> [SmartFoodSuggestion] {
        let targetWeekday = calendar.component(.weekday, from: referenceDate)
        let weekdayTag = weekdayHabitLabel(for: targetWeekday)
        let mealLower = mealType.rawValue.lowercased()

        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: referenceDate) ?? referenceDate
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: referenceDate) ?? referenceDate

        let matchingEntries = entries.filter { $0.mealType == mealType }

        var grouped: [String: AggregatedFood] = [:]

        for entry in matchingEntries {
            let key = normalizeKey(entry.name)
            guard !key.isEmpty else { continue }

            let isSameWeekday = calendar.component(.weekday, from: entry.date) == targetWeekday
            let isLast7 = entry.date >= sevenDaysAgo
            let isLast14 = entry.date >= fourteenDaysAgo

            if var existing = grouped[key] {
                if entry.date > existing.latestEntry.date {
                    existing.latestEntry = entry
                }
                existing.totalPortion += max(1.0, entry.portionGrams)
                existing.totalCount += 1
                if isSameWeekday { existing.weekdayCount += 1 }
                if isLast7 { existing.last7DaysCount += 1 }
                if isLast14 { existing.last14DaysCount += 1 }
                grouped[key] = existing
            } else {
                grouped[key] = AggregatedFood(
                    key: key,
                    latestEntry: entry,
                    totalPortion: max(1.0, entry.portionGrams),
                    totalCount: 1,
                    weekdayCount: isSameWeekday ? 1 : 0,
                    last7DaysCount: isLast7 ? 1 : 0,
                    last14DaysCount: isLast14 ? 1 : 0
                )
            }
        }

        let allAggregated = Array(grouped.values)

        // 1. Hábitos específicos do dia da semana atual nesta refeição (ex: o que mais almoça na quarta)
        let weekdayFavorites = allAggregated
            .filter { $0.weekdayCount > 0 }
            .sorted { a, b in
                if a.weekdayCount != b.weekdayCount { return a.weekdayCount > b.weekdayCount }
                if a.last14DaysCount != b.last14DaysCount { return a.last14DaysCount > b.last14DaysCount }
                if a.totalCount != b.totalCount { return a.totalCount > b.totalCount }
                return a.latestEntry.date > b.latestEntry.date
            }

        // 2. O que mais está consumindo recentemente / com frequência nesta refeição
        let recentFavorites = allAggregated
            .sorted { a, b in
                let scoreA = (a.last7DaysCount * 5) + (a.last14DaysCount * 3) + a.totalCount
                let scoreB = (b.last7DaysCount * 5) + (b.last14DaysCount * 3) + b.totalCount
                if scoreA != scoreB { return scoreA > scoreB }
                return a.latestEntry.date > b.latestEntry.date
            }

        var selectedKeys = Set<String>()
        var results: [SmartFoodSuggestion] = []

        let maxWeekdaySlots = max(2, (limit + 1) / 2)
        for item in weekdayFavorites.prefix(maxWeekdaySlots) {
            guard results.count < limit else { break }
            selectedKeys.insert(item.key)
            results.append(buildSuggestion(from: item, mealType: mealType, badge: weekdayTag))
        }

        for item in recentFavorites {
            guard results.count < limit else { break }
            guard !selectedKeys.contains(item.key) else { continue }
            selectedKeys.insert(item.key)
            let badge: String
            if item.last14DaysCount > 0 {
                badge = "Recente no \(mealLower)"
            } else {
                badge = "Frequente no \(mealLower)"
            }
            results.append(buildSuggestion(from: item, mealType: mealType, badge: badge))
        }

        // 3. Fallback contextual apenas se o usuário ainda tiver menos de 4 itens históricos na refeição
        if results.count < min(4, limit) {
            for fallback in defaultSuggestions(for: mealType) {
                guard results.count < min(4, limit) else { break }
                let key = normalizeKey(fallback.name)
                guard !selectedKeys.contains(key) else { continue }
                selectedKeys.insert(key)
                results.append(fallback)
            }
        }

        return results
    }

    private static func buildSuggestion(
        from item: AggregatedFood,
        mealType: MealType,
        badge: String
    ) -> SmartFoodSuggestion {
        let latest = item.latestEntry
        let avgPortion = max(5.0, (item.totalPortion / Double(max(1, item.totalCount))))
        let roundedPortion = (avgPortion / 5.0).rounded() * 5.0
        let finalPortion = max(5.0, roundedPortion)
        let basePortion = max(1.0, latest.portionGrams)
        let scale = finalPortion / basePortion
        let liquid = isLikelyLiquid(name: latest.name, brand: latest.brand)

        return SmartFoodSuggestion(
            id: "hist_\(mealType.rawValue)_\(item.key)",
            name: latest.name,
            brand: latest.brand,
            mealType: mealType,
            portionValue: finalPortion,
            unit: liquid ? "ml" : "g",
            isLiquid: liquid,
            calories: ((latest.calories * scale) * 10.0).rounded() / 10.0,
            protein: ((latest.protein * scale) * 10.0).rounded() / 10.0,
            carbs: ((latest.carbohydrates * scale) * 10.0).rounded() / 10.0,
            fat: ((latest.fat * scale) * 10.0).rounded() / 10.0,
            reasonBadge: badge,
            isFromHistory: true
        )
    }

    private static func normalizeKey(_ raw: String) -> String {
        raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func weekdayHabitLabel(for weekday: Int) -> String {
        switch weekday {
        case 1: return "Comum no domingo"
        case 2: return "Comum na segunda"
        case 3: return "Comum na terça"
        case 4: return "Comum na quarta"
        case 5: return "Comum na quinta"
        case 6: return "Comum na sexta"
        case 7: return "Comum no sábado"
        default: return "Hábito do dia"
        }
    }

    private static func isLikelyLiquid(name: String, brand: String) -> Bool {
        let lower = "\(name) \(brand)".lowercased()
        let keywords = ["ml", "suco", "leite", "shake", "vitamina", "café", "cafe", "refrigerante", "água", "agua", "iogurte líquido", "whey"]
        return keywords.contains { lower.contains($0) }
    }

    private static func defaultSuggestions(for mealType: MealType) -> [SmartFoodSuggestion] {
        switch mealType {
        case .breakfast:
            return [
                SmartFoodSuggestion(id: "def_bf_1", name: "Ovos mexidos", brand: "TACO", mealType: .breakfast, portionValue: 100, unit: "g", isLiquid: false, calories: 148, protein: 13.0, carbs: 1.2, fat: 10.0, reasonBadge: "Café da Manhã", isFromHistory: false),
                SmartFoodSuggestion(id: "def_bf_2", name: "Pão francês", brand: "TACO", mealType: .breakfast, portionValue: 50, unit: "g", isLiquid: false, calories: 150, protein: 4.0, carbs: 29.3, fat: 1.5, reasonBadge: "Café da Manhã", isFromHistory: false),
                SmartFoodSuggestion(id: "def_bf_3", name: "Pão de queijo", brand: "TACO", mealType: .breakfast, portionValue: 100, unit: "g", isLiquid: false, calories: 350, protein: 8.0, carbs: 32.0, fat: 21.0, reasonBadge: "Café da Manhã", isFromHistory: false),
                SmartFoodSuggestion(id: "def_bf_4", name: "Banana prata", brand: "TACO", mealType: .breakfast, portionValue: 90, unit: "g", isLiquid: false, calories: 89, protein: 1.2, carbs: 23.4, fat: 0.1, reasonBadge: "Café da Manhã", isFromHistory: false)
            ]
        case .lunch:
            return [
                SmartFoodSuggestion(id: "def_lu_1", name: "Arroz branco cozido", brand: "TACO", mealType: .lunch, portionValue: 150, unit: "g", isLiquid: false, calories: 192, protein: 3.8, carbs: 42.2, fat: 0.3, reasonBadge: "Almoço", isFromHistory: false),
                SmartFoodSuggestion(id: "def_lu_2", name: "Feijão carioca cozido", brand: "TACO", mealType: .lunch, portionValue: 100, unit: "g", isLiquid: false, calories: 76, protein: 4.8, carbs: 13.6, fat: 0.5, reasonBadge: "Almoço", isFromHistory: false),
                SmartFoodSuggestion(id: "def_lu_3", name: "Peito de frango grelhado", brand: "TACO", mealType: .lunch, portionValue: 150, unit: "g", isLiquid: false, calories: 239, protein: 48.0, carbs: 0.0, fat: 3.8, reasonBadge: "Almoço", isFromHistory: false),
                SmartFoodSuggestion(id: "def_lu_4", name: "Patinho moído refogado", brand: "TACO", mealType: .lunch, portionValue: 130, unit: "g", isLiquid: false, calories: 285, protein: 46.7, carbs: 0.0, fat: 9.5, reasonBadge: "Almoço", isFromHistory: false)
            ]
        case .dinner:
            return [
                SmartFoodSuggestion(id: "def_di_1", name: "Peito de frango grelhado", brand: "TACO", mealType: .dinner, portionValue: 150, unit: "g", isLiquid: false, calories: 239, protein: 48.0, carbs: 0.0, fat: 3.8, reasonBadge: "Jantar", isFromHistory: false),
                SmartFoodSuggestion(id: "def_di_2", name: "Arroz branco cozido", brand: "TACO", mealType: .dinner, portionValue: 120, unit: "g", isLiquid: false, calories: 154, protein: 3.0, carbs: 33.7, fat: 0.2, reasonBadge: "Jantar", isFromHistory: false),
                SmartFoodSuggestion(id: "def_di_3", name: "Omelete simples", brand: "TACO", mealType: .dinner, portionValue: 120, unit: "g", isLiquid: false, calories: 198, protein: 15.6, carbs: 1.8, fat: 14.2, reasonBadge: "Jantar", isFromHistory: false),
                SmartFoodSuggestion(id: "def_di_4", name: "Batata doce cozida", brand: "TACO", mealType: .dinner, portionValue: 130, unit: "g", isLiquid: false, calories: 100, protein: 0.8, carbs: 23.9, fat: 0.1, reasonBadge: "Jantar", isFromHistory: false)
            ]
        case .snacks:
            return [
                SmartFoodSuggestion(id: "def_sn_1", name: "Whey Protein com água", brand: "Suplemento", mealType: .snacks, portionValue: 250, unit: "ml", isLiquid: true, calories: 120, protein: 24.0, carbs: 3.0, fat: 1.5, reasonBadge: "Lanche", isFromHistory: false),
                SmartFoodSuggestion(id: "def_sn_2", name: "Iogurte natural integral", brand: "TACO", mealType: .snacks, portionValue: 170, unit: "g", isLiquid: false, calories: 104, protein: 6.8, carbs: 9.9, fat: 5.1, reasonBadge: "Lanche", isFromHistory: false),
                SmartFoodSuggestion(id: "def_sn_3", name: "Banana com aveia", brand: "TACO", mealType: .snacks, portionValue: 120, unit: "g", isLiquid: false, calories: 205, protein: 5.4, carbs: 43.0, fat: 2.3, reasonBadge: "Lanche", isFromHistory: false),
                SmartFoodSuggestion(id: "def_sn_4", name: "Pão de queijo", brand: "TACO", mealType: .snacks, portionValue: 80, unit: "g", isLiquid: false, calories: 280, protein: 6.4, carbs: 25.6, fat: 16.8, reasonBadge: "Lanche", isFromHistory: false)
            ]
        }
    }
}
