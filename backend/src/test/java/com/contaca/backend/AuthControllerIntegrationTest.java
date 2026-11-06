package com.contaca.backend;

import com.contaca.backend.dto.AdminDto;
import com.contaca.backend.dto.AuthDto;
import com.contaca.backend.service.AdminUserService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class AuthControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private AdminUserService adminUserService;

    @Test
    @DisplayName("GET /api/auth/config retorna googleClientId público")
    void shouldReturnPublicAuthConfig() throws Exception {
        mockMvc.perform(get("/api/auth/config"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.googleClientId").value("test-google-client-id.apps.googleusercontent.com"));
    }

    @Test
    @DisplayName("POST /api/auth/register cria usuário, normaliza e-mail, gera JWT e bloqueia duplicidade")
    void shouldRegisterUserAndRejectDuplicateEmail() throws Exception {
        AuthDto.RegisterRequest registerReq = new AuthDto.RegisterRequest(
            "  Joao.Atleta@Forma.App  ",
            "SenhaForte123",
            "João Pedro"
        );

        MvcResult result = mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(registerReq)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.token").isNotEmpty())
            .andExpect(jsonPath("$.email").value("joao.atleta@forma.app"))
            .andExpect(jsonPath("$.name").value("João Pedro"))
            .andExpect(jsonPath("$.authProvider").value("EMAIL"))
            .andExpect(jsonPath("$.profile.targetCalorieIntake").value(2800.0))
            .andReturn();

        JsonNode body = objectMapper.readTree(result.getResponse().getContentAsString());
        assertThat(body.path("userId").asText()).isNotBlank();

        // Tentativa de recadastro com o mesmo e-mail deve retornar 400 Bad Request
        mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(registerReq)))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.error").value("E-mail já cadastrado."));
    }

    @Test
    @DisplayName("POST /api/auth/login valida credenciais, retorna 401 para senha errada e 403 para conta pausada")
    void shouldAuthenticateRejectWrongPasswordAndBlockPausedAccount() throws Exception {
        AuthDto.RegisterRequest registerReq = new AuthDto.RegisterRequest(
            "login@forma.app",
            "MinhaSenha2026",
            "Atleta Forma"
        );

        MvcResult regResult = mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(registerReq)))
            .andExpect(status().isOk())
            .andReturn();

        UUID userId = UUID.fromString(
            objectMapper.readTree(regResult.getResponse().getContentAsString()).path("userId").asText()
        );

        // 1. Login válido -> 200 OK
        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new AuthDto.LoginRequest("LOGIN@forma.app", "MinhaSenha2026"))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.token").isNotEmpty())
            .andExpect(jsonPath("$.userId").value(userId.toString()));

        // 2. Senha incorreta -> 401 Unauthorized
        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new AuthDto.LoginRequest("login@forma.app", "SenhaIncorreta"))))
            .andExpect(status().isUnauthorized())
            .andExpect(jsonPath("$.error").value("Usuário ou senha incorretos."));

        // 3. Conta pausada pelo admin -> 403 Forbidden com accountPaused: true
        adminUserService.updateStatus(userId, new AdminDto.UserStatusRequest(true, "Revisão cadastral"));

        mockMvc.perform(post("/api/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new AuthDto.LoginRequest("login@forma.app", "MinhaSenha2026"))))
            .andExpect(status().isForbidden())
            .andExpect(jsonPath("$.accountPaused").value(true));
    }

    @Test
    @DisplayName("POST /api/auth/social autentica Sign in with Apple / Google e reaproveita conta existente")
    void shouldAuthenticateSocialLoginAndReuseExistingUser() throws Exception {
        AuthDto.SocialLoginRequest appleReq = new AuthDto.SocialLoginRequest(
            "APPLE",
            "apple_identity_token_dev_sim",
            "apple.user@privaterelay.appleid.com",
            "Ana Clara",
            "apple_sub_001",
            "nonce_123"
        );

        MvcResult firstLogin = mockMvc.perform(post("/api/auth/social")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(appleReq)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.authProvider").value("APPLE"))
            .andExpect(jsonPath("$.name").value("Ana Clara"))
            .andReturn();

        String firstUserId = objectMapper.readTree(firstLogin.getResponse().getContentAsString())
            .path("userId").asText();

        // Novo login social com o mesmo e-mail deve manter o mesmo userId
        MvcResult secondLogin = mockMvc.perform(post("/api/auth/social")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(appleReq)))
            .andExpect(status().isOk())
            .andReturn();

        String secondUserId = objectMapper.readTree(secondLogin.getResponse().getContentAsString())
            .path("userId").asText();

        assertThat(secondUserId).isEqualTo(firstUserId);
    }
}
