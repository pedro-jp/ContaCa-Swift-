package com.contaca.backend.security;

import com.contaca.backend.entity.User;
import com.contaca.backend.exception.DomainExceptions.*;
import com.contaca.backend.repository.AiRequestLogRepository;
import com.contaca.backend.repository.UserRepository;
import com.contaca.backend.service.AppConfigService;
import com.contaca.backend.service.JwtService;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.UUID;

@Component
public class AuthContextResolver {

    public static final String ADMIN_COOKIE_NAME = "contaca_admin_token";

    private final JwtService jwtService;
    private final UserRepository userRepository;
    private final AppConfigService appConfigService;
    private final AiRequestLogRepository aiRequestLogRepository;
    private final String configuredAdminPassword;
    private final String configuredAdminKey;

    public AuthContextResolver(
        JwtService jwtService,
        UserRepository userRepository,
        AppConfigService appConfigService,
        AiRequestLogRepository aiRequestLogRepository,
        @Value("${app.admin.password:admin123}") String configuredAdminPassword,
        @Value("${app.admin.key:admin123}") String configuredAdminKey
    ) {
        this.jwtService = jwtService;
        this.userRepository = userRepository;
        this.appConfigService = appConfigService;
        this.aiRequestLogRepository = aiRequestLogRepository;
        this.configuredAdminPassword = configuredAdminPassword;
        this.configuredAdminKey = configuredAdminKey;
    }

    public UUID resolveOptionalUserId(String authHeader, String fallbackUserId) {
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7).trim();
            if (!token.isEmpty() && jwtService.validateToken(token)) {
                try {
                    return jwtService.getUserIdFromToken(token);
                } catch (Exception ignored) {
                }
            }
        }
        if (fallbackUserId != null && !fallbackUserId.isBlank()) {
            try {
                return UUID.fromString(fallbackUserId.trim());
            } catch (Exception ignored) {
            }
        }
        return null;
    }

    public User requireActiveUser(String authHeader, String fallbackUserId) {
        UUID userId = resolveOptionalUserId(authHeader, fallbackUserId);
        if (userId == null) {
            throw new UnauthorizedAccessException("Sessão inválida ou não autenticada.");
        }
        return verifyUserAccountActive(userId);
    }

    public UUID validateAiAccess(String authHeader, String fallbackUserId) {
        if (appConfigService.isAiBlocked()) {
            throw new AiBlockedException(
                "As análises de Inteligência Artificial foram temporariamente pausadas no painel administrativo.",
                true
            );
        }

        UUID userId = resolveOptionalUserId(authHeader, fallbackUserId);
        if (userId != null) {
            User user = verifyUserAccountActive(userId);
            if (user.isAiBlocked()) {
                throw new AiBlockedException(
                    "O acesso à Inteligência Artificial está desativado para esta conta.",
                    false
                );
            }
            if (user.getDailyAiLimit() != null && user.getDailyAiLimit() > 0) {
                Instant startOfDay = LocalDate.now().atStartOfDay(ZoneId.systemDefault()).toInstant();
                long usedToday = aiRequestLogRepository.countByUserIdAndCreatedAtAfter(userId, startOfDay);
                if (usedToday >= user.getDailyAiLimit()) {
                    throw new AiQuotaExceededException(
                        "Limite diário de IA atingido (" + usedToday + "/" + user.getDailyAiLimit() + " análises hoje)."
                    );
                }
            }
        }
        return userId;
    }

    public boolean isAdminAuthenticated(HttpServletRequest request, String adminKey, String cookieToken) {
        String effectiveCookie = cookieToken;
        if ((effectiveCookie == null || effectiveCookie.isBlank()) && request != null && request.getCookies() != null) {
            for (Cookie c : request.getCookies()) {
                if (ADMIN_COOKIE_NAME.equals(c.getName())) {
                    effectiveCookie = c.getValue();
                    break;
                }
            }
        }
        if (effectiveCookie != null && jwtService.validateAdminToken(effectiveCookie)) {
            return true;
        }

        if (request != null) {
            String authHeader = request.getHeader(HttpHeaders.AUTHORIZATION);
            if (authHeader != null && authHeader.startsWith("Bearer ")) {
                String token = authHeader.substring(7).trim();
                if (jwtService.validateAdminToken(token)) {
                    return true;
                }
            }
        }

        String headerKey = adminKey;
        if ((headerKey == null || headerKey.isBlank()) && request != null) {
            headerKey = request.getHeader("X-Admin-Key");
        }
        if (headerKey != null && !headerKey.isBlank()) {
            String trimmed = headerKey.trim();
            return trimmed.equals(configuredAdminKey.trim()) || trimmed.equals(configuredAdminPassword.trim());
        }

        return false;
    }

    public void requireAdmin(HttpServletRequest request, String adminKey, String cookieToken) {
        if (!isAdminAuthenticated(request, adminKey, cookieToken)) {
            throw new UnauthorizedAccessException("Acesso administrativo não autorizado. Faça login novamente.");
        }
    }

    private User verifyUserAccountActive(UUID userId) {
        User user = userRepository.findById(userId)
            .orElseThrow(() -> new AccountDeletedException("Conta não encontrada ou removida pelo administrador."));

        if (user.isPaused()) {
            String suffix = (user.getPausedReason() != null && !user.getPausedReason().isBlank())
                ? " Motivo: " + user.getPausedReason().trim()
                : "";
            throw new AccountPausedException("Sua conta está temporariamente pausada pelo administrador." + suffix);
        }
        return user;
    }
}
