#!/bin/bash
# Reset script for SANS Offensive AI Workshop
# Cleans up Shannon deliverables and resets the Juice Shop workspace

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$SCRIPT_DIR/workspace/juice-shop"

echo "========================================="
echo "SANS Workshop - Workspace Reset"
echo "========================================="
echo ""
echo "This script will clean up Shannon's previous run artifacts"
echo "and reset the Juice Shop workspace to a clean state."
echo ""

# Check if workspace exists
if [ ! -d "$WORKSPACE_DIR" ]; then
    echo "✗ Juice Shop workspace not found at: $WORKSPACE_DIR"
    echo "Run setup.sh first to create the workspace."
    exit 1
fi

echo "This will:"
echo "  - Remove .shannon directory (previous Shannon findings)"
echo "  - Clean untracked files from the workspace"
echo "  - Reset any modified files to their original state"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Cleaning workspace..."
cd "$WORKSPACE_DIR"

# Remove Shannon deliverables
if [ -d ".shannon" ]; then
    echo "✓ Removing .shannon directory..."
    rm -rf .shannon
else
    echo "  (no .shannon directory found)"
fi

# Clean untracked files
echo "✓ Cleaning untracked files..."
git clean -fdx

# Reset modified files
echo "✓ Resetting modified files..."
git reset --hard

echo ""
echo "========================================="
echo "✓ Workspace Reset Complete!"
echo "========================================="
echo ""
echo "The Juice Shop workspace is now clean and ready for a fresh Shannon scan."
echo ""
echo "To run Shannon again:"
echo "  docker compose run --rm shannon-worker node apps/worker/dist/temporal/worker.js \\"
echo "    http://juice-shop:3000 \\"
echo "    /app/repos/juice-shop \\"
echo "    --task-queue shannon \\"
echo "    --config /app/configs/juice-shop-lite.yaml"
echo ""
