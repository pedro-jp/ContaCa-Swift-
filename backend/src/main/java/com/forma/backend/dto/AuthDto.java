package com.forma.backend.dto;

import java.util.UUID;

public class AuthDto {

    public record LoginRequest(String email, String password) {}

    public record RegisterRequest(String email, String password, String name) {}

    public record ForgotPasswordRequest(String email) {}

    public record ResetPasswordRequest(String email, String code, String newPassword) {}

    public record ChangePasswordRequest(String currentPassword, String newPassword) {}

    public record SocialLoginRequest(
        String provider,       // GOOGLE ou APPLE
        String idToken,
        String email,
        String name,
        String providerId,
        String nonce           // Nonce original para prevenção de replay attacks no Sign in with Apple
    ) {
        public SocialLoginRequest(String provider, String idToken, String email, String name, String providerId) {
            this(provider, idToken, email, name, providerId, null);
        }
    }

    public record AuthResponse(
        String token,
        UUID userId,
        String email,
        String name,
        String authProvider,
        SyncDto.ProfileDto profile
    ) {}
}
