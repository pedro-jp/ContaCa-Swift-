# ==============================================================================
# Stage 1: Build do artefato Spring Boot (Java 21 + Maven)
# ==============================================================================
FROM maven:3.9.9-eclipse-temurin-21-alpine AS build
WORKDIR /workspace

# Faz cache das dependências antes de copiar o código-fonte
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Compila o JAR executável
COPY src ./src
RUN mvn clean package -DskipTests -B

# ==============================================================================
# Stage 2: Runtime enxuto otimizado para Render Free Tier (512 MB RAM)
# ==============================================================================
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Executa como usuário sem privilégios de root
RUN addgroup -S forma && adduser -S forma -G forma

COPY --from=build /workspace/target/forma-backend-*.jar /app/app.jar
RUN chown -R forma:forma /app

USER forma

# Ajusta heap e GC para caber com folga nos 512 MB de RAM do Render Free Tier
ENV PORT=8085
ENV JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=70.0 -XX:+UseSerialGC -XX:TieredStopAtLevel=1 -Djava.security.egd=file:/dev/./urandom"

EXPOSE 8085

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD wget -q --spider http://127.0.0.1:${PORT}/api/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
