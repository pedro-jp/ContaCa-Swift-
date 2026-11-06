package com.contaca.backend.entity;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "app_config")
public class AppConfigEntity {
    @Id
    @Column(name = "id", length = 50)
    private String id;

    @Column(name = "config_value", columnDefinition = "TEXT")
    private String configValue;

    @Column(name = "description")
    private String description;

    @Column(name = "updated_at")
    private Instant updatedAt = Instant.now();

    public AppConfigEntity() {}

    public AppConfigEntity(String id, String configValue, String description) {
        this.id = id;
        this.configValue = configValue;
        this.description = description;
        this.updatedAt = Instant.now();
    }

    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getConfigValue() { return configValue; }
    public void setConfigValue(String configValue) {
        this.configValue = configValue;
        this.updatedAt = Instant.now();
    }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
