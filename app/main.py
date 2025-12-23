import json
import logging
import os
import secrets
import sqlite3
import time
import uuid
from urllib.parse import urlparse

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, RedirectResponse, Response
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from pydantic import BaseModel

DB_PATH = os.getenv("DB_PATH", "data.db")
BASE_URL = os.getenv("BASE_URL", "http://localhost:8000").rstrip("/")
ALPHABET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

logger = logging.getLogger("app")
handler = logging.StreamHandler()
handler.setFormatter(logging.Formatter("%(message)s"))
logger.addHandler(handler)
logger.setLevel(logging.INFO)

REQUEST_COUNT = Counter("request_count", "HTTP request count", ["method", "route", "status"])
REQUEST_LATENCY = Histogram("request_latency_seconds", "HTTP request latency", ["method", "route"])

resource = Resource.create({"service.name": "url-shortener"})
provider = TracerProvider(resource=resource)
provider.add_span_processor(SimpleSpanProcessor(ConsoleSpanExporter()))
trace.set_tracer_provider(provider)

app = FastAPI()
FastAPIInstrumentor.instrument_app(app)

conn = sqlite3.connect(DB_PATH, check_same_thread=False)
conn.execute("CREATE TABLE IF NOT EXISTS urls (code TEXT PRIMARY KEY, url TEXT)")
conn.commit()


class ShortenRequest(BaseModel):
    url: str


def is_valid_url(value: str) -> bool:
    parsed = urlparse(value)
    return parsed.scheme in ("http", "https") and bool(parsed.netloc)


def make_code(length: int = 6) -> str:
    return "".join(secrets.choice(ALPHABET) for _ in range(length))


def log_event(**fields) -> None:
    logger.info(json.dumps(fields, separators=(",", ":")))


@app.middleware("http")
async def observe(request: Request, call_next):
    start = time.perf_counter()
    request_id = str(uuid.uuid4())
    path = request.url.path
    try:
        response = await call_next(request)
        status = response.status_code
    except Exception as exc:
        duration = (time.perf_counter() - start) * 1000
        route = getattr(request.scope.get("route"), "path", path)
        REQUEST_COUNT.labels(request.method, route, "500").inc()
        REQUEST_LATENCY.labels(request.method, route).observe(duration / 1000)
        log_event(
            timestamp=time.time(),
            method=request.method,
            path=path,
            status=500,
            duration_ms=round(duration, 2),
            request_id=request_id,
            error=str(exc),
        )
        raise
    duration = (time.perf_counter() - start) * 1000
    route = getattr(request.scope.get("route"), "path", path)
    REQUEST_COUNT.labels(request.method, route, str(status)).inc()
    REQUEST_LATENCY.labels(request.method, route).observe(duration / 1000)
    log_event(
        timestamp=time.time(),
        method=request.method,
        path=path,
        status=status,
        duration_ms=round(duration, 2),
        request_id=request_id,
    )
    response.headers["X-Request-ID"] = request_id
    return response


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/shorten")
def shorten(body: ShortenRequest):
    if not is_valid_url(body.url):
        raise HTTPException(status_code=400, detail="invalid url")
    code = None
    for _ in range(5):
        candidate = make_code()
        try:
            conn.execute("INSERT INTO urls (code, url) VALUES (?, ?)", (candidate, body.url))
            conn.commit()
            code = candidate
            break
        except sqlite3.IntegrityError:
            continue
    if not code:
        raise HTTPException(status_code=500, detail="could not generate code")
    return {"code": code, "short_url": f"{BASE_URL}/{code}"}


@app.get("/{code}")
def resolve(code: str):
    row = conn.execute("SELECT url FROM urls WHERE code = ?", (code,)).fetchone()
    if not row:
        return JSONResponse({"error": "not found"}, status_code=404)
    return RedirectResponse(row[0], status_code=302)
