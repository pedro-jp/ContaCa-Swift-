package com.forma.backend.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "workout_routines")
public class WorkoutRoutineEntity {
    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false)
    private String title;

    @Column(name = "workout_type", nullable = false)
    private String workoutType;

    @Column(name = "target_muscles")
    private String targetMuscles;

    @Column(name = "hypertrophy_focus", columnDefinition = "TEXT")
    private String hypertrophyFocus;

    @Column(name = "estimated_duration_minutes")
    private Integer estimatedDurationMinutes = 50;

    @Column(name = "estimated_calories")
    private Double estimatedCalories = 350.0;

    @Column(name = "recommended_rest_seconds")
    private Integer recommendedRestSeconds = 90;

    @Column(name = "is_favorite")
    private Boolean isFavorite = false;

    @Column(name = "exercises_json", columnDefinition = "TEXT")
    private String exercisesJson;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "created_at")
    private Instant createdAt = Instant.now();

    @Column(name = "last_trained_at")
    private Instant lastTrainedAt;

    public WorkoutRoutineEntity() {}

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getUserId() { return userId; }
    public void setUserId(UUID userId) { this.userId = userId; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getWorkoutType() { return workoutType; }
    public void setWorkoutType(String workoutType) { this.workoutType = workoutType; }

    public String getTargetMuscles() { return targetMuscles; }
    public void setTargetMuscles(String targetMuscles) { this.targetMuscles = targetMuscles; }

    public String getHypertrophyFocus() { return hypertrophyFocus; }
    public void setHypertrophyFocus(String hypertrophyFocus) { this.hypertrophyFocus = hypertrophyFocus; }

    public Integer getEstimatedDurationMinutes() { return estimatedDurationMinutes; }
    public void setEstimatedDurationMinutes(Integer estimatedDurationMinutes) { this.estimatedDurationMinutes = estimatedDurationMinutes; }

    public Double getEstimatedCalories() { return estimatedCalories; }
    public void setEstimatedCalories(Double estimatedCalories) { this.estimatedCalories = estimatedCalories; }

    public Integer getRecommendedRestSeconds() { return recommendedRestSeconds; }
    public void setRecommendedRestSeconds(Integer recommendedRestSeconds) { this.recommendedRestSeconds = recommendedRestSeconds; }

    public Boolean getIsFavorite() { return isFavorite; }
    public void setIsFavorite(Boolean isFavorite) { this.isFavorite = isFavorite; }

    public String getExercisesJson() { return exercisesJson; }
    public void setExercisesJson(String exercisesJson) { this.exercisesJson = exercisesJson; }

    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getLastTrainedAt() { return lastTrainedAt; }
    public void setLastTrainedAt(Instant lastTrainedAt) { this.lastTrainedAt = lastTrainedAt; }
}
