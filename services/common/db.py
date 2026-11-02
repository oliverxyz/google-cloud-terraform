"""Database connection pool and schema."""

from psycopg_pool import ConnectionPool

from common.config import DatabaseSettings
from common.secrets import read_secret

# Arbitrary constant: serializes schema creation between services starting together.
SCHEMA_LOCK_ID = 727001

SCHEMA = """
CREATE TABLE IF NOT EXISTS documents (
    id                 uuid PRIMARY KEY,
    title              text NOT NULL,
    status             text NOT NULL DEFAULT 'pending',
    latest_revision    integer NOT NULL DEFAULT 1,
    processed_revision integer NOT NULL DEFAULT 0,
    error              text,
    created_at         timestamptz NOT NULL DEFAULT now(),
    updated_at         timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS revisions (
    document_id  uuid NOT NULL REFERENCES documents (id),
    revision     integer NOT NULL,
    content      text NOT NULL,
    object_name  text,
    processed_at timestamptz,
    PRIMARY KEY (document_id, revision)
);
"""


def create_pool(project_id: str, database: DatabaseSettings) -> ConnectionPool:
    pool = ConnectionPool(
        min_size=1,
        max_size=4,
        open=False,
        kwargs={
            "host": database.host,
            "port": database.port,
            "dbname": database.name,
            "user": database.user,
            "password": read_secret(project_id, database.password_secret),
            # The endpoint is reached by IP, and the certificate is issued for a DNS name,
            # so verify-full is not possible here.
            "sslmode": "verify-ca",
            "sslrootcert": database.ca_cert_path,
            "connect_timeout": 10,
        },
    )
    pool.open(wait=True, timeout=60)
    return pool


def ensure_schema(pool: ConnectionPool) -> None:
    with pool.connection() as connection:
        connection.execute("SELECT pg_advisory_xact_lock(%s)", (SCHEMA_LOCK_ID,))
        connection.execute(SCHEMA)
