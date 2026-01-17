"""Main CLI entry point for VoidNet"""

import typer
from rich.console import Console
from .commands import satellite, capsule, system

app = typer.Typer(
    name="voidnet",
    help="VoidNet CLI - Manage Void satellites and capsules",
    no_args_is_help=True,
)

# Add sub-commands
app.add_typer(satellite.app, name="satellite")
app.add_typer(capsule.app, name="capsule")
app.add_typer(system.app, name="system")

console = Console()


@app.callback()
def main(
    version: bool = typer.Option(
        False, "--version", "-v", help="Show version and exit"
    ),
):
    """VoidNet CLI - Manage Void distributed infrastructure"""
    if version:
        from . import __version__

        console.print(f"VoidNet v{__version__}")
        raise typer.Exit()


def cli_main():
    """Main entry point"""
    app()


if __name__ == "__main__":
    cli_main()
