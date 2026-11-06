package com.contaca.backend.websocket;

import com.contaca.backend.entity.AiRequestLogEntity;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class AdminEventPublisherService {

    private final AdminWebSocketHandler webSocketHandler;

    public AdminEventPublisherService(AdminWebSocketHandler webSocketHandler) {
        this.webSocketHandler = webSocketHandler;
    }

    public void publishAiRequest(AiRequestLogEntity log, long totalAiRequests) {
        webSocketHandler.broadcast("AI_REQUEST", Map.of(
            "id", log.getId(),
            "userId", log.getUserId(),
            "endpoint", log.getEndpoint(),
            "promptSummary", log.getPromptSummary(),
            "status", log.getStatus(),
            "durationMs", log.getDurationMs(),
            "createdAt", log.getCreatedAt().toString(),
            "totalAiRequests", totalAiRequests
        ));
    }

    public void publishUserActivity(String event, String email, String name, String authProvider, long totalUsers) {
        webSocketHandler.broadcast("USER_ACTIVITY", Map.of(
            "event", event,
            "email", email,
            "name", name != null ? name : "Atleta",
            "authProvider", authProvider != null ? authProvider : "EMAIL",
            "totalUsers", totalUsers
        ));
    }

    public void publishSyncActivity(String entityType, int count, long totalFoods, long totalWorkouts) {
        webSocketHandler.broadcast("SYNC_ACTIVITY", Map.of(
            "entityType", entityType,
            "count", count,
            "totalFoods", totalFoods,
            "totalWorkouts", totalWorkouts
        ));
    }

    public void publishKillSwitchState(boolean isBlocked) {
        webSocketHandler.broadcast("KILL_SWITCH_CHANGED", Map.of(
            "isBlocked", isBlocked,
            "message", isBlocked ? "⛔️ Requisições à API de IA foram BLOQUEADAS" : "🟢 Requisições à API de IA foram LIBERADAS"
        ));
    }

    public void publishConfigUpdated(String keyMasked, String model) {
        webSocketHandler.broadcast("CONFIG_UPDATED", Map.of(
            "activeApiKeyMasked", keyMasked,
            "geminiModel", model
        ));
    }
}
