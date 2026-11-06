package com.contaca.app.data.model

import java.util.UUID

enum class MealType(val title: String, val icon: String) {
    BREAKFAST("Café da Manhã", "☀️"),
    LUNCH("Almoço", "🍲"),
    DINNER("Jantar", "🌙"),
    SNACKS("Lanches", "☕")
}

data class FoodEntry(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val brand: String = "",
    val mealType: MealType = MealType.LUNCH,
    val portionGrams: Double = 100.0,
    val calories: Double,
    val protein: Double = 0.0,
    val carbohydrates: Double = 0.0,
    val fat: Double = 0.0,
    val consumedAt: Long = System.currentTimeMillis()
)

data class WorkoutEntry(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val workoutType: String = "Musculação",
    val durationMinutes: Int = 45,
    val caloriesBurned: Double = 350.0,
    val notes: String = "",
    val workoutDate: Long = System.currentTimeMillis()
)

data class WaterEntry(
    val id: String = UUID.randomUUID().toString(),
    val milliliters: Int = 250,
    val entryDate: Long = System.currentTimeMillis()
)

data class WeightEntry(
    val id: String = UUID.randomUUID().toString(),
    val weight: Double,
    val entryDate: Long = System.currentTimeMillis(),
    val notes: String = ""
)

enum class FitnessGoal(val title: String, val subtitle: String) {
    GAIN("Ganhar peso", "Superávit calórico e hipertrofia"),
    LOSE("Perder peso", "Déficit calórico e definição muscular"),
    MAINTAIN("Manter peso", "Equilíbrio calórico e manutenção")
}

data class RecalculationContext(
    val workoutsLast14DaysCount: Int = 0,
    val avgDailyWorkoutBurn: Double = 0.0,
    val routineEstimatedDailyBurn: Double = 0.0,
    val recentAvgSteps: Double = 0.0,
    val weeklyWeightTrendKg: Double? = null
)

data class UserProfile(
    val name: String = "João Pedro",
    val email: String = "joao@email.com",
    val goal: FitnessGoal = FitnessGoal.GAIN,
    val targetCalorieIntake: Double = 2800.0,
    val targetCalorieBurn: Double = 600.0,
    val targetSteps: Double = 8000.0,
    val currentWeight: Double = 72.0,
    val targetWeight: Double = 80.0,
    val heightMeters: Double = 1.78,
    val targetProtein: Double = 160.0,
    val targetFat: Double = 70.0,
    val targetCarbohydrates: Double = 380.0,
    val targetWaterMilliliters: Int = 2500
) {
    val tmb: Double
        get() {
            val weight = if (currentWeight > 30.0) currentWeight else 70.0
            val heightCm = heightMeters.coerceAtLeast(1.0) * 100.0
            return (10.0 * weight) + (6.25 * heightCm) - (5.0 * 25.0) + 5.0
        }

    fun contextualTdee(
        weightOverride: Double = currentWeight,
        heightOverride: Double = heightMeters,
        context: RecalculationContext? = null
    ): Double {
        val validWeight = weightOverride.coerceIn(30.0, 300.0)
        val validHeight = if (heightOverride >= 100.0 && heightOverride <= 250.0) {
            (heightOverride / 100.0).coerceIn(1.0, 2.5)
        } else {
            heightOverride.coerceIn(1.0, 2.5)
        }
        val baseTmb = (10.0 * validWeight) + (6.25 * validHeight * 100.0) - (5.0 * 25.0) + 5.0
        val safeTargetSteps = targetSteps.coerceAtLeast(3000.0)
        val effectiveSteps = maxOf(context?.recentAvgSteps ?: 0.0, safeTargetSteps * 0.85)
        val neatFactor = 1.25 + ((effectiveSteps / 10000.0) * 0.15).coerceIn(0.08, 0.25)
        val dailyExerciseBurn = maxOf(
            (context?.avgDailyWorkoutBurn ?: 0.0).coerceAtLeast(0.0),
            maxOf(
                (context?.routineEstimatedDailyBurn ?: 0.0).coerceAtLeast(0.0),
                targetCalorieBurn.coerceAtLeast(0.0) * 0.65
            )
        )
        return (baseTmb * neatFactor) + dailyExerciseBurn
    }

    fun recalculated(
        newWeight: Double = currentWeight,
        newHeight: Double = heightMeters,
        newGoal: FitnessGoal = goal,
        newTargetWeight: Double = targetWeight,
        context: RecalculationContext? = null
    ): UserProfile {
        val validWeight = newWeight.coerceIn(30.0, 300.0)
        val validHeight = if (newHeight >= 100.0 && newHeight <= 250.0) {
            (newHeight / 100.0).coerceIn(1.0, 2.5)
        } else {
            newHeight.coerceIn(1.0, 2.5)
        }
        val imc = validWeight / (validHeight * validHeight)
        val baseTmb = (10.0 * validWeight) + (6.25 * validHeight * 100.0) - (5.0 * 25.0) + 5.0
        val safeTargetSteps = targetSteps.coerceAtLeast(3000.0)
        val effectiveSteps = maxOf(context?.recentAvgSteps ?: 0.0, safeTargetSteps * 0.85)
        val neatFactor = 1.25 + ((effectiveSteps / 10000.0) * 0.15).coerceIn(0.08, 0.25)
        val dailyExerciseBurn = maxOf(
            (context?.avgDailyWorkoutBurn ?: 0.0).coerceAtLeast(0.0),
            maxOf(
                (context?.routineEstimatedDailyBurn ?: 0.0).coerceAtLeast(0.0),
                targetCalorieBurn.coerceAtLeast(0.0) * 0.65
            )
        )
        val maintenance = (baseTmb * neatFactor) + dailyExerciseBurn
        val highTrainingLoad = dailyExerciseBurn >= 320.0 || (context?.workoutsLast14DaysCount ?: 0) >= 8

        val rawCalories: Double
        val proteinFactor: Double
        val fatFactor: Double
        val minCarbs: Double
        when (newGoal) {
            FitnessGoal.GAIN -> {
                val weightGap = (newTargetWeight - validWeight).coerceAtLeast(0.0)
                val gapBonus = ((weightGap - 4.0) * 10.0).coerceIn(0.0, 150.0)
                val lowBmiBonus = if (imc < 20.0) 50.0 else 0.0
                val trendBonus = context?.weeklyWeightTrendKg?.let { trend ->
                    when {
                        trend < 0.10 -> 100.0
                        trend > 0.75 -> -75.0
                        else -> 0.0
                    }
                } ?: 0.0
                rawCalories = maintenance + 400.0 + gapBonus + lowBmiBonus + trendBonus
                proteinFactor = if (highTrainingLoad) 2.1 else 2.0
                fatFactor = 1.0
                minCarbs = 120.0
            }
            FitnessGoal.LOSE -> {
                val loseGap = (validWeight - newTargetWeight).coerceAtLeast(0.0)
                val gapDeficit = ((loseGap - 6.0) * 6.0).coerceIn(0.0, 100.0)
                val trendAdjust = context?.weeklyWeightTrendKg?.let { trend ->
                    when {
                        trend > -0.10 -> -75.0
                        trend < -1.0 -> 75.0
                        else -> 0.0
                    }
                } ?: 0.0
                val safeFloor = maxOf(1300.0, baseTmb * 1.05)
                rawCalories = (maintenance - 450.0 - gapDeficit + trendAdjust).coerceAtLeast(safeFloor)
                proteinFactor = if (highTrainingLoad) 2.3 else 2.2
                fatFactor = 0.8
                minCarbs = 60.0
            }
            FitnessGoal.MAINTAIN -> {
                val trendAdjust = context?.weeklyWeightTrendKg?.let { trend ->
                    when {
                        trend > 0.35 -> -60.0
                        trend < -0.35 -> 60.0
                        else -> 0.0
                    }
                } ?: 0.0
                rawCalories = (maintenance + trendAdjust).coerceAtLeast(1300.0)
                proteinFactor = if (highTrainingLoad) 2.0 else 1.9
                fatFactor = 0.9
                minCarbs = 80.0
            }
        }

        val newCalories = kotlin.math.round(rawCalories / 10.0) * 10.0
        val proteinGrams = kotlin.math.round(validWeight * proteinFactor)
        val fatGrams = kotlin.math.round(validWeight * fatFactor)
        val remainingCalories = (newCalories - (proteinGrams * 4.0 + fatGrams * 9.0)).coerceAtLeast(0.0)
        val carbsGrams = kotlin.math.round(remainingCalories / 4.0).coerceAtLeast(minCarbs)
        val stepHydrationBonus = if (effectiveSteps > 8000.0) (effectiveSteps - 8000.0) * 0.04 else 0.0
        val rawWater = (validWeight * 35.0) + (dailyExerciseBurn * 0.85) + stepHydrationBonus
        val waterMl = ((kotlin.math.round(rawWater / 250.0).toInt()) * 250).coerceAtLeast(1750)

        return copy(
            goal = newGoal,
            currentWeight = kotlin.math.round(validWeight * 10.0) / 10.0,
            targetWeight = kotlin.math.round(newTargetWeight * 10.0) / 10.0,
            heightMeters = kotlin.math.round(validHeight * 100.0) / 100.0,
            targetCalorieIntake = newCalories,
            targetProtein = proteinGrams,
            targetFat = fatGrams,
            targetCarbohydrates = carbsGrams,
            targetWaterMilliliters = waterMl
        )
    }
}

data class WorkoutExerciseItem(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val sets: Int = 3,
    val reps: String = "10-12",
    val suggestedWeight: String = "",
    val targetMuscle: String = "",
    val executionTip: String = "",
    val restSeconds: Int = 90,
    val completedSets: MutableList<Boolean> = MutableList(sets) { false }
)

data class WorkoutRoutine(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val workoutType: String = "Musculação",
    val targetMuscles: String = "",
    val hypertrophyFocus: String = "",
    val estimatedDurationMinutes: Int = 50,
    val estimatedCalories: Double = 350.0,
    val recommendedRestSeconds: Int = 90,
    val isFavorite: Boolean = false,
    val exercises: List<WorkoutExerciseItem> = emptyList(),
    val notes: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

data class SuggestedNutritionTargets(
    val dailyCalories: Double,
    val proteinGrams: Double,
    val carbsGrams: Double,
    val fatGrams: Double,
    val waterMilliliters: Int,
    val explanation: String
)

data class AIRecommendedRoutine(
    val title: String,
    val workoutType: String,
    val targetMuscles: String,
    val hypertrophyFocus: String,
    val estimatedDurationMinutes: Int,
    val estimatedCalories: Double,
    val recommendedRestSeconds: Int,
    val exercises: List<WorkoutExerciseItem>
)

data class EvolutionAIAnalysis(
    val id: String = UUID.randomUUID().toString(),
    val statusSummary: String,
    val calorieDiagnostic: String,
    val macroDiagnostic: String,
    val hydrationDiagnostic: String,
    val workoutSuggestions: List<String> = emptyList(),
    val nutritionSuggestions: List<String> = emptyList(),
    val weeklyActionPlan: String,
    val suggestedTargets: SuggestedNutritionTargets? = null,
    val recommendedRoutine: AIRecommendedRoutine? = null,
    val generatedAt: Long = System.currentTimeMillis()
)

data class ActivityLogRecord(
    val id: String = UUID.randomUUID().toString(),
    val timestamp: String,
    val category: String, // meal, workout, water, weight
    val title: String,
    val isSnack: Boolean? = false,
    val caloriesChange: Double = 0.0,
    val proteinGrams: Double? = null,
    val carbsGrams: Double? = null,
    val fatGrams: Double? = null,
    val waterMilliliters: Int? = null,
    val weightKg: Double? = null,
    val details: String? = null
)
