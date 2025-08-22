#!/bin/bash

# Setup script for GitHub Container Registry publishing

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}GitHub Container Registry Setup${NC}"
echo "=================================="
echo ""

# Check if git is configured
if ! git config user.name > /dev/null 2>&1; then
    echo -e "${RED}Git user.name is not configured. Please run:${NC}"
    echo "git config --global user.name 'Your Name'"
    echo "git config --global user.email 'your.email@example.com'"
    exit 1
fi

# Get GitHub username
GITHUB_USERNAME=$(git config user.name | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
echo -e "${GREEN}Detected GitHub username: ${GITHUB_USERNAME}${NC}"

# Check if GITHUB_TOKEN is set
if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${YELLOW}GITHUB_TOKEN environment variable is not set.${NC}"
    echo ""
    echo "To create a GitHub token:"
    echo "1. Go to https://github.com/settings/tokens"
    echo "2. Click 'Generate new token (classic)'"
    echo "3. Select 'write:packages' permission"
    echo "4. Copy the token and set it:"
    echo ""
    echo "export GITHUB_TOKEN=your_token_here"
    echo ""
    echo "Or add it to your ~/.bashrc or ~/.zshrc:"
    echo "echo 'export GITHUB_TOKEN=your_token_here' >> ~/.bashrc"
    echo ""
    read -p "Press Enter to continue after setting GITHUB_TOKEN..."
fi

# Verify token is set
if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}GITHUB_TOKEN is still not set. Please set it and run this script again.${NC}"
    exit 1
fi

echo -e "${GREEN}GITHUB_TOKEN is set.${NC}"

# Test login
echo -e "${BLUE}Testing GitHub Container Registry login...${NC}"
if echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin > /dev/null 2>&1; then
    echo -e "${GREEN}Login successful!${NC}"
else
    echo -e "${RED}Login failed. Please check your token and try again.${NC}"
    exit 1
fi

# Update package.json with correct repository URL
echo -e "${BLUE}Updating package.json with repository information...${NC}"
if [ -f "package.json" ]; then
    # Get repository URL from git
    REPO_URL=$(git config --get remote.origin.url)
    if [ -n "$REPO_URL" ]; then
        # Convert SSH URL to HTTPS if needed
        REPO_URL=$(echo "$REPO_URL" | sed 's/git@github.com:/https:\/\/github.com\//' | sed 's/\.git$//')
        
        # Update package.json
        sed -i.bak "s|git+https://github.com/yourusername/nats-cli.git|$REPO_URL|g" package.json
        sed -i.bak "s|https://github.com/yourusername/nats-cli|$REPO_URL|g" package.json
        
        echo -e "${GREEN}Updated package.json with repository URL: $REPO_URL${NC}"
    fi
fi

# Create .env.example file
echo -e "${BLUE}Creating .env.example file...${NC}"
cat > .env.example << EOF
# GitHub Container Registry Configuration
GITHUB_TOKEN=your_github_token_here
GITHUB_USERNAME=$GITHUB_USERNAME

# Docker Image Configuration
IMAGE_NAME=nats-server
IMAGE_TAG=latest
REGISTRY=ghcr.io/

# NATS Configuration
NATS_SERVER_NAME=nats-server
NATS_DEBUG=false
NATS_TRACE=false
EOF

echo -e "${GREEN}Created .env.example file${NC}"

# Show next steps
echo ""
echo -e "${GREEN}Setup completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Copy .env.example to .env and update with your values:"
echo "   cp .env.example .env"
echo ""
echo "2. Build and test your image:"
echo "   make build"
echo "   make test"
echo ""
echo "3. Publish to GitHub Container Registry:"
echo "   make push"
echo "   # or"
echo "   make release"
echo ""
echo -e "${BLUE}Your image will be available at:${NC}"
echo "ghcr.io/$GITHUB_USERNAME/nats-server:latest"
echo ""
echo -e "${YELLOW}For automated publishing, push your code to GitHub and the GitHub Actions will handle the rest!${NC}"
