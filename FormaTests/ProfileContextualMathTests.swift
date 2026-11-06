//
//  ProfileContextualMathTests.swift
//  FormaTests
//

import XCTest
@testable import Forma

@MainActor
final class ProfileContextualMathTests: XCTestCase {

    func testIMCBoundaryClassificationHasNoRangeGaps() {
        XCTAssertEqual(EvolutionCalculator.classifyIMC(18.49), "Abaixo do peso ideal")
        XCTAssertEqual(EvolutionCalculator.classifyIMC(18.50), "Peso saudável")
        XCTAssertEqual(EvolutionCalculator.classifyIMC(24.95), "Peso saudável")
        XCTAssertEqual(EvolutionCalculator.classifyIMC(25.00), "Sobrepeso leve")
        XCTAssertEqual(EvolutionCalculator.classifyIMC(29.95), "Sobrepeso leve")
        XCTAssertEqual(EvolutionCalculator.classifyIMC(30.00), "Obesidade Grau I")
        XCTAssertEqual(EvolutionCalculator.classifyIMC(34.95), "Obesidade Grau I")
        XCTAssertEqual(EvolutionCalculator.classifyIMC(35.00), "Obesidade Grau II+")
    }

    func testFlexibleProfileInputValidation() {
        XCTAssertEqual(ProfileInputValidator.parseFlexibleWeight("74,5"), 74.5)
        XCTAssertEqual(ProfileInputValidator.parseFlexibleWeight(" 80.24 "), 80.2)
        XCTAssertNil(ProfileInputValidator.parseFlexibleWeight("25"))
        XCTAssertNil(ProfileInputValidator.parseFlexibleWeight("350"))
        XCTAssertNil(ProfileInputValidator.parseFlexibleWeight("abc"))

        XCTAssertEqual(ProfileInputValidator.parseFlexibleHeight("1,78"), 1.78)
        XCTAssertEqual(ProfileInputValidator.parseFlexibleHeight("178"), 1.78)
        XCTAssertNil(ProfileInputValidator.parseFlexibleHeight("0,85"))
        XCTAssertNil(ProfileInputValidator.parseFlexibleHeight("290"))
    }

    func testContextualTargetsScaleWithTrainingLoadAndGoal() {
        let lowActivityContext = RecalculationContext(
            workoutsLast14DaysCount: 0,
            avgDailyWorkoutBurn: 0.0,
            routineEstimatedDailyBurn: 0.0,
            recentAvgSteps: 4000.0,
            weeklyWeightTrendKg: 0.30
        )

        let highActivityStalledContext = RecalculationContext(
            workoutsLast14DaysCount: 10,
            avgDailyWorkoutBurn: 520.0,
            routineEstimatedDailyBurn: 450.0,
            recentAvgSteps: 12000.0,
            weeklyWeightTrendKg: 0.0 // Estagnado no ganho de peso -> bônus calórico
        )

        let baseGain = Profile.computeContextualTargets(
            weight: 70.0,
            height: 1.78,
            targetWeight: 80.0,
            goal: .gain,
            targetCalorieBurn: 400.0,
            targetSteps: 6000.0,
            context: lowActivityContext
        )

        let activeGain = Profile.computeContextualTargets(
            weight: 70.0,
            height: 1.78,
            targetWeight: 80.0,
            goal: .gain,
            targetCalorieBurn: 400.0,
            targetSteps: 6000.0,
            context: highActivityStalledContext
        )

        XCTAssertEqual(baseGain.tmb, activeGain.tmb, accuracy: 0.1)
        XCTAssertGreaterThan(activeGain.contextualTdee, baseGain.contextualTdee + 250.0)
        XCTAssertGreaterThan(activeGain.suggestedCalories, baseGain.suggestedCalories + 300.0)
        XCTAssertGreaterThan(activeGain.proteinGrams, baseGain.proteinGrams)
        XCTAssertGreaterThan(activeGain.waterMilliliters, baseGain.waterMilliliters)

        // Modo perda de peso respeita piso metabólico seguro (>= 1.05 * TMB e >= 1300 kcal)
        let weightLoss = Profile.computeContextualTargets(
            weight: 60.0,
            height: 1.65,
            targetWeight: 54.0,
            goal: .lose,
            targetCalorieBurn: 200.0,
            targetSteps: 4000.0,
            context: nil
        )
        XCTAssertGreaterThanOrEqual(weightLoss.suggestedCalories, max(1300.0, (weightLoss.tmb * 1.05 / 10.0).rounded() * 10.0 - 10.0))
    }
}
