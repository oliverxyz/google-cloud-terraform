import uvicorn
from google.cloud import storage

from common.config import configure_logging
from common.db import create_pool, ensure_schema
from reporter.app import create_app
from reporter.config import Settings


def main() -> None:
    configure_logging()
    settings = Settings.from_env()
    pool = create_pool(settings.project_id, settings.database)
    ensure_schema(pool)
    bucket = storage.Client(project=settings.project_id).bucket(settings.bucket)
    app = create_app(pool, bucket)
    uvicorn.run(app, host="0.0.0.0", port=8080, access_log=False)  # noqa: S104 - inside a Pod


if __name__ == "__main__":
    main()
