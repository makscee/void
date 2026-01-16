"""
Void Uplink - Satellite Agent
Receives commands from Overseer and executes Docker operations
"""

from fastapi import FastAPI, HTTPException, status, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional
import os
import subprocess
import tempfile
from pathlib import Path
from contextlib import asynccontextmanager
import docker
from datetime import datetime

# Configuration
UPLINK_HOST = os.getenv("UPLINK_HOST", "0.0.0.0")
UPLINK_PORT = int(os.getenv("UPLINK_PORT", "8001"))
OVERSEER_URL = os.getenv("OVERSEER_URL", "http://localhost:8000")
SATellite_NAME = os.getenv("SATELLITE_NAME", "unknown")
OVERSEER_API_KEY = os.getenv("OVERSEER_API_KEY", "")

# Docker client
docker_client = docker.from_env()


# Lifespan manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup - Register with Overseer
    print("🚀 Uplink starting...")
    print(f"📡 Connecting to Overseer at {OVERSEER_URL}")

    # Get system info
    import socket

    hostname = socket.gethostname()

    try:
        import httpx

        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                f"{OVERSEER_URL}/satellite/register",
                json={
                    "name": SATELLITE_NAME,
                    "ip_address": os.getenv(
                        "SATELLITE_IP", socket.gethostbyname(hostname)
                    ),
                    "hostname": hostname,
                    "capabilities": ["docker"],
                },
            )
            response.raise_for_status()
            result = response.json()
            print(f"✅ Registered with Overseer!")
            print(f"🔑 API Key: {result['api_key']}")
            print(f"⚠️  Save this key in OVERSEER_API_KEY environment variable!")
    except Exception as e:
        print(f"⚠️  Failed to register with Overseer: {e}")
        print("⚠️  Uplink will continue but won't be able to receive deployments")

    yield
    # Shutdown
    print("🛑 Uplink stopping...")


app = FastAPI(
    title="Void Uplink",
    description="Satellite Agent for Void Distributed Infrastructure",
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


# Verify API key
def verify_api_key(x_api_key: str = Header(...)):
    """Verify API key from Overseer"""
    if not OVERSEER_API_KEY:
        return True  # Allow all if no key configured (dev mode)

    if x_api_key != OVERSEER_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid API key"
        )
    return True


# Pydantic models
class DeployRequest(BaseModel):
    capsule_id: int
    compose_file: str = Field(..., description="Docker Compose YAML content")


class StopRequest(BaseModel):
    capsule_id: int


# Helper functions
def execute_docker_compose(compose_content: str, action: str = "up"):
    """Execute docker compose command"""
    try:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".yml", delete=False) as f:
            f.write(compose_content)
            compose_file = f.name

        if action == "up":
            result = subprocess.run(
                ["docker", "compose", "-f", compose_file, "up", "-d", "--build"],
                capture_output=True,
                text=True,
                timeout=300,
            )
        elif action == "down":
            result = subprocess.run(
                ["docker", "compose", "-f", compose_file, "down"],
                capture_output=True,
                text=True,
                timeout=60,
            )
        elif action == "logs":
            result = subprocess.run(
                [
                    "docker",
                    "compose",
                    "-f",
                    compose_file,
                    "logs",
                    "--tail",
                    "100",
                    "--timestamps",
                ],
                capture_output=True,
                text=True,
                timeout=30,
            )

        os.unlink(compose_file)

        return {
            "success": result.returncode == 0,
            "output": result.stdout,
            "error": result.stderr,
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


# Endpoints


@app.get("/")
async def root():
    return {
        "name": "Void Uplink",
        "version": "1.0.0",
        "description": "Satellite Agent for Void Distributed Infrastructure",
        "satellite_name": SATELLITE_NAME,
        "endpoints": {
            "POST /deploy": "Deploy a Capsule (docker compose up)",
            "POST /stop": "Stop a Capsule (docker compose down)",
            "GET /logs": "Get Capsule logs",
            "GET /containers": "List running containers",
            "GET /health": "Health check",
        },
    }


@app.post("/deploy")
async def deploy_capsule(request: DeployRequest, _: bool = Depends(verify_api_key)):
    """Deploy a Capsule using docker compose"""
    result = execute_docker_compose(request.compose_file, action="up")

    if result["success"]:
        return {
            "capsule_id": request.capsule_id,
            "message": "Capsule deployed successfully",
            "output": result["output"],
        }
    else:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Deployment failed: {result['error']}",
        )


@app.post("/stop")
async def stop_capsule(request: StopRequest, _: bool = Depends(verify_api_key)):
    """Stop a Capsule using docker compose down"""
    # Find the compose file for this capsule
    # In production, we'd store compose file paths
    # For now, we'll try to find it by container name
    try:
        # Get all containers
        containers = docker_client.containers.list(all=True)

        # Find containers matching capsule_id
        capsule_containers = [
            c for c in containers if f"capsule-{request.capsule_id}" in c.name
        ]

        if not capsule_containers:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No containers found for capsule {request.capsule_id}",
            )

        # Stop all capsule containers
        for container in capsule_containers:
            container.stop()

        return {
            "capsule_id": request.capsule_id,
            "message": f"Stopped {len(capsule_containers)} containers",
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Stop failed: {str(e)}",
        )


@app.get("/logs")
async def get_capsule_logs(
    capsule_id: int, tail: int = 100, _: bool = Depends(verify_api_key)
):
    """Get logs from Capsule containers"""
    try:
        containers = docker_client.containers.list(all=True)
        capsule_containers = [
            c for c in containers if f"capsule-{capsule_id}" in c.name
        ]

        if not capsule_containers:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"No containers found for capsule {capsule_id}",
            )

        logs = {}
        for container in capsule_containers:
            try:
                logs[container.name] = container.logs(
                    tail=tail, timestamps=True
                ).decode("utf-8")
            except Exception as e:
                logs[container.name] = f"Error: {str(e)}"

        return {"capsule_id": capsule_id, "logs": logs}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get logs: {str(e)}",
        )


@app.get("/containers")
async def list_containers(_: bool = Depends(verify_api_key)):
    """List all containers on this Satellite"""
    try:
        containers = docker_client.containers.list(all=True)

        return {
            "containers": [
                {
                    "id": c.id[:12],
                    "name": c.name,
                    "image": c.image.tags[0] if c.image.tags else str(c.image),
                    "status": c.status,
                    "ports": c.ports,
                }
                for c in containers
            ]
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list containers: {str(e)}",
        )


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        containers = docker_client.containers.list()
        return {
            "status": "healthy",
            "satellite_name": SATELLITE_NAME,
            "running_containers": len(containers),
            "timestamp": datetime.now().isoformat(),
        }
    except Exception as e:
        return {
            "status": "degraded",
            "error": str(e),
            "timestamp": datetime.now().isoformat(),
        }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=UPLINK_HOST, port=UPLINK_PORT)
