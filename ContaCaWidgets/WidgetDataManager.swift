//
//  WidgetDataManager.swift
//  ContaCa
//
//  Created by João Pedro on 10/29/26.
//

import Foundation
import WidgetKit

/// Modelo de dados compartilhado entre o App e os Widgets do iOS
public struct WidgetCalorieData: Codable, Sendable {
    public var caloriesConsumed: Double
    public var caloriesTarget: Double
    public var caloriesBurned: Double
    public var proteinConsumed: Double
    public var proteinTarget: Double
    public var carbsConsumed: Double
    public var carbsTarget: Double
    public var fatConsumed: Double
    public var fatTarget: Double
    public var goalRaw: String
    public var lastUpdated: Date
    
    public init(
        caloriesConsumed: Double = 0,
        caloriesTarget: Double = 2500,
        caloriesBurned: Double = 0,
        proteinConsumed: Double = 0,
        proteinTarget: Double = 160,
        carbsConsumed: Double = 0,
        carbsTarget: Double = 300,
        fatConsumed: Double = 0,
        fatTarget: Double = 70,
        goalRaw: String = "gain",
        lastUpdated: Date = Date()
    ) {
        self.caloriesConsumed = caloriesConsumed
        self.caloriesTarget = caloriesTarget
        self.caloriesBurned = caloriesBurned
        self.proteinConsumed = proteinConsumed
        self.proteinTarget = proteinTarget
        self.carbsConsumed = carbsConsumed
        self.carbsTarget = carbsTarget
        self.fatConsumed = fatConsumed
        self.fatTarget = fatTarget
        self.goalRaw = goalRaw
        self.lastUpdated = lastUpdated
    }
    
    public var remainingCalories: Double {
        max(0, caloriesTarget - caloriesConsumed)
    }
    
    public var progressRatio: Double {
        guard caloriesTarget > 0 else { return 0 }
        return min(1.0, max(0.0, caloriesConsumed / caloriesTarget))
    }
}

/// Gerenciador de sincronização de dados com WidgetKit usando App Groups e File Container
public final class WidgetDataManager: Sendable {
    public static let shared = WidgetDataManager()
    public static let appGroupId = "group.jota.ContaCa"
    public static let storageKey = "widget_calorie_data"
    public static let jsonFileName = "widget_calorie_data.json"
    
    private init() {}
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupId)
    }
    
    private var sharedFileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupId)?
            .appendingPathComponent(Self.jsonFileName)
    }
    
    public func saveWidgetData(_ data: WidgetCalorieData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        
        // 1. Grava no UserDefaults do App Group
        if let shared = sharedDefaults {
            shared.set(encoded, forKey: Self.storageKey)
            shared.synchronize()
        }
        
        // 2. Grava no arquivo JSON do Container compartilhado (redundância segura)
        if let fileURL = sharedFileURL {
            try? encoded.write(to: fileURL, options: .atomic)
        }
        
        // 3. Fallback no sandbox local
        UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        
        // 4. Notifica o WidgetKit para recarregar imediatamente todas as timelines
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    public func loadWidgetData() -> WidgetCalorieData {
        let decoder = JSONDecoder()
        
        // 1. Tenta recuperar do App Group UserDefaults
        if let shared = sharedDefaults,
           let data = shared.data(forKey: Self.storageKey),
           let decoded = try? decoder.decode(WidgetCalorieData.self, from: data) {
            return decoded
        }
        
        // 2. Tenta recuperar do arquivo JSON compartilhado no App Group
        if let fileURL = sharedFileURL,
           FileManager.default.fileExists(atPath: fileURL.path),
           let fileData = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode(WidgetCalorieData.self, from: fileData) {
            return decoded
        }
        
        // 3. Fallback para UserDefaults standard
        if let standardData = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? decoder.decode(WidgetCalorieData.self, from: standardData) {
            return decoded
        }
        
        return WidgetCalorieData()
    }
}
