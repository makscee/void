# Quick Uplink Installation

## 🚀 One-Command Installation

```bash
curl -fsSL https://raw.githubusercontent.com/makscee/void/main/uplink/install-web.sh | bash
```

## ⚙️ With Custom Configuration

```bash
OVERSEER_URL=http://your-overseer:8000 curl -fsSL https://raw.githubusercontent.com/makscee/void/main/uplink/install-web.sh | bash
```

## 📋 What This Does

The installer automatically:

1. **Checks dependencies**
   - Python 3
   - Docker
   - Git
   - Installs if missing

2. **Collects configuration** (interactive)
   - Satellite name
   - Overseer URL
   - System info (hostname, IP)

3. **Installs Uplink**
   - Downloads Void repository
   - Installs Python dependencies
   - Creates systemd service
   - Registers with Overseer

4. **Shows API key**
   - Displays your Satellite API key
   - Shows how to save it to shell

## 📖 Installation Flow

```
Step 1: Check Dependencies
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[✓] Python 3 found
[✓] Docker found
[✓] Git found
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 2: Collect Configuration
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Hostname: my-mac
IP: 192.168.1.100
Overseer URL: http://localhost:8000
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 3: Install Dependencies
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Installing python3...
Installing docker.io...
Installing git...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 4: Clone Repository
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Cloning repository...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 5: Install Uplink
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Installing Python dependencies...
Creating environment file...
Installing systemd service...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Step 6: Register with Overseer
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Registering satellite: my-mac...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

╔════════════════════════════════════════════╗
║  API KEY: abc123def456...                    ║
║                                             ║
╚═════════════════════════════════════════════════╝

⚠️  IMPORTANT: Save this API key!

💡 Add to your shell:
   export VOID_UPLINK_API_KEY=abc123def456...

Step 7: Start Service
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Starting Uplink service...
[✓] Uplink service started successfully!

Service status:   systemctl status void-uplink
View logs:        journalctl -u void-uplink -f
API health check:  curl http://localhost:8000/health
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

═════════════════════════════════════════════════╗
║  Installation Complete! Your Satellite is Ready.        ║
║                                                ║
═════════════════════════════════════════════════╝

Next Steps:
  1. Verify Overseer connection: curl http://your-overseer:8000/health
  2. View Satellite status: void satellite list
  3. Create your first Capsule: void capsule create

═══════════════════════════════════════════════════
```

## 🐛 Troubleshooting

### Installer won't run

```bash
# Make sure you're root
sudo -i
curl -fsSL https://raw.githubusercontent.com/makscee/void/main/uplink/install-web.sh | bash
```

### Service won't start

```bash
# Check service status
systemctl status void-uplink

# View logs
journalctl -u void-uplink -n 50

# Restart service
systemctl restart void-uplink
```

### Can't connect to Overseer

```bash
# Test Overseer health
curl http://your-overseer:8000/health

# Check if on same network
# Overseer and Satellite need to be on same network or VPN
```

## 🔧 Advanced Options

```bash
# Custom Satellite name
SATELLITE_NAME=my-custom-satellite curl -fsSL https://raw.githubusercontent.com/makscee/void/main/uplink/install-web.sh | bash

# Custom Overseer URL
OVERSEER_URL=http://192.168.1.50:8000 curl -fsSL https://raw.githubusercontent.com/makscee/void/main/uplink/install-web.sh | bash

# Custom branch (for testing)
GITHUB_BRANCH=develop curl -fsSL https://raw.githubusercontent.com/makscee/void/main/uplink/install-web.sh | bash

# Skip dependency installation (if already installed)
SKIP_DEPS=1 curl -fsSL https://raw.githubusercontent.com/makscee/void/main/uplink/install-web.sh | bash
```

## 📱 Share with Friends

Just share this command with your friend:

```bash
curl -fsSL https://raw.githubusercontent.com/makscee/void/main/uplink/install-web.sh | bash
```

They'll walk through the interactive installation and their Satellite will be automatically set up!

## 🔒 Security Notes

- The installer runs as root (required for systemd service)
- The API key is saved in `/opt/void/uplink/.env` (chmod 600)
- All communication uses Overseer API key for authentication
- Service files are owned by root with appropriate permissions

## 📖 Supported Operating Systems

- ✅ Ubuntu 18.04+
- ✅ Debian 10+
- ✅ RHEL 8+
- ✅ CentOS 7+
- ✅ Fedora 28+
- 🟡 macOS (manual setup required - see notes below)
- 🟡 Arch Linux (manual setup required)

## 🍏 macOS Notes

For macOS, you'll need to set things up manually:

```bash
# Install Python 3 (if not installed)
brew install python3

# Install Docker Desktop (if not installed)
# https://docs.docker.com/desktop/mac/

# Clone repository
git clone https://github.com/makscee/void.git /opt/void
cd /opt/void/uplink

# Install dependencies
pip3 install -r requirements.txt

# Create environment file
cat > .env << EOF
OVERSEER_URL=http://your-overseer:8000
SATELLITE_NAME=my-mac
EOF

# Set custom port (optional)
UPLINK_PORT=8001

# Run Uplink manually
python3 main.py
```

Or use the simplified local install script (create this if needed):

```bash
cd /opt/void/uplink
bash install.sh
```
