"""Platform detection utilities"""

import platform


def detect_platform():
    """Detect current operating system platform"""
    system = platform.system()
    if system == "Darwin":
        return "macos"
    elif system == "Linux":
        return "linux"
    else:
        raise RuntimeError(f"Unsupported platform: {system}")


def is_root():
    """Check if running with root/sudo privileges"""
    import os

    return os.geteuid() == 0
