import httpx
import uvicorn

from common.config import configure_logging
from common.rate_limit import RateLimiter
from web.app import create_app
from web.config import Settings

API_TIMEOUT_SECONDS = 70


def main() -> None:
    configure_logging()
    settings = Settings.from_env()
    app = create_app(
        client=httpx.AsyncClient(timeout=API_TIMEOUT_SECONDS),
        api_url=settings.api_url,
        probes={
            "api": settings.api_url,
            "worker": settings.worker_url,
            "dlq-handler": settings.dlq_handler_url,
            "reporter": settings.reporter_url,
        },
        limiter=RateLimiter(
            rate_per_second=settings.rate_limit_per_second,
            burst=settings.rate_limit_burst,
        ),
    )
    # Access logs are off: request lines are not needed, and headers carry the token.
    uvicorn.run(app, host="0.0.0.0", port=8080, access_log=False)  # noqa: S104 - inside a Pod


if __name__ == "__main__":
    main()
