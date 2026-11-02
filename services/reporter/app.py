"""Internal service: summarizes the database and the stored files into a new file."""

import json
import uuid
from datetime import UTC, datetime

from fastapi import FastAPI

FILES_PREFIX = "documents/"
# Reading is part of the report, but its cost must stay bounded.
MAX_FILES_READ = 100


def build_report(pool, bucket) -> dict:
    with pool.connection() as connection:
        rows = connection.execute(
            "SELECT status, count(*) FROM documents GROUP BY status ORDER BY status"
        ).fetchall()

    blobs = list(bucket.list_blobs(prefix=FILES_PREFIX, max_results=MAX_FILES_READ))
    total_bytes = sum(len(blob.download_as_bytes()) for blob in blobs)

    now = datetime.now(UTC)
    report = {
        "created_at": now.isoformat(),
        "documents_by_status": {status: count for status, count in rows},
        "files_read": len(blobs),
        "bytes_read": total_bytes,
    }
    name = f"reports/{now:%Y%m%dT%H%M%S}-{uuid.uuid4().hex[:8]}.json"
    bucket.blob(name).upload_from_string(json.dumps(report), content_type="application/json")
    return {**report, "report_object": name}


def create_app(pool, bucket) -> FastAPI:
    app = FastAPI(title="Reporter", docs_url=None, redoc_url=None, openapi_url=None)

    @app.get("/healthz")
    def health() -> dict:
        return {"status": "ok"}

    @app.post("/reports")
    def create_report() -> dict:
        return build_report(pool, bucket)

    return app
