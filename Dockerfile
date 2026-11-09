
FROM eclipse-temurin:21-jre

LABEL org.opencontainers.image.title="Desafio DevOps"
LABEL org.opencontainers.image.description="Spring Boot com PostgreSQL"
LABEL org.opencontainers.image.version="0.0.1"

WORKDIR /app

# Usuario e grupo com IDs numericos fixos
RUN groupadd --gid 10001 appgroup \
    && useradd \
       --uid 10001 \
       --gid 10001 \
       --no-create-home \
       --shell /usr/sbin/nologin \
       appuser

COPY --chown=10001:10001 \
    target/desafio-*.jar /app/app.jar

USER 10001:10001

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
