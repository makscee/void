"""Main CLI entry point for VoidNet"""

import sys
from pathlib import Path
import typer
from rich.console import Console

# Add parent directory to path for direct execution
sys.path.insert(0, str(Path(__file__).parent))

from voidnet.commands import satellite, capsule, system

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


@app.callback(no_args_is_help=True)
def main():
    """Main entry point"""
    try:
        app()
    except KeyboardInterrupt:
        from rich.console import Console

        Console().print("\n[bold yellow]Interrupted by user[/bold]")


def cli_main():
    """Main entry point"""
    main()


if __name__ == "__main__":
    cli_main()
