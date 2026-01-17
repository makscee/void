"""Service management for VoidNet Uplink"""

import subprocess
import os
from pathlib import Path
from typing import Optional
from .config import Config
from .utils.platform import detect_platform


class ServiceManager:
    """Cross-platform service manager for Uplink"""

    def __init__(self, config: Config):
        self.config = config
        self.platform = detect_platform()

    def install_service(self):
        """Install service (launchd or systemd)"""
        if self.platform == "macos":
            self._install_launchd()
        elif self.platform == "linux":
            self._install_systemd()
        else:
            raise RuntimeError(f"Unsupported platform: {self.platform}")

    def start_service(self):
        """Start the service"""
        if self.platform == "macos":
            plist_path = Path(
                self.config.get(
                    "paths",
                    "plist_path",
                    default="~/Library/LaunchAgents/com.void.uplink.plist",
                )
            ).expanduser()
            subprocess.run(["launchctl", "load", str(plist_path)], check=False)
            subprocess.run(["launchctl", "start", "com.void.uplink"], check=False)
        elif self.platform == "linux":
            subprocess.run(["systemctl", "enable", "void-uplink"], check=False)
            subprocess.run(["systemctl", "start", "void-uplink"], check=False)

    def stop_service(self):
        """Stop the service"""
        if self.platform == "macos":
            subprocess.run(["launchctl", "stop", "com.void.uplink"], check=False)
        elif self.platform == "linux":
            subprocess.run(["systemctl", "stop", "void-uplink"], check=False)

    def restart_service(self):
        """Restart the service"""
        self.stop_service()
        import time

        time.sleep(1)
        self.start_service()

    def get_service_status(self) -> str:
        """Get service status"""
        if self.platform == "macos":
            result = subprocess.run(
                ["launchctl", "list"],
                capture_output=True,
                text=True,
            )
            if "com.void.uplink" in result.stdout:
                return "running"
            return "stopped"
        elif self.platform == "linux":
            result = subprocess.run(
                ["systemctl", "is-active", "void-uplink"],
                capture_output=True,
                text=True,
            )
            return result.stdout.strip()
        return "unknown"

    def get_logs(self, tail: int = 100, follow: bool = False):
        """Get service logs"""
        log_file = Path(
            self.config.get("paths", "log_file", default="/tmp/void-uplink.log")
        )

        if self.platform == "macos":
            cmd = ["tail", f"-{tail}", str(log_file)]
            if follow:
                cmd.insert(1, "-f")
        elif self.platform == "linux":
            cmd = ["journalctl", "-u", "void-uplink", f"-n{tail}"]
            if follow:
                cmd.append("-f")

        subprocess.run(cmd)

    def _install_launchd(self):
        """Create launchd plist file"""
        plist_dir = Path("~/Library/LaunchAgents").expanduser()
        plist_dir.mkdir(parents=True, exist_ok=True)

        plist_path = plist_dir / "com.void.uplink.plist"

        # Find python3
        python_path = self._find_python()
        uplink_dir = Path(
            self.config.get("paths", "uplink_dir", default="~/.voidnet/uplink")
        ).expanduser()

        # Create plist file
        plist_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.void.uplink</string>
    <key>ProgramArguments</key>
    <array>
        <string>{python_path}</string>
        <string>{uplink_dir}/main.py</string>
    </array>
    <key>WorkingDirectory</key>
    <string>{uplink_dir}</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>OVERSEER_URL</key>
        <string>{self.config.get("overseer", "url")}</string>
        <key>SATELLITE_NAME</key>
        <string>{self.config.get("satellite", "name")}</string>
        <key>SATELLITE_IP</key>
        <string>{self.config.get("satellite", "ip")}</string>
        <key>OVERSEER_API_KEY</key>
        <string>{self.config.get("satellite", "api_key")}</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>{self.config.get("paths", "log_file")}</string>
    <key>StandardErrorPath</key>
    <string>{self.config.get("paths", "err_log")}</string>
</dict>
</plist>
"""

        with open(plist_path, "w") as f:
            f.write(plist_content)

        # Save plist path to config
        self.config.set("paths", "plist_path", value=str(plist_path))
        self.config.save()

    def _install_systemd(self):
        """Create systemd service file"""
        service_path = "/etc/systemd/system/void-uplink.service"

        uplink_dir = Path(
            self.config.get("paths", "uplink_dir", default="~/.voidnet/uplink")
        ).expanduser()

        service_content = f"""[Unit]
Description=Void Uplink - Satellite Agent
After=network.target docker.service

[Service]
Type=simple
User={os.environ.get("USER", "root")}
WorkingDirectory={uplink_dir}
Environment="OVERSEER_URL={self.config.get("overseer", "url")}"
Environment="SATELLITE_NAME={self.config.get("satellite", "name")}"
Environment="SATELLITE_IP={self.config.get("satellite", "ip")}"
Environment="OVERSEER_API_KEY={self.config.get("satellite", "api_key")}"
ExecStart=/usr/bin/python3 {uplink_dir}/main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
"""

        with open(service_path, "w") as f:
            f.write(service_content)

    def _find_python(self) -> str:
        """Find python3 executable"""
        for path in [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
        ]:
            if Path(path).exists():
                return path
        return "python3"  # Fallback to PATH
