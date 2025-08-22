#!/bin/bash

# Generate self-signed TLS certificates for NATS Server

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Generating TLS certificates for NATS Server${NC}"
echo "================================================"
echo ""

# Check if openssl is installed
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}OpenSSL is not installed. Please install it first.${NC}"
    exit 1
fi

# Create certificates directory
mkdir -p k8s/certs

# Generate CA private key
echo -e "${YELLOW}Generating CA private key...${NC}"
openssl genrsa -out k8s/certs/ca-key.pem 2048

# Generate CA certificate
echo -e "${YELLOW}Generating CA certificate...${NC}"
openssl req -new -x509 -sha256 -days 365 -key k8s/certs/ca-key.pem -out k8s/certs/ca.pem -subj "/C=US/ST=CA/L=San Francisco/O=NATS/OU=IT/CN=NATS-CA"

# Generate server private key
echo -e "${YELLOW}Generating server private key...${NC}"
openssl genrsa -out k8s/certs/server-key.pem 2048

# Generate server certificate signing request
echo -e "${YELLOW}Generating server certificate signing request...${NC}"
openssl req -new -key k8s/certs/server-key.pem -out k8s/certs/server.csr -subj "/C=US/ST=CA/L=San Francisco/O=NATS/OU=IT/CN=nats-server"

# Create server certificate config
cat > k8s/certs/server-ext.conf <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = nats-server
DNS.2 = nats-server.nats-system
DNS.3 = nats-server.nats-system.svc
DNS.4 = nats-server.nats-system.svc.cluster.local
DNS.5 = localhost
IP.1 = 127.0.0.1
EOF

# Sign server certificate
echo -e "${YELLOW}Signing server certificate...${NC}"
openssl x509 -req -in k8s/certs/server.csr -CA k8s/certs/ca.pem -CAkey k8s/certs/ca-key.pem -CAcreateserial -out k8s/certs/server-cert.pem -days 365 -extfile k8s/certs/server-ext.conf

# Update TLS secret
echo -e "${YELLOW}Updating TLS secret...${NC}"
cat > k8s/tls-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: nats-tls-secret
  namespace: nats-system
type: kubernetes.io/tls
data:
  tls.crt: $(cat k8s/certs/server-cert.pem | base64 -w 0)
  tls.key: $(cat k8s/certs/server-key.pem | base64 -w 0)
  ca.crt: $(cat k8s/certs/ca.pem | base64 -w 0)
EOF

# Set proper permissions
chmod 600 k8s/certs/*.pem

echo -e "${GREEN}TLS certificates generated successfully!${NC}"
echo ""
echo -e "${BLUE}Certificate files:${NC}"
echo "====================="
echo -e "CA Certificate: k8s/certs/ca.pem"
echo -e "Server Certificate: k8s/certs/server-cert.pem"
echo -e "Server Private Key: k8s/certs/server-key.pem"
echo ""
echo -e "${YELLOW}To enable TLS in NATS configuration:${NC}"
echo "1. Update k8s/configmap.yaml to uncomment TLS section"
echo "2. Apply the updated TLS secret: kubectl apply -f k8s/tls-secret.yaml"
echo ""
echo -e "${GREEN}Certificate generation completed!${NC}"
