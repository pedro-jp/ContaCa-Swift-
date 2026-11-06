package com.forma.backend;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

import java.io.File;
import java.nio.file.Files;
import java.util.List;

@SpringBootApplication
@EnableScheduling
public class FormaBackendApplication {

    private static final Logger log = LoggerFactory.getLogger(FormaBackendApplication.class);

    public static void main(String[] args) {
        loadDotEnv();
        SpringApplication.run(FormaBackendApplication.class, args);
    }

    private static void loadDotEnv() {
        File[] candidates = { new File(".env"), new File("../.env"), new File("backend/.env") };
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
}
