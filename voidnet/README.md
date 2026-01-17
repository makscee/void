# VoidNet CLI

Manage Void distributed infrastructure satellites from your command line.

## Installation

### From Git Repository

```bash
cd voidnet
pip install -e .
```

### From GitHub

```bash
pip install git+https://github.com/makscee/void.git#subdirectory=voidnet
```

### Web Installer

```bash
curl -fsSL https://raw.githubusercontent.com/makscee/void/master/voidnet/install.sh | bash
```

## Quick Start

```bash
# Initialize voidnet
voidnet init

# Register as satellite
voidnet satellite register

# Check status
voidnet satellite status

# View logs
voidnet satellite logs -f
```

## Configuration

Configuration is stored in `~/.voidnet/config.yaml`:

```yaml
overseer:
  url: "http://85.209.135.21:8000"

satellite:
  name: "your-hostname"
  ip: "192.168.1.100"
  hostname: "your-hostname"
  api_key: "generated-api-key"

paths:
  install_dir: "~/.voidnet"
  uplink_dir: "~/.voidnet/uplink"
  log_file: "/tmp/void-uplink.log"
```

## Commands

### Satellite Management

```bash
# Register this machine as a satellite
voidnet satellite register [--name NAME] [--overseer-url URL]

# Start uplink service
voidnet satellite start

# Stop uplink service
voidnet satellite stop

# Restart uplink service
voidnet satellite restart

# Check satellite status
voidnet satellite status

# View service logs
voidnet satellite logs [--tail N] [-f]

# Unregister from overseer
voidnet satellite unregister
```

### Capsule Management

```bash
# List all capsules
voidnet capsule list [--satellite-id ID]

# View capsule status
voidnet capsule status <capsule_id>

# View capsule logs
voidnet capsule logs <capsule_id> [--tail N]

# Deploy a capsule
voidnet capsule deploy <capsule_id>

# Stop a capsule
voidnet capsule stop <capsule_id>
```

### System Commands

```bash
# Initialize voidnet
voidnet init

# Update voidnet
voidnet update

# Uninstall voidnet
voidnet uninstall
```

## Platform Support

- macOS (Darwin) - Uses launchd for service management
- Linux - Uses systemd for service management

## Requirements

- Python 3.8+
- Docker
- Git
