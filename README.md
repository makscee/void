# Void - Distributed Container Orchestration

**Void** transforms your homelab from a single-machine setup to a distributed Controller-Agent architecture.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Overseer                         │
│              (Central Controller)                     │
│              Running on mcow VPS                     │
│                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │ Satellite A  │  │ Satellite B  │  │ Satellite C  │ │
│  │ (Uplink)    │  │ (Uplink)    │  │ (Uplink)    │ │
│  │ docker-tower │  │  your-mac   │  │   nether     │ │
│  └─────────────┘  └─────────────┘  └─────────────┘ │
│                                                      │
│  Private Network (Headscale/Tailscale)                │
└─────────────────────────────────────────────────────────────┘
```

## 📖 Concepts

- **Overseer**: Central controller (FastAPI) running on mcow VPS
  - Holds database of all Satellites and Capsules
  - Handles Git operations and YAML security validation
  - Deploys Capsules to specific Satellites

- **Uplink**: Satellite agent (FastAPI) running on each machine
  - Registers with Overseer via Headscale VPN
  - Executes Docker commands received from Overseer
  - Reports health and status back

- **Satellite**: Physical machine running Uplink (docker-tower, your-mac, nether)

- **Capsule**: Deployable stack (docker-compose.yml) stored in Git repo
  - Validated for security before deployment
  - Deployed to specific Satellites by Overseer

## 🚀 Quick Start

### 1. Deploy Overseer on mcow VPS

```bash
# SSH to mcow
ssh root@mcow

# Clone repository
git clone https://github.com/makscee/void.git /opt/void
cd /opt/void/overseer

# Run installation script
bash install.sh

# Get admin API key from logs
journalctl -u void-overseer --no-pager | grep "Default admin API key"

# Save API key
export VOID_API_KEY=<your-admin-key>
```

### 2. Register Satellite (docker-tower)

```bash
# SSH to docker-tower
ssh root@docker-tower

# Clone repository
git clone https://github.com/makscee/void.git /opt/void
cd /opt/void/uplink

# Set environment variables
export OVERSEER_URL=http://mcow:8000
export SATELLITE_NAME=docker-tower

# Run installation script
bash install.sh

# Save the API key displayed after registration
```

### 3. Register Satellite (your-mac)

```bash
# On your local machine
cd void/uplink

export OVERSEER_URL=http://mcow:8000
export SATELLITE_NAME=my-mac

bash install.sh
```

### 4. Deploy Your First Capsule

```bash
# Set admin API key
export VOID_API_KEY=<your-admin-key>
export VOID_OVERSEER_URL=http://mcow:8000

# From your app directory
cd ~/my-app

# Create capsule
void capsule create my-app 1 https://github.com/user/my-app.git

# Deploy capsule
void capsule deploy 1

# View logs
void capsule logs 1

# List capsules
void capsule list
```

## 📡 Workflow

### Normal Development Loop

1. **Develop locally** on your machine
2. **Commit and push** to Git
3. **Deploy with Void CLI**: `void capsule deploy <id>`

### What Happens

1. Overseer clones your Git repo
2. Overseer validates docker-compose.yml for security (bans root, host mounts, etc.)
3. Overseer sends validated config to Uplink on chosen Satellite
4. Uplink runs `docker compose up -d`
5. Containers are deployed!

## 🔒 Security Features

Overseer validates all docker-compose.yml files for:

- ❌ Privileged mode (`privileged: true`)
- ❌ Host networking (`network_mode: host`)
- ❌ Root user (`user: root`)
- ❌ Host path mounts (`/: /`, `/root:`, `/home:`)
- ❌ Docker socket access (`/var/run/docker.sock`)

Violations prevent deployment with clear error messages.

## 📋 Commands

### Satellite Management

```bash
# List all satellites
void satellite list

# Register a new satellite (from satellite machine)
export OVERSEER_URL=http://mcow:8000
export SATELLITE_NAME=my-satellite
cd void/uplink
bash install.sh
```

### Capsule Management

```bash
# Create capsule from docker-compose.yml
void capsule create my-app 1 https://github.com/user/app.git

# List all capsules
void capsule list

# Deploy a capsule
void capsule deploy <capsule_id>

# Stop a capsule
void capsule stop <capsule_id>

# View logs
void capsule logs <capsule_id> 500
```

## 🗂️ Project Structure

```
void/
├── overseer/           # Central Controller
│   ├── main.py        # FastAPI application
│   ├── database/      # SQLite database
│   └── install.sh    # Installation script
├── uplink/             # Satellite Agent
│   ├── main.py        # FastAPI application
│   ├── docker/        # Docker operations
│   └── install.sh    # Installation script
├── cli/               # CLI tool
│   └── void.sh       # Main CLI script
└── README.md          # This file
```

## 🔧 Configuration

### Overseer Environment Variables

```bash
OVERSEER_HOST=0.0.0.0          # Host to bind to
OVERSEER_PORT=8000               # Port to listen on
DB_PATH=/opt/void/overseer/void.db      # Database path
GIT_CLONE_DIR=/opt/void/overseer/clones  # Git clone directory
```

### Uplink Environment Variables

```bash
UPLINK_HOST=0.0.0.0           # Host to bind to
UPLINK_PORT=8001                # Port to listen on
OVERSEER_URL=http://mcow:8000   # Overseer URL
SATELLITE_NAME=docker-tower      # Satellite name
SATELLITE_IP=10.0.0.1          # Satellite IP address
```

### CLI Environment Variables

```bash
VOID_OVERSEER_URL=http://mcow:8000  # Overseer API URL
VOID_API_KEY=<admin-key>             # Admin API key
```

## 🔗 API Documentation

### Overseer API (Port 8000)

- `GET /` - API info
- `POST /satellite/register` - Register Satellite
- `GET /satellites` - List all Satellites
- `POST /capsules` - Create Capsule
- `GET /capsules` - List all Capsules
- `POST /capsules/{id}/deploy` - Deploy Capsule
- `POST /capsules/{id}/stop` - Stop Capsule
- `GET /capsules/{id}/logs` - Get Capsule logs
- `GET /health` - Health check

### Uplink API (Port 8001)

- `GET /` - API info
- `POST /deploy` - Deploy Capsule (docker compose up)
- `POST /stop` - Stop Capsule
- `GET /logs` - Get Capsule logs
- `GET /containers` - List containers
- `GET /health` - Health check

## 🧪 Testing

### Test Overseer

```bash
# Check health
curl http://mcow:8000/health

# List satellites
curl -H "X-API-Key: $VOID_API_KEY" http://mcow:8000/satellites

# View API docs
open http://mcow:8000/docs
```

### Test Uplink

```bash
# Check health
curl http://docker-tower:8001/health

# List containers
curl http://docker-tower:8001/containers

# View API docs
open http://docker-tower:8001/docs
```

## 🐛 Troubleshooting

### Satellite won't register with Overseer

```bash
# Check Overseer is running
curl http://mcow:8000/health

# Check network connectivity (Headscale)
tailscale status

# Check Uplink logs
journalctl -u void-uplink -n 50
```

### Capsule deployment fails

```bash
# Check security violations
# Overseer will return specific error

# Check deployment logs
void capsule logs <capsule_id>

# Check Uplink logs
journalctl -u void-uplink -n 100
```

### Connection refused

```bash
# Check if services are running
systemctl status void-overseer
systemctl status void-uplink

# Check firewall
ufw status  # On mcow
# Allow ports 8000 (Overseer) and 8001 (Uplink)
```

## 📝 Next Steps

- [ ] Add authentication to Uplink API
- [ ] Add Capsule restart endpoint
- [ ] Add Capsule update endpoint
- [ ] Add webhook integration for Git push auto-deploy
- [ ] Add monitoring (Prometheus + Grafana)
- [ ] Add secret management (SOPS)

## 🔄 Migration from Homestack

If migrating from single-machine Homestack:

1. Deploy Overseer on mcow
2. Register docker-tower as Satellite
3. Migrate existing docker-compose.yml files to Git repos
4. Create Capsules for each stack
5. Deploy Capsules using Void CLI
6. Decommission old Tower API service

## 📄 License

MIT License - See LICENSE file for details
