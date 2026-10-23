#!/bin/bash
# Setup script for SANS Offensive AI Workshop
# This script automates the setup of Shannon and PentestGPT tools

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/tools"
WORKSPACE_DIR="$SCRIPT_DIR/workspace"
CONFIGS_DIR="$TOOLS_DIR/shannon/configs"

echo "========================================="
echo "SANS Offensive AI Workshop - Setup"
echo "========================================="
echo ""

# Check if .env file exists
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "⚠️  No .env file found!"
    echo "Creating .env from .env.example..."
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    echo ""
    echo "⚠️  IMPORTANT: Please edit .env and add your ANTHROPIC_API_KEY"
    echo "   File location: $SCRIPT_DIR/.env"
    echo ""
    read -p "Press Enter after you've added your API key to continue..."
fi

# Create tools directory
echo "Creating tools directory..."
mkdir -p "$TOOLS_DIR"

# Clone Shannon if not already cloned
if [ ! -d "$TOOLS_DIR/shannon" ]; then
    echo "Cloning Shannon repository..."
    git clone https://github.com/KeygraphHQ/shannon "$TOOLS_DIR/shannon"
else
    echo "✓ Shannon repository already exists"
fi

# Clone PentestGPT if not already cloned
if [ ! -d "$TOOLS_DIR/PentestGPT" ]; then
    echo "Cloning PentestGPT repository..."
    git clone https://github.com/greydgl/pentestgpt "$TOOLS_DIR/PentestGPT"
else
    echo "✓ PentestGPT repository already exists"
fi

# Copy Dockerfiles if they don't exist
echo ""
echo "Setting up Dockerfiles..."

if [ ! -f "$TOOLS_DIR/shannon/Dockerfile" ]; then
    echo "Copying Shannon Dockerfile..."
    cp "$SCRIPT_DIR/dockerfiles/shannon.Dockerfile" "$TOOLS_DIR/shannon/Dockerfile"
else
    echo "⚠️  Shannon Dockerfile already exists, skipping..."
fi

if [ ! -f "$TOOLS_DIR/PentestGPT/Dockerfile" ]; then
    echo "Copying PentestGPT Dockerfile..."
    cp "$SCRIPT_DIR/dockerfiles/pentestgpt.Dockerfile" "$TOOLS_DIR/PentestGPT/Dockerfile"
else
    echo "⚠️  PentestGPT Dockerfile already exists, skipping..."
fi

# Create Shannon configs directory and copy juice-shop.yaml
echo ""
echo "Setting up Shannon configuration..."
mkdir -p "$CONFIGS_DIR"

if [ -f "../juice-shop.yaml" ]; then
    echo "Copying juice-shop.yaml to Shannon configs..."
    cp "../juice-shop.yaml" "$CONFIGS_DIR/juice-shop.yaml"
else
    echo "⚠️  juice-shop.yaml not found in parent directory"
fi

# Create workspace directory structure
echo ""
echo "Creating workspace directory structure..."
mkdir -p "$WORKSPACE_DIR"
mkdir -p "$SCRIPT_DIR/out/zap"
mkdir -p "$SCRIPT_DIR/out/shannon"

# Clone Juice Shop source code
if [ ! -d "$WORKSPACE_DIR/juice-shop" ]; then
    echo "Cloning Juice Shop source code for Shannon analysis..."
    git clone https://github.com/juice-shop/juice-shop.git "$WORKSPACE_DIR/juice-shop"

    # Set git config for the juice-shop repo
    cd "$WORKSPACE_DIR/juice-shop"
    git config user.email "pentest@localhost"
    git config user.name "Pentest Agent"
    cd "$SCRIPT_DIR"
else
    echo "✓ Juice Shop source already exists"
fi

echo ""
echo "========================================="
echo "✓ Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Ensure your ANTHROPIC_API_KEY is set in .env"
echo "2. Start all services:"
echo "   cd workshop-bundle"
echo "   docker compose up -d"
echo ""
echo "3. Wait for services to be healthy (check with: docker compose ps)"
echo ""
echo "4. Run Shannon pentest:"
echo "   docker compose run --rm shannon-worker node apps/worker/dist/temporal/worker.js \\"
echo "     http://juice-shop:3000 \\"
echo "     /app/repos/juice-shop \\"
echo "     --task-queue shannon \\"
echo "     --config /app/configs/juice-shop.yaml"
echo ""
echo "5. Or connect to PentestGPT interactively:"
echo "   docker compose exec -it pentestgpt bash"
echo "   pentestgpt --target juice-shop:3000"
echo ""
echo "For more information, see README.md"
echo ""
