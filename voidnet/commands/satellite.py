"""Satellite management commands"""

import typer
import socket
import asyncio
import httpx
from rich.table import Table
from rich.console import Console
from rich.panel import Panel

from voidnet.config import Config
from voidnet.api import VoidAPI
from voidnet.service import ServiceManager
from voidnet.utils.logging import success, error, info, warn, panel

app = typer.Typer()
console = Console()


@app.command()
def register(
    name: str = typer.Option(None, "--name", "-n", help="Satellite name"),
    overseer_url: str = typer.Option(None, "--overseer-url", "-u", help="Overseer URL"),
):
    """Register this machine as a satellite with Overseer"""
    config = Config()

    # Get satellite name
    if not name:
        name = socket.gethostname()
        info(f"Using hostname as satellite name: {name}")

    # Get overseer URL
    if not overseer_url:
        overseer_url = config.get("overseer", "url")

    info(f"Registering satellite '{name}' with Overseer at {overseer_url}...")

    # Get system info
    hostname = socket.gethostname()
    try:
        ip = socket.gethostbyname(hostname)
    except socket.gaierror:
        ip = "127.0.0.1"
        warn(f"Could not resolve hostname, using localhost: {ip}")

    # Register with overseer
    api = VoidAPI(overseer_url)
    try:
        result = asyncio.run(api.register_satellite(name, ip, hostname, ["docker"]))
    except httpx.HTTPStatusError as e:
        error(f"Registration failed: {e.response.status_code}")
        try:
            error_msg = e.response.json()
            error(f"Details: {error_msg}")
        except:
            pass
        raise typer.Exit(1)
    except Exception as e:
        error(f"Registration failed: {e}")
        raise typer.Exit(1)

    api_key = result.get("api_key")
    satellite_id = result.get("satellite_id")

    # Save to config
    config.set("satellite", "name", value=name)
    config.set("satellite", "ip", value=ip)
    config.set("satellite", "hostname", value=hostname)
    config.set("satellite", "api_key", value=api_key)
    config.save()

    success(f"Satellite registered successfully!")
    info(f"Satellite ID: {satellite_id}")
    info(f"API Key: {api_key}")
    info("Configuration saved to ~/.voidnet/config.yaml")

    # Install and start service
    info("Installing uplink service...")
    service = ServiceManager(config)
    service.install_service()
    service.start_service()

    success("Uplink service installed and started")


@app.command()
def start():
    """Start uplink service"""
    config = Config()

    if not config.get("satellite", "api_key"):
        error("No satellite registered. Run 'voidnet satellite register' first.")
        raise typer.Exit(1)

    info("Starting uplink service...")
    service = ServiceManager(config)
    service.start_service()
    success("Uplink service started")


@app.command()
def stop():
    """Stop uplink service"""
    config = Config()

    info("Stopping uplink service...")
    service = ServiceManager(config)
    service.stop_service()
    success("Uplink service stopped")


@app.command()
def restart():
    """Restart uplink service"""
    config = Config()

    info("Restarting uplink service...")
    service = ServiceManager(config)
    service.restart_service()
    success("Uplink service restarted")


@app.command()
def status():
    """Check satellite service status"""
    config = Config()

    if not config.get("satellite", "api_key"):
        error("No satellite registered. Run 'voidnet satellite register' first.")
        raise typer.Exit(1)

    service = ServiceManager(config)
    service_status = service.get_service_status()

    # Check health endpoint
    health_status = "unknown"
    try:
        response = httpx.get("http://localhost:8001/health", timeout=5.0)
        health = response.json()
        health_status = health.get("status", "unknown")
        containers = health.get("running_containers", 0)
    except Exception as e:
        health_status = f"unreachable ({e})"

    # Display status
    table = Table(title="Satellite Status")
    table.add_column("Field", style="cyan")
    table.add_column("Value", style="green")

    table.add_row("Satellite Name", config.get("satellite", "name", default="Unknown"))
    table.add_row("Service Status", service_status)
    table.add_row("Health Status", health_status)
    if "containers" in locals():
        table.add_row("Running Containers", str(containers))

    console.print(table)


@app.command()
def logs(
    tail: int = typer.Option(100, "--tail", "-n", help="Number of lines"),
    follow: bool = typer.Option(False, "--follow", "-f", help="Follow logs"),
):
    """View uplink service logs"""
    config = Config()

    service = ServiceManager(config)
    service.get_logs(tail, follow)


@app.command()
def unregister():
    """Unregister satellite from Overseer"""
    config = Config()

    if not config.get("satellite", "api_key"):
        error("No satellite registered.")
        raise typer.Exit(1)

    satellite_name = config.get("satellite", "name", default="Unknown")

    if not typer.confirm(
        f"Unregister satellite '{satellite_name}' from Overseer?", default=False
    ):
        raise typer.Abort()

    info("Unregistering satellite...")

    # Get satellite ID from overseer
    api = VoidAPI(
        config.get("overseer", "url"),
        config.get("satellite", "api_key"),
    )

    try:
        satellites = asyncio.run(api.get_satellites(config.get("satellite", "api_key")))
        satellite_list = satellites.get("satellites", [])
        satellite_id = None

        for sat in satellite_list:
            if sat.get("name") == satellite_name:
                satellite_id = sat.get("id")
                break

        if not satellite_id:
            error(f"Satellite '{satellite_name}' not found in Overseer")
            raise typer.Exit(1)

        # Delete from overseer
        asyncio.run(
            api.delete_satellite(satellite_id, config.get("satellite", "api_key"))
        )
        success(f"Satellite '{satellite_name}' unregistered from Overseer")

    except Exception as e:
        error(f"Failed to unregister: {e}")
        raise typer.Exit(1)

    # Stop and remove service
    info("Stopping uplink service...")
    service = ServiceManager(config)
    service.stop_service()

    # Remove config
    if typer.confirm("Remove configuration file?", default=False):
        config.path.unlink()
        success("Configuration removed")

    info("Satellite unregistered. Run 'voidnet satellite register' to register again.")
