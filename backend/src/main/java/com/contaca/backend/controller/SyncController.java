package com.contaca.backend.controller;

import com.contaca.backend.dto.SyncDto;
import com.contaca.backend.entity.User;
import com.contaca.backend.repository.FoodEntryRepository;
import com.contaca.backend.repository.WorkoutEntryRepository;
import com.contaca.backend.security.AuthContextResolver;
import com.contaca.backend.service.SyncService;
import com.contaca.backend.websocket.AdminEventPublisherService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/sync")
public class SyncController {

    private final SyncService syncService;
    private final AuthContextResolver authContextResolver;
    private final FoodEntryRepository foodEntryRepository;
    private final WorkoutEntryRepository workoutEntryRepository;
    private final AdminEventPublisherService adminEventPublisherService;

    public SyncController(
        SyncService syncService,
        AuthContextResolver authContextResolver,
        FoodEntryRepository foodEntryRepository,
        WorkoutEntryRepository workoutEntryRepository,
        AdminEventPublisherService adminEventPublisherService
    ) {
        this.syncService = syncService;
        this.authContextResolver = authContextResolver;
        this.foodEntryRepository = foodEntryRepository;
        this.workoutEntryRepository = workoutEntryRepository;
        this.adminEventPublisherService = adminEventPublisherService;
    }

    @PostMapping("/push")
    public ResponseEntity<?> push(
        @RequestHeader(value = "Authorization", required = false) String authHeader,
        @RequestHeader(value = "X-User-Id", required = false) String fallbackUserId,
        @RequestBody SyncDto.SyncPushRequest request
    ) {
        User user = authContextResolver.requireActiveUser(authHeader, fallbackUserId);

        // Se o administrador zerou a conta recentemente e o app ainda não reconheceu o reset,
        // ignora o push de dados antigos e sinaliza ao dispositivo para limpar o cache local.
        if (user.getForceResetAt() != null) {
            long resetEpoch = user.getForceResetAt().toEpochMilli();
            long clientAck = (request != null && request.clientResetAckEpochMs() != null)
                ? request.clientResetAckEpochMs()
                : 0L;
            if (clientAck < resetEpoch) {
                return ResponseEntity.ok(Map.of(
                    "status", "reset_required",
                    "forceResetEpochMs", resetEpoch,
                    "message", "Conta zerada pelo administrador. Limpando dados locais..."
                ));
            }
        }

        syncService.pushData(user.getId(), request);
        int count = (request != null && request.foods() != null ? request.foods().size() : 0)
            + (request != null && request.workouts() != null ? request.workouts().size() : 0);
        adminEventPublisherService.publishSyncActivity(
            "DATA_PUSH",
            count,
            foodEntryRepository.count(),
            workoutEntryRepository.count()
        );
        return ResponseEntity.ok(Map.of(
            "status", "synced",
            "message", "Dados sincronizados com sucesso no Forma!"
        ));
    }

    @GetMapping("/pull")
    public ResponseEntity<SyncDto.SyncPullResponse> pull(
        @RequestHeader(value = "Authorization", required = false) String authHeader,
        @RequestHeader(value = "X-User-Id", required = false) String fallbackUserId
    ) {
        User user = authContextResolver.requireActiveUser(authHeader, fallbackUserId);
        return ResponseEntity.ok(syncService.pullData(user.getId()));
    }
}
