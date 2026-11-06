package com.contaca.backend.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "water_entries")
public class WaterEntryEntity {
    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false)
    private Integer milliliters;

    @Column(name = "entry_date", nullable = false)
    private Instant entryDate;

    @Column(name = "created_at")
    private Instant createdAt = Instant.now();

    public WaterEntryEntity() {}

    public UUID getId() { return id; }
    public void setId(UUID id) { this.id = id; }

    public UUID getUserId() { return userId; }
    public void setUserId(UUID userId) { this.userId = userId; }

    public Integer getMilliliters() { return milliliters; }
    public void setMilliliters(Integer milliliters) { this.milliliters = milliliters; }

    public Instant getEntryDate() { return entryDate; }
    public void setEntryDate(Instant entryDate) { this.entryDate = entryDate; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
