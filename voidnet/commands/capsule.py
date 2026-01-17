"""Capsule management commands"""

import typer
import asyncio
from rich.table import Table
from rich.console import Console
from rich.panel import Panel

from ..config import Config
from ..api import VoidAPI
from ..utils.logging import success, error, info, panel

app = typer.Typer()
console = Console()


@app.command()
def list(
    satellite_id: int = typer.Option(
        None, "--satellite-id", "-s", help="Filter by satellite ID"
    ),
):
    """List all capsules"""
    config = Config()

    api_key = typer.prompt("Admin API Key", hide_input=True)

    api = VoidAPI(config.get("overseer", "url"), api_key)

    try:
        result = asyncio.run(api.get_capsules(api_key))
        capsules = result.get("capsules", [])

        table = Table(title="Capsules")
        table.add_column("ID", style="cyan")
        table.add_column("Name", style="green")
        table.add_column("Status", style="yellow")
        table.add_column("Satellite", style="blue")
        table.add_column("Git URL", style="dim")

        for cap in capsules:
            if satellite_id is None or cap.get("satellite_id") == satellite_id:
                table.add_row(
                    str(cap.get("id")),
                    cap.get("name"),
                    cap.get("status"),
                    cap.get("satellite_name", "Unknown"),
                    cap.get("git_url", ""),
                )

        console.print(table)
    except Exception as e:
        error(f"Failed to list capsules: {e}")
        raise typer.Exit(1)


@app.command()
def status(capsule_id: int):
    """Show capsule status"""
    config = Config()

    api_key = typer.prompt("Admin API Key", hide_input=True)

    api = VoidAPI(config.get("overseer", "url"), api_key)

    try:
        result = asyncio.run(api.get_capsule(capsule_id, api_key))

        panel_content = f"""
Name: {result.get("name", "Unknown")}
ID: {result.get("id")}
Status: {result.get("status")}
Satellite: {result.get("satellite_name", "Unknown")}
Satellite Hostname: {result.get("satellite_hostname", "Unknown")}
Git URL: {result.get("git_url", "N/A")}
Git Branch: {result.get("git_branch", "main")}
Created: {result.get("created_at", "N/A")}
"""
        console.print(Panel.fit(panel_content, title=f"Capsule {capsule_id}"))

    except Exception as e:
        error(f"Failed to get capsule status: {e}")
        raise typer.Exit(1)


@app.command()
def logs(
    capsule_id: int,
    tail: int = typer.Option(100, "--tail", "-n", help="Number of lines"),
):
    """View capsule logs"""
    config = Config()

    api_key = typer.prompt("Admin API Key", hide_input=True)

    api = VoidAPI(config.get("overseer", "url"), api_key)

    try:
        result = asyncio.run(api.get_capsule_logs(capsule_id, tail, api_key))

        logs = result.get("logs", {})

        if not logs:
            info("No logs available for this capsule")
            return

        console.print(f"\n[bold]Capsule {capsule_id} Logs:[/bold]\n")

        for container_name, log_lines in logs.items():
            console.print(f"\n[cyan]{container_name}:[/cyan]")
            if isinstance(log_lines, str):
                console.print(log_lines)
            else:
                console.print("No logs available")

    except Exception as e:
        error(f"Failed to get capsule logs: {e}")
        raise typer.Exit(1)


@app.command()
def deploy(capsule_id: int):
    """Deploy a capsule"""
    config = Config()

    api_key = typer.prompt("Admin API Key", hide_input=True)

    api = VoidAPI(config.get("overseer", "url"), api_key)

    info(f"Deploying capsule {capsule_id}...")

    try:
        result = asyncio.run(api.deploy_capsule(capsule_id, api_key))
        success(f"Capsule {capsule_id} deployed successfully")
        info(f"Deployment output: {result}")

    except Exception as e:
        error(f"Failed to deploy capsule: {e}")
        raise typer.Exit(1)


@app.command()
def stop(capsule_id: int):
    """Stop a capsule"""
    config = Config()

    api_key = typer.prompt("Admin API Key", hide_input=True)

    api = VoidAPI(config.get("overseer", "url"), api_key)

    info(f"Stopping capsule {capsule_id}...")

    if not typer.confirm("Are you sure?", default=False):
        raise typer.Abort()

    try:
        asyncio.run(api.stop_capsule(capsule_id, api_key))
        success(f"Capsule {capsule_id} stopped successfully")

    except Exception as e:
        error(f"Failed to stop capsule: {e}")
        raise typer.Exit(1)
