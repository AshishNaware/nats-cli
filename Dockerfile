# Multi-stage build for NATS server with credentials
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make

# Clone and build NATS server
WORKDIR /go/src/github.com/nats-io
RUN git clone https://github.com/nats-io/nats-server.git && \
    cd nats-server && \
    git checkout v2.10.7 && \
    go build -o nats-server

# Final stage
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata

# Create nats user and group
RUN addgroup -g 1000 nats && \
    adduser -D -s /bin/sh -u 1000 -G nats nats

# Create necessary directories
RUN mkdir -p /etc/nats /var/lib/nats /var/log/nats && \
    chown -R nats:nats /etc/nats /var/lib/nats /var/log/nats

# Copy NATS server binary from builder
COPY --from=builder /go/src/github.com/nats-io/nats-server/nats-server /usr/local/bin/

# Copy default configuration
COPY --chown=nats:nats nats-server.conf /etc/nats/nats-server.conf

# Create credentials directory
RUN mkdir -p /etc/nats/creds && \
    chown -R nats:nats /etc/nats/creds && \
    chmod 700 /etc/nats/creds

# Switch to nats user
USER nats

# Expose NATS ports
EXPOSE 4222 8222

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8222/healthz || exit 1

# Default command
CMD ["nats-server", "-c", "/etc/nats/nats-server.conf"]
