from typing import Generator, AsyncGenerator

import pytest
from fastapi.testclient import TestClient
from httpx import AsyncClient, ASGITransport

from ..main import app

@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"
    
@pytest.fixture()
def client() -> Generator:
    print("Setting up TestClient")
    yield TestClient(app)

@pytest.fixture()
async def async_client(client) -> AsyncGenerator:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url=client.base_url) as ac:
        print("Setting up AsyncClient")
        yield ac