//
//  Profile.swift
//  ContaCa
//
//  Created by João Pedro on 10/18/26.
//

import Foundation

struct HealthInfo: Identifiable {
    var id: UUID
    var height: String
    var weight: String
    var protein: String?
    
    init(
        id: UUID,
        height: String,
        weight: String,
        protein: String? = nil
    ) {
        self.id = id
        self.height = height
        self.weight = weight
        self.protein = protein
    }
}
