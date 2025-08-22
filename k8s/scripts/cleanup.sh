#!/bin/bash

# Cleanup script for NATS Server on Kind cluster

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Cleaning up NATS Server from Kind cluster${NC}"
echo "================================================"
echo ""

# Delete Kubernetes resources
echo -e "${YELLOW}Deleting Kubernetes resources...${NC}"
kubectl delete -f k8s/ --ignore-not-found=true

echo -e "${GREEN}Kubernetes resources cleaned up!${NC}"
echo -e "${YELLOW}Note: Your Kubernetes cluster is still running.${NC}"
echo -e "${YELLOW}To delete the cluster, use your cluster management tool (kind, minikube, etc.)${NC}"

echo -e "${GREEN}Cleanup completed!${NC}"
