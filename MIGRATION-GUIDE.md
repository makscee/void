# Migration Guide: Homestack → Void

This guide helps you migrate from the single-machine Homestack setup to the distributed Void architecture.

## What Changed

### Homestack (Old)
```
docker-tower
└── Tower API (monolithic, directly controls Docker)
    └── Single machine deployment
```

### Void (New)
```
mcow (Overseer)
├── Overseer API (central controller)
│   ├── Satellite management
│   ├── Capsule management
│   ├── Git operations
│   └── Security validation
│
└── Multiple Satellites
    ├── docker-tower (Uplink)
    ├── your-mac (Uplink)
    └── nether (Uplink)
```

## Migration Steps

### Phase 1: Deploy Overseer (mcow)

**Prerequisites:**
- mcow VPS accessible via SSH
- mcow has Docker installed (for Git operations only)

**Steps:**

```bash
# 1. SSH to mcow
ssh root@mcow

# 2. Clone Void repository
git clone https://github.com/makscee/void.git /opt/void
cd /opt/void/overseer

# 3. Run installation script
bash install.sh

# 4. Save the admin API key displayed
journalctl -u void-overseer --no-pager | grep "Default admin API key"
```

**Result:**
- Overseer running on port 8000
- Admin API key generated (save this!)
- Database initialized

### Phase 2: Migrate Satellites

#### docker-tower

```bash
# SSH to docker-tower
ssh root@docker-tower

# Clone Void repository
git clone https://github.com/makscee/void.git /opt/void
cd /opt/void/uplink

# Set Overseer URL
export OVERSEER_URL=http://mcow:8000
export SATELLITE_NAME=docker-tower

# Run installation script
bash install.sh

# Save the Satellite API key displayed
# It will be shown after successful registration
```

**After installation:**
- Uplink runs on port 8001
- Automatically registers with Overseer
- Ready to receive deployment commands

**Test connection:**
```bash
# From mcow:
curl http://docker-tower:8001/health

# From docker-tower:
curl http://mcow:8000/satellites
```

#### your-mac (local machine)

```bash
# On your local Mac
cd void/uplink

# Set environment variables
export OVERSEER_URL=http://mcow:8000
export SATELLITE_NAME=my-mac

# Run installation script
bash install.sh
```

### Phase 3: Migrate Workspaces → Capsules

Each Homestack workspace needs to become a Void capsule.

#### Example: Media Stack

**Homestack way:**
```bash
cd /opt/homestack/services/tower
docker-compose up -d jellyfin qbittorrent sonarr
```

**Void way:**

1. Move docker-compose.yml to a Git repo
2. Create Capsule in Overseer

```bash
# On your local machine with admin API key:
export VOID_API_KEY=<admin-key>
export VOID_OVERSEER_URL=http://mcow:8000

# Create a Git repo for your media stack
cd ~/media-stack
git init
# Copy docker-compose.yml here
# Add and commit
git add .
git commit -m "Initial media stack"
git push origin main

# Create capsule
void capsule create media-stack 1 https://github.com/user/media-stack.git
```

#### Example: Development Workspace

**Homestack way:**
```bash
cd /opt/homestack/workspaces/arena-game
docker-compose up -d
```

**Void way:**

```bash
# Ensure workspace is in Git
cd ~/arena-game
git remote add origin https://github.com/user/arena-game.git
git push origin main

# Create capsule
void capsule create arena-game 1 https://github.com/user/arena-game.git

# Deploy to docker-tower
void capsule deploy 1
```

### Phase 4: Update Scripts/Workflows

#### Update Deployment Scripts

Replace direct SSH/Docker commands with Void CLI:

**Before:**
```bash
ssh root@docker-tower "cd /opt/homestack/services/tower && docker-compose up -d"
```

**After:**
```bash
export VOID_API_KEY=<admin-key>
void capsule deploy <capsule_id>
```

#### Update OpenCode Skills

Update Tower skill to Void skill:

1. Rename skill: `skills/tower/` → `skills/void/`
2. Update skill.json:
   ```json
   {
     "name": "void",
     "description": "Void distributed infrastructure management",
     "commands": ["void capsule deploy", "void capsule logs", "void capsule list"]
   }
   ```
3. Update README in skill directory

### Phase 5: Decommission Old Tower API

**After confirming Void works:**

```bash
# SSH to docker-tower
ssh root@docker-tower

# Stop old Tower API
systemctl stop tower-api
systemctl disable tower-api

# Remove old Tower API
# (Optional) Keep for backup
rm /opt/homestack/services/tower/api/main.py

# Uplink is now handling all Docker operations
```

## Verification Checklist

### Overseer (mcow)

- [ ] Overseer service running: `systemctl status void-overseer`
- [ ] Port 8000 accessible: `curl http://mcow:8000/health`
- [ ] Database contains satellites: `curl -H "X-API-Key: $KEY" http://mcow:8000/satellites`
- [ ] Admin API key saved securely

### Satellites

- [ ] docker-tower Uplink running: `curl http://docker-tower:8001/health`
- [ ] your-mac Uplink running: `curl http://your-mac:8001/health`
- [ ] All satellites registered in Overseer
- [ ] Satellites can connect to Overseer

### Capsules

- [ ] Old stacks migrated to Git repos
- [ ] Capsules created in Overseer
- [ ] Capsules can be deployed: `void capsule deploy <id>`
- [ ] Capsules show correct status

### CLI

- [ ] Void CLI installed locally
- [ ] VOID_API_KEY configured
- [ ] VOID_OVERSEER_URL configured
- [ ] `void capsule list` works
- [ ] `void capsule deploy <id>` works

## Troubleshooting

### Overseer won't start

```bash
# Check logs
journalctl -u void-overseer -n 100

# Common issues:
# - Port 8000 already in use
# - Python dependencies missing
# - Database directory permissions

# Fix: Reinstall
cd /opt/void/overseer
bash install.sh
```

### Satellite can't register

```bash
# Check Overseer is running
curl http://mcow:8000/health

# Check network connectivity
tailscale status

# Check Satellite logs
journalctl -u void-uplink -n 50
```

### Capsule deployment fails

```bash
# Check for security violations
# Overseer returns specific errors

# Check Satellite logs
journalctl -u void-uplink -n 100

# Manually verify docker-compose.yml
# Check for: privileged mode, host mounts, root user
```

### Old Tower API still running

```bash
# Check what's using port 8000 on docker-tower
ssh root@docker-tower "netstat -tlnp | grep 8000"

# If old tower-api is running:
ssh root@docker-tower "systemctl stop tower-api && systemctl disable tower-api"
```

## Rollback Plan

If Void doesn't work as expected, you can rollback:

### Quick Rollback (keep Void)

```bash
# Keep Void Overseer running
# Just revert to direct Docker commands on Satellites

# On docker-tower:
cd /opt/homestack/services/tower
docker-compose up -d

# You're back to old workflow
```

### Full Rollback (remove Void)

```bash
# 1. Stop Void services
ssh root@mcow "systemctl stop void-overseer"

# 2. Stop Uplink on all Satellites
ssh root@docker-tower "systemctl stop void-uplink"
# On your-mac: cd /opt/void/uplink && bash uninstall.sh (if created)

# 3. Restore old Tower API
ssh root@docker-tower "systemctl start tower-api && systemctl enable tower-api"

# 4. Clone old Homestack if needed
ssh root@docker-tower "cd /opt && git clone https://github.com/makscee/homestack.git"
```

## Benefits of Migration

### What You Gain

1. **Distributed Deployment**
   - Deploy to multiple machines from one place
   - Easy to add more Satellites later

2. **Centralized Management**
   - Single API for all operations
   - Unified database of deployments
   - Better logging and monitoring

3. **Git-First Workflow**
   - All stacks versioned in Git
   - Easy rollback to previous versions
   - Better deployment tracking

4. **Security**
   - Automatic YAML validation
   - Prevents dangerous configurations
   - Clear audit trail

5. **Scalability**
   - Easy to add more Satellites
   - Capsules can move between Satellites
   - Load balancing possible in future

### What You Keep

1. All your existing docker-compose.yml files
2. All your workspaces
3. All your configurations
4. Familiar GitOps workflow (just centralized)

### What Changes

1. API endpoint: Tower API (port 8000) → Overseer (port 8000)
2. Commands: Direct Docker → Void CLI
3. Architecture: Single machine → Distributed
4. Mental model: "docker-tower" → "Overseer + Satellites"

## Support

If you encounter issues during migration:

1. Check this guide's Troubleshooting section
2. Check main Void README.md
3. Check Overseer API docs: http://mcow:8000/docs
4. Check logs: `journalctl -u void-overseer -f` or `journalctl -u void-uplink -f`
