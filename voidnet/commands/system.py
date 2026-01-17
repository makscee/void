"""System commands for VoidNet CLI"""

import typer
import subprocess
from pathlib import Path

from ..config import Config, DEFAULT_CONFIG
from ..utils.logging import success, error, info

app = typer.Typer()


@app.command()
def init():
    """Initialize voidnet on this machine"""
    info("Initializing voidnet...")

    config = Config()

    # Ask for Overseer URL
    current_url = config.get("overseer", "url")
    if typer.confirm(f"Use Overseer at {current_url}?", default=True):
        info(f"Using Overseer: {current_url}")
    else:
        url = typer.prompt("Enter Overseer URL")
        config.set("overseer", "url", value=url)
        config.save()
        info(f"Overseer URL set to: {url}")

    # Create directory structure
    install_dir = Path(config.get("paths", "install_dir")).expanduser()
    uplink_dir = Path(config.get("paths", "uplink_dir")).expanduser()

    install_dir.mkdir(parents=True, exist_ok=True)
    uplink_dir.mkdir(parents=True, exist_ok=True)

    info(f"Created directory: {install_dir}")
    info(f"Created directory: {uplink_dir}")

    # Copy uplink files
    package_dir = Path(__file__).parent.parent.parent
    uplink_source = package_dir / "uplink"

    if uplink_source.exists():
        info(f"Copying uplink files to {uplink_dir}...")

        # Copy main.py
        import shutil

        if (uplink_source / "main.py").exists():
            shutil.copy2(uplink_source / "main.py", uplink_dir / "main.py")
        if (uplink_source / "requirements.txt").exists():
            shutil.copy2(
                uplink_source / "requirements.txt", uplink_dir / "requirements.txt"
            )

        # Install dependencies
        info("Installing Python dependencies...")
        subprocess.run(
            ["python3", "-m", "pip", "install", "-q", "-r", "uplink/requirements.txt"],
            check=True,
        )

        success("voidnet initialized successfully!")
        info("Run 'voidnet satellite register' to register as a satellite")
    else:
        error("Uplink files not found in voidnet package")
        raise typer.Exit(1)


@app.command()
def update():
    """Update voidnet to latest version"""
    info("Updating voidnet...")

    try:
        # Check current version
        from .. import __version__

        info(f"Current version: {__version__}")

        # Update from git repo
        package_dir = Path(__file__).parent.parent.parent
        subprocess.run(
            ["git", "-C", str(package_dir), "pull"],
            check=True,
        )

        # Reinstall
        subprocess.run(
            ["pip", "install", "--upgrade", "-e", str(package_dir)],
            check=True,
        )

        success("voidnet updated successfully!")
    except Exception as e:
        error(f"Update failed: {e}")
        raise typer.Exit(1)


@app.command()
def uninstall():
    """Remove voidnet CLI and configuration"""
    if not typer.confirm(
        "This will remove voidnet and stop all services. Continue?",
        default=False,
    ):
        raise typer.Abort()

    info("Uninstalling voidnet...")

    config = Config()

    # Stop service
    info("Stopping uplink service...")
    try:
        from ..service import ServiceManager

        service = ServiceManager(config)
        service.stop_service()
        success("Service stopped")
    except Exception as e:
        warn(f"Could not stop service: {e}")

    # Remove launchd service
    plist_path = Path(config.get("paths", "plist_path")).expanduser()
    if plist_path.exists():
        info(f"Removing service file: {plist_path}")
        plist_path.unlink()

    # Remove installation directory
    install_dir = Path(config.get("paths", "install_dir")).expanduser()
    if install_dir.exists():
        if typer.confirm(f"Remove {install_dir}?", default=False):
            info(f"Removing {install_dir}...")
            import shutil

            shutil.rmtree(inst_dir_dir)

    # Remove config
    if config.path.exists():
        if typer.confirm("Remove configuration file?", default=False):
            config.path.unlink()

    success("voidnet uninstalled")
