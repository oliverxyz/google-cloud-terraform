"""Environment of the api service. Values are set in charts/platform/env/api.yaml."""

import os
from dataclasses import dataclass

from common.config import DatabaseSettings


@dataclass(frozen=True)
class Settings:
    project_id: str
    database: DatabaseSettings
    pubsub_endpoint: str
    pubsub_topic: str
    api_token_secret: str
    reporter_url: str
    rate_limit_per_second: float
    rate_limit_burst: int

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            project_id=os.environ["PROJECT_ID"],
            database=DatabaseSettings.from_env(),
            pubsub_endpoint=os.environ["PUBSUB_ENDPOINT"],
            pubsub_topic=os.environ["PUBSUB_TOPIC"],
            api_token_secret=os.environ["API_TOKEN_SECRET"],
            reporter_url=os.environ["REPORTER_URL"],
            rate_limit_per_second=float(os.environ["RATE_LIMIT_PER_SECOND"]),
            rate_limit_burst=int(os.environ["RATE_LIMIT_BURST"]),
        )
