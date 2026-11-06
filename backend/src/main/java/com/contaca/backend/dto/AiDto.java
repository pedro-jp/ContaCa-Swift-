package com.contaca.backend.dto;

public class AiDto {

    public record MealAiRequest(
        String description,
        String userName,
        String imageBase64,
        String imageMimeType
    ) {}

    public record WorkoutAiRequest(
        String description,
        Double userWeight,
        String userName
    ) {}

    public record EvolutionAiRequest(
        String userGoal,
        Double currentWeight,
        Double targetWeight,
        Double heightMeters,
        Double targetCalories,
        Double targetCalorieBurn,
        Double targetSteps,
        Double calculatedTmb,
        Double contextualTdee,
        Double suggestedBaseCalories,
        Double suggestedProtein,
        Double suggestedCarbs,
        Double suggestedFat,
        Integer suggestedWaterMl,
        Double avgDailyWorkoutBurn,
        String activityLogJson,
        String userName
    ) {}
}
