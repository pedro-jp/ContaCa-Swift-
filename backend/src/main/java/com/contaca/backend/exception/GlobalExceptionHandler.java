package com.contaca.backend.exception;

import com.contaca.backend.exception.DomainExceptions.*;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(UnauthorizedAccessException.class)
    public ResponseEntity<Map<String, Object>> handleUnauthorized(UnauthorizedAccessException ex) {
        return buildResponse(HttpStatus.UNAUTHORIZED, ex.getMessage(), Map.of("authenticated", false));
    }

    @ExceptionHandler(InvalidCredentialsException.class)
    public ResponseEntity<Map<String, Object>> handleInvalidCredentials(InvalidCredentialsException ex) {
        return buildResponse(HttpStatus.UNAUTHORIZED, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(AccountDeletedException.class)
    public ResponseEntity<Map<String, Object>> handleAccountDeleted(AccountDeletedException ex) {
        return buildResponse(HttpStatus.UNAUTHORIZED, ex.getMessage(), Map.of("accountDeleted", true));
    }

    @ExceptionHandler(AccountPausedException.class)
    public ResponseEntity<Map<String, Object>> handleAccountPaused(AccountPausedException ex) {
        return buildResponse(HttpStatus.FORBIDDEN, ex.getMessage(), Map.of("accountPaused", true));
    }

    @ExceptionHandler(AiBlockedException.class)
    public ResponseEntity<Map<String, Object>> handleAiBlocked(AiBlockedException ex) {
        if (ex.isGlobalBlock()) {
            return buildResponse(HttpStatus.SERVICE_UNAVAILABLE, ex.getMessage(), Map.of("blocked", true));
        }
        return buildResponse(HttpStatus.FORBIDDEN, ex.getMessage(), Map.of("aiBlockedForUser", true));
    }

    @ExceptionHandler(AiQuotaExceededException.class)
    public ResponseEntity<Map<String, Object>> handleAiQuotaExceeded(AiQuotaExceededException ex) {
        return buildResponse(HttpStatus.TOO_MANY_REQUESTS, ex.getMessage(), Map.of("quotaExceeded", true));
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<Map<String, Object>> handleNotFound(ResourceNotFoundException ex) {
        return buildResponse(HttpStatus.NOT_FOUND, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(AiUpstreamException.class)
    public ResponseEntity<Map<String, Object>> handleAiUpstream(AiUpstreamException ex) {
        return buildResponse(HttpStatus.BAD_GATEWAY, ex.getMessage(), Map.of("aiTemporaryError", true));
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> handleBadRequest(IllegalArgumentException ex) {
        return buildResponse(HttpStatus.BAD_REQUEST, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(IllegalStateException.class)
    public ResponseEntity<Map<String, Object>> handleIllegalState(IllegalStateException ex) {
        return buildResponse(HttpStatus.CONFLICT, ex.getMessage(), Map.of());
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleUnexpected(Exception ex) {
        String message = ex.getMessage() != null && !ex.getMessage().isBlank()
            ? ex.getMessage()
            : "Erro interno inesperado no servidor Forma.";
        return buildResponse(HttpStatus.INTERNAL_SERVER_ERROR, message, Map.of());
    }

    private ResponseEntity<Map<String, Object>> buildResponse(
        HttpStatus status,
        String errorMessage,
        Map<String, Object> extraFields
    ) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("error", errorMessage);
        body.put("message", errorMessage);
        body.putAll(extraFields);
        body.put("timestamp", Instant.now().toString());
        return ResponseEntity.status(status).body(body);
    }
}
