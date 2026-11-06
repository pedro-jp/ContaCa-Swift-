package com.forma.backend;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

import java.io.File;
import java.net.URI;
import java.nio.file.Files;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Properties;
import java.util.Set;

@SpringBootApplication
@EnableScheduling
public class FormaBackendApplication {

    private static final Logger log = LoggerFactory.getLogger(FormaBackendApplication.class);

    public static void main(String[] args) {
        loadDotEnv();
        resolveSupabaseJdbcConnection();
        SpringApplication.run(FormaBackendApplication.class, args);
    }

    private static void loadDotEnv() {
        File[] candidates = {
            new File(".env"),
            new File("../.env"),
            new File("backend/.env"),
            new File("/etc/secrets/.env")
        };
        for (File f : candidates) {
            if (f.exists() && f.isFile()) {
                try {
                    List<String> lines = Files.readAllLines(f.toPath());
                    for (String line : lines) {
                        String trimmed = line.trim();
                        if (trimmed.isEmpty() || trimmed.startsWith("#")) continue;
                        int idx = trimmed.indexOf('=');
                        if (idx > 0) {
                            String key = trimmed.substring(0, idx).trim();
                            String value = trimmed.substring(idx + 1).trim();
                            if ((value.startsWith("\"") && value.endsWith("\"")) ||
                                (value.startsWith("'") && value.endsWith("'"))) {
                                value = value.substring(1, value.length() - 1);
                            }
                            if (System.getProperty(key) == null && System.getenv(key) == null) {
                                System.setProperty(key, value);
                            }
                        }
                    }
                    log.info("[Config] Variáveis de ambiente carregadas de: {}", f.getAbsolutePath());
                    return;
                } catch (Exception e) {
                    log.warn("[Config] Falha ao ler .env: {}", e.getMessage());
                }
            }
        }
    }

    private static String getEnvOrProperty(String key) {
        String env = System.getenv(key);
        if (env != null && !env.isBlank()) return env.trim();
        String prop = System.getProperty(key);
        if (prop != null && !prop.isBlank()) return prop.trim();
        return null;
    }

    private static String extractProjectRef(String supabaseUrl) {
        if (supabaseUrl == null || supabaseUrl.isBlank()) return null;
        try {
            URI uri = URI.create(supabaseUrl.trim());
            String host = uri.getHost();
            if (host != null && host.endsWith(".supabase.co")) {
                return host.substring(0, host.length() - ".supabase.co".length());
            }
        } catch (Exception ignored) {
        }
        return null;
    }

    private record JdbcCandidate(String url, String user, String label) {}

    /**
     * Valida e resolve automaticamente a região/host PostgreSQL do Supabase a partir de
     * SUPABASE_URL + SUPABASE_DB_PASSWORD (e SUPABASE_DB_URL se definido). Caso a senha
     * ou rede falhem, faz fallback seguro para o banco H2 local sem derrubar o servidor.
     */
    private static void resolveSupabaseJdbcConnection() {
        String dbPassword = getEnvOrProperty("SUPABASE_DB_PASSWORD");
        String configuredUrl = getEnvOrProperty("SUPABASE_DB_URL");
        String configuredUser = getEnvOrProperty("SUPABASE_DB_USER");
        String supabaseUrl = getEnvOrProperty("SUPABASE_URL");
        String projectRef = extractProjectRef(supabaseUrl);

        if ((dbPassword == null || dbPassword.isBlank()) && configuredUrl != null && configuredUrl.contains("password=")) {
            for (String param : configuredUrl.substring(configuredUrl.indexOf('?') + 1).split("&")) {
                if (param.startsWith("password=")) {
                    dbPassword = param.substring("password=".length());
                } else if (param.startsWith("user=") && (configuredUser == null || configuredUser.isBlank())) {
                    configuredUser = param.substring("user=".length());
                }
            }
        }

        if (dbPassword == null || dbPassword.isBlank()) {
            log.info("[Database] SUPABASE_DB_PASSWORD não configurado. Usando banco local H2 (./forma_local_db).");
            activateH2Fallback();
            return;
        }

        try {
            Class.forName("org.postgresql.Driver");
        } catch (ClassNotFoundException e) {
            log.warn("[Database] Driver PostgreSQL não encontrado: {}", e.getMessage());
            return;
        }

        List<JdbcCandidate> candidates = new ArrayList<>();
        Set<String> seenUrls = new LinkedHashSet<>();

        if (configuredUrl != null && configuredUrl.startsWith("jdbc:postgresql:")) {
            String normalizedUrl = configuredUrl.contains("prepareThreshold=")
                ? configuredUrl
                : configuredUrl + (configuredUrl.contains("?") ? "&" : "?") + "prepareThreshold=0";
            String user = (configuredUser != null && !configuredUser.isBlank())
                ? configuredUser
                : (projectRef != null ? "postgres." + projectRef : "postgres");
            candidates.add(new JdbcCandidate(normalizedUrl, user, "configurado no .env"));
            seenUrls.add(normalizedUrl + "|" + user);
        }

        if (projectRef != null && !projectRef.isBlank()) {
            String directUrl = "jdbc:postgresql://db." + projectRef + ".supabase.co:5432/postgres?sslmode=require&prepareThreshold=0";
            if (seenUrls.add(directUrl + "|postgres")) {
                candidates.add(new JdbcCandidate(directUrl, "postgres", "Host direto db." + projectRef));
            }

            String poolerUser = "postgres." + projectRef;
            String[] poolerRegions = {
                "aws-0-sa-east-1",
                "aws-1-sa-east-1",
                "aws-0-us-east-1",
                "aws-1-us-east-1",
                "aws-0-us-east-2",
                "aws-1-us-east-2",
                "aws-0-us-west-1",
                "aws-0-us-west-2",
                "aws-0-eu-central-1",
                "aws-0-eu-west-1",
                "aws-0-eu-west-2"
            };
            for (String region : poolerRegions) {
                String url = "jdbc:postgresql://" + region + ".pooler.supabase.com:5432/postgres?sslmode=require&prepareThreshold=0";
                String key = url + "|" + poolerUser;
                if (seenUrls.add(key)) {
                    candidates.add(new JdbcCandidate(url, poolerUser, "Pooler " + region));
                }
            }
        }

        String lastError = null;
        for (JdbcCandidate candidate : candidates) {
            Properties props = new Properties();
            props.setProperty("user", candidate.user());
            props.setProperty("password", dbPassword);
            props.setProperty("connectTimeout", "4");
            props.setProperty("loginTimeout", "4");
            props.setProperty("socketTimeout", "8");

            try (Connection conn = DriverManager.getConnection(candidate.url(), props)) {
                System.setProperty("SUPABASE_DB_DRIVER", "org.postgresql.Driver");
                System.setProperty("SUPABASE_DB_URL", candidate.url());
                System.setProperty("SUPABASE_DB_USER", candidate.user());
                System.setProperty("SUPABASE_DB_PASSWORD", dbPassword);
                log.info("[Supabase] Conectado com sucesso ao PostgreSQL do Supabase ({})!", candidate.label());
                return;
            } catch (SQLException ex) {
                String msg = ex.getMessage() != null ? ex.getMessage() : ex.toString();
                lastError = msg;
                if ("28P01".equals(ex.getSQLState())
                    || msg.toLowerCase().contains("password authentication failed")
                    || msg.toLowerCase().contains("circuit breaker")) {
                    log.error(
                        "[Supabase] Região encontrada ({}), mas SUPABASE_DB_PASSWORD foi recusada pelo PostgreSQL ({}). " +
                        "Confira a senha do banco em Supabase -> Project Settings -> Database. Usando H2 local temporariamente.",
                        candidate.label(),
                        msg
                    );
                    activateH2Fallback();
                    return;
                }
            }
        }

        log.error(
            "[Supabase] Não foi possível conectar ao PostgreSQL do Supabase (último erro: {}). " +
            "Usando H2 local temporariamente para manter o servidor e o /admin ativos.",
            lastError
        );
        activateH2Fallback();
    }

    private static void activateH2Fallback() {
        System.setProperty("SUPABASE_DB_DRIVER", "org.h2.Driver");
        System.setProperty("SUPABASE_DB_URL", "jdbc:h2:file:./forma_local_db;DB_CLOSE_DELAY=-1");
        System.setProperty("SUPABASE_DB_USER", "sa");
        System.setProperty("SUPABASE_DB_PASSWORD", "");
    }
}
