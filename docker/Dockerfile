# syntax=docker/dockerfile:1
# Financial Enterprise API - multi-stage production image
FROM python:3.12-slim AS builder

WORKDIR /build
COPY pyproject.toml README.md ./
COPY app ./app
RUN pip install --no-cache-dir build && pip wheel --no-cache-dir --wheel-dir /wheels .

FROM python:3.12-slim AS runtime

LABEL org.opencontainers.image.title="fin-enterprise-api" \
      org.opencontainers.image.description="Financial Enterprise Application API" \
      org.opencontainers.image.vendor="Financial Enterprise Application"

RUN groupadd -r finenterprise && useradd -r -g finenterprise finenterprise
WORKDIR /app

COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir /wheels/*.whl && rm -rf /wheels

COPY database ./database

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    API_HOST=0.0.0.0 \
    API_PORT=8000

RUN mkdir -p /tmp/prometheus && chown finenterprise:finenterprise /tmp/prometheus

USER finenterprise
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')" || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
