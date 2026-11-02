"""Configuration shared by all services. What is specific to a service is in its own config.py."""

import logging
import os
from dataclasses import dataclass


def configure_logging() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format='{"severity":"%(levelname)s","logger":"%(name)s","message":"%(message)s"}',
    )


@dataclass(frozen=True)
class DatabaseSettings:
    host: str
    name: str
    user: str
    password_secret: str
    ca_cert_path: str
    port: int = 5432

    @classmethod
    def from_env(cls) -> "DatabaseSettings":
        return cls(
            host=os.environ["DB_HOST"],
            name=os.environ["DB_NAME"],
            user=os.environ["DB_USER"],
            password_secret=os.environ["DB_PASSWORD_SECRET"],
            ca_cert_path=os.environ["DB_CA_CERT_PATH"],
        )
