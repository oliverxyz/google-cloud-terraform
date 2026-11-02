"""Environment of the worker service. Values are set in charts/platform/env/worker.yaml."""

import os
from dataclasses import dataclass

from common.config import DatabaseSettings


@dataclass(frozen=True)
class Settings:
    project_id: str
    database: DatabaseSettings
    pubsub_endpoint: str
    pubsub_subscription: str
    bucket: str

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            project_id=os.environ["PROJECT_ID"],
            database=DatabaseSettings.from_env(),
            pubsub_endpoint=os.environ["PUBSUB_ENDPOINT"],
            pubsub_subscription=os.environ["PUBSUB_SUBSCRIPTION"],
            bucket=os.environ["BUCKET"],
        )
