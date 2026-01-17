"""
Void Overseer - Central Controller
Manages Satellites and Capsules across the distributed infrastructure
"""

from fastapi import FastAPI, HTTPException, Depends, status, Header, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, HttpUrl, validator
from typing import Optional, List, Dict, Any, Tuple
import httpx
import os
import subprocess
import tempfile
import shutil
from pathlib import Path
from datetime import datetime
import sqlite3
import yaml
import hashlib
import secrets
from contextlib import asynccontextmanager

# Configuration
OVERSEER_HOST = os.getenv("OVERSEER_HOST", "0.0.0.0")
OVERSEER_PORT = int(os.getenv("OVERSEER_PORT", "8000"))
DB_PATH = os.getenv("DB_PATH", "/opt/void/overseer/void.db")
GIT_CLONE_DIR = os.getenv("GIT_CLONE_DIR", "/opt/void/overseer/clones")

# Ensure directories exist
Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)
Path(GIT_CLONE_DIR).mkdir(parents=True, exist_ok=True)


# Database setup
def init_db():
    """Initialize SQLite database"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Satellites table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS satellites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            ip_address TEXT NOT NULL,
            hostname TEXT NOT NULL,
            api_key TEXT UNIQUE NOT NULL,
            status TEXT DEFAULT 'online',
            last_heartbeat TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            capabilities TEXT DEFAULT '[]'
        )
    """)

    # Capsules table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS capsules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            satellite_id INTEGER NOT NULL,
            git_url TEXT NOT NULL,
            git_branch TEXT DEFAULT 'main',
            compose_file TEXT NOT NULL,
            status TEXT DEFAULT 'stopped',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (satellite_id) REFERENCES satellites(id)
        )
    """)

    # Deployments table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS deployments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            capsule_id INTEGER NOT NULL,
            status TEXT NOT NULL,
            output TEXT,
            error TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (capsule_id) REFERENCES capsules(id)
        )
    """)

    # Users table for auth
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            api_key TEXT UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

    # Create default admin user if none exists
    cursor.execute("SELECT COUNT(*) FROM users")
    if cursor.fetchone()[0] == 0:
        default_key = secrets.token_urlsafe(32)
        cursor.execute(
            "INSERT INTO users (username, api_key) VALUES (?, ?)",
            ("admin", default_key),
        )
        print(f"⚠️  Default admin API key: {default_key}")
        print(f"⚠️  Save this key, it won't be shown again!")

    conn.commit()
    conn.close()


def get_db():
    """Get database connection"""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


# Initialize database
init_db()


# Lifespan manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print("🚀 Overseer starting...")
    yield
    # Shutdown
    print("🛑 Overseer stopping...")


app = FastAPI(
    title="Void Overseer",
    description="Central Controller for Void Distributed Infrastructure",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Security validation for YAML
class SecurityValidator:
    """Validates docker-compose files for security issues"""

    BANNED_KEYWORDS = [
        "privileged: true",
        "network_mode: host",
        "pid: host",
        "user: root",
        "/:/",
        "/root:",
        "/home:",
        "/var/run/docker.sock",
    ]

    @staticmethod
    def validate_yaml(yaml_content: str) -> Tuple[bool, List[str]]:
        """
        Validate YAML for security issues
        Returns: (is_valid, list_of_violations)
        """
        violations = []

        # Check for banned keywords
        for keyword in SecurityValidator.BANNED_KEYWORDS:
            if keyword in yaml_content:
                violations.append(f"Banned keyword found: {keyword}")

        # Parse YAML
        try:
            parsed = yaml.safe_load(yaml_content)
        except Exception as e:
            return False, [f"Invalid YAML: {str(e)}"]

        # Check for dangerous volume mounts
        if "services" in parsed:
            for service_name, service in parsed["services"].items():
                if "volumes" in service:
                    for volume in service["volumes"]:
                        if isinstance(volume, str) and "/" in volume:
                            # Check if mounting host path
                            host_path = volume.split(":")[0]
                            if not host_path.startswith(
                                "/tmp"
                            ) and not host_path.startswith("./"):
                                violations.append(
                                    f"Host mount detected in {service_name}: {volume}"
                                )

        return len(violations) == 0, violations


# Pydantic models
class SatelliteRegister(BaseModel):
    name: str
    ip_address: str
    hostname: str
    capabilities: Optional[List[str]] = []
    rust_support: Optional[bool] = False
    opencode_support: Optional[bool] = False
    git_user: Optional[str] = None
    git_ssh_key: Optional[str] = None
    rust_support: Optional[bool] = False
    opencode_support: Optional[bool] = False
    git_user: Optional[str] = None
    git_ssh_key: Optional[str] = None


class SatelliteResponse(BaseModel):
    id: int
    name: str
    ip_address: str
    hostname: str
    api_key: str
    status: str
    last_heartbeat: str
    created_at: str


class CapsuleCreate(BaseModel):
    name: str
    satellite_id: int
    git_url: str
    git_branch: str = "main"
    compose_file: str


class CapsuleResponse(BaseModel):
    id: int
    name: str
    satellite_id: int
    git_url: str
    git_branch: str
    status: str
    created_at: str


class DeploymentRequest(BaseModel):
    capsule_id: int


# API Key authentication
async def verify_api_key(x_api_key: str = Header(...)):
    """Verify API key for requests"""
    conn = get_db()
    user = conn.execute(
        "SELECT * FROM users WHERE api_key = ?", (x_api_key,)
    ).fetchone()
    conn.close()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid API key"
        )
    return user


# Endpoints


@app.get("/")
async def root():
    return {
        "name": "Void Overseer",
        "version": "1.0.0",
        "description": "Central Controller for Void Distributed Infrastructure",
        "endpoints": {
            "POST /satellite/register": "Register a new Satellite (Uplink)",
            "GET /satellites": "List all registered Satellites",
            "GET /satellites/{id}": "Get Satellite details",
            "DELETE /satellites/{id}": "Delete a Satellite",
            "POST /capsules": "Create a new Capsule",
            "GET /capsules": "List all Capsules",
            "GET /capsules/{id}": "Get Capsule details",
            "POST /capsules/{id}/deploy": "Deploy a Capsule",
            "POST /capsules/{id}/stop": "Stop a Capsule",
            "POST /capsules/{id}/logs": "Get Capsule logs",
        },
    }


# Satellite management
@app.post("/satellite/register")
async def register_satellite(satellite: SatelliteRegister):
    """Register a new Satellite (Uplink) with the Overseer"""
    api_key = secrets.token_urlsafe(32)

    conn = get_db()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO satellites (name, ip_address, hostname, api_key, capabilities)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                satellite.name,
                satellite.ip_address,
                satellite.hostname,
                api_key,
                str(satellite.capabilities),
            ),
        )
        conn.commit()
        satellite_id = cursor.lastrowid
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Satellite '{satellite.name}' already registered",
        )
    finally:
        conn.close()

    return {
        "satellite_id": satellite_id,
        "api_key": api_key,
        "message": f"Satellite '{satellite.name}' registered successfully",
    }


    @app.delete("/satellites/{satellite_id}")
    async def delete_satellite(satellite_id: int):
        """Delete a Satellite"""
        conn = get_db()
        satellite = conn.execute(
            "SELECT * FROM satellites WHERE id = ?", (satellite_id,)
        ).fetchone()

        if not satellite:
            conn.close()
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Satellite {satellite_id} not found",
            )

        satellite_name = satellite["name"]

        conn.execute("DELETE FROM capsules WHERE satellite_id = ?", (satellite_id,))

        conn.execute("DELETE FROM satellites WHERE id = ?", (satellite_id,))
        conn.commit()
        conn.close()

        return {
            "message": f"Satellite '{satellite_name}' deleted successfully",
            "satellite_id": satellite_id,
        }

@app.get("/satellites")
async def list_satellites():
    """List all registered Satellites"""
    conn = get_db()
    satellites = conn.execute("SELECT * FROM satellites").fetchall()
    conn.close()

    return {
        "satellites": [
            {
                "id": s["id"],
                "name": s["name"],
                "ip_address": s["ip_address"],
                "hostname": s["hostname"],
                "status": s["status"],
                "last_heartbeat": s["last_heartbeat"],
                "capabilities": eval(s["capabilities"]) if s["capabilities"] else [],
                "created_at": s["created_at"],
            }
            for s in satellites
        ]
    }


@app.get("/satellites/{satellite_id}")
async def get_satellite(satellite_id: int):
    """Get details of a specific Satellite"""
    conn = get_db()
    satellite = conn.execute(
        "SELECT * FROM satellites WHERE id = ?", (satellite_id,)
    ).fetchone()
    conn.close()

    if not satellite:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Satellite {satellite_id} not found",
        )

    return {
        "id": satellite["id"],
        "name": satellite["name"],
        "ip_address": satellite["ip_address"],
        "hostname": satellite["hostname"],
        "status": satellite["status"],
        "last_heartbeat": satellite["last_heartbeat"],
        "capabilities": eval(satellite["capabilities"])
        if satellite["capabilities"]
        else [],
        "created_at": satellite["created_at"],
    }


# Capsule management
@app.post("/capsules")
async def create_capsule(capsule: CapsuleCreate):
    """Create a new Capsule (deployable stack)"""
    conn = get_db()

    # Verify satellite exists
    satellite = conn.execute(
        "SELECT * FROM satellites WHERE id = ?", (capsule.satellite_id,)
    ).fetchone()

    if not satellite:
        conn.close()
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Satellite {capsule.satellite_id} not found",
        )

    # Validate YAML security
    is_valid, violations = SecurityValidator.validate_yaml(capsule.compose_file)
    if not is_valid:
        conn.close()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Security violations: {violations}",
        )

    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO capsules (name, satellite_id, git_url, git_branch, compose_file)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                capsule.name,
                capsule.satellite_id,
                capsule.git_url,
                capsule.git_branch,
                capsule.compose_file,
            ),
        )
        conn.commit()
        capsule_id = cursor.lastrowid
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Capsule '{capsule.name}' already exists",
        )
    finally:
        conn.close()

    return {
        "capsule_id": capsule_id,
        "message": f"Capsule '{capsule.name}' created successfully",
    }


@app.get("/capsules")
async def list_capsules():
    """List all Capsules"""
    conn = get_db()
    capsules = conn.execute("""
        SELECT c.*, s.name as satellite_name, s.hostname as satellite_hostname
        FROM capsules c
        JOIN satellites s ON c.satellite_id = s.id
    """).fetchall()
    conn.close()

    return {
        "capsules": [
            {
                "id": c["id"],
                "name": c["name"],
                "satellite_id": c["satellite_id"],
                "satellite_name": c["satellite_name"],
                "satellite_hostname": c["satellite_hostname"],
                "git_url": c["git_url"],
                "git_branch": c["git_branch"],
                "status": c["status"],
                "created_at": c["created_at"],
            }
            for c in capsules
        ]
    }


@app.get("/capsules/{capsule_id}")
async def get_capsule(capsule_id: int):
    """Get details of a specific Capsule"""
    conn = get_db()
    capsule = conn.execute(
        """
        SELECT c.*, s.name as satellite_name, s.hostname as satellite_hostname
        FROM capsules c
        JOIN satellites s ON c.satellite_id = s.id
        WHERE c.id = ?
    """,
        (capsule_id,),
    ).fetchone()
    conn.close()

    if not capsule:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Capsule {capsule_id} not found",
        )

    return {
        "id": capsule["id"],
        "name": capsule["name"],
        "satellite_id": capsule["satellite_id"],
        "satellite_name": capsule["satellite_name"],
        "satellite_hostname": capsule["satellite_hostname"],
        "git_url": capsule["git_url"],
        "git_branch": capsule["git_branch"],
        "status": capsule["status"],
        "created_at": capsule["created_at"],
    }


# Deployment operations
@app.post("/capsules/{capsule_id}/deploy")
async def deploy_capsule(capsule_id: int):
    """Deploy a Capsule to its Satellite"""
    conn = get_db()

    # Get capsule and satellite info
    capsule = conn.execute(
        """
        SELECT c.*, s.ip_address, s.api_key
        FROM capsules c
        JOIN satellites s ON c.satellite_id = s.id
        WHERE c.id = ?
    """,
        (capsule_id,),
    ).fetchone()

    if not capsule:
        conn.close()
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Capsule {capsule_id} not found",
        )

    # Clone git repo
    try:
        clone_dir = Path(GIT_CLONE_DIR) / capsule["name"]
        if clone_dir.exists():
            shutil.rmtree(clone_dir)

        subprocess.run(
            [
                "git",
                "clone",
                "-b",
                capsule["git_branch"],
                capsule["git_url"],
                str(clone_dir),
            ],
            check=True,
            capture_output=True,
            timeout=300,
        )

        # Read docker-compose.yml
        compose_file = clone_dir / "docker-compose.yml"
        if not compose_file.exists():
            raise FileNotFoundError("docker-compose.yml not found in repo")

        with open(compose_file) as f:
            compose_content = f.read()

        # Validate security again
        is_valid, violations = SecurityValidator.validate_yaml(compose_content)
        if not is_valid:
            conn.close()
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Security violations in docker-compose.yml: {violations}",
            )

        # Deploy to satellite via Uplink
        satellite_url = f"http://{capsule['ip_address']}:8001"

        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f"{satellite_url}/deploy",
                headers={"X-API-Key": capsule["api_key"]},
                json={"capsule_id": capsule_id, "compose_file": compose_content},
            )
            response.raise_for_status()
            result = response.json()

        # Update capsule status
        conn.execute(
            "UPDATE capsules SET status = 'running', updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            (capsule_id,),
        )

        # Log deployment
        conn.execute(
            """
            INSERT INTO deployments (capsule_id, status, output)
            VALUES (?, 'success', ?)
            """,
            (capsule_id, str(result)),
        )

        conn.commit()
        conn.close()

        return {
            "message": f"Capsule '{capsule['name']}' deployed successfully",
            "deployment": result,
        }

    except Exception as e:
        # Log failed deployment
        conn.execute(
            """
            INSERT INTO deployments (capsule_id, status, error)
            VALUES (?, 'failed', ?)
            """,
            (capsule_id, str(e)),
        )
        conn.commit()
        conn.close()

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Deployment failed: {str(e)}",
        )


@app.post("/capsules/{capsule_id}/stop")
async def stop_capsule(capsule_id: int):
    """Stop a Capsule"""
    conn = get_db()

    capsule = conn.execute(
        """
        SELECT c.*, s.ip_address, s.api_key
        FROM capsules c
        JOIN satellites s ON c.satellite_id = s.id
        WHERE c.id = ?
    """,
        (capsule_id,),
    ).fetchone()

    if not capsule:
        conn.close()
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Capsule {capsule_id} not found",
        )

    try:
        satellite_url = f"http://{capsule['ip_address']}:8001"

        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f"{satellite_url}/stop",
                headers={"X-API-Key": capsule["api_key"]},
                json={"capsule_id": capsule_id},
            )
            response.raise_for_status()

        # Update capsule status
        conn.execute(
            "UPDATE capsules SET status = 'stopped', updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            (capsule_id,),
        )
        conn.commit()
        conn.close()

        return {"message": f"Capsule '{capsule['name']}' stopped successfully"}

    except Exception as e:
        conn.close()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Stop failed: {str(e)}",
        )


@app.post("/capsules/{capsule_id}/logs")
async def get_capsule_logs(capsule_id: int, tail: int = 100):
    """Get logs from a Capsule"""
    conn = get_db()

    capsule = conn.execute(
        """
        SELECT c.*, s.ip_address, s.api_key
        FROM capsules c
        JOIN satellites s ON c.satellite_id = s.id
        WHERE c.id = ?
    """,
        (capsule_id,),
    ).fetchone()

    if not capsule:
        conn.close()
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Capsule {capsule_id} not found",
        )

    try:
        satellite_url = f"http://{capsule['ip_address']}:8001"

        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.get(
                f"{satellite_url}/logs?capsule_id={capsule_id}&tail={tail}",
                headers={"X-API-Key": capsule["api_key"]},
            )
            response.raise_for_status()
            logs = response.json()

        conn.close()
        return logs

    except Exception as e:
        conn.close()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get logs: {str(e)}",
        )


# Health check
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    conn = get_db()
    satellite_count = conn.execute("SELECT COUNT(*) FROM satellites").fetchone()[0]
    capsule_count = conn.execute("SELECT COUNT(*) FROM capsules").fetchone()[0]
    conn.close()

    return {
        "status": "healthy",
        "satellites": satellite_count,
        "capsules": capsule_count,
    }


# Install script endpoint
@app.get("/install-web.sh")
async def get_install_script():
    """Serve the satellite install script"""
    script_path = Path(__file__).parent / "install-web.sh"
    if not script_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Install script not found"
        )

    with open(script_path, "r") as f:
        script_content = f.read()

    return Response(
        content=script_content,
        media_type="text/x-shellscript",
        headers={"Content-Disposition": 'inline; filename="install-web.sh"'},
    )

    with open(script_path, "r") as f:
        script_content = f.read()

    return JSONResponse(
        content=script_content,
        media_type="text/x-shellscript",
        headers={"Content-Disposition": 'inline; filename="install-web.sh"'},
    )


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=OVERSEER_HOST, port=OVERSEER_PORT)
