package com.forma.backend.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "user_activity_logs")
public class UserActivityLogEntity {
    @Id
    @Column(length = 100)
    private String id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false, length = 50)
    private String category;

    @Column(nullable = false)
    private String title;

    @Column(name = "is_snack")
    private Boolean isSnack = false;

    @Column(name = "calories_change")
    private Double caloriesChange = 0.0;

    @Column(name = "protein_grams")
    private Double proteinGrams;

    @Column(name = "carbs_grams")
    private Double carbsGrams;

    @Column(name = "fat_grams")
    private Double fatGrams;

    @Column(name = "water_milliliters")
    private Integer waterMilliliters;

    @Column(name = "weight_kg")
    private Double weightKg;

    @Column(columnDefinition = "TEXT")
    private String details;

    @Column(name = "activity_timestamp", nullable = false)
    private Instant activityTimestamp;

    @Column(name = "created_at")
    private Instant createdAt = Instant.now();

    public UserActivityLogEntity() {}

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public UUID getUserId() { return userId; }
    public void setUserId(UUID userId) { this.userId = userId; }

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public Boolean getIsSnack() { return isSnack; }
    public void setIsSnack(Boolean isSnack) { this.isSnack = isSnack; }

    public Double getCaloriesChange() { return caloriesChange; }
    public void setCaloriesChange(Double caloriesChange) { this.caloriesChange = caloriesChange; }

    public Double getProteinGrams() { return proteinGrams; }
    public void setProteinGrams(Double proteinGrams) { this.proteinGrams = proteinGrams; }

    public Double getCarbsGrams() { return carbsGrams; }
    public void setCarbsGrams(Double carbsGrams) { this.carbsGrams = carbsGrams; }

    public Double getFatGrams() { return fatGrams; }
    public void setFatGrams(Double fatGrams) { this.fatGrams = fatGrams; }

    public Integer getWaterMilliliters() { return waterMilliliters; }
    public void setWaterMilliliters(Integer waterMilliliters) { this.waterMilliliters = waterMilliliters; }

    public Double getWeightKg() { return weightKg; }
    public void setWeightKg(Double weightKg) { this.weightKg = weightKg; }

    public String getDetails() { return details; }
    public void setDetails(String details) { this.details = details; }

    public Instant getActivityTimestamp() { return activityTimestamp; }
    public void setActivityTimestamp(Instant activityTimestamp) { this.activityTimestamp = activityTimestamp; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
