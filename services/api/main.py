import httpx
import uvicorn
from google.cloud import pubsub_v1

from api.app import create_app
from api.config import Settings
from api.rate_limit import RateLimiter
from api.store import Store
from common.config import configure_logging
from common.db import create_pool, ensure_schema
from common.secrets import read_secret

PUBLISH_TIMEOUT_SECONDS = 30


def main() -> None:
    configure_logging()
    settings = Settings.from_env()
    pool = create_pool(settings.project_id, settings.database)
    ensure_schema(pool)

    # The topic only accepts traffic in its own region, and ordering needs one region anyway.
    publisher = pubsub_v1.PublisherClient(
        publisher_options=pubsub_v1.types.PublisherOptions(enable_message_ordering=True),
        client_options={"api_endpoint": settings.pubsub_endpoint},
    )
    topic = publisher.topic_path(settings.project_id, settings.pubsub_topic)

    def publish(data: bytes, ordering_key: str) -> None:
        try:
            publisher.publish(topic, data, ordering_key=ordering_key).result(
                timeout=PUBLISH_TIMEOUT_SECONDS
            )
        except Exception:
            # The client pauses a key after a failure until this is called.
            publisher.resume_publish(topic, ordering_key)
            raise

    def request_report() -> dict:
        response = httpx.post(f"{settings.reporter_url}/reports", timeout=60)
        response.raise_for_status()
        return response.json()

    app = create_app(
        store=Store(pool),
        publish=publish,
        request_report=request_report,
        api_token=read_secret(settings.project_id, settings.api_token_secret),
        limiter=RateLimiter(
            rate_per_second=settings.rate_limit_per_second,
            burst=settings.rate_limit_burst,
        ),
    )
    uvicorn.run(app, host="0.0.0.0", port=8080, access_log=False)  # noqa: S104 - inside a Pod


if __name__ == "__main__":
    main()
