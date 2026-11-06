package com.forma.backend.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "user_profiles")
public class UserProfile {
    @Id
    @Column(name = "user_id")
    private UUID userId;

    private String goal = "gain";
    private Double targetCalorieIntake = 2800.0;
    private Double targetCalorieBurn = 600.0;
    private Double targetSteps = 8000.0;
    private Double targetWeight = 80.0;
    private Double targetProtein = 160.0;
    private Double targetCarbohydrates = 380.0;
    private Double targetFat = 70.0;
    private Integer targetWaterMilliliters = 2500;
    private Double heightMeters = 1.78;
    private Double currentWeight = 72.0;

    @Column(name = "onboarding_completed")
    private Boolean onboardingCompleted = false;

    @Column(name = "updated_at")
    private Instant updatedAt = Instant.now();

    public UserProfile() {}

    public UserProfile(UUID userId) {
        this.userId = userId;
        this.onboardingCompleted = false;
        this.updatedAt = Instant.now();
    }

    public UUID getUserId() { return userId; }
    public void setUserId(UUID userId) { this.userId = userId; }

    public String getGoal() { return goal; }
    public void setGoal(String goal) { this.goal = goal; }

    public Double getTargetCalorieIntake() { return targetCalorieIntake; }
    public void setTargetCalorieIntake(Double targetCalorieIntake) { this.targetCalorieIntake = targetCalorieIntake; }

    public Double getTargetCalorieBurn() { return targetCalorieBurn; }
    public void setTargetCalorieBurn(Double targetCalorieBurn) { this.targetCalorieBurn = targetCalorieBurn; }

    public Double getTargetSteps() { return targetSteps; }
    public void setTargetSteps(Double targetSteps) { this.targetSteps = targetSteps; }

    public Double getTargetWeight() { return targetWeight; }
    public void setTargetWeight(Double targetWeight) { this.targetWeight = targetWeight; }

    public Double getTargetProtein() { return targetProtein; }
    public void setTargetProtein(Double targetProtein) { this.targetProtein = targetProtein; }

    public Double getTargetCarbohydrates() { return targetCarbohydrates; }
    public void setTargetCarbohydrates(Double targetCarbohydrates) { this.targetCarbohydrates = targetCarbohydrates; }

    public Double getTargetFat() { return targetFat; }
    public void setTargetFat(Double targetFat) { this.targetFat = targetFat; }

    public Integer getTargetWaterMilliliters() { return targetWaterMilliliters; }
    public void setTargetWaterMilliliters(Integer targetWaterMilliliters) { this.targetWaterMilliliters = targetWaterMilliliters; }

    public Double getHeightMeters() { return heightMeters; }
    public void setHeightMeters(Double heightMeters) { this.heightMeters = heightMeters; }

    public Double getCurrentWeight() { return currentWeight; }
    public void setCurrentWeight(Double currentWeight) { this.currentWeight = currentWeight; }

    public Boolean getOnboardingCompleted() { return Boolean.TRUE.equals(onboardingCompleted); }
    public void setOnboardingCompleted(Boolean onboardingCompleted) { this.onboardingCompleted = onboardingCompleted; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
