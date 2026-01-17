#!/bin/bash
# VoidNet Bash Client - Lightweight CLI for Void infrastructure
# Usage: voidnet <command> <subcommand> [options]

set -e

# Configuration
VOIDNET_DIR="${VOIDNET_DIR:-$HOME/.voidnet}"
CONFIG_FILE="$VOIDNET_DIR/config"

# Default values (can be overridden by env vars or config)
OVERSEER_URL="${VOID_OVERSEER_URL:-}"
API_KEY="${VOID_API_KEY:-}"

# Load configuration from file if it exists
if [ -f "$CONFIG_FILE" ]; then
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^#.*$ ]] && continue
        [[ -z "$key" ]] && continue

        # Remove quotes from values
        value=$(echo "$value" | sed 's/^["\x27]*//;s/["\x27]*$//')

        case "$key" in
            overseer_url)
                [ -z "$OVERSEER_URL" ] && OVERSEER_URL="$value"
                ;;
            api_key)
                [ -z "$API_KEY" ] && API_KEY="$value"
                ;;
            client_name)
                CLIENT_NAME="$value"
                ;;
        esac
    done < "$CONFIG_FILE"
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# API Functions
api_call() {
    local endpoint="$1"
    local method="${2:-GET}"
    local data="$3"

    local url="$OVERSEER_URL$endpoint"

    if [ -z "$OVERSEER_URL" ]; then
        echo -e "${RED}Error: Overseer URL not configured${NC}"
        echo "Set VOID_OVERSEER_URL environment variable or configure in $CONFIG_FILE"
        return 1
    fi

    if [ "$method" = "GET" ]; then
        curl -s -H "X-API-Key: $API_KEY" "$url" 2>/dev/null
    elif [ "$method" = "POST" ]; then
        curl -s -X POST -H "X-API-Key: $API_KEY" \
             -H "Content-Type: application/json" \
             -d "$data" "$url" 2>/dev/null
    elif [ "$method" = "DELETE" ]; then
        curl -s -X DELETE -H "X-API-Key: $API_KEY" "$url" 2>/dev/null
    fi
}

# Check API key validity
check_config() {
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}Error: API key not configured${NC}"
        echo "Set VOID_API_KEY environment variable or configure in $CONFIG_FILE"
        echo "Get your admin API key from overseer machine"
        return 1
    fi

    if [ -z "$OVERSEER_URL" ]; then
        echo -e "${RED}Error: Overseer URL not configured${NC}"
        echo "Set VOID_OVERSEER_URL environment variable or configure in $CONFIG_FILE"
        return 1
    fi
}

# Display help
show_help() {
    cat << EOF
${BLUE}VoidNet CLI - Lightweight Client for Void Infrastructure${NC}

${GREEN}Usage:${NC}
  voidnet <command> <subcommand> [options]

${GREEN}Commands:${NC}
  ${BLUE}capsule${NC}      Manage capsules
    list                  List all capsules
    connect <name>        SSH into a capsule
    status <name>         Show capsule status

  ${BLUE}satellite${NC}     Manage satellites
    list                  List all satellites
    connect <name>        SSH into a satellite
    status <name>         Show satellite status

  ${BLUE}config${NC}        Show configuration
    show                  Display current configuration

  ${BLUE}health${NC}        Check overseer health

  ${BLUE}help${NC}          Show this help message

${GREEN}Environment Variables:${NC}
  VOID_OVERSEER_URL    Overseer API URL (default: from config)
  VOID_API_KEY          Admin API key (default: from config)

${GREEN}Examples:${NC}
  voidnet capsule list
  voidnet satellite list
  voidnet capsule connect my-app
  voidnet health

EOF
}

# Display satellites in table format
display_satellites() {
    local response="$1"

    # Check for error in response
    if echo "$response" | grep -q '"detail"'; then
        local error=$(echo "$response" | grep -o '"detail":"[^"]*"' | cut -d'"' -f4)
        echo -e "${RED}Error: $error${NC}"
        return 1
    fi

    # Parse satellites from JSON
    local count=$(echo "$response" | grep -o '"satellites":\[.*\]' | grep -o '\[.*\]' | grep -o '{' | wc -l | tr -d ' ')

    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}No satellites found${NC}"
        return 0
    fi

    echo -e "${BLUE}Satellites ($count):${NC}"
    echo ""
    printf "%-4s %-20s %-20s %-15s %-20s\n" "ID" "Name" "Hostname" "Status" "Last Heartbeat"
    printf "%s\n" "$(printf '%*s' 90 | tr ' ' '-')"

    # Extract satellite info and display
    echo "$response" | grep -oE '"id":[0-9]+|"name":"[^"]*"|"hostname":"[^"]*"|"status":"[^"]*"|"last_heartbeat":"[^"]*"' | \
    paste - - - - - | \
    while read id_line name_line hostname_line status_line heartbeat_line; do
        id=$(echo "$id_line" | cut -d':' -f2)
        name=$(echo "$name_line" | cut -d'"' -f4)
        hostname=$(echo "$hostname_line" | cut -d'"' -f4)
        status=$(echo "$status_line" | cut -d'"' -f4)
        heartbeat=$(echo "$heartbeat_line" | cut -d'"' -f4 | cut -d'T' -f1)

        # Color status
        case "$status" in
            online)
                status="${GREEN}online${NC}"
                ;;
            offline)
                status="${RED}offline${NC}"
                ;;
            *)
                status="${YELLOW}$status${NC}"
                ;;
        esac

        printf "%-4s %-20s %-20s %b %-20s\n" "$id" "$name" "$hostname" "$status" "$heartbeat"
    done
}

# Display capsules in table format
display_capsules() {
    local response="$1"

    # Check for error in response
    if echo "$response" | grep -q '"detail"'; then
        local error=$(echo "$response" | grep -o '"detail":"[^"]*"' | cut -d'"' -f4)
        echo -e "${RED}Error: $error${NC}"
        return 1
    fi

    # Parse capsules from JSON
    local count=$(echo "$response" | grep -o '"capsules":\[.*\]' | grep -o '\[.*\]' | grep -o '{' | wc -l | tr -d ' ')

    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}No capsules found${NC}"
        return 0
    fi

    echo -e "${BLUE}Capsules ($count):${NC}"
    echo ""
    printf "%-4s %-25s %-20s %-15s %-20s\n" "ID" "Name" "Satellite" "Status" "Created"
    printf "%s\n" "$(printf '%*s' 90 | tr ' ' '-')"

    # Extract capsule info and display
    echo "$response" | grep -oE '"id":[0-9]+|"name":"[^"]*"|"satellite_name":"[^"]*"|"status":"[^"]*"|"created_at":"[^"]*"' | \
    paste - - - - - | \
    while read id_line name_line satellite_line status_line created_line; do
        id=$(echo "$id_line" | cut -d':' -f2)
        name=$(echo "$name_line" | cut -d'"' -f4)
        satellite=$(echo "$satellite_line" | cut -d'"' -f4)
        status=$(echo "$status_line" | cut -d'"' -f4)
        created=$(echo "$created_line" | cut -d'"' -f4 | cut -d'T' -f1)

        # Color status
        case "$status" in
            running)
                status="${GREEN}running${NC}"
                ;;
            stopped)
                status="${RED}stopped${NC}"
                ;;
            *)
                status="${YELLOW}$status${NC}"
                ;;
        esac

        printf "%-4s %-25s %-20s %b %-20s\n" "$id" "$name" "$satellite" "$status" "$created"
    done
}

# Find satellite hostname by name
find_satellite_hostname() {
    local name="$1"
    local response=$(api_call "/satellites" "GET")
    local hostname=$(echo "$response" | grep -oE '"name":"'"$name"'[^"]*"|"hostname":"[^"]*"' | \
                    grep -A1 '"name":"'"$name"'"' | grep '"hostname"' | cut -d'"' -f4)
    echo "$hostname"
}

# Find satellite IP by name
find_satellite_ip() {
    local name="$1"
    local response=$(api_call "/satellites" "GET")
    local ip=$(echo "$response" | grep -oE '"name":"'"$name"'[^"]*"|"ip_address":"[^"]*"' | \
               grep -A1 '"name":"'"$name"'"' | grep '"ip_address"' | cut -d'"' -f4)
    echo "$ip"
}

# Connect to capsule
connect_to_capsule() {
    local capsule_name="$1"

    check_config || return 1

    echo -e "${BLUE}Connecting to capsule: $capsule_name${NC}"

    # Get capsule info
    local response=$(api_call "/capsules" "GET")

    # Find the capsule
    local capsule=$(echo "$response" | grep -oE '"name":"'"$capsule_name"'[^"]*"|"satellite_name":"[^"]*"|"git_url":"[^"]*"' | \
                    grep -A2 '"name":"'"$capsule_name"'"')

    if [ -z "$capsule" ]; then
        echo -e "${RED}Error: Capsule '$capsule_name' not found${NC}"
        echo "Run 'voidnet capsule list' to see available capsules"
        return 1
    fi

    local satellite=$(echo "$capsule" | grep '"satellite_name"' | cut -d'"' -f4)
    echo "Capsule is on satellite: $satellite"

    # Get satellite hostname
    local satellite_hostname=$(find_satellite_hostname "$satellite")
    if [ -z "$satellite_hostname" ]; then
        echo -e "${RED}Error: Could not find satellite hostname for $satellite${NC}"
        return 1
    fi

    echo "Connecting to $satellite_hostname..."
    echo ""

    # SSH to satellite and show containers
    ssh "$satellite_hostname" "docker ps --filter 'name=${capsule_name}' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

    echo ""
    read -p "Enter container name to connect (or press Ctrl+C to cancel): " container_name

    if [ -n "$container_name" ]; then
        echo -e "${GREEN}Connecting to container: $container_name${NC}"
        ssh -t "$satellite_hostname" "docker exec -it $container_name /bin/bash || docker exec -it $container_name /bin/sh"
    fi
}

# Connect to satellite
connect_to_satellite() {
    local satellite_name="$1"

    check_config || return 1

    echo -e "${BLUE}Connecting to satellite: $satellite_name${NC}"

    # Get satellite hostname
    local satellite_hostname=$(find_satellite_hostname "$satellite_name")
    if [ -z "$satellite_hostname" ]; then
        echo -e "${RED}Error: Satellite '$satellite_name' not found${NC}"
        echo "Run 'voidnet satellite list' to see available satellites"
        return 1
    fi

    echo "Connecting to $satellite_hostname..."
    ssh "$satellite_hostname"
}

# Show capsule status
show_capsule_status() {
    local capsule_name="$1"

    check_config || return 1

    echo -e "${BLUE}Capsule status: $capsule_name${NC}"

    # Get capsule info
    local response=$(api_call "/capsules" "GET")

    # Find the capsule
    local capsule=$(echo "$response" | grep -oE '"name":"'"$capsule_name"'[^"]*"|"satellite_name":"[^"]*"|"status":"[^"]*"|"git_url":"[^"]*"|"git_branch":"[^"]*"' | \
                    grep -A4 '"name":"'"$capsule_name"'"')

    if [ -z "$capsule" ]; then
        echo -e "${RED}Error: Capsule '$capsule_name' not found${NC}"
        echo "Run 'voidnet capsule list' to see available capsules"
        return 1
    fi

    local satellite=$(echo "$capsule" | grep '"satellite_name"' | cut -d'"' -f4)
    local status=$(echo "$capsule" | grep '"status"' | cut -d'"' -f4)
    local git_url=$(echo "$capsule" | grep '"git_url"' | cut -d'"' -f4)
    local git_branch=$(echo "$capsule" | grep '"git_branch"' | cut -d'"' -f4)

    echo "Satellite: $satellite"
    echo "Status: $status"
    echo "Git URL: $git_url"
    echo "Git Branch: $git_branch"
}

# Show satellite status
show_satellite_status() {
    local satellite_name="$1"

    check_config || return 1

    echo -e "${BLUE}Satellite status: $satellite_name${NC}"

    # Get satellite info
    local response=$(api_call "/satellites" "GET")

    # Find the satellite
    local satellite=$(echo "$response" | grep -oE '"name":"'"$satellite_name"'[^"]*"|"hostname":"[^"]*"|"ip_address":"[^"]*"|"status":"[^"]*"|"last_heartbeat":"[^"]*"' | \
                    grep -A4 '"name":"'"$satellite_name"'"')

    if [ -z "$satellite" ]; then
        echo -e "${RED}Error: Satellite '$satellite_name' not found${NC}"
        echo "Run 'voidnet satellite list' to see available satellites"
        return 1
    fi

    local hostname=$(echo "$satellite" | grep '"hostname"' | cut -d'"' -f4)
    local ip=$(echo "$satellite" | grep '"ip_address"' | cut -d'"' -f4)
    local status=$(echo "$satellite" | grep '"status"' | cut -d'"' -f4)
    local heartbeat=$(echo "$satellite" | grep '"last_heartbeat"' | cut -d'"' -f4)

    echo "Hostname: $hostname"
    echo "IP Address: $ip"
    echo "Status: $status"
    echo "Last Heartbeat: $heartbeat"
}

# Show configuration
show_config() {
    echo -e "${BLUE}VoidNet Configuration:${NC}"
    echo ""
    echo "Config file: $CONFIG_FILE"
    echo "Overseer URL: ${OVERSEER_URL:-Not set}"
    echo "API Key: ${API_KEY:+***configured***}"
    echo "Client Name: ${CLIENT_NAME:-Not set}"
}

# Check health
check_health() {
    echo -e "${BLUE}Checking Overseer health...${NC}"
    echo ""

    local response=$(curl -s "$OVERSEER_URL/health" 2>/dev/null)

    if [ -z "$response" ]; then
        echo -e "${RED}Error: Could not connect to overseer at $OVERSEER_URL${NC}"
        return 1
    fi

    local status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    local satellites=$(echo "$response" | grep -o '"satellites":[0-9]*' | cut -d':' -f2)
    local capsules=$(echo "$response" | grep -o '"capsules":[0-9]*' | cut -d':' -f2)

    echo "Status: $status"
    echo "Satellites: $satellites"
    echo "Capsules: $capsules"

    if [ "$status" = "healthy" ]; then
        echo -e "\n${GREEN}✓ Overseer is healthy${NC}"
        return 0
    else
        echo -e "\n${RED}✗ Overseer is not healthy${NC}"
        return 1
    fi
}

# Main command parsing
case "${1:-help}" in
    help|--help|-h)
        show_help
        ;;

    capsule)
        case "${2:-help}" in
            list)
                check_config || exit 1
                local response=$(api_call "/capsules" "GET")
                display_capsules "$response"
                ;;
            connect)
                if [ -z "$3" ]; then
                    echo -e "${RED}Error: Capsule name required${NC}"
                    echo "Usage: voidnet capsule connect <name>"
                    exit 1
                fi
                connect_to_capsule "$3"
                ;;
            status)
                if [ -z "$3" ]; then
                    echo -e "${RED}Error: Capsule name required${NC}"
                    echo "Usage: voidnet capsule status <name>"
                    exit 1
                fi
                show_capsule_status "$3"
                ;;
            help|--help|-h|*)
                echo -e "${BLUE}Capsule Commands:${NC}"
                echo "  list              List all capsules"
                echo "  connect <name>    SSH into a capsule"
                echo "  status <name>     Show capsule status"
                ;;
        esac
        ;;

    satellite)
        case "${2:-help}" in
            list)
                check_config || exit 1
                local response=$(api_call "/satellites" "GET")
                display_satellites "$response"
                ;;
            connect)
                if [ -z "$3" ]; then
                    echo -e "${RED}Error: Satellite name required${NC}"
                    echo "Usage: voidnet satellite connect <name>"
                    exit 1
                fi
                connect_to_satellite "$3"
                ;;
            status)
                if [ -z "$3" ]; then
                    echo -e "${RED}Error: Satellite name required${NC}"
                    echo "Usage: voidnet satellite status <name>"
                    exit 1
                fi
                show_satellite_status "$3"
                ;;
            help|--help|-h|*)
                echo -e "${BLUE}Satellite Commands:${NC}"
                echo "  list              List all satellites"
                echo "  connect <name>    SSH into a satellite"
                echo "  status <name>     Show satellite status"
                ;;
        esac
        ;;

    config)
        case "${2:-help}" in
            show)
                show_config
                ;;
            help|--help|-h|*)
                echo -e "${BLUE}Config Commands:${NC}"
                echo "  show              Display current configuration"
                ;;
        esac
        ;;

    health)
        check_health
        ;;

    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
