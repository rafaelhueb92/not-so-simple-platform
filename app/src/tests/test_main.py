import pytest
from httpx import AsyncClient

@pytest.mark.anyio
async def test_read_root(async_client: AsyncClient):
    body = "test Post"
    response = await async_client.get("/")
    assert response.status_code == 200
    assert response.text == "Hello World"

@pytest.mark.anyio
async def test_health(async_client: AsyncClient):
    body = "test Post"
    response = await async_client.get("/health")
    assert response.status_code == 200
    assert response.text == "ok"

@pytest.mark.anyio
async def test_metrics(async_client: AsyncClient):
    response = await async_client.get("/metrics")
    assert response.status_code == 200
    assert b"hello_requests_total" in response.content
