import json
import logging

from google.cloud import pubsub_v1
from psycopg_pool import ConnectionPool

from common.config import configure_logging
from common.db import create_pool, ensure_schema
from common.health import start_health_server
from dlq_handler.config import Settings

logger = logging.getLogger(__name__)


def mark_failed(data: bytes, delivery_attempts: str | None, pool: ConnectionPool) -> None:
    message = json.loads(data)
    error = f"revision {message['revision']} failed after {delivery_attempts or '?'} deliveries"
    with pool.connection() as connection:
        connection.execute(
            "UPDATE documents SET status = 'failed', error = %s, updated_at = now() WHERE id = %s",
            (error, message["document_id"]),
        )


def main() -> None:
    configure_logging()
    settings = Settings.from_env()
    pool = create_pool(settings.project_id, settings.database)
    ensure_schema(pool)

    def callback(message) -> None:
        try:
            mark_failed(
                message.data,
                message.attributes.get("CloudPubSubDeadLetterSourceDeliveryCount"),
                pool,
            )
        except Exception:
            logger.exception("dead letter processing failed")
            message.nack()
        else:
            logger.warning("message %s marked as failed", message.message_id)
            message.ack()

    subscriber = pubsub_v1.SubscriberClient(
        client_options={"api_endpoint": settings.pubsub_endpoint}
    )
    subscription = subscriber.subscription_path(settings.project_id, settings.pubsub_subscription)
    future = subscriber.subscribe(subscription, callback)
    start_health_server(lambda: future.running())
    future.result()


if __name__ == "__main__":
    main()
