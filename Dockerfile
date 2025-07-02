# Multi-stage build for Keycloak from source
FROM registry.access.redhat.com/ubi8/openjdk-17:1.17 AS builder

# Set working directory
WORKDIR /opt/keycloak

# Copy source code
COPY . .

# Install Maven if not available
USER root
RUN microdnf install -y maven

# Switch back to jboss user
USER 185

# Build Keycloak
RUN mvn clean install -DskipTests -Pdistribution

# Extract the built distribution
RUN tar -xzf distribution/server-dist/target/keycloak-*.tar.gz --strip-components=1

# Runtime stage
FROM registry.access.redhat.com/ubi8/openjdk-17-runtime:1.17

# Environment variables
ENV KEYCLOAK_ADMIN=admin \
    KEYCLOAK_ADMIN_PASSWORD=admin \
    KC_HTTP_RELATIVE_PATH="/auth" \
    KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true \
    KC_FEATURES=token-exchange \
    KC_RUN_IN_CONTAINER=true

# Copy built Keycloak from builder stage
COPY --from=builder --chown=185 /opt/keycloak /opt/keycloak

# Create necessary directories and set permissions
USER root
RUN mkdir -p /opt/keycloak/data && \
    mkdir -p /opt/keycloak/conf && \
    chown -R 185:0 /opt/keycloak && \
    chmod -R g+rwX /opt/keycloak

# Switch to non-root user
USER 185

# Set working directory
WORKDIR /opt/keycloak

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/auth/health/ready || exit 1

# Expose ports
EXPOSE 8080 8443

# Set entrypoint
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"] 