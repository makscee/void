#!/bin/bash

# Void Overseer Installation Script

set -e

echo "🚀 Installing Void Overseer..."

# Create directories
echo "📁 Creating directories..."
mkdir -p /opt/void/overseer/clones

# Copy install script for satellites
echo "📄 Installing satellite install script..."
cp install-web.sh /opt/void/overseer/

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip3 install -r requirements.txt

# Install systemd service
echo "🔧 Installing systemd service..."
cp overseer.service /etc/systemd/system/void-overseer.service
systemctl daemon-reload
systemctl enable void-overseer

echo "✅ Overseer installed successfully!"
echo ""
echo "🔑 Starting Overseer..."
systemctl start void-overseer

echo ""
echo "📋 Check status: systemctl status void-overseer"
echo "📋 View logs: journalctl -u void-overseer -f"
echo "📋 API docs: http://<mcow-ip>:8000/docs"
