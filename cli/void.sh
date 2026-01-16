#!/bin/bash

# Void CLI - Manage Capsules and Satellites via Overseer
# Usage: void <command> [options]

OVERSEER_URL="${VOID_OVERSEER_URL:-http://localhost:8000}"
OVERSEER_API_KEY="${VOID_API_KEY:-}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
RESET='\033[0m'


def info() {
    echo -e "${BLUE}ℹ $1${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${RESET}"
}

def success() {
    echo -e "${GREEN}✓ $1${NC}"
}

def error() {
    echo -e "${RED}✗ $1${NC}"
}

def warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}


# Source capsule-create.py
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CAPSULE_CREATE="$SCRIPT_DIR/capsule-create.py"


# API wrapper
api_call() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="${3:-}"

    if [ -z "$OVERSEER_API_KEY" ]; then
        error "VOID_API_KEY environment variable not set"
        return 1
    fi

    curl -s -X "$method" "$OVERSEER_URL${endpoint}" \
        -H "Content-Type: application/json" \
        -H "X-API-Key: ${OVERSEER_API_KEY}" \
        -d "$data"
        return 0
}


# Commands
capsule_list() {
    info "Fetching capsules from Overseer..."
    local response=$(api_call "/capsules" "GET" "{}")
    
    if [ -z "$response" ]; then
        error "No response from Overseer"
        return 1
    fi
    
    echo "$response" | jq -r 'if .capsules then .capsules else empty'
}


capsule_create() {
    local name="$1"
    local satellite_id="$2"
    local git_url="$3"
    shift 3
    
    if [ -z "$name" ] || [ -z "$satellite_id" ] || [ -z "$git_url" ]; then
        error "Usage: void capsule create <name> <satellite_id> <git_url>"
        return 1
    fi
    
    # Read docker-compose.yml from current directory
    if [ ! -f "docker-compose.yml" ]; then
        error "docker-compose.yml not found in current directory"
        return 1
    fi
    
    local compose_content
    compose_content=$(cat docker-compose.yml)
    
    # Ask about environment flags
    local flags="{}"
    info "Environment flags (comma-separated, press Enter when done):"
    
    while true; do
        read -p "  1. Rust support [y/N]: "
        local flag_input
        read -p "   Rust support [y/N]: "
        if [ "$flag_input" = "y" ]; then
            flags["rust"]='y'
            success "  ✓ Rust support enabled"
        fi
        ;;
        read -p "  2. OpenCode support [y/N]: "
        local flag_input
        read -p "   OpenCode support [y/N]: "
        if [ "$flag_input" = "y" ]; then
            flags["opencode"]='y'
            success "  ✓ OpenCode support enabled"
        fi
        ;;
        
        # Ask for git credentials
        info ""
        read -p "  3. Git username (for commits, leave empty for defaults): "
        local git_user
        read -p "   Git username ${git_user:-default} "
        
        # Ask for SSH key
        info ""
        read -p "   4. Git SSH key (for private repos, leave empty for public): "
        local git_ssh_key
        read -p "   Git SSH key ${git_ssh_key:-skip} "
        
        # Validate flags are not empty
        if [ "${flags}" == "{}" ]; then
            error "No flags selected. Exiting."
            return 1
        fi
        
        # Ask for SSH access preference
        info ""
        read -p "  5. SSH access preference [auto/local/both/skip]: "
        local ssh_pref
        ssh_pref=$(echo "$ssh_pref" | tr '[:upper:]' | cut -d1)
        
        flags["ssh"]="$ssh_pref"
        
        # Ask if ready to proceed
        info ""
        read -p "  ${YELLOW}Create Capsule '${name}'? [y/N]: ${RESET} "
        local confirm
        read confirm
        
        if [ "$confirm" != "y" ]; then
            echo "Cancelled"
            return 1
        fi
    done
    
    # Validate docker-compose.yml
    info ""
    is_valid=1
    issues=()
    
    # Check for services
    while IFS= read -r service; do
            service=$(echo "$service" | sed 's/^[[:space:]]*//')
            
            if grep -q "image:" "$compose_content"; then
                issues+=("❌ Service '$service' missing 'image'")
            fi
            
            if grep -q "ports:" "$compose_content"; then
                issues+=("❌ Service '$service' missing 'ports'")
            fi
            
            if grep -q "volumes:" "$compose_content"; then
                issues+=("❌ Service '$service' has host volume mounts - security risk!")
            fi
        done
    
    if [ -n "$issues" ]; then
        error "Invalid docker-compose.yml:"
        for issue in "${issues[@]}"; do
            echo "  • $issue"
        done
        return 1
    fi
    
    # Build data object
    local data="{\"name\": \"$name\", \"satellite_id\": $satellite_id, \"git_url\": \"$git_url\", \"compose_file\": $(echo "$compose_content" | jq -Rs .), \"rust_support\": $flags.rust, \"opencode_support\": $flags.opencode, \"git_user\": \"$git_user\", \"git_ssh_key\": \"$git_ssh_key\", \"ssh_access\": \"$ssh_pref\"}"
    
    # Create capsule
    info "Creating Capsule '$name}' on Overseer..."
    local response=$(api_call "/capsules" "POST" "$data")
    
    if [ -z "$response" ] || ! echo "$response" | grep -q "capsule_id"; then
        error "Failed to create Capsule"
        return 1
    fi
    
    local capsule_id=$(echo "$response" | grep -o '"capsule_id":"[^"]*' | cut -d':' -f2)
    
    success "Capsule '$name}' created with ID: $capsule_id"
    info "Deploy it with: void capsule deploy $capsule_id"
}


capsule_deploy() {
    local capsule_id="$1"

    if [ -z "$capsule_id" ]; then
        error "Usage: void capsule deploy <capsule_id>"
        return 1
    fi
    
    info "Deploying Capsule $capsule_id..."
    local response=$(api_call "/capsules/$capsule_id/deploy" "POST" "{}")
    
    if [ -z "$response" ]; then
        error "No response from Overseer"
        return 1
    fi
    
    success "Capsule $capsule_id deployed successfully"
}


capsule_stop() {
    local capsule_id="$1"

    if [ -z "$capsule_id" ]; then
        error "Usage: void capsule stop <capsule_id>"
        return 1
    fi
    
    info "Stopping Capsule $capsule_id..."
    local response=$(api_call "/capsules/$capsule_id/stop" "POST" "{\"capsule_id\": $capsule_id}")
    
    if [ -z "$response" ]; then
        error "No response from Overseer"
        return 1
    fi
    
    success "Capsule $capsule_id stopped successfully"
}


capsule_logs() {
    local capsule_id="$1"
    local tail="${2:-100}"

    if [ -z "$capsule_id" ]; then
        error "Usage: void capsule logs <capsule_id> [tail]"
        return 1
    fi
    
    info "Fetching logs from Capsule $capsule_id (tail: $tail)..."
    local response=$(api_call "/capsules/$capsule_id/logs?tail=$tail" "GET" "")
    
    if [ -z "$response" ]; then
        error "No response from Overseer"
        return 1
    fi
    
    echo "$response"
}


satellite_register() {
    local name="$1"

    if [ -z "$name" ]; then
        error "Usage: void satellite register <name>"
        return 1
    fi
    
    # Get system info
    local hostname=$(hostname)
    local ip_address=$(hostname -I | awk '{print $1}')
    
    info "Registering satellite: $name..."
    info "  Hostname: $hostname"
    info "  IP: $ip_address"
    
    local response=$(api_call "/satellite/register" "POST" "{\"name\": \"$name\", \"ip_address\": \"$ip_address\", \"hostname\": \"$hostname\", \"capabilities\": [\"docker\"]}")
    
    if [ -z "$response" ]; then
        error "Failed to register satellite: $response"
        return 1
    fi
    
    local api_key=$(echo "$response" | grep -o '"api_key":"[^"]*' | cut -d'"' -f4)
    
    success "Satellite '$name' registered!"
    echo ""
    echo "🔑 API Key: $api_key"
    echo ""
    warn "⚠️  Save this key! You'll need it for Overseer operations."
    echo ""
    info "💡 Add to your shell:"
    echo "   export VOID_UPLINK_API_KEY=$api_key"
    echo ""
}


satellite_list() {
    info "Fetching satellites from Overseer..."
    api_call "/satellites" | jq '.'
}


show_help() {
    cat << 'HELP'
${GREEN}Void CLI - Distributed Infrastructure Management${NC}

${BLUE}Capsule Commands:${NC}
${GREEN}  void capsule create <name> <satellite_id> <git_url>
${GREEN}  void capsule list
${GREEN}  void capsule deploy <id>
${GREEN}  void capsule stop <id>
${GREEN}  void capsule logs <id> <tail>

${BLUE}Satellite Commands:${NC}
${GREEN}  void satellite register <name>
${GREEN}  void satellite list
${GREEN}  void satellite status

${YELLOW}Environment Variables:${NC}
${GREEN}  VOID_OVERSEER_URL     Overseer API URL (default: http://localhost:8000)
${GREEN}  VOID_API_KEY          Overseer API key (required)

${YELLOW}Examples:${NC}
${GREEN}  void capsule create my-app 1 https://github.com/user/my-app.git
${GREEN}  void capsule deploy 1
${GREEN}  void capsule logs 1
${GREEN}  void satellite register my-mac
${GREEN}  void satellite list

${BLUE}Capsule Creator Features:${NC}
${CYAN}🦀 Rust support${NC}: Automatically sets up Rust toolchain
${CYAN}🧪 OpenCode support${NC}: Adds OpenCode service for browser access
${CYAN}📦 Git integration${NC}: Stores your git credentials for commits
${CYAN}🔧 Docker Compose validation${NC}: Checks docker-compose.yml for security issues
${CYAN}🤖 SSH access${NC}: Configurable SSH connection method
${CYAN}⚡ Multi-satellite${NC}: Deploy to multiple Satellites from one place

HELP
EOF
}


main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    local command="$1"
    local subcommand="${2:-}"
    shift 2
    
    case "$command" in
        capsule)
            case "$subcommand" in
                create)
                    source "$CAPSULE_CREATE" capsule_create "$@"
                    ;;
                list)
                    source "$CAPSULE_CREATE" capsule_list
                    ;;
                deploy)
                    local capsule_id="$1"
                    shift
                    capsule_deploy "$capsule_id"
                    ;;
                stop)
                    local capsule_id="$1"
                    shift
                    capsule_stop "$capsule_id"
                    ;;
                logs)
                    local capsule_id="$1"
                    shift
                    local tail="${2:-100}"
                    capsule_logs "$capsule_id" "$tail"
                    ;;
                *)
                    error "Unknown capsule command: $command"
                    show_help
                    ;;
                esac
            ;;
        satellite)
            case "$subcommand" in
                register)
                    satellite_register "$@"
                    ;;
                list)
                    satellite_list
                    ;;
                *)
                    error "Unknown satellite command: $command"
                    show_help
                    ;;
                esac
            ;;
        *)
            error "Unknown command: $command"
            show_help
            ;;
    esac
}
