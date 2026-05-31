from decimal import Decimal

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_health(client: AsyncClient) -> None:
    response = await client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert "version" in body
    assert body["version"]


@pytest.mark.asyncio
async def test_create_portfolio_and_holding(client: AsyncClient) -> None:
    portfolio_resp = await client.post(
        "/api/v1/portfolios",
        json={
            "name": "Financial Enterprise Core Bond",
            "strategy": "core_fixed_income",
            "base_currency": "USD",
        },
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
    data = summary.json()
    assert data["holdings_count"] == 1
    assert Decimal(data["total_cost_basis"]) == Decimal("1000") * Decimal("98.50")


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
    assert Decimal(nav.json()["nav"]) == Decimal("15000000.00")


@pytest.mark.asyncio
async def test_list_portfolios_filter_by_strategy(client: AsyncClient) -> None:
    await client.post(
        "/api/v1/portfolios",
        json={"name": "Alpha", "strategy": "equity_long_only", "base_currency": "USD"},
    )
    await client.post(
        "/api/v1/portfolios",
        json={"name": "Beta", "strategy": "core_fixed_income", "base_currency": "EUR"},
    )
    only_equity = await client.get("/api/v1/portfolios", params={"strategy": "equity_long_only"})
    assert only_equity.status_code == 200
    names = {p["name"] for p in only_equity.json()}
    assert names == {"Alpha"}

    all_rows = await client.get("/api/v1/portfolios")
    assert len(all_rows.json()) == 2
