#!/bin/bash

# VoidNet Installer
# This script installs voidnet on macOS without Homebrew PEP 668 restrictions

set -e

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}Installing VoidNet...${NC}"

# Install dependencies directly using python -m pip
echo "Installing dependencies..."
python3 -m pip install --user typer pyyaml httpx rich -q

# Create voidnet directory structure
echo "Setting up directories..."
mkdir -p ~/.voidnet/commands ~/.voidnet/utils ~/.voidnet/uplink

# Copy voidnet files
echo "Copying voidnet files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cp "$SCRIPT_DIR/__init__.py" ~/.voidnet/
cp "$SCRIPT_DIR/cli.py" ~/.voidnet/
cp "$SCRIPT_DIR/api.py" ~/.voidnet/
cp "$SCRIPT_DIR/config.py" ~/.voidnet/
cp "$SCRIPT_DIR/service.py" ~/.voidnet/
cp -r "$SCRIPT_DIR/commands/" ~/.voidnet/commands/
cp -r "$SCRIPT_DIR/utils/" ~/.voidnet/utils/

# Copy uplink files
echo "Copying uplink files..."
cp -r "$SCRIPT_DIR/uplink/" ~/.voidnet/uplink/

# Create wrapper script for voidnet
cat > /usr/local/bin/voidnet << 'EOF'
#!/usr/bin/env python3
import sys
from pathlib import Path
sys.path.insert(0, str(Path.home() / ".voidnet"))

from voidnet.cli import main

if __name__ == "__main__":
    main()
EOF

chmod +x /usr/local/bin/voidnet

echo -e "${GREEN}✓ VoidNet installed successfully!${NC}"
echo ""
echo "Run 'voidnet init' to get started"
echo "Run 'voidnet --help' for available commands"
