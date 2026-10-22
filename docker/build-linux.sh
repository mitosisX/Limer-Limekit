#!/bin/bash
# ============================================================
#   LIMER LINUX BUILD (DOCKER)
#   Builds the Linux executable in Ubuntu 22.04 and drops it in
#   ./dist-linux/ on the host.
# ============================================================
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"
CONTEXT="$(cd .. && pwd)"
OUT="$PROJECT_ROOT/dist-linux"

echo "Building image (first run pulls Ubuntu + PySide6, ~5 min)..."
docker build -f "$PROJECT_ROOT/docker/Dockerfile" -t limer-linux-build "$CONTEXT"

mkdir -p "$OUT"
echo "Running build..."
docker run --rm -v "$OUT:/out" limer-linux-build --console --clean --output /out

echo ""
echo "Output:"
ls -la "$OUT"
