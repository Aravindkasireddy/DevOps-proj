from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class PortfolioCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=128)
    strategy: str = Field(default="core_fixed_income", max_length=64)
    base_currency: str = Field(default="USD", pattern=r"^[A-Z]{3}$")


class PortfolioRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    strategy: str
    base_currency: str
    created_at: datetime


class HoldingCreate(BaseModel):
    symbol: str = Field(..., min_length=1, max_length=32)
    cusip: str | None = Field(default=None, max_length=9)
    quantity: Decimal = Field(..., gt=0)
    cost_basis: Decimal = Field(..., ge=0)
    asset_class: str = Field(default="bond", max_length=32)


class HoldingRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    portfolio_id: int
    symbol: str
    cusip: str | None
    quantity: Decimal
    cost_basis: Decimal
    asset_class: str
    updated_at: datetime


class NavSnapshotCreate(BaseModel):
    as_of_date: date
    nav: Decimal = Field(..., gt=0)
    notes: str | None = None


class NavSnapshotRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    portfolio_id: int
    as_of_date: date
    nav: Decimal
    notes: str | None
    created_at: datetime


class PortfolioSummaryRead(BaseModel):
    """Aggregated view for dashboards and risk snapshots."""

    portfolio_id: int
    name: str
    holdings_count: int
    total_cost_basis: Decimal
    latest_nav: Decimal | None = None


class HealthResponse(BaseModel):
    status: str
    app: str
    environment: str
    database: str
    version: str = Field(default="unknown", description="Package version from distribution metadata")
