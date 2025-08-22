#!/bin/bash

# Setup script for NATS Server on existing Kind cluster

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Setting up NATS Server on existing Kind cluster${NC}"
echo "====================================================="
echo ""

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo -e "${RED}Kind is not installed. Please install it first:${NC}"
    echo "curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64"
    echo "chmod +x ./kind"
    echo "sudo mv ./kind /usr/local/bin/kind"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Kubectl is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if any Kubernetes cluster is accessible
echo -e "${YELLOW}Checking Kubernetes cluster access...${NC}"
if ! kubectl get nodes &> /dev/null; then
    echo -e "${RED}No Kubernetes cluster is accessible.${NC}"
    echo -e "${YELLOW}Please ensure you have a cluster running and kubectl is configured.${NC}"
    echo -e "${YELLOW}You can use any Kubernetes cluster (Kind, Minikube, Docker Desktop, etc.)${NC}"
    exit 1
fi

echo -e "${GREEN}Kubernetes cluster is accessible!${NC}"
echo -e "${BLUE}Cluster info:${NC}"
kubectl cluster-info

# Create namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl apply -f k8s/namespace.yaml

# Update credentials in secret
echo -e "${YELLOW}Updating credentials...${NC}"
read -p "Enter NATS username (default: admin): " username
username=${username:-admin}
read -s -p "Enter NATS password (default: password123): " password
password=${password:-password123}
echo ""

# Update the secret with new credentials
cat > k8s/secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: nats-auth-secret
  namespace: nats-system
type: Opaque
data:
  username: $(echo -n "$username" | base64)
  password: $(echo -n "$password" | base64)
EOF

echo -e "${GREEN}Credentials updated!${NC}"

# Apply Kubernetes manifests
echo -e "${YELLOW}Applying Kubernetes manifests...${NC}"
kubectl apply -f k8s/

# Wait for deployment to be ready
echo -e "${YELLOW}Waiting for NATS server to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/nats-server -n nats-system

# Get service information
echo -e "${GREEN}NATS Server deployed successfully!${NC}"
echo ""
echo -e "${BLUE}Service Information:${NC}"
echo "========================"
echo -e "Cluster IP: $(kubectl get svc nats-server -n nats-system -o jsonpath='{.spec.clusterIP}')"
echo -e "NodePort Client: localhost:30422"
echo -e "NodePort HTTP: localhost:30822"
echo ""
echo -e "${BLUE}Connection Information:${NC}"
echo "=========================="
echo -e "NATS Client URL: nats://$username:$password@localhost:30422"
echo -e "HTTP Monitoring: http://localhost:30822"
echo -e "Health Check: http://localhost:30822/healthz"
echo ""
echo -e "${YELLOW}To test the connection:${NC}"
echo "kubectl port-forward svc/nats-server-nodeport 30422:4222 -n nats-system"
echo "kubectl port-forward svc/nats-server-nodeport 30822:8222 -n nats-system"
echo ""
echo -e "${GREEN}Setup completed!${NC}"
