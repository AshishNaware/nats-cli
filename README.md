# NATS Server Docker Image with Credentials

This repository contains a Dockerfile to build a secure NATS server image with support for various authentication methods including credentials.

## Features

- Multi-stage build for smaller image size
- Support for multiple authentication methods:
  - Username/Password
  - Token-based authentication
  - NKey-based authentication
  - JWT-based authentication
- TLS support for production use
- JetStream enabled
- Health checks
- Non-root user for security
- Comprehensive logging

## Quick Start

### Using Makefile (Recommended)

The project includes a comprehensive Makefile for easy automation:

```bash
# Show all available commands
make help

# Quick start (build and run)
make quick-start

# Development setup
make dev-setup

# Production setup
make prod-setup

# Stop and clean
make quick-stop

# Publish to GitHub Container Registry
make quick-release
```

### Manual Build and Run

#### Build the Image

```bash
docker build -t nats-server:latest .
```

#### Run with Basic Configuration

```bash
docker run -d \
  --name nats-server \
  -p 4222:4222 \
  -p 8222:8222 \
  nats-server:latest
```

## Authentication Methods

### 1. Username/Password Authentication

Edit `nats-server.conf` and uncomment the username/password section:

```yaml
authorization {
    user: "admin"
    password: "your-secure-password"
    timeout: 2.0
}
```

### 2. Token-based Authentication

Edit `nats-server.conf` and uncomment the token section:

```yaml
authorization {
    token: "your-secret-token"
    timeout: 2.0
}
```

### 3. NKey-based Authentication (Recommended for Production)

First, generate NKeys using the NATS CLI:

```bash
# Install NATS CLI
go install github.com/nats-io/natscli/nats@latest

# Generate operator key
nats operator generate

# Generate account key
nats account generate

# Generate user key
nats user generate
```

Then edit `nats-server.conf` and uncomment the NKey section:

```yaml
authorization {
    users = [
        {
            nkey: "UCNGL4W5QX66CFQ5FABXWFJTQYYA7XK3N6VK7K3N6VK7K3N6VK7"
        }
    ]
}
```

### 4. JWT-based Authentication

For JWT authentication, you'll need to set up a resolver. Edit `nats-server.conf`:

```yaml
resolver {
    type: full
    dir: "/etc/nats/jwt"
}
```

## Running with Credentials

### Using Docker Volumes

```bash
# Create a directory for your credentials
mkdir -p ~/nats-creds

# Copy your credentials file
cp your-credentials.conf ~/nats-creds/

# Run with mounted credentials
docker run -d \
  --name nats-server \
  -p 4222:4222 \
  -p 8222:8222 \
  -v ~/nats-creds:/etc/nats/creds:ro \
  nats-server:latest
```

### Using Docker Secrets (for Swarm)

```bash
# Create a secret
echo "your-secret-token" | docker secret create nats-token -

# Run with secret
docker service create \
  --name nats-server \
  --secret nats-token \
  -p 4222:4222 \
  -p 8222:8222 \
  nats-server:latest
```

## TLS Configuration

For production use, enable TLS by uncommenting the TLS section in `nats-server.conf`:

```yaml
tls {
    cert_file: "/etc/nats/certs/server-cert.pem"
    key_file: "/etc/nats/certs/server-key.pem"
    ca_file: "/etc/nats/certs/ca.pem"
    verify: true
}
```

Then mount your certificates:

```bash
docker run -d \
  --name nats-server \
  -p 4222:4222 \
  -p 8222:8222 \
  -v ~/certs:/etc/nats/certs:ro \
  nats-server:latest
```

## Clustering

To run NATS in a cluster, uncomment the cluster configuration in `nats-server.conf` and run multiple instances:

```bash
# Node 1
docker run -d \
  --name nats-server-1 \
  -p 4222:4222 \
  -p 8222:8222 \
  -p 6222:6222 \
  nats-server:latest

# Node 2
docker run -d \
  --name nats-server-2 \
  -p 4223:4222 \
  -p 8223:8222 \
  -p 6223:6222 \
  nats-server:latest
```

## Monitoring

The NATS server exposes monitoring endpoints on port 8222:

- Health check: `http://localhost:8222/healthz`
- Metrics: `http://localhost:8222/metrics`
- Server info: `http://localhost:8222/varz`

### Production Monitoring Stack

For production deployments, the stack includes:

- **Prometheus**: Metrics collection on port 9090
- **Grafana**: Visualization dashboard on port 3000 (admin/admin)
- **NATS Exporter**: Enhanced metrics on port 7777

Start the full monitoring stack:

```bash
make deploy-prod
```

Access dashboards:
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- NATS Exporter: http://localhost:7777

## Publishing to GitHub Container Registry

### Prerequisites

1. **GitHub Token**: Create a Personal Access Token with `write:packages` permission
2. **Repository**: Ensure your repository is public or you have package write permissions
3. **Username**: Your GitHub username will be automatically converted to lowercase for Docker compatibility

### Setup

```bash
# Set your GitHub token
export GITHUB_TOKEN=your_github_token_here

# Login to GitHub Container Registry
make login-ghcr
```

### Publishing Commands

```bash
# Build and push to ghcr.io
make push

# Build and push with latest tag
make push-latest

# Complete release (build + push + latest)
make release

# Release development version
make release-dev

# Release production version
make release-prod

# Quick release
make quick-release
```

### Using the Published Image

```bash
# Pull the image (note: username is automatically converted to lowercase)
docker pull ghcr.io/ashishnaware/nats-server:latest

# Run the image
docker run -d \
  --name nats-server \
  -p 4222:4222 \
  -p 8222:8222 \
  ghcr.io/ashishnaware/nats-server:latest
```

**Note**: Your GitHub username is automatically converted to lowercase for Docker compatibility. For example:
- `AshishNaware` becomes `ashishnaware`
- `Ashish Naware` becomes `ashishnaware`

### Automated Publishing

The repository includes GitHub Actions that automatically publish images on:
- Push to main/master branch
- Tagged releases (v*)
- Pull requests (build only, no push)

## Environment Variables

You can override configuration using environment variables:

```bash
docker run -d \
  --name nats-server \
  -p 4222:4222 \
  -p 8222:8222 \
  -e NATS_SERVER_NAME="my-nats-server" \
  -e NATS_PORT=4222 \
  -e NATS_HTTP_PORT=8222 \
  nats-server:latest
```

## Security Best Practices

1. **Use NKey or JWT authentication** for production environments
2. **Enable TLS** for encrypted communication
3. **Run as non-root user** (already configured in the image)
4. **Mount credentials as read-only** volumes
5. **Use Docker secrets** in production environments
6. **Regularly update** the NATS server version
7. **Monitor logs** for suspicious activity

## Security Scanning

The project includes automated security scanning using Trivy:

```bash
# Run security scan on the built image
make security-scan

# Force security scan with full output (for debugging)
make security-scan-force
```

### Security Scan Features

- **Automatic image building**: If the image doesn't exist, it will be built automatically
- **Vulnerability detection**: Scans for HIGH and CRITICAL vulnerabilities
- **Robust error handling**: Gracefully handles network connectivity issues
- **Fallback validation**: Performs basic image functionality tests when trivy fails
- **Clear reporting**: Provides detailed vulnerability information and remediation advice

### Manual Security Scanning

You can also run trivy manually:

```bash
# Install trivy (if not already installed)
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Scan the image
trivy image ghcr.io/yourusername/nats-server:latest

# Scan with specific severity filters
trivy image --severity HIGH,CRITICAL ghcr.io/yourusername/nats-server:latest
```

## Troubleshooting

### Using Makefile Commands

```bash
# Check server status
make status

# View logs
make logs

# View last 100 lines of logs
make logs-tail

# Access shell in container
make shell

# Validate configuration
make config-check
```

### Manual Troubleshooting

```bash
# Check if the container is running
docker ps | grep nats-server

# Check logs
docker logs nats-server

# Check health
curl http://localhost:8222/healthz
```

### Common Issues

1. **Permission denied**: Ensure credentials files have correct permissions
2. **Connection refused**: Check if ports are properly exposed
3. **Authentication failed**: Verify credentials configuration
4. **Invalid repository name**: Username is automatically converted to lowercase for Docker compatibility
5. **Buildx failed with uppercase error**: Run `./scripts/test-username.sh` to verify username conversion

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License.
