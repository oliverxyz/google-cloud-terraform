"""Processes one revision of a document.

Delivery is at-least-once and a redelivery repeats later messages of the same key,
so every step has to be safe to repeat.
"""

import json
from collections.abc import Callable

from google.api_core.exceptions import PreconditionFailed
from psycopg_pool import ConnectionPool


class RetryLater(Exception):
    """The message cannot be processed now. A nack sends it back to Pub/Sub."""


def object_name(document_id: str, revision: int) -> str:
    return f"documents/{document_id}/{revision}.txt"


def write_once(bucket, name: str, content: str) -> None:
    """Writes a new object. The service account may create objects but not overwrite them."""
    try:
        bucket.blob(name).upload_from_string(content, if_generation_match=0)
    except PreconditionFailed:
        # A previous delivery got this far. The content of a revision never changes.
        pass


def process_message(data: bytes, pool: ConnectionPool, write: Callable[[str, str], None]) -> str:
    message = json.loads(data)
    document_id = message["document_id"]
    revision = message["revision"]
    if message.get("simulate_failure"):
        raise RetryLater("failure requested by the client")

    with pool.connection() as connection:
        row = connection.execute(
            "SELECT processed_revision FROM documents WHERE id = %s FOR UPDATE", (document_id,)
        ).fetchone()
        if row is None:
            raise RetryLater(f"document {document_id} is not visible yet")
        processed = row[0]
        if revision <= processed:
            return "duplicate"
        if revision != processed + 1:
            raise RetryLater(f"revision {revision} arrived after {processed}")

        content = connection.execute(
            "SELECT content FROM revisions WHERE document_id = %s AND revision = %s",
            (document_id, revision),
        ).fetchone()
        if content is None:
            raise RetryLater(f"revision {revision} is not visible yet")

        name = object_name(document_id, revision)
        write(name, content[0])
        connection.execute(
            """
            UPDATE revisions SET object_name = %s, processed_at = now()
            WHERE document_id = %s AND revision = %s
            """,
            (name, document_id, revision),
        )
        connection.execute(
            """
            UPDATE documents
            SET processed_revision = %s,
                status = CASE WHEN latest_revision = %s THEN 'processed' ELSE 'pending' END,
                updated_at = now()
            WHERE id = %s
            """,
            (revision, revision, document_id),
        )
    return "processed"
