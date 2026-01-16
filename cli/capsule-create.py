#!/usr/bin/env python3
"""
Void Capsule Creator - Interactive CLI tool
Create and deploy Capsules from command line
"""

import sys
import os
import subprocess
from pathlib import Path

# Configuration
VOID_OVERSEER_URL = os.getenv("VOID_OVERSEER_URL", "http://localhost:8000")
API_KEY = os.getenv("VOID_API_KEY", "")

# Colors
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
RED = "\033[0;31m"
CYAN = "\033[0;36m"
RESET = "\033[0m"


def print_header(text):
    print(f"{CYAN}═══════════════════════════════════════{RESET}")
    print(f"{CYAN}  {text}")
    print(f"{CYAN}═══════════════════════════════════{RESET}")


def print_success(text):
    print(f"{GREEN}✓ {text}")


def print_error(text):
    print(f"{RED}✗ {text}")


def print_info(text):
    print(f"{CYAN}ℹ {text}")


def print_menu_item(num, text, description=""):
    print(f"  {num}. {text}{RESET}  {description}")


def get_satellites():
    """Get all existing satellites from Overseer"""
    try:
        result = subprocess.run(
            [
                "curl",
                "-s",
                "-X",
                "POST",
                f"{VOID_OVERSEER_URL}/capsules",
                "-H",
                f"Content-Type: application/json",
                "-H",
                f"X-API-Key: {API_KEY}",
                "-d",
                "{}",
            ],
            capture_output=True,
            text=True,
            timeout=10.0,
        )
        return result.stdout
    except Exception as e:
        print_error(f"Failed to get satellites: {e}")
        return None


def create_capsule(name, satellite_id, git_url, compose_content, flags):
    """Create a capsule on Overseer"""
    try:
        data = {
            "name": name,
            "satellite_id": satellite_id,
            "git_url": git_url,
            "git_branch": "main",
            "compose_file": compose_content,
        }

        # Add optional fields
        if flags.get("rust"):
            data["rust_support"] = True
        if flags.get("opencode"):
            data["opencode_support"] = True
        if flags.get("git_user"):
            data["git_user"] = flags.get("git_user")
        if flags.get("git_ssh_key"):
            data["git_ssh_key"] = flags.get("git_ssh_key")

        result = subprocess.run(
            [
                "curl",
                "-s",
                "-X",
                "POST",
                f"{VOID_OVERSEER_URL}/capsules",
                "-H",
                f"Content-Type: application/json",
                "-H",
                f"X-API-Key: {API_KEY}",
                "-d",
                json.dumps(data),
            ],
            capture_output=True,
            text=True,
            timeout=30.0,
        )

        return result.stdout
    except Exception as e:
        print_error(f"Failed to create capsule: {e}")
        return None


def deploy_capsule(capsule_id):
    """Deploy an existing capsule"""
    try:
        result = subprocess.run(
            [
                "curl",
                "-s",
                "-X",
                "POST",
                f"{VOID_OVERSEER_URL}/capsules/{capsule_id}/deploy",
                "-H",
                f"Content-Type: application/json",
                "-H",
                f"X-API-Key: {API_KEY}",
                "-d",
                "{}",
            ],
            capture_output=True,
            text=True,
            timeout=60.0,
        )

        return result.stdout
    except Exception as e:
        print_error(f"Failed to deploy capsule: {e}")
        return None


def read_docker_compose():
    """Read docker-compose.yml from current directory"""
    compose_file = Path("docker-compose.yml")
    if not compose_file.exists():
        return None
    with open(compose_file) as f:
        return f.read()
    return None


def validate_compose(content):
    """Validate docker-compose.yml content"""
    try:
        import yaml

        parsed = yaml.safe_load(content)

        # Check for services section
        if "services" not in parsed:
            return False, "No 'services' section found"

        issues = []
        for service_name, service in parsed["services"].items():
            # Check for required fields
            if "image" not in service:
                issues.append(f"  Service '{service_name} missing 'image'")
            if not service.get("ports"):
                issues.append(f"  Service '{service_name}' missing 'ports'")

        return len(issues) == 0, issues
    except Exception as e:
        return False, [f"YAML parsing error: {e}"]


def menu_create():
    """Interactive capsule creation menu"""
    print_header("CREATE NEW CAPSULE")

    # Get satellites first
    print_info("Fetching satellites from Overseer...")
    satellites_response = get_satellites()

    if not satellites_response:
        return

    import json

    satellites = json.loads(satellites_response)

    if not satellites.get("satellites"):
        print_error("No satellites available")
        return

    print_info(f"\n{CYAN}Available Satellites:{RESET}")
    for i, sat in enumerate(satellites["satellites"], 1):
        print_menu_item(
            i + 1, sat["name"], f"IP: {sat['ip_address']}, Hostname: {sat['hostname']}"
        )

    # Get capsule name
    name = input(f"\n{YELLOW}Capsule name:{RESET} ").strip()
    if not name:
        print_error("Name is required")
        return

    # Select satellite
    print_info(f"\n{YELLOW}Select Satellite (number):{RESET}")
    satellite_idx = input(f"{CYAN}> {RESET} ").strip()
    try:
        satellite_idx = int(satellite_idx) - 1
        if not 0 <= satellite_idx < len(satellites["satellites"]):
            raise ValueError("Invalid selection")
        satellite = satellites["satellites"][satellite_idx]
    except ValueError:
        print_error("Invalid selection")
        return

    # Get git URL
    git_url = input(f"\n{YELLOW}Git repository URL:{RESET} ").strip()
    if not git_url:
        print_error("Git URL is required")
        return

    # Read docker-compose.yml
    print_info(f"\n{YELLOW}Reading docker-compose.yml from current directory...{RESET}")
    compose_content = read_docker_compose()
    if not compose_content:
        print_error("No docker-compose.yml found in current directory")
        return

    is_valid, issues = validate_compose(compose_content)
    if not is_valid:
        print_error("Invalid docker-compose.yml:")
        for issue in issues:
            print_error(f"  • {issue}")
        return

    print_success("✓ docker-compose.yml is valid")

    # Ask about flags
    print_info(
        f"\n{CYAN}Environment flags (comma-separated, press Enter when done):{RESET}"
    )
    print_info(f"  1. Rust support")
    print_info(f"  2. OpenCode support")
    print_info(f"  3. Git user (for commits)")
    print_info(f"  4. Git SSH key (for private repos)")
    flags = {}

    while True:
        flag_input = input(f"{CYAN}> {RESET} ").strip()
        if not flag_input:
            break
        try:
            flag_num = int(flag_input)
            if flag_num == 1:
                flags["rust"] = True
                print_success("  ✓ Rust support enabled")
            elif flag_num == 2:
                flags["opencode"] = True
                print_success("  ✓ OpenCode support enabled")
            elif flag_num == 3:
                git_user = input(
                    f"{YELLOW}Git username (leave empty for default):{RESET} "
                ).strip()
                if git_user:
                    flags["git_user"] = git_user
                continue
            elif flag_num == 4:
                git_key = input(
                    f"{YELLOW}Git SSH key (paste key, leave empty):{RESET} "
                ).strip()
                if git_key:
                    flags["git_ssh_key"] = git_key
                continue
            elif flag_input == ":":
                break
        except ValueError:
            continue

    # Confirm and create
    confirm = input(f"\n{YELLOW}Create Capsule '{name}'? [y/N]{RESET} ").strip().lower()
    if confirm != "y":
        print_info("Cancelled")
        return

    print_info(f"\n{CYAN}Creating Capsule '{name}' on Overseer...{RESET}")
    result = create_capsule(name, satellite["id"], git_url, compose_content, flags)

    if result:
        try:
            import json

            capsule_data = json.loads(result)

            if "capsule_id" in capsule_data:
                print_success(
                    f"✅ Capsule created with ID: {capsule_data['capsule_id']}"
                )
                print_info(
                    f"Deploy it with: void capsule deploy {capsule_data['capsule_id']}"
                )
            else:
                print_error(f"Failed to create capsule")
        except Exception:
            print_error("Failed to parse response")


def menu_list():
    """List existing capsules"""
    print_header("LIST CAPSULES")

    print_info("Fetching capsules from Overseer...")
    capsules_response = get_satellites()

    if not capsules_response:
        return

    import json

    data = json.loads(capsules_response)

    if not data.get("capsules"):
        print_info("No capsules found")
        return

    print_info(f"\n{CYAN}Existing Capsules:{RESET}")

    for i, cap in enumerate(data["capsules"], 1):
        satellite_name = next(
            (s for s in satellites["satellites"] if s["id"] == cap["satellite_id"]),
            None,
            "Unknown",
        )

        print_menu_item(
            i + 1,
            f"{cap['name']}" if len(cap["name"]) < 30 else cap["name"][:27] + "...",
            f"on {satellite_name}Status: {cap['status']}",
        )


def menu_deploy():
    """Deploy an existing capsule"""
    print_header("DEPLOY CAPSULE")

    print_info("Fetching capsules from Overseer...")
    capsules_response = get_satellites()

    if not capsules_response:
        return

    import json

    data = json.loads(capsules_response)

    if not data.get("capsules"):
        print_info("No capsules found")
        return

    print_info(f"\n{CYAN}Select Capsule to deploy:{RESET}")
    for i, cap in enumerate(data["capsules"], 1):
        satellite_name = next(
            (s for s in satellites["satellites"] if s["id"] == cap["satellite_id"]),
            None,
            "Unknown",
        )

        print_menu_item(i + 1, cap["name"], f"on {satellite_name}")

    cap_idx = input(f"{CYAN}> {RESET} ").strip()
    try:
        cap_idx = int(cap_idx) - 1
        if not 0 <= cap_idx < len(data["capsules"]):
            raise ValueError("Invalid selection")
    except ValueError:
        print_error("Invalid selection")
        return

    print_info(f"\n{CYAN}Deploying '{data['capsules'][cap_idx]['name']}'...{RESET}")
    result = deploy_capsule(data["capsules"][cap_idx]["id"])

    if result:
        print_success("✅ Capsule deployed successfully")
    else:
        print_error("Failed to deploy capsule")


def show_help():
    """Show help information"""
    print_header("VOID CAPSULE CREATOR")
    print()
    print_info("Commands:")
    print_menu_item("1", "create", "Create new Capsule")
    print_menu_item("2", "list", "List existing Capsules")
    print_menu_item("3", "deploy", "Deploy existing Capsule")
    print_menu_item("4", "help", "Show this help")
    print()
    print_info("Environment variables:")
    print_menu_item(
        "VOID_OVERSEER_URL",
        VOID_OVERSEER_URL,
        "Overseer API URL (default: http://localhost:8000)",
    )
    print_menu_item("VOID_API_KEY", API_KEY, "API authentication key (required)")


def main():
    if len(sys.argv) > 1:
        command = sys.argv[1]
        if command == "create":
            menu_create()
        elif command == "list":
            menu_list()
        elif command == "deploy":
            menu_deploy()
        elif command == "help":
            show_help()
        else:
            print_error(f"Unknown command: {command}")
            show_help()
            sys.exit(1)
    else:
        show_help()


if __name__ == "__main__":
    main()
