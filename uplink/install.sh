#!/bin/bash

# Uplink Installation Script (Simplified)
# One-command installation that downloads and runs

set -e

OVERSEER_URL="${OVERSEER_URL:-http://localhost:8000}"
SATELLITE_NAME="${SATELLITE_NAME:-changeme}"

echo "🚀 Installing Void Uplink on $(hostname)..."
echo ""
echo "📡 Connecting to Overseer at: $OVERSEER_URL"

# Get system info
SATELLITE_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "📋 Installation details:"
echo "   Satellite name: $SATELLITE_NAME"
echo "   Satellite IP: $SATELLITE_IP"
echo "   Overseer URL: $OVERSEER_URL"
echo ""

# Register with Overseer
echo "🔑 Registering with Overseer..."
REGISTRATION=$(curl -s -X POST "$OVERSEER_URL/satellite/register" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$SATELLITE_NAME\", \"ip_address\": \"$SATELLITE_IP\", \"hostname\": \"$(hostname)\", \"capabilities\": [\"docker\"]}")

# Check registration success
if echo "$REGISTRATION" | grep -q "api_key"; then
    API_KEY=$(echo "$REGISTRATION" | grep -o '"api_key":"[^"]*' | cut -d'"' -f4)

    echo ""
    echo "✅ Successfully registered!"
    echo ""
    echo "🔑 API Key: $API_KEY"
    echo ""
    echo "⚠️  SAVE THIS KEY! You'll need it for Overseer operations."
    echo ""
    echo "💡 Add to ~/.zshrc or ~/.bashrc:"
    echo "   export VOID_UPLINK_API_KEY=$API_KEY"
else
    echo "❌ Registration failed:"
    echo "$REGISTRATION"
    exit 1
fi

# Create environment file
echo ""
echo "📁 Creating environment file..."
cat > /opt/void/uplink/.env << EOF
OVERSEER_URL=$OVERSEER_URL
SATELLITE_NAME=$SATELLITE_NAME
SATELLITE_IP=$SATELLITE_IP
UPLINK_API_KEY=$API_KEY
EOF

# Create Uplink service from template
echo "📋 Creating systemd service..."
envsubst < /opt/void/uplink/uplink.service.template > /etc/systemd/system/void-uplink.service

echo ""
echo "🔄 Reloading systemd..."
systemctl daemon-reload
systemctl enable void-uplink

echo ""
echo "🚀 Starting Uplink service..."
systemctl start void-uplink

# Wait for service to start
sleep 2

# Check status
if systemctl is-active --quiet void-uplink; then
    echo ""
    echo "✅ Uplink installed and running!"
    echo ""
    echo "📋 Next steps:"
    echo "   1. Verify connection: curl $OVERSEER_URL/health"
    echo "   2. Check Uplink logs: journalctl -u void-uplink -f"
    echo "   3. API documentation: curl $OVERSEER_URL/satellites"
    echo ""
    echo "💡 The API key has been saved to: /opt/void/uplink/.env"
else
    echo ""
    echo "❌ Service failed to start. Check logs:"
    echo "   journalctl -u void-uplink -n 50"
    exit 1
fi
