import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health(client: AsyncClient) -> None:
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_create_portfolio_and_holding(client: AsyncClient) -> None:
    portfolio_resp = await client.post(
        "/api/v1/portfolios",
        json={"name": "Financial Enterprise Core Bond", "strategy": "core_fixed_income", "base_currency": "USD"},
    )
    assert portfolio_resp.status_code == 201
    portfolio_id = portfolio_resp.json()["id"]

    holding_resp = await client.post(
        f"/api/v1/portfolios/{portfolio_id}/holdings",
        json={
            "symbol": "FE-BOND-A",
            "cusip": "123456789",
            "quantity": "1000",
            "cost_basis": "98.50",
            "asset_class": "bond",
        },
    )
    assert holding_resp.status_code == 201

    summary = await client.get(f"/api/v1/portfolios/{portfolio_id}/summary")
    assert summary.status_code == 200
    assert summary.json()["holdings_count"] == 1


@pytest.mark.asyncio
async def test_duplicate_portfolio_name(client: AsyncClient) -> None:
    payload = {"name": "Duplicate Fund", "strategy": "credit", "base_currency": "USD"}
    first = await client.post("/api/v1/portfolios", json=payload)
    second = await client.post("/api/v1/portfolios", json=payload)
    assert first.status_code == 201
    assert second.status_code == 409


@pytest.mark.asyncio
async def test_record_nav(client: AsyncClient) -> None:
    portfolio = await client.post(
        "/api/v1/portfolios",
        json={"name": "NAV Fund", "strategy": "structured_credit", "base_currency": "USD"},
    )
    pid = portfolio.json()["id"]
    nav = await client.post(
        f"/api/v1/portfolios/{pid}/nav",
        json={"as_of_date": "2026-05-27", "nav": "15000000.00", "notes": "EOD"},
    )
    assert nav.status_code == 201
    assert nav.json()["nav"] == "15000000.00"
