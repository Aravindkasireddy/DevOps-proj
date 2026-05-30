from __future__ import annotations

from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, DateTime, ForeignKey, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Portfolio(Base):
    __tablename__ = "portfolios"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    strategy: Mapped[str] = mapped_column(String(64), default="core_fixed_income")
    base_currency: Mapped[str] = mapped_column(String(3), default="USD")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    holdings: Mapped[list[Holding]] = relationship(
        back_populates="portfolio",
        cascade="all, delete-orphan",
    )
    nav_snapshots: Mapped[list[NavSnapshot]] = relationship(
        back_populates="portfolio",
        cascade="all, delete-orphan",
    )


class Holding(Base):
    __tablename__ = "holdings"

    id: Mapped[int] = mapped_column(primary_key=True)
    portfolio_id: Mapped[int] = mapped_column(
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        index=True,
    )
    symbol: Mapped[str] = mapped_column(String(32), index=True)
    cusip: Mapped[str | None] = mapped_column(String(9), nullable=True)
    quantity: Mapped[Decimal] = mapped_column(Numeric(18, 6))
    cost_basis: Mapped[Decimal] = mapped_column(Numeric(18, 4))
    asset_class: Mapped[str] = mapped_column(String(32), default="bond")
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    portfolio: Mapped[Portfolio] = relationship(back_populates="holdings")


class NavSnapshot(Base):
    __tablename__ = "nav_snapshots"

    id: Mapped[int] = mapped_column(primary_key=True)
    portfolio_id: Mapped[int] = mapped_column(
        ForeignKey("portfolios.id", ondelete="CASCADE"),
        index=True,
    )
    as_of_date: Mapped[date] = mapped_column(Date, index=True)
    nav: Mapped[Decimal] = mapped_column(Numeric(20, 4))
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    portfolio: Mapped[Portfolio] = relationship(back_populates="nav_snapshots")
