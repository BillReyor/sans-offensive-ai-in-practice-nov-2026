#!/bin/bash
# Verification script for SANS Offensive AI Workshop setup
# This script checks if all components are properly configured

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/tools"
WORKSPACE_DIR="$SCRIPT_DIR/workspace"

echo "========================================="
echo "SANS Workshop - Setup Verification"
echo "========================================="
echo ""

ERRORS=0
WARNINGS=0

# Function to check if a file exists
check_file() {
    local file="$1"
    local description="$2"
    if [ -f "$file" ]; then
        echo "✓ $description"
        return 0
    else
        echo "✗ $description (missing: $file)"
        ((ERRORS++))
        return 1
    fi
}

# Function to check if a directory exists
check_dir() {
    local dir="$1"
    local description="$2"
    if [ -d "$dir" ]; then
        echo "✓ $description"
        return 0
    else
        echo "✗ $description (missing: $dir)"
        ((ERRORS++))
        return 1
    fi
}

# Function to check if a service is running
check_service() {
    local service="$1"
    if docker compose ps | grep -q "$service.*running"; then
        echo "✓ Service $service is running"
        return 0
    else
        echo "⚠ Service $service is not running"
        ((WARNINGS++))
        return 1
    fi
}

# Check environment file
echo "Checking environment configuration..."
if check_file "$SCRIPT_DIR/.env" "Environment file (.env)"; then
    if grep -q "ANTHROPIC_API_KEY=<add key>" "$SCRIPT_DIR/.env" || grep -q "ANTHROPIC_API_KEY=$" "$SCRIPT_DIR/.env"; then
        echo "  ⚠ Warning: ANTHROPIC_API_KEY appears to be unset in .env"
        ((WARNINGS++))
    else
        echo "  ✓ ANTHROPIC_API_KEY appears to be configured"
    fi
fi
echo ""

# Check tool repositories
echo "Checking tool repositories..."
check_dir "$TOOLS_DIR/shannon" "Shannon repository"
check_dir "$TOOLS_DIR/PentestGPT" "PentestGPT repository"
echo ""

# Check Dockerfiles
echo "Checking Dockerfiles..."
check_file "$TOOLS_DIR/shannon/Dockerfile" "Shannon Dockerfile"
check_file "$TOOLS_DIR/PentestGPT/Dockerfile" "PentestGPT Dockerfile"
echo ""

# Check Shannon configuration
echo "Checking Shannon configuration..."
check_file "$TOOLS_DIR/shannon/configs/juice-shop.yaml" "Shannon juice-shop.yaml config"
echo ""

# Check workspace
echo "Checking workspace..."
check_dir "$WORKSPACE_DIR" "Workspace directory"
if check_dir "$WORKSPACE_DIR/juice-shop" "Juice Shop source code"; then
    if [ -d "$WORKSPACE_DIR/juice-shop/.git" ]; then
        echo "  ✓ Juice Shop is a valid git repository"
    else
        echo "  ✗ Juice Shop directory exists but is not a git repository"
        ((ERRORS++))
    fi
fi
echo ""

# Check output directories
echo "Checking output directories..."
check_dir "$SCRIPT_DIR/out" "Output directory"
check_dir "$SCRIPT_DIR/out/zap" "ZAP output directory"
check_dir "$SCRIPT_DIR/out/shannon" "Shannon output directory"
echo ""

# Check Docker services if docker is running
echo "Checking Docker services (if running)..."
if command -v docker &> /dev/null; then
    if docker compose ps &> /dev/null; then
        check_service "juice-shop"
        check_service "shannon-postgres"
        check_service "shannon-temporal"
        check_service "shannon-temporal-ui"
        check_service "shannon-worker"
        check_service "pentestgpt"
        echo ""
        echo "To check service health: docker compose ps"
    else
        echo "⚠ Docker Compose services are not running yet"
        echo "  Start with: docker compose up -d"
        ((WARNINGS++))
    fi
else
    echo "⚠ Docker command not found - cannot check service status"
    ((WARNINGS++))
fi
echo ""

# Summary
echo "========================================="
echo "Verification Summary"
echo "========================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✓ All checks passed! Setup is complete."
    echo ""
    echo "Next steps:"
    echo "1. Start services if not running: docker compose up -d"
    echo "2. Wait for services to be healthy: docker compose ps"
    echo "3. Run tools as described in README.md"
elif [ $ERRORS -eq 0 ]; then
    echo "⚠ Setup is mostly complete with $WARNINGS warning(s)"
    echo "Review warnings above and fix if needed"
else
    echo "✗ Setup is incomplete with $ERRORS error(s) and $WARNINGS warning(s)"
    echo "Please run setup.sh or follow manual setup instructions in README.md"
    exit 1
fi
