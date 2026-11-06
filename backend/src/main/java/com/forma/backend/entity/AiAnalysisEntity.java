package com.forma.backend.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "ai_analyses")
public class AiAnalysisEntity {
    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "status_summary", columnDefinition = "TEXT")
    private String statusSummary;

    @Column(name = "calorie_diagnostic", columnDefinition = "TEXT")
    private String calorieDiagnostic;

    @Column(name = "macro_diagnostic", columnDefinition = "TEXT")
    private String macroDiagnostic;

    @Column(name = "hydration_diagnostic", columnDefinition = "TEXT")
    private String hydrationDiagnostic;

    @Column(name = "workout_suggestions_json", columnDefinition = "TEXT")
    private String workoutSuggestionsJson;

    @Column(name = "nutrition_suggestions_json", columnDefinition = "TEXT")
    private String nutritionSuggestionsJson;

    @Column(name = "weekly_action_plan", columnDefinition = "TEXT")
    private String weeklyActionPlan;

    @Column(name = "suggested_targets_json", columnDefinition = "TEXT")
    private String suggestedTargetsJson;

    @Column(name = "recommended_routine_json", columnDefinition = "TEXT")
    private String recommendedRoutineJson;

    @Column(name = "created_at")
    private Instant createdAt = Instant.now();

    public AiAnalysisEntity() {}

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getUserId() { return userId; }
    public void setUserId(UUID userId) { this.userId = userId; }

    public String getStatusSummary() { return statusSummary; }
    public void setStatusSummary(String statusSummary) { this.statusSummary = statusSummary; }

    public String getCalorieDiagnostic() { return calorieDiagnostic; }
    public void setCalorieDiagnostic(String calorieDiagnostic) { this.calorieDiagnostic = calorieDiagnostic; }

    public String getMacroDiagnostic() { return macroDiagnostic; }
    public void setMacroDiagnostic(String macroDiagnostic) { this.macroDiagnostic = macroDiagnostic; }

    public String getHydrationDiagnostic() { return hydrationDiagnostic; }
    public void setHydrationDiagnostic(String hydrationDiagnostic) { this.hydrationDiagnostic = hydrationDiagnostic; }

    public String getWorkoutSuggestionsJson() { return workoutSuggestionsJson; }
    public void setWorkoutSuggestionsJson(String workoutSuggestionsJson) { this.workoutSuggestionsJson = workoutSuggestionsJson; }

    public String getNutritionSuggestionsJson() { return nutritionSuggestionsJson; }
    public void setNutritionSuggestionsJson(String nutritionSuggestionsJson) { this.nutritionSuggestionsJson = nutritionSuggestionsJson; }

    public String getWeeklyActionPlan() { return weeklyActionPlan; }
    public void setWeeklyActionPlan(String weeklyActionPlan) { this.weeklyActionPlan = weeklyActionPlan; }

    public String getSuggestedTargetsJson() { return suggestedTargetsJson; }
    public void setSuggestedTargetsJson(String suggestedTargetsJson) { this.suggestedTargetsJson = suggestedTargetsJson; }

    public String getRecommendedRoutineJson() { return recommendedRoutineJson; }
    public void setRecommendedRoutineJson(String recommendedRoutineJson) { this.recommendedRoutineJson = recommendedRoutineJson; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
