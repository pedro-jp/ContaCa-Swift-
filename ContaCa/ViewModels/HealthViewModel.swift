//
//  HealthViewModel.swift
//  ContaCa
//
//  Created by João Pedro on 10/13/26.
//

import Foundation
import Combine
import HealthKit

@MainActor
class HealthViewModel: ObservableObject {
    @Published var steps: Double = 0
    @Published var calories: Double = 0
    
    private let healthManager = HealthManager.shared
    
    func loadHealthData() {
        healthManager.requestAuthorization { [weak self] success, _ in
            guard success, let self = self else { return }
            
            self.healthManager.fetchTodaySteps { steps in
                Task {
                    await MainActor.run {
                        self.steps = steps
                    }
                }
            }
            
            self.healthManager.fetchTodayCalories { calories in
                Task {
                    await MainActor.run {
                        self.calories = calories
                    }
                }
            }
        }
    }
}
