from decimal import Decimal
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models import Holding, NavSnapshot, Portfolio
from app.schemas import (
    HoldingCreate,
    HoldingRead,
    NavSnapshotCreate,
    NavSnapshotRead,
    PortfolioCreate,
    PortfolioRead,
    PortfolioSummaryRead,
)

router = APIRouter(prefix="/api/v1/portfolios", tags=["portfolios"])

DbSession = Annotated[AsyncSession, Depends(get_db)]


@router.post("", response_model=PortfolioRead, status_code=status.HTTP_201_CREATED)
async def create_portfolio(payload: PortfolioCreate, db: DbSession) -> Portfolio:
    existing = await db.scalar(select(Portfolio).where(Portfolio.name == payload.name))
    if existing:
        raise HTTPException(status_code=409, detail="Portfolio name already exists")
    portfolio = Portfolio(**payload.model_dump())
    db.add(portfolio)
    await db.commit()
    await db.refresh(portfolio)
    return portfolio


@router.get("", response_model=list[PortfolioRead])
async def list_portfolios(
    db: DbSession,
    strategy: str | None = Query(
        default=None,
        description="When set, return only portfolios with this strategy code.",
        max_length=64,
    ),
) -> list[Portfolio]:
    stmt = select(Portfolio).order_by(Portfolio.id)
    if strategy is not None and strategy != "":
        stmt = stmt.where(Portfolio.strategy == strategy)
    result = await db.scalars(stmt)
    return list(result.all())


@router.get("/{portfolio_id}", response_model=PortfolioRead)
async def get_portfolio(portfolio_id: int, db: DbSession) -> Portfolio:
    portfolio = await db.get(Portfolio, portfolio_id)
    if not portfolio:
        raise HTTPException(status_code=404, detail="Portfolio not found")
    return portfolio


@router.post(
    "/{portfolio_id}/holdings",
    response_model=HoldingRead,
    status_code=status.HTTP_201_CREATED,
)
async def add_holding(
    portfolio_id: int,
    payload: HoldingCreate,
    db: DbSession,
) -> Holding:
    portfolio = await db.get(Portfolio, portfolio_id)
    if not portfolio:
        raise HTTPException(status_code=404, detail="Portfolio not found")
    holding = Holding(portfolio_id=portfolio_id, **payload.model_dump())
    db.add(holding)
    await db.commit()
    await db.refresh(holding)
    return holding


@router.get("/{portfolio_id}/holdings", response_model=list[HoldingRead])
async def list_holdings(portfolio_id: int, db: DbSession) -> list[Holding]:
    portfolio = await db.get(Portfolio, portfolio_id)
    if not portfolio:
        raise HTTPException(status_code=404, detail="Portfolio not found")
    result = await db.scalars(select(Holding).where(Holding.portfolio_id == portfolio_id))
    return list(result.all())


@router.post(
    "/{portfolio_id}/nav",
    response_model=NavSnapshotRead,
    status_code=status.HTTP_201_CREATED,
)
async def record_nav(
    portfolio_id: int,
    payload: NavSnapshotCreate,
    db: DbSession,
) -> NavSnapshot:
    portfolio = await db.get(Portfolio, portfolio_id)
    if not portfolio:
        raise HTTPException(status_code=404, detail="Portfolio not found")
    snapshot = NavSnapshot(portfolio_id=portfolio_id, **payload.model_dump())
    db.add(snapshot)
    await db.commit()
    await db.refresh(snapshot)
    return snapshot


@router.get("/{portfolio_id}/summary", response_model=PortfolioSummaryRead)
async def portfolio_summary(portfolio_id: int, db: DbSession) -> PortfolioSummaryRead:
    stmt = (
        select(Portfolio)
        .where(Portfolio.id == portfolio_id)
        .options(selectinload(Portfolio.holdings), selectinload(Portfolio.nav_snapshots))
    )
    portfolio = await db.scalar(stmt)
    if not portfolio:
        raise HTTPException(status_code=404, detail="Portfolio not found")
    total_cost = sum(
        (h.quantity * h.cost_basis for h in portfolio.holdings),
        start=Decimal(0),
    )
    latest_nav = max((n.nav for n in portfolio.nav_snapshots), default=None)
    return PortfolioSummaryRead(
        portfolio_id=portfolio.id,
        name=portfolio.name,
        holdings_count=len(portfolio.holdings),
        total_cost_basis=total_cost,
        latest_nav=latest_nav,
    )
