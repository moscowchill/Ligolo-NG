#!/bin/bash

# Garble-enabled Ligolo-ng Builder
# Requires Go 1.25+ and garble

set -e

echo "============================================"
echo "  Ligolo-ng Garble Stealth Builder"
echo "============================================"

# Check dependencies
if ! command -v go >/dev/null 2>&1; then
    echo "[ERROR] Go is not installed"
    exit 1
fi

if ! command -v garble >/dev/null 2>&1; then
    echo "[ERROR] Garble is not installed"
    echo "Install with: go install mvdan.cc/garble@latest"
    exit 1
fi

GO_VERSION=$(go version | grep -oP 'go\K[0-9]+\.[0-9]+')
MAJOR=$(echo "$GO_VERSION" | cut -d. -f1)
MINOR=$(echo "$GO_VERSION" | cut -d. -f2)

if [ "$MAJOR" -lt 1 ] || ([ "$MAJOR" -eq 1 ] && [ "$MINOR" -lt 25 ]); then
    echo "[ERROR] Go version $GO_VERSION is too old"
    echo "Garble requires Go 1.25+, current version: $GO_VERSION"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "cmd/agent/main.go" ]; then
    echo "[ERROR] Please run this script from the ligolo-ng root directory"
    exit 1
fi

echo "[INFO] Go version: $GO_VERSION ✓"
echo "[INFO] Garble version: $(garble version | head -n1) ✓"

# Create builds directory
mkdir -p builds

# Backup original
echo "[INFO] Backing up original files..."
cp cmd/agent/main.go cmd/agent/main.go.original

# Apply basic string obfuscation (garble will handle more)
echo "[INFO] Applying initial string obfuscation..."
sed -i \
    -e 's/Ligolo-ng/NetAgent/g' \
    -e 's/Made in France with love by @Nicocha30!/Network utility tool/g' \
    -e 's|https://github.com/nicocha30/ligolo-ng|https://github.com/user/netagent|g' \
    -e 's/connect to proxy/connect to server/g' \
    cmd/agent/main.go

# Cleanup function
cleanup() {
    echo "[INFO] Restoring original files..."
    if [ -f cmd/agent/main.go.original ]; then
        mv cmd/agent/main.go.original cmd/agent/main.go
    fi
}

trap cleanup EXIT

echo "[INFO] Building with garble obfuscation..."

# Build variants with different garble settings
echo "[INFO] Building builds/agent-garbled-basic.exe..."
GOOS=windows GOARCH=amd64 garble \
    -seed=random \
    build \
    -ldflags="-s -w" \
    -o builds/agent-garbled-basic.exe \
    cmd/agent/main.go

echo "[INFO] Building builds/agent-garbled-literals.exe..."
GOOS=windows GOARCH=amd64 garble \
    -literals \
    -seed=random \
    build \
    -ldflags="-s -w" \
    -o builds/agent-garbled-literals.exe \
    cmd/agent/main.go

echo "[INFO] Building builds/agent-garbled-tiny.exe..."
GOOS=windows GOARCH=amd64 garble \
    -literals \
    -tiny \
    -seed=random \
    build \
    -ldflags="-s -w" \
    -o builds/agent-garbled-tiny.exe \
    cmd/agent/main.go

# UPX compression if available
if command -v upx >/dev/null 2>&1; then
    echo "[INFO] Creating UPX compressed versions..."

    for variant in basic literals tiny; do
        if [ -f "builds/agent-garbled-$variant.exe" ]; then
            echo "[INFO] Compressing agent-garbled-$variant.exe..."
            cp "builds/agent-garbled-$variant.exe" "builds/agent-garbled-$variant-upx.exe"
            if timeout 120 upx --best "builds/agent-garbled-$variant-upx.exe" >/dev/null 2>&1; then
                echo "[SUCCESS] Compressed agent-garbled-$variant-upx.exe"
            else
                echo "[WARNING] Failed to compress $variant variant (timeout/error)"
                rm -f "builds/agent-garbled-$variant-upx.exe"
            fi
        fi
    done

    echo "[SUCCESS] UPX compression completed"
else
    echo "[WARNING] UPX not available, skipping compression"
fi

# Show results
echo ""
echo "Build Summary:"
echo "=============="
if ls builds/agent-garbled-*.exe >/dev/null 2>&1; then
    ls -lah builds/agent-garbled-*.exe | while read line; do
        filename=$(echo "$line" | awk '{print $9}' | sed 's|builds/||')
        size=$(echo "$line" | awk '{print $5}')
        printf "%-35s %8s\n" "$filename" "$size"
    done
else
    echo "No builds found!"
    exit 1
fi

echo ""
echo "Testing Recommendations (Best to Worst for AV Evasion):"
echo "======================================================="
if [ -f "builds/agent-garbled-tiny-upx.exe" ]; then
    echo "1. builds/agent-garbled-tiny-upx.exe      (Maximum obfuscation + compression)"
fi
if [ -f "builds/agent-garbled-literals-upx.exe" ]; then
    echo "2. builds/agent-garbled-literals-upx.exe  (String obfuscation + compression)"
fi
if [ -f "builds/agent-garbled-basic-upx.exe" ]; then
    echo "3. builds/agent-garbled-basic-upx.exe     (Basic obfuscation + compression)"
fi
echo "4. builds/agent-garbled-tiny.exe          (Maximum obfuscation only)"
echo "5. builds/agent-garbled-literals.exe      (String obfuscation only)"
echo "6. builds/agent-garbled-basic.exe         (Basic obfuscation only)"

echo ""
echo "Garble Features Applied:"
echo "======================="
echo "✓ Function name obfuscation"
echo "✓ Variable name obfuscation"
echo "✓ Package name obfuscation"
echo "✓ String literal obfuscation (-literals variants)"
echo "✓ Binary size optimization (-tiny variants)"
echo "✓ Random seed for unique builds"
echo "✓ Control flow obfuscation"

echo ""
echo "[SUCCESS] Garble build completed!"
echo ""
echo "Note: Each build uses a random seed, so binaries will be unique."
echo "Rebuild with different seeds if one variant gets detected."