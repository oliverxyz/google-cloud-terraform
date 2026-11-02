"""In-process token bucket per client. The limit applies per Pod, not per deployment."""

import threading
import time
from collections import OrderedDict
from collections.abc import Callable


class RateLimiter:
    def __init__(
        self,
        rate_per_second: float,
        burst: int,
        max_clients: int = 10_000,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._rate = rate_per_second
        self._burst = burst
        self._max_clients = max_clients
        self._clock = clock
        self._buckets: OrderedDict[str, tuple[float, float]] = OrderedDict()
        self._lock = threading.Lock()

    def allow(self, client: str) -> bool:
        now = self._clock()
        with self._lock:
            tokens, updated = self._buckets.pop(client, (float(self._burst), now))
            tokens = min(self._burst, tokens + (now - updated) * self._rate)
            allowed = tokens >= 1
            self._buckets[client] = (tokens - 1 if allowed else tokens, now)
            # Bounded memory: many spoofed clients only evict the oldest ones.
            while len(self._buckets) > self._max_clients:
                self._buckets.popitem(last=False)
        return allowed


def client_address(forwarded_for: str | None, peer: str | None) -> str:
    """Returns the address the load balancer saw.

    The load balancer appends "<client>,<load balancer>", so anything earlier in the
    header was supplied by the client and cannot be trusted.
    """
    parts = [part.strip() for part in (forwarded_for or "").split(",") if part.strip()]
    if len(parts) >= 2:
        return parts[-2]
    return peer or "unknown"
