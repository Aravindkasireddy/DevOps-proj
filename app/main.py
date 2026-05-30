from __future__ import annotations

import time
from collections.abc import AsyncIterator, Awaitable, Callable
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, Response
from fastapi.responses import PlainTextResponse
from sqlalchemy import text

from app.config import get_settings
from app.database import Base, engine
from app.logging_config import setup_logging
from app.metrics import APP_INFO, REQUEST_COUNT, REQUEST_LATENCY, metrics_payload
from app.routers import portfolios
from app.schemas import HealthResponse

settings = get_settings()
setup_logging(settings.log_level)


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    APP_INFO.info(
        {
            "version": "1.0.0",
            "client": "fin-enterprise-application",
            "env": settings.app_env,
        }
    )
    yield
    await engine.dispose()


app = FastAPI(
    title="Financial Enterprise Application API",
    description="Portfolio, holdings, and NAV management for institutional asset management.",
    version="1.0.0",
    lifespan=lifespan,
)
app.include_router(portfolios.router)


_METRICS_SKIP_PATHS = frozenset(
    {"/metrics", "/health", "/ready", "/docs", "/redoc", "/openapi.json"}
)


def _metrics_path(request: Request) -> str:
    route = request.scope.get("route")
    if route is not None and getattr(route, "path", None):
        return str(route.path)
    return request.url.path


@app.middleware("http")
async def metrics_middleware(
    request: Request,
    call_next: Callable[[Request], Awaitable[Response]],
) -> Response:
    path = request.url.path
    if path in _METRICS_SKIP_PATHS or path.startswith("/docs/"):
        return await call_next(request)
    start = time.perf_counter()
    response: Response = await call_next(request)
    elapsed = time.perf_counter() - start
    endpoint = _metrics_path(request)
    REQUEST_COUNT.labels(request.method, endpoint, str(response.status_code)).inc()
    REQUEST_LATENCY.labels(request.method, endpoint).observe(elapsed)
    return response


@app.get("/health", response_model=HealthResponse, tags=["ops"])
async def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        app=settings.app_name,
        environment=settings.app_env,
        database="unknown",
    )


@app.get("/ready", response_model=HealthResponse, tags=["ops"])
async def ready() -> HealthResponse:
    db_status = "ok"
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
    except Exception:
        db_status = "down"
    return HealthResponse(
        status="ok" if db_status == "ok" else "degraded",
        app=settings.app_name,
        environment=settings.app_env,
        database=db_status,
    )


@app.get("/metrics", tags=["ops"])
async def metrics() -> PlainTextResponse:
    return PlainTextResponse(content=metrics_payload().decode("utf-8"), media_type="text/plain")


@app.get("/", tags=["ops"])
async def root() -> dict[str, str]:
    return {"service": settings.app_name, "docs": "/docs"}
