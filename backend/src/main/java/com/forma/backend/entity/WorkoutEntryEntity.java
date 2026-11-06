package com.forma.backend.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "workout_entries")
public class WorkoutEntryEntity {
    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false)
    private String title;

    @Column(name = "workout_type", nullable = false)
    private String workoutType;

    @Column(name = "duration_minutes")
    private Integer durationMinutes = 45;

    @Column(name = "calories_burned")
    private Double caloriesBurned = 300.0;

    @Column(columnDefinition = "TEXT")
    private String notes;

    @Column(name = "workout_date", nullable = false)
    private Instant workoutDate;

    @Column(name = "created_at")
    private Instant createdAt = Instant.now();

    public WorkoutEntryEntity() {}

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getUserId() { return userId; }
    public void setUserId(UUID userId) { this.userId = userId; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getWorkoutType() { return workoutType; }
    public void setWorkoutType(String workoutType) { this.workoutType = workoutType; }

    public Integer getDurationMinutes() { return durationMinutes; }
    public void setDurationMinutes(Integer durationMinutes) { this.durationMinutes = durationMinutes; }

    public Double getCaloriesBurned() { return caloriesBurned; }
    public void setCaloriesBurned(Double caloriesBurned) { this.caloriesBurned = caloriesBurned; }

    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }

    public Instant getWorkoutDate() { return workoutDate; }
    public void setWorkoutDate(Instant workoutDate) { this.workoutDate = workoutDate; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
