#!/bin/bash

# Test script to verify username conversion

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Testing username conversion for Docker compatibility${NC}"
echo "=================================================="
echo ""

# Get original username
ORIGINAL_USERNAME=$(git config user.name)
echo -e "${YELLOW}Original username: ${ORIGINAL_USERNAME}${NC}"

# Convert to lowercase and remove spaces
CONVERTED_USERNAME=$(echo "$ORIGINAL_USERNAME" | tr '[:upper:]' '[:lower:]' | sed 's/ //g')
echo -e "${GREEN}Converted username: ${CONVERTED_USERNAME}${NC}"

# Test Docker tag format
DOCKER_TAG="ghcr.io/${CONVERTED_USERNAME}/nats-server:latest"
echo -e "${GREEN}Docker tag: ${DOCKER_TAG}${NC}"

# Validate Docker tag format
if [[ $DOCKER_TAG =~ ^[a-z0-9._/-]+:[a-zA-Z0-9._-]+$ ]]; then
    echo -e "${GREEN}✓ Docker tag format is valid${NC}"
else
    echo -e "${YELLOW}⚠ Docker tag format may have issues${NC}"
fi

# Check for uppercase letters
if [[ $CONVERTED_USERNAME =~ [A-Z] ]]; then
    echo -e "${YELLOW}⚠ Warning: Converted username still contains uppercase letters${NC}"
else
    echo -e "${GREEN}✓ Username is properly lowercase${NC}"
fi

echo ""
echo -e "${BLUE}Test completed!${NC}"
