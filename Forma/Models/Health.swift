//
//  Health.swift
//  Forma
//
//  Created by João Pedro on 10/18/26.
//

import Foundation
import SwiftData

nonisolated public struct Macros: Codable, Sendable, Equatable {
    public var protein: Double
    public var fat: Double
    public var carbohydrates: Double
    
    public init(
        protein: Double = 160.0,
        fat: Double = 70.0,
        carbohydrates: Double = 380.0
    ) {
        self.protein = protein
        self.fat = fat
        self.carbohydrates = carbohydrates
    }
}

@Model
final class Health {
    var id: UUID = UUID()
    var height: Double = 1.78
    var weight: Double = 72.0
    var protein: Double = 160.0
    var fat: Double = 70.0
    var carbohydrates: Double = 380.0
    
    var macros: Macros {
        get {
            Macros(protein: protein, fat: fat, carbohydrates: carbohydrates)
        }
        set {
            protein = newValue.protein
            fat = newValue.fat
            carbohydrates = newValue.carbohydrates
        }
    }
    
    init(
        id: UUID = UUID(),
        height: Double = 1.78,
        weight: Double = 72.0,
        macros: Macros = Macros()
    ) {
        self.id = id
        self.height = height
        self.weight = weight
        self.protein = macros.protein
        self.fat = macros.fat
        self.carbohydrates = macros.carbohydrates
    }
}
