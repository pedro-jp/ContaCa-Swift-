package com.forma.backend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

/**
 * Mantém a instância gratuita do Render ativa disparando requisições periódicas
 * pela URL pública (RENDER_EXTERNAL_URL) antes da janela de 15 minutos de ociosidade.
 */
@Service
public class RenderKeepAliveService {

    private static final Logger log = LoggerFactory.getLogger(RenderKeepAliveService.class);

    private final boolean enabled;
    private final String publicUrl;
    private final HttpClient httpClient;

    public RenderKeepAliveService(
        @Value("${app.keepalive.enabled:true}") boolean enabled,
        @Value("${app.keepalive.public-url:}") String publicUrl
    ) {
        this.enabled = enabled;
        this.publicUrl = publicUrl != null ? publicUrl.trim() : "";
        this.httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .followRedirects(HttpClient.Redirect.NORMAL)
            .build();
    }

    @Scheduled(
        fixedDelayString = "${app.keepalive.interval-ms:600000}",
        initialDelayString = "120000"
    )
    public void pingSelfExternally() {
        if (!enabled || publicUrl.isEmpty()) {
            return;
        }

        String base = publicUrl.endsWith("/") ? publicUrl.substring(0, publicUrl.length() - 1) : publicUrl;
        String targetUrl = base + "/api/ping";

        try {
            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(targetUrl))
                .timeout(Duration.ofSeconds(10))
                .header("User-Agent", "Forma-KeepAlive/1.0")
                .GET()
                .build();

            HttpResponse<Void> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
            log.debug("[KeepAlive] Ping externo concluído ({}) -> HTTP {}", targetUrl, response.statusCode());
        } catch (Exception e) {
            log.warn("[KeepAlive] Falha no ping externo ({}): {}", targetUrl, e.getMessage());
        }
    }
}
