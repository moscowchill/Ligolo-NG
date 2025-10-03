#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Ligolo-ng Server Setup Script      ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""

# Configuration
INSTALL_DIR="/root/ligolo-ng"
DOMAIN=""
USERNAME="admin"
PASSWORD=""
WEB_PORT="8081"
PROXY_PORT="11601"
USE_AUTOCERT=false

# Prompt for configuration
read -p "Enter your domain name (leave empty for no autocert): " DOMAIN
if [ ! -z "$DOMAIN" ]; then
    USE_AUTOCERT=true
    echo -e "${GREEN}✓${NC} Will use Let's Encrypt autocert for $DOMAIN"
else
    echo -e "${YELLOW}⚠${NC} No domain provided, will use self-signed certificates"
fi

read -p "Enter WebUI username [admin]: " input_username
USERNAME=${input_username:-admin}

read -p "Enter WebUI port [8081]: " input_port
WEB_PORT=${input_port:-8081}

# Generate strong password
echo -e "\n${YELLOW}Generating strong password...${NC}"
PASSWORD=$(openssl rand -base64 24 | tr -d '\n')
echo -e "${GREEN}✓${NC} Generated password: ${GREEN}$PASSWORD${NC}"
echo -e "${YELLOW}⚠ SAVE THIS PASSWORD!${NC}\n"

# Check if Go is installed
echo "Checking Go installation..."
if ! command -v /usr/local/go/bin/go &> /dev/null; then
    echo "Installing Go 1.23.4..."
    wget -q https://go.dev/dl/go1.23.4.linux-amd64.tar.gz -O /tmp/go1.23.4.linux-amd64.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /tmp/go1.23.4.linux-amd64.tar.gz
    echo -e "${GREEN}✓${NC} Go installed"
else
    echo -e "${GREEN}✓${NC} Go already installed"
fi

export PATH=/usr/local/go/bin:$PATH

# Check Node.js
echo "Checking Node.js installation..."
if ! command -v node &> /dev/null; then
    echo -e "${RED}✗${NC} Node.js not found. Please install Node.js first."
    exit 1
else
    echo -e "${GREEN}✓${NC} Node.js installed ($(node --version))"
fi

# Clone repository
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}⚠${NC} Directory exists, removing..."
    rm -rf "$INSTALL_DIR"
fi

echo "Cloning ligolo-ng repository..."
git clone https://github.com/nicocha30/ligolo-ng.git "$INSTALL_DIR" > /dev/null 2>&1
cd "$INSTALL_DIR"
echo -e "${GREEN}✓${NC} Repository cloned"

# Initialize submodule
echo "Initializing WebUI submodule..."
git submodule update --init --recursive > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Submodule initialized"

# Install WebUI dependencies
echo "Installing WebUI dependencies..."
cd web/ligolo-ng-web
npm install > /dev/null 2>&1
echo -e "${GREEN}✓${NC} WebUI dependencies installed"

# Build WebUI
echo "Building WebUI..."
npm run build > /dev/null 2>&1
cp -r dist/* ../dist/
cd "$INSTALL_DIR"
echo -e "${GREEN}✓${NC} WebUI built"

# Install Go dependencies and build
echo "Installing Go dependencies..."
go mod download > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Go dependencies installed"

echo "Building ligolo-ng proxy..."
make linux > /dev/null 2>&1
echo -e "${GREEN}✓${NC} Proxy built"

# Generate password hash
echo "Generating password hash..."
mkdir -p /tmp/ligolo_hash
cd /tmp/ligolo_hash
cat > hash_password.go << 'EOF'
package main

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"os"
	"golang.org/x/crypto/argon2"
)

func main() {
	if len(os.Args) != 2 {
		fmt.Println("Usage: hash_password <password>")
		os.Exit(1)
	}
	password := os.Args[1]
	salt := make([]byte, 16)
	if _, err := rand.Read(salt); err != nil {
		panic(err)
	}
	hash := argon2.IDKey([]byte(password), salt, 3, 32768, 4, 32)
	b64Salt := base64.RawStdEncoding.EncodeToString(salt)
	b64Hash := base64.RawStdEncoding.EncodeToString(hash)
	encodedHash := fmt.Sprintf("$argon2id$v=19$m=32768,t=3,p=4$%s$%s", b64Salt, b64Hash)
	fmt.Println(encodedHash)
}
EOF

go mod init hash_password > /dev/null 2>&1
go mod tidy > /dev/null 2>&1
PASSWORD_HASH=$(go run hash_password.go "$PASSWORD" 2>/dev/null | tail -1)
echo -e "${GREEN}✓${NC} Password hashed"

# Create configuration file
echo "Creating configuration file..."
SECRET=$(openssl rand -hex 32)

if [ "$USE_AUTOCERT" = true ]; then
    cat > /root/ligolo-ng.yaml << EOF
agent:
    example:
        autobind: false
        interface: ligolo
interface:
    ligolo:
        routes:
            - 10.0.0.0/8
            - 172.16.0.0/12
            - 192.168.0.0/16
web:
    behindreverseproxy: false
    corsallowedorigin:
        - https://webui.ligolo.ng
    debug: false
    enabled: true
    enableui: true
    listen: 0.0.0.0:${WEB_PORT}
    logfile: ui.log
    secret: ${SECRET}
    tls:
        alloweddomains:
            - ${DOMAIN}
        autocert: true
        certfile: ""
        enabled: true
        keyfile: ""
        selfcert: false
        selfcertdomain: ligolo
    trustedproxies:
        - 127.0.0.1
    users:
        ${USERNAME}: ${PASSWORD_HASH}
EOF
else
    cat > /root/ligolo-ng.yaml << EOF
agent:
    example:
        autobind: false
        interface: ligolo
interface:
    ligolo:
        routes:
            - 10.0.0.0/8
            - 172.16.0.0/12
            - 192.168.0.0/16
web:
    behindreverseproxy: false
    corsallowedorigin:
        - https://webui.ligolo.ng
    debug: false
    enabled: true
    enableui: true
    listen: 0.0.0.0:${WEB_PORT}
    logfile: ui.log
    secret: ${SECRET}
    tls:
        alloweddomains: []
        autocert: false
        certfile: ""
        enabled: false
        keyfile: ""
        selfcert: true
        selfcertdomain: ligolo
    trustedproxies:
        - 127.0.0.1
    users:
        ${USERNAME}: ${PASSWORD_HASH}
EOF
fi

echo -e "${GREEN}✓${NC} Configuration created"

# Add alias to shell config
SHELL_CONFIG=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
fi

if [ ! -z "$SHELL_CONFIG" ]; then
    if [ "$USE_AUTOCERT" = true ]; then
        echo "alias ligolo-server='${INSTALL_DIR}/dist/ligolo-ng-proxy-linux_amd64 -autocert'" >> "$SHELL_CONFIG"
    else
        echo "alias ligolo-server='${INSTALL_DIR}/dist/ligolo-ng-proxy-linux_amd64 -selfcert'" >> "$SHELL_CONFIG"
    fi
    echo -e "${GREEN}✓${NC} Alias 'ligolo-server' added to $SHELL_CONFIG"
fi

# Summary
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Setup Complete! 🎉           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Credentials:${NC}"
echo -e "  Username: ${GREEN}$USERNAME${NC}"
echo -e "  Password: ${GREEN}$PASSWORD${NC}"
echo ""
if [ "$USE_AUTOCERT" = true ]; then
    echo -e "${YELLOW}WebUI Access:${NC}"
    echo -e "  URL: ${GREEN}https://$DOMAIN:$WEB_PORT${NC}"
    echo -e "  ${YELLOW}Note: Port 80 must be accessible for Let's Encrypt${NC}"
else
    echo -e "${YELLOW}WebUI Access:${NC}"
    echo -e "  URL: ${GREEN}https://<your-ip>:$WEB_PORT${NC}"
    echo -e "  ${YELLOW}Note: Self-signed cert - browser will warn${NC}"
fi
echo ""
echo -e "${YELLOW}To start the server:${NC}"
echo -e "  Run: ${GREEN}ligolo-server${NC}"
echo -e "  Or: ${GREEN}${INSTALL_DIR}/dist/ligolo-ng-proxy-linux_amd64${NC}"
echo ""
echo -e "${YELLOW}Proxy Port:${NC} ${GREEN}$PROXY_PORT${NC} (for agent connections)"
echo ""
echo -e "${YELLOW}Configuration:${NC} /root/ligolo-ng.yaml"
echo ""
