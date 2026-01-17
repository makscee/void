"""Rich console output utilities"""

from rich.console import Console
from rich.text import Text
from rich.panel import Panel

console = Console()


def success(message: str):
    """Display success message"""
    console.print(Text("✓ ", style="bold green") + Text(message))


def error(message: str):
    """Display error message"""
    console.print(Text("✗ ", style="bold red") + Text(message))


def info(message: str):
    """Display info message"""
    console.print(Text("ℹ ", style="bold blue") + Text(message))


def warn(message: str):
    """Display warning message"""
    console.print(Text("⚠ ", style="bold yellow") + Text(message))


def panel(content: str, title: str = "", style: str = "blue"):
    """Display content in a styled panel"""
    console.print(Panel.fit(content, title=title, border_style=style))
