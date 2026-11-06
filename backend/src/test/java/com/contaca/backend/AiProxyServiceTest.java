package com.contaca.backend;

import com.contaca.backend.dto.AiDto;
import com.contaca.backend.dto.AuthDto;
import com.contaca.backend.exception.DomainExceptions.AiUpstreamException;
import com.contaca.backend.repository.AiRequestLogRepository;
import com.contaca.backend.service.AppConfigService;
import com.contaca.backend.service.GeminiAiProxyService;
import com.contaca.backend.websocket.AdminEventPublisherService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
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

import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLParameters;
import javax.net.ssl.SSLSession;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.Authenticator;
import java.net.CookieHandler;
import java.net.ProxySelector;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.Executor;
import java.util.concurrent.Flow;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class AiProxyServiceTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private AppConfigService appConfigService;

    @Autowired
    private AiRequestLogRepository aiRequestLogRepository;

    @Autowired
    private AdminEventPublisherService adminEventPublisherService;

    @BeforeEach
    void setupConfig() {
        appConfigService.setAiBlocked(false);
        appConfigService.setGeminiApiKey("AIzaSyTestKeyForAutomatedIntegrationSuite123");
        appConfigService.setGeminiModel("gemini-3.1-flash-lite");
    }

    @Test
    @DisplayName("Kill-switch global de IA retorna HTTP 503 com flag blocked: true")
    void shouldBlockAiRequestsWhenGlobalKillSwitchIsEnabled() throws Exception {
        MvcResult reg = mockMvc.perform(post("/api/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new AuthDto.RegisterRequest("aiuser@forma.app", "Senha1234", "João"))))
            .andExpect(status().isOk())
            .andReturn();
        AuthDto.AuthResponse auth = objectMapper.readValue(reg.getResponse().getContentAsString(), AuthDto.AuthResponse.class);

        appConfigService.setAiBlocked(true);

        mockMvc.perform(post("/api/ai/analyze-meal")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + auth.token())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new AiDto.MealAiRequest("200g de arroz e 150g de frango", "João", null, null))))
            .andExpect(status().isServiceUnavailable())
            .andExpect(jsonPath("$.blocked").value(true));
    }

    @Test
    @DisplayName("Formatação multimodal Base64 remove prefixo data URI e faz failover automático Gemini 3.1 Flash-Lite (503) -> Gemini 3.6 Flash (200)")
    void shouldFormatMultimodalImagePayloadAndFailoverOnHttp503() throws Exception {
        String validGeminiCandidate = """
            {
              "candidates": [
                {
                  "content": {
                    "parts": [
                      {
                        "text": "{\\"meal_type\\":\\"Almoço\\",\\"items\\":[{\\"name\\":\\"Peito de Frango Grelhado\\",\\"portion_value\\":160.0,\\"unit\\":\\"g\\",\\"is_liquid\\":false,\\"calories\\":254.4,\\"protein\\":51.2,\\"carbohydrates\\":0.0,\\"fat\\":4.0}],\\"total_calories\\":254.4,\\"total_protein\\":51.2,\\"total_carbs\\":0.0,\\"total_fat\\":4.0,\\"ai_summary\\":\\"Prato proteico identificado com sucesso.\\"}"
                      }
                    ]
                  }
                }
              ]
            }
            """;

        StubHttpClient stubHttpClient = new StubHttpClient(List.of(
            new StubResponseSpec(503, "{\"error\":{\"code\":503,\"message\":\"High demand\",\"status\":\"UNAVAILABLE\"}}"),
            new StubResponseSpec(200, validGeminiCandidate)
        ));

        GeminiAiProxyService service = new GeminiAiProxyService(
            appConfigService,
            aiRequestLogRepository,
            adminEventPublisherService,
            stubHttpClient
        );

        UUID userId = UUID.randomUUID();
        AiDto.MealAiRequest mealReq = new AiDto.MealAiRequest(
            "Prato pós-treino",
            "João Pedro",
            "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAAAQABAAD==",
            "image/jpeg"
        );

        String jsonResult = service.analyzeMeal(userId, mealReq);
        JsonNode parsedResult = objectMapper.readTree(jsonResult);
        assertThat(parsedResult.path("meal_type").asText()).isEqualTo("Almoço");
        assertThat(parsedResult.path("items").get(0).path("name").asText()).isEqualTo("Peito de Frango Grelhado");

        List<HttpRequest> sentRequests = stubHttpClient.capturedRequests();
        assertThat(sentRequests).hasSize(2);
        assertThat(sentRequests.get(0).uri().toString()).contains("models/gemini-3.1-flash-lite:generateContent");
        assertThat(sentRequests.get(1).uri().toString()).contains("models/gemini-3.6-flash:generateContent");

        String sentBody = extractRequestBody(sentRequests.get(0));
        JsonNode payloadRoot = objectMapper.readTree(sentBody);
        JsonNode inlineData = payloadRoot.path("contents").get(0).path("parts").get(0).path("inlineData");
        assertThat(inlineData.path("mimeType").asText()).isEqualTo("image/jpeg");
        assertThat(inlineData.path("data").asText()).isEqualTo("/9j/4AAQSkZJRgABAQAAAQABAAD==");
        assertThat(payloadRoot.path("generationConfig").path("responseMimeType").asText()).isEqualTo("application/json");
    }

    @Test
    @DisplayName("Quando todos os modelos falham com HTTP 503, AiUpstreamException oculta JSON técnico bruto e entrega mensagem amigável")
    void shouldSanitizeUpstreamFailureIntoFriendlyPortugueseMessage() {
        StubHttpClient stubHttpClient = new StubHttpClient(List.of(
            new StubResponseSpec(503, "{\"error\":{\"code\":503,\"status\":\"UNAVAILABLE\"}}")
        ));

        GeminiAiProxyService service = new GeminiAiProxyService(
            appConfigService,
            aiRequestLogRepository,
            adminEventPublisherService,
            stubHttpClient
        );

        AiDto.EvolutionAiRequest evoReq = new AiDto.EvolutionAiRequest(
            "Ganhar peso", 72.0, 80.0, 1.78, 2900.0, 600.0, 8000.0,
            1740.0, 2500.0, 2900.0, 160.0, 390.0, 75.0, 2600, 400.0, "[]", "João"
        );

        assertThatThrownBy(() -> service.analyzeEvolution(UUID.randomUUID(), evoReq))
            .isInstanceOf(AiUpstreamException.class)
            .hasMessageContaining("A análise inteligente de evolução está temporariamente ocupada")
            .hasMessageNotContaining("UNAVAILABLE")
            .hasMessageNotContaining("\"error\"");
    }

    private static String extractRequestBody(HttpRequest request) {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        request.bodyPublisher().orElseThrow().subscribe(new Flow.Subscriber<>() {
            @Override
            public void onSubscribe(Flow.Subscription subscription) {
                subscription.request(Long.MAX_VALUE);
            }

            @Override
            public void onNext(ByteBuffer item) {
                byte[] bytes = new byte[item.remaining()];
                item.get(bytes);
                baos.write(bytes, 0, bytes.length);
            }

            @Override
            public void onError(Throwable throwable) {}

            @Override
            public void onComplete() {}
        });
        return baos.toString(StandardCharsets.UTF_8);
    }

    private record StubResponseSpec(int statusCode, String body) {}

    private static final class StubHttpClient extends HttpClient {
        private final Deque<StubResponseSpec> responses;
        private final StubResponseSpec fallbackResponse;
        private final List<HttpRequest> capturedRequests = new ArrayList<>();

        StubHttpClient(List<StubResponseSpec> scriptedResponses) {
            this.responses = new ArrayDeque<>(scriptedResponses);
            this.fallbackResponse = scriptedResponses.getLast();
        }

        List<HttpRequest> capturedRequests() {
            return capturedRequests;
        }

        @Override
        @SuppressWarnings("unchecked")
        public <T> HttpResponse<T> send(HttpRequest request, HttpResponse.BodyHandler<T> responseBodyHandler) throws IOException {
            capturedRequests.add(request);
            StubResponseSpec next = responses.isEmpty() ? fallbackResponse : responses.pollFirst();
            return (HttpResponse<T>) new StubHttpResponse(request, next.statusCode(), next.body());
        }

        @Override
        public <T> CompletableFuture<HttpResponse<T>> sendAsync(HttpRequest request, HttpResponse.BodyHandler<T> responseBodyHandler) {
            throw new UnsupportedOperationException();
        }

        @Override
        public <T> CompletableFuture<HttpResponse<T>> sendAsync(HttpRequest request, HttpResponse.BodyHandler<T> responseBodyHandler, HttpResponse.PushPromiseHandler<T> pushPromiseHandler) {
            throw new UnsupportedOperationException();
        }

        @Override public Optional<CookieHandler> cookieHandler() { return Optional.empty(); }
        @Override public Optional<Duration> connectTimeout() { return Optional.of(Duration.ofSeconds(5)); }
        @Override public Redirect followRedirects() { return Redirect.NEVER; }
        @Override public Optional<ProxySelector> proxy() { return Optional.empty(); }
        @Override public SSLContext sslContext() { return null; }
        @Override public SSLParameters sslParameters() { return new SSLParameters(); }
        @Override public Optional<Authenticator> authenticator() { return Optional.empty(); }
        @Override public Version version() { return Version.HTTP_1_1; }
        @Override public Optional<Executor> executor() { return Optional.empty(); }
    }

    private record StubHttpResponse(HttpRequest request, int statusCode, String body) implements HttpResponse<String> {
        @Override public Optional<HttpResponse<String>> previousResponse() { return Optional.empty(); }
        @Override public java.net.http.HttpHeaders headers() { return java.net.http.HttpHeaders.of(Map.of(), (a, b) -> true); }
        @Override public Optional<SSLSession> sslSession() { return Optional.empty(); }
        @Override public URI uri() { return request.uri(); }
        @Override public HttpClient.Version version() { return HttpClient.Version.HTTP_1_1; }
    }
}
