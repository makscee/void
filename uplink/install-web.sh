#!/bin/bash

# Void Uplink Web Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/makscee/void/master/uplink/install-web.sh | bash
# Or: bash <(curl -fsSL https://raw.githubusercontent.com/makscee/void/master/uplink/install-web.sh)
#
# Version: 1.0.0

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
OVERSEER_URL="${OVERSEER_URL:-}"
SATELLITE_NAME="${SATELLITE_NAME:-}"
GITHUB_REPO="${GITHUB_REPO:-makscee/void}"
GITHUB_BRANCH="${GITHUB_BRANCH:-master}"
INSTALL_DIR="${INSTALL_DIR:-/opt/void}"

print_header() {
    clear
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}          ${BOLD}${GREEN}Void Uplink - Satellite Agent${NC}           ${CYAN}           ║${NC}"
    echo -e "${CYAN}╚═════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    local num="$1"
    local text="$2"
    echo -e "${CYAN}[${num}/X]${NC} ${text}"
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

print_menu_item() {
    local num="$1"
    local text="$2"
    echo -e "  ${BOLD}${num})${NC} ${text}"
}

check_dependencies() {
    print_step "1" "Checking dependencies..."

    # Check if running as root or sudo
    if [ "$EUID" -ne 0 ]; then
        print_error "This installer must be run as root"
        echo ""
        echo "Please run: sudo bash <(curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/uplink/install-web.sh)"
        exit 1
    fi
    print_success "Running as root ✓"

    # Check for Python
    if command -v python3 &> /dev/null; then
        print_success "Python 3 found ✓"
    else
        print_warning "Python 3 not found, will install..."
    fi

    # Check for Docker
    if command -v docker &> /dev/null; then
        print_success "Docker found ✓"
    else
        print_warning "Docker not found, will install..."
    fi

    # Check for Git
    if command -v git &> /dev/null; then
        print_success "Git found ✓"
    else
        print_warning "Git not found, will install..."
    fi

    echo ""
}

install_dependencies() {
    print_step "2" "Installing missing dependencies..."

    local deps_to_install=()

    # Detect OS
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        if ! command -v python3 &> /dev/null; then
            deps_to_install+=("python3")
        fi
        if ! command -v docker &> /dev/null; then
            deps_to_install+=("docker.io")
        fi
        if ! command -v git &> /dev/null; then
            deps_to_install+=("git")
        fi

        if [ ${#deps_to_install[@]} -gt 0 ]; then
            echo ""
            print_info "Installing: ${deps_to_install[*]}"
            DEBIAN_FRONTEND=noninteractive apt-get update -qq
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ${deps_to_install[@]}
        fi
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS/Fedora
        if ! command -v python3 &> /dev/null; then
            deps_to_install+=("python3")
        fi
        if ! command -v docker &> /dev/null; then
            deps_to_install+=("docker")
        fi
        if ! command -v git &> /dev/null; then
            deps_to_install+=("git")
        fi

        if [ ${#deps_to_install[@]} -gt 0 ]; then
            echo ""
            print_info "Installing: ${deps_to_install[*]}"
            dnf install -y ${deps_to_install[@]}
        fi
    elif [ "$(uname -s)" = "Darwin" ]; then
        # macOS
        print_info "macOS detected - using Homebrew..."
        if ! command -v python3 &> /dev/null; then
            print_info "Please install Python 3: brew install python3"
        fi
        if ! command -v docker &> /dev/null; then
            print_info "Please install Docker Desktop: https://docs.docker.com/desktop/mac/"
        fi
        if ! command -v git &> /dev/null; then
            print_info "Please install Git: brew install git"
        fi

        if ! command -v python3 &> /dev/null || ! command -v docker &> /dev/null; then
            exit 1
        fi
    else
        print_error "Unsupported operating system"
        exit 1
    fi

    echo ""
    print_success "All dependencies installed ✓"
}

collect_configuration() {
    print_step "3" "Collecting configuration..."

    # Get system info
    SATELLITE_IP=$(hostname -I | awk '{print $1}')
    SATELLITE_HOSTNAME=$(hostname)

    # Ask for Overseer URL
    if [ -z "$OVERSEER_URL" ]; then
        echo ""
        echo -e "${BOLD}Overseer Configuration${NC}"
        echo -e "  ${BLUE}Overseer is the central controller that manages your Satellite${NC}"
        echo ""
        read -p "  ${BLUE}Enter Overseer URL${NC} [${YELLOW}http://localhost:8000${NC}]: " OVERSEER_URL
        echo ""
    fi

    # Ask for Satellite name
    if [ -z "$SATELLITE_NAME" ]; then
        read -p "  ${BLUE}Enter Satellite name${NC} [${YELLOW}${SATELLITE_HOSTNAME}${NC}]: " SATELLITE_NAME
        echo ""
    fi

    print_info "Configuration collected:"
    echo -e "  ${BOLD}Satellite Name:${NC}    ${SATELLITE_NAME}"
    echo -e "  ${BOLD}Hostname:${NC}           ${SATELLITE_HOSTNAME}"
    echo -e "  ${BOLD}IP Address:${NC}       ${SATELLITE_IP}"
    echo -e "  ${BOLD}Overseer URL:${NC}     ${OVERSEER_URL}"
    echo ""
}

clone_repo() {
    print_step "4" "Cloning Void repository..."

    if [ -d "${INSTALL_DIR}/uplink" ]; then
        print_info "Directory already exists, pulling latest..."
        cd "${INSTALL_DIR}/uplink"
        git pull origin ${GITHUB_BRANCH} || true
    else
        print_info "Cloning repository..."
        mkdir -p "$INSTALL_DIR"
        git clone -b "$GITHUB_BRANCH" "https://github.com/${GITHUB_REPO}.git" "$INSTALL_DIR" || true
        cd "${INSTALL_DIR}/uplink"
    fi

    print_success "Repository ready ✓"
    echo ""
}

install_uplink() {
    print_step "5" "Installing Uplink service..."

    # Install Python dependencies
    print_info "Installing Python dependencies..."
    pip3 install -q -r requirements.txt

    # Create environment file
    print_info "Creating environment file..."
    cat > .env << EOF
OVERSEER_URL=$OVERSEER_URL
SATELLITE_NAME=$SATELLITE_NAME
SATELLITE_IP=$SATELLITE_IP
EOF

    # Create systemd service
    print_info "Installing systemd service..."
    envsubst < uplink.service.template > /etc/systemd/system/void-uplink.service

    # Reload systemd
    systemctl daemon-reload

    print_success "Uplink installed ✓"
    echo ""
}

register_satellite() {
    print_step "6" "Registering with Overseer..."

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
        echo -e "${BOLD}${GREEN}╔════════════════════════════════╗${NC}"
        echo -e "${BOLD}${GREEN}║  ${BOLD}API KEY: ${API_KEY}${NC}  ${BOLD}                   ║${NC}"
        echo -e "${BOLD}${GREEN}╚══════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  IMPORTANT: Save this API key!${NC}"
        echo -e "${YELLOW}   You'll need it for Overseer operations${NC}"
        echo ""
        echo -e "${BLUE}💡 Add to your shell:${NC}"
        echo -e "   ${BOLD}export VOID_UPLINK_API_KEY=${API_KEY}${NC}"
        echo ""

        # Start service
        print_step "7" "Starting Uplink service..."

        systemctl enable void-uplink
        systemctl start void-uplink

        # Wait for service to start
        sleep 3

        if systemctl is-active --quiet void-uplink; then
            print_success "Uplink service started successfully! ✓"
            echo ""
            print_info "Service status:"
            echo -e "   ${BOLD}systemctl status void-uplink${NC}"
            echo ""
            print_info "View logs:"
            echo -e "   ${BOLD}journalctl -u void-uplink -f${NC}"
            echo ""
            print_info "API health check:"
            echo -e "   ${BOLD}curl ${OVERSEER_URL}/health${NC}"
            echo ""
            echo -e "${GREEN}═════════════════════════════════════════════════════════${NC}"
            echo -e "${GREEN}       Installation Complete! Your Satellite is Ready.        ${NC}"
            echo -e "${GREEN}═════════════════════════════════════════════════════════${NC}"
        else
            print_error "Uplink service failed to start"
            echo ""
            print_info "Check logs for errors:"
            echo -e "   ${BOLD}journalctl -u void-uplink -n 50${NC}"
            exit 1
        fi
    else
        print_error "Failed to register with Overseer"
        echo ""
        echo "Response:"
        echo "$response"
        exit 1
    fi
}

show_completion_message() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}          ${BOLD}${MAGENTA}Next Steps${NC}                               ${CYAN}           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}1.${NC} Verify Overseer connection:"
    echo -e "   ${BOLD}curl ${OVERSEER_URL}/health${NC}"
    echo ""
    echo -e "${BLUE}2.${NC} Create your first Capsule:"
    echo -e "   ${BOLD}void capsule create <name> <satellite_id> <git_url>${NC}"
    echo ""
    echo -e "${BLUE}3.${NC} View Satellite status:"
    echo -e "   ${BOLD}void satellite list${NC}"
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}Installation Complete! Your Satellite is Ready.           ${CYAN}           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Main installation flow
main() {
    print_header

    # Step 1: Check dependencies
    check_dependencies

    # Step 2: Install missing dependencies
    install_dependencies

    # Step 3: Collect configuration
    collect_configuration

    # Confirm installation
    echo ""
    echo -e "${BOLD}Installation Summary:${NC}"
    echo -e "  Satellite Name:    ${GREEN}${SATELLITE_NAME}${NC}"
    echo -e "  Hostname:          ${SATELLITE_HOSTNAME}"
    echo -e "  IP Address:        ${SATELLITE_IP}"
    echo -e "  Overseer URL:     ${OVERSEER_URL}"
    echo ""

    read -p "  ${YELLOW}Proceed with installation? [Y/n]: " -n 1 -r

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        print_error "Installation cancelled"
        exit 0
    fi

    echo ""

    # Step 4: Clone repository
    clone_repo

    # Step 5: Install Uplink
    install_uplink

    # Step 6: Register with Overseer
    register_satellite

    # Show completion message
    show_completion_message
}

# Run main function
main
