"""Environment of the reporter service. Values are set in charts/platform/env/reporter.yaml."""

import os
from dataclasses import dataclass

from common.config import DatabaseSettings


@dataclass(frozen=True)
class Settings:
    project_id: str
    database: DatabaseSettings
    bucket: str

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            project_id=os.environ["PROJECT_ID"],
            database=DatabaseSettings.from_env(),
            bucket=os.environ["BUCKET"],
        )
