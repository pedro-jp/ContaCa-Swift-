package com.forma.backend;

import com.forma.backend.dto.AdminDto;
import com.forma.backend.dto.AuthDto;
import com.forma.backend.dto.SyncDto;
import com.forma.backend.service.AdminUserService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class SyncIsolationIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private AdminUserService adminUserService;

    private AuthDto.AuthResponse registerTestUser(String email, String name) throws Exception {
        MvcResult res = mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new AuthDto.RegisterRequest(email, "Senha1234", name))))
            .andExpect(status().isOk())
            .andReturn();
        return objectMapper.readValue(res.getResponse().getContentAsString(), AuthDto.AuthResponse.class);
    }

    @Test
    @DisplayName("Isolamento estrito entre Usuário A e Usuário B + proteção contra colisão de UUID")
    void shouldIsolateUserDataAndPreventCrossUserUuidCollision() throws Exception {
        AuthDto.AuthResponse userA = registerTestUser("usera@forma.app", "Usuário A");
        AuthDto.AuthResponse userB = registerTestUser("userb@forma.app", "Usuário B");

        UUID sharedAttemptFoodId = UUID.randomUUID();
        UUID workoutIdA = UUID.randomUUID();

        SyncDto.SyncPushRequest pushA = new SyncDto.SyncPushRequest(
            new SyncDto.ProfileDto("Ganhar peso", 3100.0, 650.0, 9000.0, 82.0, 170.0, 410.0, 80.0, 3000, 1.80, 75.5),
            List.of(new SyncDto.FoodDto(sharedAttemptFoodId, "Arroz Integral + Frango", "TACO", "Almoço", 280.0, 420.0, 42.0, 48.0, 6.0, Instant.now())),
            List.of(new SyncDto.WorkoutDto(workoutIdA, "Treino A - Peito", "Musculação", 55, 390.0, "4x10 Supino", Instant.now())),
            List.of(new SyncDto.WaterDto(UUID.randomUUID(), 500, Instant.now())),
            List.of(new SyncDto.WeightDto(UUID.randomUUID(), 75.5, Instant.now())),
            List.of(),
            List.of(),
            List.of(),
            0L
        );

        mockMvc.perform(post("/api/sync/push")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + userA.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(pushA)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("synced"));

        // 1. Usuário B faz pull -> não deve enxergar nenhum dado do Usuário A
        mockMvc.perform(get("/api/sync/pull")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + userB.token()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.foods").isEmpty())
            .andExpect(jsonPath("$.workouts").isEmpty())
            .andExpect(jsonPath("$.waters").isEmpty())
            .andExpect(jsonPath("$.weights").isEmpty())
            .andExpect(jsonPath("$.profile.currentWeight").value(72.0));

        // 2. Usuário B tenta sobrescrever o alimento do Usuário A usando o mesmo UUID
        SyncDto.SyncPushRequest hijackPushB = new SyncDto.SyncPushRequest(
            null,
            List.of(new SyncDto.FoodDto(sharedAttemptFoodId, "Alimento Invasor B", "Hack", "Jantar", 999.0, 9999.0, 1.0, 1.0, 1.0, Instant.now())),
            List.of(),
            List.of(),
            List.of(),
            List.of(),
            List.of(),
            List.of(),
            0L
        );

        mockMvc.perform(post("/api/sync/push")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + userB.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(hijackPushB)))
            .andExpect(status().isOk());

        // 3. Dados do Usuário A permanecem intactos e exclusivos
        mockMvc.perform(get("/api/sync/pull")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + userA.token()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.foods.length()").value(1))
            .andExpect(jsonPath("$.foods[0].name").value("Arroz Integral + Frango"))
            .andExpect(jsonPath("$.foods[0].calories").value(420.0))
            .andExpect(jsonPath("$.workouts.length()").value(1))
            .andExpect(jsonPath("$.profile.currentWeight").value(75.5));
    }

    @Test
    @DisplayName("Propagação de forceResetEpochMs bloqueia push de cache antigo até confirmação do cliente")
    void shouldPropagateAdminForceResetAndBlockStaleClientPush() throws Exception {
        AuthDto.AuthResponse user = registerTestUser("reset@forma.app", "Atleta Reset");

        SyncDto.SyncPushRequest initialPush = new SyncDto.SyncPushRequest(
            null,
            List.of(new SyncDto.FoodDto(UUID.randomUUID(), "Aveia com Banana", "TACO", "Café da Manhã", 150.0, 260.0, 8.0, 48.0, 4.0, Instant.now())),
            List.of(),
            List.of(),
            List.of(),
            List.of(),
            List.of(),
            List.of(),
            0L
        );

        mockMvc.perform(post("/api/sync/push")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + user.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(initialPush)))
            .andExpect(status().isOk());

        // Admin zera a conta do usuário
        adminUserService.resetUserAccount(user.userId(), new AdminDto.ResetUserRequest(true, true, true, true, true));

        // Dispositivo tenta enviar dados antigos sem clientResetAckEpochMs atualizado -> recebe reset_required
        MvcResult blockedPush = mockMvc.perform(post("/api/sync/push")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + user.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(initialPush)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("reset_required"))
            .andExpect(jsonPath("$.forceResetEpochMs").isNumber())
            .andReturn();

        JsonNode resetBody = objectMapper.readTree(blockedPush.getResponse().getContentAsString());
        long resetEpochMs = resetBody.path("forceResetEpochMs").asLong();
        assertThat(resetEpochMs).isGreaterThan(0L);

        // Pull confirma que a nuvem está limpa e expõe forceResetEpochMs
        mockMvc.perform(get("/api/sync/pull")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + user.token()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.foods").isEmpty())
            .andExpect(jsonPath("$.forceResetEpochMs").value(resetEpochMs));

        // Após o app confirmar o reset (clientResetAckEpochMs >= forceResetEpochMs), novos pushes voltam a sincronizar
        SyncDto.SyncPushRequest postResetPush = new SyncDto.SyncPushRequest(
            null,
            List.of(new SyncDto.FoodDto(UUID.randomUUID(), "Omelete Pós-Reset", "Caseiro", "Café da Manhã", 120.0, 210.0, 18.0, 2.0, 14.0, Instant.now())),
            List.of(),
            List.of(),
            List.of(),
            List.of(),
            List.of(),
            List.of(),
            resetEpochMs
        );

        mockMvc.perform(post("/api/sync/push")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + user.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(postResetPush)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("synced"));
    }

    @Test
    @DisplayName("Exclusão sincronizada remove refeições e treinos definitivamente na nuvem respeitando isolamento por usuário")
    void shouldDeleteMealsAndWorkoutsPermanentlyAndPreventCrossUserDeletion() throws Exception {
        AuthDto.AuthResponse userA = registerTestUser("deletea@forma.app", "Atleta Exclusao A");
        AuthDto.AuthResponse userB = registerTestUser("deleteb@forma.app", "Atleta Exclusao B");

        UUID foodIdA = UUID.randomUUID();
        UUID workoutIdA = UUID.randomUUID();

        SyncDto.SyncPushRequest initialPushA = new SyncDto.SyncPushRequest(
            null,
            List.of(new SyncDto.FoodDto(foodIdA, "Pão de Queijo", "Mineiro", "Café da Manhã", 100.0, 350.0, 8.0, 32.0, 21.0, Instant.now())),
            List.of(new SyncDto.WorkoutDto(workoutIdA, "Treino de Costas e Bíceps", "Musculação", 41, 238.0, "Checklist", Instant.now())),
            List.of(),
            List.of(),
            List.of(),
            List.of(),
            List.of(),
            0L
        );

        mockMvc.perform(post("/api/sync/push")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + userA.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(initialPushA)))
            .andExpect(status().isOk());

        // Usuário B tenta apagar os itens do Usuário A -> deve ser ignorado
        SyncDto.SyncPushRequest maliciousDeleteB = new SyncDto.SyncPushRequest(
            null, List.of(), List.of(), List.of(), List.of(), List.of(), List.of(), List.of(), 0L,
            List.of(foodIdA), List.of(workoutIdA), List.of(), List.of(), List.of()
        );
        mockMvc.perform(post("/api/sync/push")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + userB.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(maliciousDeleteB)))
            .andExpect(status().isOk());

        mockMvc.perform(get("/api/sync/pull")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + userA.token()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.foods.length()").value(1))
            .andExpect(jsonPath("$.workouts.length()").value(1));

        // Usuário A apaga a própria refeição e o próprio treino -> não devem mais voltar no pull
        SyncDto.SyncPushRequest ownerDeleteA = new SyncDto.SyncPushRequest(
            null, List.of(), List.of(), List.of(), List.of(), List.of(), List.of(), List.of(), 0L,
            List.of(foodIdA), List.of(workoutIdA), List.of(), List.of(), List.of()
        );
        mockMvc.perform(post("/api/sync/push")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + userA.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(ownerDeleteA)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("synced"));

        mockMvc.perform(get("/api/sync/pull")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + userA.token()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.foods").isEmpty())
            .andExpect(jsonPath("$.workouts").isEmpty());
    }

    @Test
    @DisplayName("Conta nova inicia com onboardingCompleted=false, zero treinos/refeições e endpoints remote-first + IA inicial funcionam")
    void shouldEnforceOnboardingFalseForNewUserAndSupportRemoteFirstEndpoints() throws Exception {
        AuthDto.AuthResponse newUser = registerTestUser("novaconta@forma.app", "Nova Atleta");
        assertThat(newUser.profile().onboardingCompleted()).isFalse();

        // Pull inicial de conta recém-criada deve estar 100% zerado (sem treinos ou rotinas de terceiros)
        mockMvc.perform(get("/api/sync/pull")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + newUser.token()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.profile.onboardingCompleted").value(false))
            .andExpect(jsonPath("$.foods").isEmpty())
            .andExpect(jsonPath("$.workouts").isEmpty())
            .andExpect(jsonPath("$.routines").isEmpty())
            .andExpect(jsonPath("$.waters").isEmpty())
            .andExpect(jsonPath("$.weights").isEmpty());

        // Sugestão inicial de metas via endpoint /api/ai/suggest-initial-goals (com fallback fisiológico)
        mockMvc.perform(post("/api/ai/suggest-initial-goals")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + newUser.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"userName":"Nova Atleta","goal":"Perder peso","currentWeight":78.0,"heightMeters":1.68,"activityLevel":"Moderado (3-4x/semana)"}
                    """))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.daily_calories").isNumber())
            .andExpect(jsonPath("$.protein_grams").isNumber())
            .andExpect(jsonPath("$.carbs_grams").isNumber())
            .andExpect(jsonPath("$.fat_grams").isNumber())
            .andExpect(jsonPath("$.water_milliliters").isNumber())
            .andExpect(jsonPath("$.suggested_target_weight").isNumber())
            .andExpect(jsonPath("$.explanation").isString());

        // Conclusão do onboarding via PUT /api/sync/profile grava direto no banco primeiro
        SyncDto.ProfileWriteRequest onboardingWrite = new SyncDto.ProfileWriteRequest(
            "Nova Atleta",
            "Perder peso",
            1950.0,
            500.0,
            8500.0,
            68.0,
            156.0,
            190.0,
            62.0,
            2900,
            1.68,
            78.0,
            true
        );

        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/api/sync/profile")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + newUser.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(onboardingWrite)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("saved"))
            .andExpect(jsonPath("$.profile.onboardingCompleted").value(true))
            .andExpect(jsonPath("$.profile.currentWeight").value(78.0))
            .andExpect(jsonPath("$.profile.targetWeight").value(68.0));

        // Gravação direta de treino via POST /api/sync/workouts
        UUID directWorkoutId = UUID.randomUUID();
        SyncDto.WorkoutWriteRequest workoutWrite = new SyncDto.WorkoutWriteRequest(
            new SyncDto.WorkoutDto(directWorkoutId, "Funcional Matinal", "Funcional / HIIT", 35, 290.0, "HIIT", Instant.now()),
            null,
            null
        );

        mockMvc.perform(post("/api/sync/workouts")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + newUser.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(workoutWrite)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("saved"))
            .andExpect(jsonPath("$.workout.id").value(directWorkoutId.toString()));

        // Remoção direta via DELETE /api/sync/workouts/{id}
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete("/api/sync/workouts/" + directWorkoutId)
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + newUser.token()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.status").value("deleted"));

        mockMvc.perform(get("/api/sync/pull")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + newUser.token()))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.profile.onboardingCompleted").value(true))
            .andExpect(jsonPath("$.workouts").isEmpty());
    }
}
