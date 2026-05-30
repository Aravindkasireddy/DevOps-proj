from prometheus_client import Counter, Histogram, Info, generate_latest

REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"],
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["method", "endpoint"],
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
)
APP_INFO = Info("fin_enterprise_app", "Application build metadata")


def metrics_payload() -> bytes:
    return generate_latest()
