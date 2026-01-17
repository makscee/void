"""API client for Overseer"""

import httpx
from typing import Optional, Dict, Any


class VoidAPI:
    """HTTP client for Overseer API"""

    def __init__(self, overseer_url: str, api_key: Optional[str] = None):
        self.base_url = overseer_url.rstrip("/")
        self.api_key = api_key
        self.timeout = 30.0

    async def register_satellite(
        self, name: str, ip: str, hostname: str, capabilities: list
    ) -> Dict[str, Any]:
        """Register a new satellite with Overseer"""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                f"{self.base_url}/satellite/register",
                json={
                    "name": name,
                    "ip_address": ip,
                    "hostname": hostname,
                    "capabilities": capabilities,
                },
            )
            response.raise_for_status()
            return response.json()

    async def get_satellites(self, api_key: str) -> Dict[str, Any]:
        """List all satellites"""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.get(
                f"{self.base_url}/satellites",
                headers={"X-API-Key": api_key},
            )
            response.raise_for_status()
            return response.json()

    async def get_satellite(self, satellite_id: int, api_key: str) -> Dict[str, Any]:
        """Get specific satellite details"""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.get(
                f"{self.base_url}/satellites/{satellite_id}",
                headers={"X-API-Key": api_key},
            )
            response.raise_for_status()
            return response.json()

    async def delete_satellite(self, satellite_id: int, api_key: str) -> Dict[str, Any]:
        """Delete a satellite"""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.delete(
                f"{self.base_url}/satellites/{satellite_id}",
                headers={"X-API-Key": api_key},
            )
            response.raise_for_status()
            return response.json()

    async def get_capsules(self, api_key: str) -> Dict[str, Any]:
        """List all capsules"""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.get(
                f"{self.base_url}/capsules",
                headers={"X-API-Key": api_key},
            )
            response.raise_for_status()
            return response.json()

    async def get_capsule(self, capsule_id: int, api_key: str) -> Dict[str, Any]:
        """Get specific capsule details"""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.get(
                f"{self.base_url}/capsules/{capsule_id}",
                headers={"X-API-Key": api_key},
            )
            response.raise_for_status()
            return response.json()

    async def create_capsule(
        self,
        name: str,
        satellite_id: int,
        git_url: str,
        compose_file: str,
        api_key: str,
    ) -> Dict[str, Any]:
        """Create a new capsule"""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                f"{self.base_url}/capsules",
                headers={"X-API-Key": api_key},
                json={
                    "name": name,
                    "satellite_id": satellite_id,
                    "git_url": git_url,
                    "compose_file": compose_file,
                },
            )
            response.raise_for_status()
            return response.json()

    async def deploy_capsule(self, capsule_id: int, api_key: str) -> Dict[str, Any]:
        """Deploy a capsule"""
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f"{self.base_url}/capsules/{capsule_id}/deploy",
                headers={"X-API-Key": api_key},
            )
            response.raise_for_status()
            return response.json()

    async def stop_capsule(self, capsule_id: int, api_key: str) -> Dict[str, Any]:
        """Stop a capsule"""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                f"{self.base_url}/capsules/{capsule_id}/stop",
                headers={"X-API-Key": api_key},
            )
            response.raise_for_status()
            return response.json()

    async def get_capsule_logs(
        self, capsule_id: int, tail: int, api_key: str
    ) -> Dict[str, Any]:
        """Get capsule logs"""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                f"{self.base_url}/capsules/{capsule_id}/logs",
                headers={"X-API-Key": api_key},
                params={"tail": tail},
            )
            response.raise_for_status()
            return response.json()

    async def get_health(self) -> Dict[str, Any]:
        """Get Overseer health status"""
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(f"{self.base_url}/health")
            response.raise_for_status()
            return response.json()
