"""Database access of the API."""

import uuid

from psycopg_pool import ConnectionPool


class DocumentNotFound(Exception):
    pass


class Store:
    def __init__(self, pool: ConnectionPool) -> None:
        self._pool = pool

    def create_document(self, title: str, content: str) -> str:
        document_id = str(uuid.uuid4())
        with self._pool.connection() as connection:
            connection.execute(
                "INSERT INTO documents (id, title) VALUES (%s, %s)", (document_id, title)
            )
            connection.execute(
                "INSERT INTO revisions (document_id, revision, content) VALUES (%s, 1, %s)",
                (document_id, content),
            )
        return document_id

    def add_revision(self, document_id: str, content: str) -> int:
        with self._pool.connection() as connection:
            row = connection.execute(
                """
                UPDATE documents
                SET latest_revision = latest_revision + 1, status = 'pending', updated_at = now()
                WHERE id = %s
                RETURNING latest_revision
                """,
                (document_id,),
            ).fetchone()
            if row is None:
                raise DocumentNotFound(document_id)
            connection.execute(
                "INSERT INTO revisions (document_id, revision, content) VALUES (%s, %s, %s)",
                (document_id, row[0], content),
            )
        return row[0]

    def get_document(self, document_id: str) -> dict:
        with self._pool.connection() as connection:
            row = connection.execute(
                """
                SELECT id, title, status, latest_revision, processed_revision, error
                FROM documents WHERE id = %s
                """,
                (document_id,),
            ).fetchone()
        if row is None:
            raise DocumentNotFound(document_id)
        return {
            "id": str(row[0]),
            "title": row[1],
            "status": row[2],
            "latest_revision": row[3],
            "processed_revision": row[4],
            "error": row[5],
        }
