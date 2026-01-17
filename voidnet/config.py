"""Configuration management for VoidNet"""

import yaml
from pathlib import Path
import os
import platform

DEFAULT_CONFIG = {
    "overseer": {
        "url": "http://85.209.135.21:8000",
    },
    "satellite": {
        "name": None,
        "ip": None,
        "hostname": None,
        "api_key": None,
    },
    "paths": {
        "install_dir": "~/.voidnet",
        "uplink_dir": "~/.voidnet/uplink",
        "log_file": "/tmp/void-uplink.log",
        "err_log": "/tmp/void-uplink.err",
        "plist_path": "~/Library/LaunchAgents/com.void.uplink.plist",
    },
    "service": {
        "type": "launchd" if platform.system() == "Darwin" else "systemd",
        "name": "com.void.uplink" if platform.system() == "Darwin" else "void-uplink",
    },
}


class Config:
    """Configuration manager for VoidNet"""

    def __init__(self, path="~/.voidnet/config.yaml"):
        self.path = Path(path).expanduser()
        self.data = DEFAULT_CONFIG.copy()
        self._load()

    def _load(self):
        """Load configuration from file"""
        if self.path.exists():
            try:
                with open(self.path) as f:
                    loaded = yaml.safe_load(f)
                    if loaded:
                        # Deep merge with defaults
                        for section in loaded:
                            if section in self.data and isinstance(
                                self.data[section], dict
                            ):
                                self.data[section].update(loaded[section])
                            else:
                                self.data[section] = loaded[section]
            except Exception as e:
                print(f"Warning: Could not load config: {e}")

    def save(self):
        """Save configuration to file"""
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with open(self.path, "w") as f:
            yaml.dump(self.data, f, default_flow_style=False)

    def get(self, *keys, default=None):
        """Get nested configuration value"""
        value = self.data
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return default
        return value

    def set(self, *keys, value):
        """Set nested configuration value"""
        data = self.data
        for key in keys[:-1]:
            if key not in data:
                data[key] = {}
            data = data[key]
        data[keys[-1]] = value
