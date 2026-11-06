package com.forma.backend.controller;

import org.springframework.core.env.Environment;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class HealthPingController {

    private final Environment environment;

    public HealthPingController(Environment environment) {
        this.environment = environment;
    }

    @RequestMapping(value = {"/ping", "/health"}, method = {RequestMethod.GET, RequestMethod.HEAD})
    public ResponseEntity<Map<String, Object>> ping() {
        String dbUrl = environment.getProperty("spring.datasource.url", "");
        String databaseEngine = dbUrl.startsWith("jdbc:postgresql:") ? "supabase-postgresql" : "h2-local";
        return ResponseEntity.ok(Map.of(
            "status", "ok",
            "service", "forma-backend",
            "database", databaseEngine,
            "timestamp", Instant.now().toEpochMilli()
        ));
    }
}
