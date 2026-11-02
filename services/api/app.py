"""Public HTTP API. Everything except the health check requires a token."""

import hmac
import json
import logging
import uuid
from collections.abc import Callable

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from api.store import DocumentNotFound
from common.rate_limit import RateLimiter, client_address

logger = logging.getLogger(__name__)

MAX_BODY_BYTES = 128 * 1024
MAX_CONTENT_CHARS = 64 * 1024


class NewDocument(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    content: str = Field(max_length=MAX_CONTENT_CHARS)
    # Makes the worker fail on purpose, to show the path to the dead-letter topic.
    simulate_failure: bool = False


class NewRevision(BaseModel):
    content: str = Field(max_length=MAX_CONTENT_CHARS)
    simulate_failure: bool = False


def create_app(
    store,
    publish: Callable[[bytes, str], None],
    request_report: Callable[[], dict],
    api_token: str,
    limiter: RateLimiter,
) -> FastAPI:
    app = FastAPI(title="Documents API", docs_url=None, redoc_url=None, openapi_url=None)

    @app.middleware("http")
    async def guard(request: Request, call_next):
        if request.url.path == "/healthz":
            return await call_next(request)
        client = client_address(
            request.headers.get("x-forwarded-for"),
            request.client.host if request.client else None,
        )
        if not limiter.allow(client):
            return JSONResponse(
                {"detail": "rate limit exceeded"}, status_code=429, headers={"Retry-After": "1"}
            )
        if request.method == "POST":
            length = request.headers.get("content-length")
            if length is None:
                return JSONResponse({"detail": "content length required"}, status_code=411)
            if not length.isdigit() or int(length) > MAX_BODY_BYTES:
                return JSONResponse({"detail": "body too large"}, status_code=413)
        return await call_next(request)

    def require_token(authorization: str = Header(default="")) -> None:
        if not hmac.compare_digest(authorization.encode(), f"Bearer {api_token}".encode()):
            raise HTTPException(status_code=401, detail="invalid token")

    def publish_revision(document_id: str, revision: int, simulate_failure: bool) -> None:
        message = {
            "document_id": document_id,
            "revision": revision,
            "simulate_failure": simulate_failure,
        }
        try:
            publish(json.dumps(message).encode(), document_id)
        except Exception as error:
            logger.exception("publish failed")
            raise HTTPException(status_code=502, detail="queue is unavailable") from error

    @app.get("/healthz")
    def health() -> dict:
        return {"status": "ok"}

    @app.post("/documents", status_code=202, dependencies=[Depends(require_token)])
    def create_document(body: NewDocument) -> dict:
        document_id = store.create_document(body.title, body.content)
        publish_revision(document_id, 1, body.simulate_failure)
        return {"id": document_id, "revision": 1}

    @app.post(
        "/documents/{document_id}/revisions",
        status_code=202,
        dependencies=[Depends(require_token)],
    )
    def add_revision(document_id: uuid.UUID, body: NewRevision) -> dict:
        try:
            revision = store.add_revision(str(document_id), body.content)
        except DocumentNotFound as error:
            raise HTTPException(status_code=404, detail="document not found") from error
        publish_revision(str(document_id), revision, body.simulate_failure)
        return {"id": str(document_id), "revision": revision}

    @app.get("/documents/{document_id}", dependencies=[Depends(require_token)])
    def get_document(document_id: uuid.UUID) -> dict:
        try:
            return store.get_document(str(document_id))
        except DocumentNotFound as error:
            raise HTTPException(status_code=404, detail="document not found") from error

    @app.post("/reports", dependencies=[Depends(require_token)])
    def create_report() -> dict:
        try:
            return request_report()
        except Exception as error:
            logger.exception("report failed")
            raise HTTPException(status_code=502, detail="reporter is unavailable") from error

    return app
