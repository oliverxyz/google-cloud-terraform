"""Environment of the web service. Values are set in charts/platform/env/web.yaml."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    api_url: str
    worker_url: str
    dlq_handler_url: str
    reporter_url: str
    rate_limit_per_second: float
    rate_limit_burst: int

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            api_url=os.environ["API_URL"],
            worker_url=os.environ["WORKER_URL"],
            dlq_handler_url=os.environ["DLQ_HANDLER_URL"],
            reporter_url=os.environ["REPORTER_URL"],
            rate_limit_per_second=float(os.environ["RATE_LIMIT_PER_SECOND"]),
            rate_limit_burst=int(os.environ["RATE_LIMIT_BURST"]),
        )
