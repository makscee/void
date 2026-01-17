#!/bin/bash

# VoidNet Client Installer for macOS
# Uses virtual environment to avoid Homebrew PEP 668 conflicts

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}VoidNet Client Installer${NC}"
echo "This will install voidnet CLI on your Mac for managing remote Void capsules"
echo ""

# Check for required tools
echo "Checking requirements..."

if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 not found. Please install Python 3.8+ first."
    exit 1
else
    echo -e "${GREEN}✓${NC} Python 3 found"
fi

if ! command -v ssh &> /dev/null; then
    echo "Error: SSH not found. Please install OpenSSH first."
    exit 1
fi

# Determine Python command
PYTHON_CMD=""
for cmd in python3 python3.10 python3.9 python; do
    if command -v $cmd &> /dev/null; then
        PYTHON_CMD=$cmd
        break
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo "Error: Python 3 not found."
    exit 1
fi

# Create virtual environment
echo "Creating voidnet virtual environment..."
VOIDNET_DIR="$HOME/.voidnet"
VENV_DIR="$VOIDNET_DIR/venv"

rm -rf "$VENV_DIR"
$PYTHON_CMD -m venv "$VENV_DIR"

# Activate venv and install dependencies
echo "Installing dependencies..."
source "$VENV_DIR/bin/activate"
pip install -q typer pyyaml httpx rich

# Copy voidnet files to venv
echo "Copying voidnet files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

rm -rf "$VOIDNET_DIR/commands"
rm -rf "$VOIDNET_DIR/utils"
rm -f "$VOIDNET_DIR/__init__.py"
rm -f "$VOIDNET_DIR/cli.py"
rm -f "$VOIDNET_DIR/api.py"
rm -f "$VOIDNET_DIR/config.py"
rm -f "$VOIDNET_DIR/service.py"

mkdir -p "$VOIDNET_DIR/commands" "$VOIDNET_DIR/utils"

cp "$SCRIPT_DIR/__init__.py" "$VOIDNET_DIR/"
cp "$SCRIPT_DIR/cli.py" "$VOIDNET_DIR/"
cp "$SCRIPT_DIR/api.py" "$VOIDNET_DIR/"
cp "$SCRIPT_DIR/config.py" "$VOIDNET_DIR/"
cp "$SCRIPT_DIR/service.py" "$VOIDNET_DIR/"
cp -r "$SCRIPT_DIR/commands/" "$VOIDNET_DIR/commands/"
cp -r "$SCRIPT_DIR/utils/" "$VOIDNET_DIR/utils/"

# Create wrapper script that uses venv
echo "Creating voidnet wrapper..."
cat > /usr/local/bin/voidnet << 'EOF'
#!/bin/bash
# Activate voidnet venv and run CLI
source "$HOME/.voidnet/venv/bin/activate"
python -m voidnet.cli "\$@"
EOF

chmod +x /usr/local/bin/voidnet

# Deactivate venv
deactivate

echo ""
echo -e "${GREEN}✓ VoidNet client installed successfully!${NC}"
echo ""
echo "Installation details:"
echo "  - Virtual environment: $VENV_DIR"
echo "  - Voidnet files: $VOIDNET_DIR"
echo "  - Wrapper script: /usr/local/bin/voidnet"
echo ""
echo "Next steps:"
echo "  1. Run ${BLUE}voidnet client register${NC} to configure as client"
echo "  2. Get your admin API key from overseer"
echo "  3. Run ${BLUE}voidnet capsule list${NC} to see all capsules"
echo "  4. Run ${BLUE}voidnet capsule connect <name>${NC} to connect to capsules"
echo ""
echo "For help: ${BLUE}voidnet --help${NC}"
