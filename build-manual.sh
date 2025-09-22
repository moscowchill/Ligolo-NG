#!/bin/bash

# Manual Obfuscation Only Builder
# No garble, no UPX - just string replacements and memory layout changes

set -e

echo "========================================"
echo "  Ligolo-ng Manual Obfuscation Builder"
echo "========================================"

# Check if we're in the right directory
if [ ! -f "cmd/agent/main.go" ]; then
    echo "[ERROR] Please run this script from the ligolo-ng root directory"
    exit 1
fi

# Create builds directory
mkdir -p builds

# Backup original
echo "[INFO] Backing up original files..."
cp cmd/agent/main.go cmd/agent/main.go.original

# Apply string obfuscation only (no advanced padding)
echo "[INFO] Applying manual string obfuscation..."
sed -i \
    -e 's/Ligolo-ng/NetAgent/g' \
    -e 's/Made in France with love by @Nicocha30!/Network utility tool/g' \
    -e 's|https://github.com/nicocha30/ligolo-ng|https://github.com/user/netagent|g' \
    -e 's/connect to proxy/connect to server/g' \
    -e 's/Chrome\/103\.0\.0\.0/Chrome\/120.0.0.0/g' \
    cmd/agent/main.go

# Cleanup function
cleanup() {
    echo "[INFO] Restoring original files..."
    if [ -f cmd/agent/main.go.original ]; then
        mv cmd/agent/main.go.original cmd/agent/main.go
    fi
}

trap cleanup EXIT

echo "[INFO] Building manual obfuscation agent..."

# Build with minimal flags - no symbol stripping to keep size reasonable
GOOS=windows GOARCH=amd64 go build \
    -ldflags="-X main.version=1.0.0 -X main.commit=manual -X main.date=$(date +%Y%m%d)" \
    -trimpath \
    -o builds/agent-manual-only.exe \
    cmd/agent/main.go

# Show results
echo ""
echo "Build Summary:"
echo "=============="
if [ -f "builds/agent-manual-only.exe" ]; then
    size=$(stat -c%s "builds/agent-manual-only.exe" 2>/dev/null || echo "0")
    size_mb=$(echo "scale=1; $size / 1024 / 1024" | bc -l 2>/dev/null || echo "unknown")
    echo "agent-manual-only.exe                ${size_mb}MB"
else
    echo "Build failed!"
    exit 1
fi

echo ""
echo "Features Applied:"
echo "================"
echo "✓ String obfuscation (Ligolo-ng → NetAgent, etc.)"
echo "✓ User-Agent updated to Chrome 120"
echo "✓ Build path trimming (-trimpath)"
echo "✓ Custom version info"
echo "✗ Symbol stripping (kept for smaller size)"
echo "✗ UPX compression (not applied)"
echo "✗ Garble obfuscation (not applied)"

echo ""
echo "[SUCCESS] Manual obfuscation build completed!"
echo ""
echo "Output: builds/agent-manual-only.exe"
echo "This is the most basic stealth variant with minimal changes."
echo "Use this if garble and UPX variants are detected."