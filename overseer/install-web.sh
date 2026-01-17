#!/bin/bash

# Void Uplink Web Installer - Cross-Platform Version
# Usage: curl -fsSL http://<overseer-url>/install-web.sh | bash
#
# This installer works on:
#   - Linux (with systemd)
#   - macOS (with launchd or foreground)
#
# Features:
#   - Auto-detects Overseer URL when installed FROM Overseer
#   - Cross-platform service management
#   - Works with Tailscale/MagicDNS

set -e

# Handle piped script execution to restore terminal stdin for interactive prompts
if [ ! -t 0 ]; then
    SCRIPT_FILE=$(mktemp)
    cat > "$SCRIPT_FILE"
    chmod +x "$SCRIPT_FILE"
    exec bash "$SCRIPT_FILE" "$@"
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${CYAN}╔═════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}          ${BOLD}${GREEN}Void Uplink - Satellite Agent${NC}           ${CYAN}           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    local num="$1"
    local text="$2"
    echo -e "${CYAN}[${num}/7]${NC} ${text}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Detect if running on macOS
is_macos() {
    [ "$(uname -s)" = "Darwin" ]
}

# Detect if running on Linux
is_linux() {
    [ "$(uname -s)" = "Linux" ]
}

check_dependencies() {
    print_step "1" "Checking dependencies..."

    # Check for Python
    if command -v python3 &> /dev/null; then
        print_success "Python 3 found ✓"
    else
        print_error "Python 3 not found"
        if is_macos; then
            echo "   Install with: brew install python3"
        else
            echo "   Install with: sudo apt-get install python3"
        fi
        exit 1
    fi

    # Check for Docker
    if command -v docker &> /dev/null; then
        print_success "Docker found ✓"
    else
        print_error "Docker not found"
        if is_macos; then
            echo "   Install Docker Desktop: https://docs.docker.com/desktop/mac/"
        else
            echo "   Install Docker: curl -fsSL https://get.docker.com | sh"
        fi
        exit 1
    fi

    # Check for Git
    if command -v git &> /dev/null; then
        print_success "Git found ✓"
    else
        print_error "Git not found"
        if is_macos; then
            echo "   Install with: brew install git"
        else
            echo "   Install with: sudo apt-get install git"
        fi
        exit 1
    fi

    echo ""
}

collect_configuration() {
    print_step "2" "Collecting configuration..."

    # Get system info
    SATELLITE_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [ -z "$SATELLITE_IP" ]; then
        # Try alternative methods for IP detection
        if is_macos; then
            SATELLITE_IP=$(ifconfig 2>/dev/null | grep -A1 "utun" | grep "inet " | awk '{print $2}' || echo "100.101.0.1")
        else
            SATELLITE_IP=$(ip addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1 || echo "10.0.0.1")
        fi
    fi

    SATELLITE_HOSTNAME=$(hostname)

    # Auto-detect Overseer URL from script invocation
    # If running from Overseer, default to the mcow public IP
    if [ -z "$OVERSEER_URL" ]; then
        OVERSEER_URL="http://85.209.135.21:8000"
        print_info "Auto-detected Overseer URL: $OVERSEER_URL"
    else
        print_info "Overseer URL: $OVERSEER_URL"
    fi

    # Ask for Satellite name
    if [ -z "$SATELLITE_NAME" ]; then
        DEFAULT_NAME="$SATELLITE_HOSTNAME"
        read -p "  ${BLUE}Enter Satellite name${NC} [${YELLOW}${DEFAULT_NAME}${NC}]: " SATELLITE_NAME
        if [ -z "$SATELLITE_NAME" ]; then
            SATELLITE_NAME="$DEFAULT_NAME"
        fi
    fi

    print_info "Configuration collected:"
    echo -e "  ${BOLD}Satellite Name:${NC}    ${GREEN}${SATELLITE_NAME}${NC}"
    echo -e "  ${BOLD}Hostname:${NC}           ${SATELLITE_HOSTNAME}"
    echo -e "  ${BOLD}IP Address:${NC}       ${SATELLITE_IP}"
    echo -e "  ${BOLD}Overseer URL:${NC}     ${OVERSEER_URL}"
    echo -e "  ${BOLD}Platform:${NC}         $(uname -s)"
    echo ""
}

clone_repo() {
    print_step "3" "Cloning Void repository..."

    INSTALL_DIR="${INSTALL_DIR:-/opt/void}"

    if is_macos; then
        # On macOS, install in user home or /usr/local
        if [ -w "$HOME" ]; then
            INSTALL_DIR="$HOME/.void"
        else
            INSTALL_DIR="/usr/local/void"
        fi
    fi

    if [ -d "${INSTALL_DIR}/uplink" ]; then
        print_info "Directory already exists, pulling latest..."
        cd "${INSTALL_DIR}/uplink"
        git pull origin master 2>/dev/null || true
    else
        print_info "Cloning repository..."
        mkdir -p "$INSTALL_DIR"
        git clone -b master "https://github.com/makscee/void.git" "$INSTALL_DIR" 2>/dev/null || true
        cd "${INSTALL_DIR}/uplink"
    fi

    print_success "Repository ready ✓"
    echo ""
}

install_uplink() {
    print_step "4" "Installing Uplink..."

    # Install Python dependencies
    print_info "Installing Python dependencies..."
    pip3 install -q -r requirements.txt 2>/dev/null || pip install -q -r requirements.txt

    # Create environment file
    print_info "Creating environment file..."
    cat > .env << EOF
OVERSEER_URL=$OVERSEER_URL
SATELLITE_NAME=$SATELLITE_NAME
SATELLITE_IP=$SATELLITE_IP
EOF

    print_success "Uplink installed ✓"
    echo ""
}

create_service() {
    print_step "5" "Creating service..."

    if is_macos; then
        create_macos_service
    else
        create_linux_service
    fi

    echo ""
}

create_linux_service() {
    print_info "Creating systemd service (Linux)..."

    # Create systemd service file
    cat > /etc/systemd/system/void-uplink.service << 'EOF'
[Unit]
Description=Void Uplink - Satellite Agent
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$(pwd)
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=$(pwd)/.env
ExecStart=/usr/bin/python3 $(pwd)/main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Reload and enable systemd
    systemctl daemon-reload
    systemctl enable void-uplink

    print_success "Systemd service created ✓"
}

create_macos_service() {
    print_info "Creating launchd service (macOS)..."

    # Create LaunchAgents directory
    LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
    mkdir -p "$LAUNCH_AGENTS"

    # Get Python3 path
    PYTHON_PATH=$(which python3)
    if [ -z "$PYTHON_PATH" ]; then
        PYTHON_PATH="/usr/bin/python3"
    fi

    # Create plist file
    cat > "$LAUNCH_AGENTS/com.void.uplink.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.void.uplink</string>

    <key>ProgramArguments</key>
    <array>
        <string>$PYTHON_PATH</string>
        <string>$(pwd)/main.py</string>
    </array>

    <key>WorkingDirectory</key>
    <string>$(pwd)</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>OVERSEER_URL</key>
        <string>$OVERSEER_URL</string>
        <key>SATELLITE_NAME</key>
        <string>$SATELLITE_NAME</string>
        <key>SATELLITE_IP</key>
        <string>$SATELLITE_IP</string>
    </dict>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/tmp/void-uplink.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/void-uplink.err</string>

    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF

    # Load the service
    launchctl load "$LAUNCH_AGENTS/com.void.uplink.plist" 2>/dev/null || true

    print_success "Launchd service created ✓"
}

start_service() {
    print_step "6" "Starting Uplink service..."

    if is_macos; then
        start_macos_service
    else
        start_linux_service
    fi

    # Wait for service to start
    sleep 3

    # Check if service is running
    check_service_status
}

start_linux_service() {
    print_info "Starting systemd service..."
    systemctl start void-uplink

    print_info "Waiting for service to start..."
    sleep 3

    if systemctl is-active --quiet void-uplink; then
        print_success "Uplink service started successfully! ✓"
    else
        print_error "Uplink service failed to start"
        echo ""
        print_info "Check logs:"
        echo "   ${BOLD}journalctl -u void-uplink -n 50${NC}"
        exit 1
    fi
}

start_macos_service() {
    print_info "Starting launchd service..."

    # Start using launchctl
    launchctl start ~/Library/LaunchAgents/com.void.uplink.plist 2>/dev/null || true

    # Wait and check if running
    sleep 2

    # Check if python process is running our script
    if pgrep -f "python.*void.*uplink" > /dev/null; then
        print_success "Uplink service started successfully! ✓"
    else
        print_warning "Service may not have started. Checking logs..."
        echo ""
        print_info "Check logs:"
        echo "   ${BOLD}tail -f /tmp/void-uplink.log${NC}"
    fi
}

register_satellite() {
    print_step "7" "Registering with Overseer..."

    # Try to register
    local response=$(curl -s -X POST "${OVERSEER_URL}/satellite/register" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$SATELLITE_NAME\",
            \"ip_address\": \"$SATELLITE_IP\",
            \"hostname\": \"$SATELLITE_HOSTNAME\",
            \"capabilities\": [\"docker\"]
        }")

    if echo "$response" | grep -q "api_key"; then
        API_KEY=$(echo "$response" | grep -o '"api_key":"[^"]*' | cut -d'"' -f4)

        print_success "Satellite registered successfully! ✓"
        echo ""
        echo -e "${BOLD}${GREEN}╔══════════════════════════════╗${NC}"
        echo -e "${BOLD}${GREEN}║  ${BOLD}API KEY: ${API_KEY}${NC}  ${BOLD}                   ║${NC}"
        echo -e "${BOLD}${GREEN}╚════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  IMPORTANT: Save this API key!${NC}"
        echo -e "${YELLOW}   You'll need it for Overseer operations${NC}"
        echo ""

        # Save to environment file
        echo "VOID_UPLINK_API_KEY=$API_KEY" >> .env

        echo -e "${BLUE}💡 Add to your shell:${NC}"
        echo -e "   ${BOLD}export VOID_UPLINK_API_KEY=${API_KEY}${NC}"
        echo ""
    else
        print_error "Failed to register with Overseer"
        echo ""
        echo "Response:"
        echo "$response"
        exit 1
    fi
}

check_service_status() {
    print_info "Checking service status..."

    if is_macos; then
        if pgrep -f "python.*void.*uplink" > /dev/null; then
            print_success "Uplink is running ✓"
        else
            print_warning "Uplink may not be running"
            echo ""
            print_info "Check logs: ${BOLD}tail -f /tmp/void-uplink.log${NC}"
        fi
    else
        if systemctl is-active --quiet void-uplink; then
            print_success "Uplink is running ✓"
        else
            print_error "Uplink is not running"
            echo ""
            print_info "Check logs: ${BOLD}journalctl -u void-uplink -n 50${NC}"
            exit 1
        fi
    fi
}

show_completion_message() {
    echo ""
    echo -e "${CYAN}╔═════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}          ${BOLD}${GREEN}Installation Complete!${NC}                          ${CYAN}           ║${NC}"
    echo -e "${CYAN}╚═════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo ""
    echo -e "${BLUE}1.${NC} Verify Overseer connection:"
    echo -e "   ${BOLD}curl ${OVERSEER_URL}/health${NC}"
    echo ""
    echo -e "${BLUE}2.${NC} Check Uplink status:"
    if is_macos; then
        echo -e "   ${BOLD}curl http://localhost:8001/health${NC}"
        echo ""
        echo -e "   ${BOLD}View logs: tail -f /tmp/void-uplink.log${NC}"
    else
        echo -e "   ${BOLD}systemctl status void-uplink${NC}"
        echo ""
        echo -e "   ${BOLD}View logs: journalctl -u void-uplink -f${NC}"
    fi
    echo ""
    echo -e "${BLUE}3.${NC} Create your first Capsule:"
    echo -e "   ${BOLD}void capsule create <name> <satellite_id> <git_url>${NC}"
    echo ""
    echo -e "${BLUE}4.${NC} View Satellite status:"
    echo -e "   ${BOLD}void satellite list${NC}"
    echo ""
}

show_manual_start_info() {
    echo ""
    echo -e "${YELLOW}╔═════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}  ${BOLD}Manual Start Instructions${NC}                                ${YELLOW}           ║${NC}"
    echo -e "${YELLOW}╚═════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}To manually start Uplink:${NC}"
    echo ""
    echo -e "${BOLD}cd $(pwd)${NC}"
    echo -e "${BOLD}python3 main.py${NC}"
    echo ""
    echo -e "${BLUE}Or with environment variables:${NC}"
    echo -e "${BOLD}OVERSEER_URL=${OVERSEER_URL} python3 main.py${NC}"
    echo ""
}

# Main installation flow
main() {
    print_header

    # Step 1: Check dependencies
    check_dependencies

    # Step 2: Collect configuration
    collect_configuration

    # Confirm installation
    echo ""
    echo -e "${BOLD}Installation Summary:${NC}"
    echo -e "  Satellite Name:    ${GREEN}${SATELLITE_NAME}${NC}"
    echo -e "  Hostname:          ${SATELLITE_HOSTNAME}"
    echo -e "  IP Address:        ${SATELLITE_IP}"
    echo -e "  Overseer URL:     ${OVERSEER_URL}"
    echo -e "  Platform:          $(uname -s)"
    echo ""

    echo -n "  ${YELLOW}Proceed with installation? [Y/n]:${NC} "
    read REPLY

    if [[ "$REPLY" =~ ^[Nn]$ ]]; then
        echo ""
        print_error "Installation cancelled"
        exit 0
    fi

    echo ""

    # Step 3: Clone repository
    clone_repo

    # Step 4: Install Uplink
    install_uplink

    # Step 5: Create service
    create_service

    # Step 6: Start service
    start_service

    # Step 7: Register with Overseer
    register_satellite

    # Show completion message
    show_completion_message

    # Show manual start info (for Mac users)
    if is_macos; then
        show_manual_start_info
    fi
}

# Run main function
main
