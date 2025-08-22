# Use official NATS server image as base
FROM nats:2.10.7-alpine

# Install wget for health checks
RUN apk update && apk add --no-cache wget || echo "Warning: Could not install wget"

# Copy custom configuration
COPY nats-server.conf /etc/nats/nats-server.conf

# Create necessary directories with proper permissions
RUN mkdir -p /etc/nats/creds /etc/nats/certs /etc/nats/jwt && \
    chmod 700 /etc/nats/creds /etc/nats/certs /etc/nats/jwt

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8222/healthz || exit 1

# Default command
CMD ["nats-server", "-c", "/etc/nats/nats-server.conf"]
