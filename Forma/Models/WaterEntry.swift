//
//  WaterEntry.swift
//  Forma
//
//  Created by João Pedro on 11/01/26.
//

import Foundation
import SwiftData

@Model
public final class WaterEntry {
    public var id: UUID = UUID()
    public var milliliters: Int = 250
    public var date: Date = Date()
    public var createdAt: Date = Date()
    
    public init(
        id: UUID = UUID(),
        milliliters: Int = 250,
        date: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.milliliters = milliliters
        self.date = date
        self.createdAt = createdAt
    }
}
