import logging

from google.cloud import pubsub_v1, storage

from common.config import configure_logging
from common.db import create_pool, ensure_schema
from common.health import start_health_server
from worker.config import Settings
from worker.handler import RetryLater, process_message, write_once

logger = logging.getLogger(__name__)


def main() -> None:
    configure_logging()
    settings = Settings.from_env()
    pool = create_pool(settings.project_id, settings.database)
    ensure_schema(pool)
    bucket = storage.Client(project=settings.project_id).bucket(settings.bucket)

    def write(name: str, content: str) -> None:
        write_once(bucket, name, content)

    def callback(message) -> None:
        try:
            result = process_message(message.data, pool, write)
        except RetryLater as error:
            logger.warning("message returned to the queue: %s", error)
            message.nack()
        except Exception:
            logger.exception("message processing failed")
            message.nack()
        else:
            logger.info("message %s: %s", message.message_id, result)
            message.ack()

    subscriber = pubsub_v1.SubscriberClient(
        client_options={"api_endpoint": settings.pubsub_endpoint}
    )
    subscription = subscriber.subscription_path(settings.project_id, settings.pubsub_subscription)
    future = subscriber.subscribe(
        subscription, callback, flow_control=pubsub_v1.types.FlowControl(max_messages=10)
    )
    start_health_server(lambda: future.running())
    future.result()


if __name__ == "__main__":
    main()
