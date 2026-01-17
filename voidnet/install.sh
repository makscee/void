#!/bin/bash
# VoidNet Unified Installer
# Serves from http://mcow:8000/install-client.sh
# Supports both client and satellite installation

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

OVERSEER_URL="${OVERSEER_URL:-http://localhost:8000}"
DEFAULT_OVERSEER_URL="http://localhost:8000"

# Parse arguments
MODE=""
NON_INTERACTIVE=false
CLIENT_NAME=""
API_KEY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --client)
            MODE="client"
            shift
            ;;
        --satellite)
            MODE="satellite"
            shift
            ;;
        --name)
            CLIENT_NAME="$2"
            shift 2
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--client|--satellite] [--name NAME] [--api-key KEY] [--non-interactive]"
            exit 1
            ;;
    esac
done

# Interactive mode - ask what to install
if [ "$NON_INTERACTIVE" = false ] && [ -z "$MODE" ]; then
    echo -e "${BLUE}VoidNet Unified Installer${NC}"
    echo ""
    echo "What would you like to install?"
    echo "  1) ${GREEN}Client${NC} (Mac/Linux/Windows - manage capsules remotely)"
    echo "  2) ${YELLOW}Satellite${NC} (Linux only - host containers)"
    echo ""
    read -p "Choose [1-2]: " CHOICE

    case $CHOICE in
        1) MODE="client" ;;
        2) MODE="satellite" ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
fi

# Client installation
if [ "$MODE" = "client" ]; then
    install_bash_client
# Satellite installation
elif [ "$MODE" = "satellite" ]; then
    install_satellite
fi

install_bash_client() {
    echo ""
    echo -e "${BLUE}Installing VoidNet Client...${NC}"

    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        echo "Error: Please don't run this as root for client installation"
        exit 1
    fi

    # Check for curl
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is required but not found. Please install curl first."
        exit 1
    fi

    # Get client name
    if [ -z "$CLIENT_NAME" ]; then
        if [ "$NON_INTERACTIVE" = true ]; then
            CLIENT_NAME="client-$(hostname)"
        else
            read -p "Enter client name [default: client-$(hostname)]: " INPUT_NAME
            CLIENT_NAME="${INPUT_NAME:-client-$(hostname)}"
        fi
    fi

    # Download the bash client script
    echo "Downloading voidnet client script..."
    VOIDNET_DIR="$HOME/.voidnet"
    mkdir -p "$VOIDNET_DIR"

    # Download the bash client from overseer
    if ! curl -fsSL "$OVERSEER_URL/voidnet-bash.sh" -o "$VOIDNET_DIR/voidnet-bash.sh"; then
        echo "Error: Failed to download voidnet-bash.sh from $OVERSEER_URL"
        exit 1
    fi

    chmod +x "$VOIDNET_DIR/voidnet-bash.sh"

    # Create wrapper script
    echo "Creating voidnet command..."
    VOIDNET_BIN="/usr/local/bin/voidnet"

    # Remove existing if exists
    if [ -f "$VOIDNET_BIN" ]; then
        echo "Removing existing voidnet command..."
        sudo rm -f "$VOIDNET_BIN"
    fi

    # Create new wrapper
    sudo tee "$VOIDNET_BIN" > /dev/null <<EOF
#!/bin/bash
# VoidNet Client Wrapper
# This wrapper calls the bash client script
exec "$HOME/.voidnet/voidnet-bash.sh" "\$@"
EOF

    sudo chmod +x "$VOIDNET_BIN"

    # Create configuration
    create_config

    # Installation complete
    echo ""
    echo -e "${GREEN}✓ VoidNet client installed successfully!${NC}"
    echo ""
    echo "Installation details:"
    echo "  - Client name: $CLIENT_NAME"
    echo "  - Client script: $VOIDNET_DIR/voidnet-bash.sh"
    echo "  - Wrapper script: $VOIDNET_BIN"
    echo "  - Configuration: $VOIDNET_DIR/config"
    echo ""
    echo "Next steps:"
    echo "  1. Try: ${BLUE}voidnet capsule list${NC}"
    echo "  2. Try: ${BLUE}voidnet satellite list${NC}"
    echo "  3. Connect: ${BLUE}voidnet capsule connect <name>${NC}"
    echo ""
    echo "For help: ${BLUE}voidnet --help${NC}"
}

install_satellite() {
    echo ""
    echo -e "${BLUE}Installing VoidNet Satellite...${NC}"

    # Get satellite name
    if [ -z "$CLIENT_NAME" ]; then
        if [ "$NON_INTERACTIVE" = true ]; then
            CLIENT_NAME="satellite-$(hostname)"
        else
            read -p "Enter satellite name [default: satellite-$(hostname)]: " INPUT_NAME
            CLIENT_NAME="${INPUT_NAME:-satellite-$(hostname)}"
        fi
    fi

    # Download and run satellite install script from overseer
    echo "Downloading satellite installer..."
    if ! curl -fsSL "$OVERSEER_URL/install-web.sh" -o /tmp/void-satellite-install.sh; then
        echo "Error: Failed to download satellite installer from $OVERSEER_URL"
        exit 1
    fi

    chmod +x /tmp/void-satellite-install.sh

    # Run satellite installer
    echo "Running satellite installation..."
    /tmp/void-satellite-install.sh --name "$CLIENT_NAME"

    # Clean up
    rm -f /tmp/void-satellite-install.sh
}

create_config() {
    CONFIG_FILE="$VOIDNET_DIR/config"

    if [ -f "$CONFIG_FILE" ]; then
        echo "Configuration file already exists at $CONFIG_FILE"
        if [ "$NON_INTERACTIVE" = false ]; then
            read -p "Overwrite existing config? [y/N]: " OVERWRITE
            if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
                echo "Keeping existing configuration"
                return
            fi
        fi
    fi

    # Get API key
    if [ -z "$API_KEY" ]; then
        if [ "$NON_INTERACTIVE" = true ]; then
            echo "Error: API key required in non-interactive mode. Use --api-key option."
            exit 1
        else
            echo -n "Enter Overseer API key: "
            read -s API_KEY
            echo ""
        fi
    fi

    # Get overseer URL
    OVERSEER_URL_INPUT=""
    if [ "$NON_INTERACTIVE" = true ]; then
        OVERSEER_URL_INPUT="$DEFAULT_OVERSEER_URL"
    else
        read -p "Enter Overseer URL [default: $DEFAULT_OVERSEER_URL]: " OVERSEER_URL_INPUT
        OVERSEER_URL_INPUT="${OVERSEER_URL_INPUT:-$DEFAULT_OVERSEER_URL}"
    fi

    # Write configuration
    cat > "$CONFIG_FILE" <<EOF
# VoidNet Client Configuration
client_name=$CLIENT_NAME
api_key=$API_KEY
overseer_url=$OVERSEER_URL_INPUT
EOF

    echo "Configuration saved to $CONFIG_FILE"
}
