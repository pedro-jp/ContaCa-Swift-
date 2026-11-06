//
//  WeightEntry.swift
//  Forma
//
//  Created by João Pedro on 10/27/26.
//

import Foundation
import SwiftData

@Model
final class WeightEntry {
    var id: UUID = UUID()
    var weight: Double = 72.0
    var date: Date = Date()
    var notes: String = ""
    
    init(
        id: UUID = UUID(),
        weight: Double,
        date: Date = Date(),
        notes: String = ""
    ) {
        self.id = id
        self.weight = weight
        self.date = date
        self.notes = notes
    }
}
