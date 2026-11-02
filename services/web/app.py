"""Web interface: service status for everyone, API requests for whoever has the API token.

This service holds no secrets. The token is typed into the page, travels with each request
and is forwarded to the api service, which is the one that checks it.
"""

import asyncio
import time
import uuid
from collections.abc import Callable
from pathlib import Path

import httpx
from fastapi import FastAPI, Request
from fastapi.responses import FileResponse, JSONResponse, Response
from fastapi.staticfiles import StaticFiles

from common.rate_limit import RateLimiter, client_address

STATIC_DIR = Path(__file__).parent / "static"
MAX_BODY_BYTES = 128 * 1024
PROBE_TIMEOUT_SECONDS = 3
# Visitors cannot turn page views into more internal requests than this allows.
STATUS_CACHE_SECONDS = 5

SECURITY_HEADERS = {
    "Content-Security-Policy": (
        "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; "
        "base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
    ),
    "Referrer-Policy": "no-referrer",
    "Strict-Transport-Security": "max-age=3600",
    "X-Content-Type-Options": "nosniff",
}


def create_app(
    client: httpx.AsyncClient,
    api_url: str,
    probes: dict[str, str],
    limiter: RateLimiter,
    clock: Callable[[], float] = time.monotonic,
) -> FastAPI:
    app = FastAPI(title="Web", docs_url=None, redoc_url=None, openapi_url=None)
    status_cache: dict = {"expires": 0.0, "value": None}

    @app.middleware("http")
    async def guard(request: Request, call_next):
        if request.url.path == "/healthz":
            return await call_next(request)
        visitor = client_address(
            request.headers.get("x-forwarded-for"),
            request.client.host if request.client else None,
        )
        if not limiter.allow(visitor):
            response = JSONResponse(
                {"detail": "rate limit exceeded"}, status_code=429, headers={"Retry-After": "1"}
            )
        elif request.method == "POST" and not _body_size_is_valid(request):
            response = JSONResponse({"detail": "body too large or without length"}, 413)
        else:
            response = await call_next(request)
        response.headers.update(SECURITY_HEADERS)
        return response

    async def probe(name: str, url: str) -> dict:
        try:
            response = await client.get(f"{url}/healthz", timeout=PROBE_TIMEOUT_SECONDS)
            healthy = response.status_code == 200
        except httpx.HTTPError:
            healthy = False
        # Name and state only: no addresses or errors reach the visitor.
        return {"name": name, "status": "up" if healthy else "down"}

    async def forward(request: Request, method: str, path: str) -> Response:
        headers = {"X-Forwarded-For": f"{_visitor_chain(request)},web"}
        if authorization := request.headers.get("authorization"):
            headers["Authorization"] = authorization
        if content_type := request.headers.get("content-type"):
            headers["Content-Type"] = content_type
        try:
            response = await client.request(
                method, f"{api_url}{path}", headers=headers, content=await request.body()
            )
        except httpx.HTTPError:
            return JSONResponse({"detail": "api is unavailable"}, status_code=502)
        return Response(
            response.content,
            status_code=response.status_code,
            media_type=response.headers.get("content-type"),
        )

    @app.get("/healthz")
    def health() -> dict:
        return {"status": "ok"}

    @app.get("/")
    def index() -> FileResponse:
        return FileResponse(STATIC_DIR / "index.html")

    @app.get("/status")
    async def status() -> dict:
        now = clock()
        if now >= status_cache["expires"]:
            results = await asyncio.gather(*(probe(n, u) for n, u in probes.items()))
            status_cache["value"] = {"services": list(results)}
            status_cache["expires"] = now + STATUS_CACHE_SECONDS
        return status_cache["value"]

    # An explicit list of what can be forwarded, not a generic proxy.
    @app.post("/api/documents")
    async def create_document(request: Request) -> Response:
        return await forward(request, "POST", "/documents")

    @app.post("/api/documents/{document_id}/revisions")
    async def add_revision(document_id: uuid.UUID, request: Request) -> Response:
        return await forward(request, "POST", f"/documents/{document_id}/revisions")

    @app.get("/api/documents/{document_id}")
    async def get_document(document_id: uuid.UUID, request: Request) -> Response:
        return await forward(request, "GET", f"/documents/{document_id}")

    @app.post("/api/reports")
    async def create_report(request: Request) -> Response:
        return await forward(request, "POST", "/reports")

    app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
    return app


def _body_size_is_valid(request: Request) -> bool:
    length = request.headers.get("content-length", "")
    return length.isdigit() and int(length) <= MAX_BODY_BYTES


def _visitor_chain(request: Request) -> str:
    """The api service applies its rate limit to the entry before the last one."""
    return client_address(
        request.headers.get("x-forwarded-for"),
        request.client.host if request.client else None,
    )
