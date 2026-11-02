from common.rate_limit import RateLimiter, client_address


class Clock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now


def test_burst_is_limited_and_refills() -> None:
    clock = Clock()
    limiter = RateLimiter(rate_per_second=1, burst=2, clock=clock)
    assert limiter.allow("a")
    assert limiter.allow("a")
    assert not limiter.allow("a")
    clock.now = 1.0
    assert limiter.allow("a")


def test_clients_are_independent() -> None:
    limiter = RateLimiter(rate_per_second=1, burst=1, clock=Clock())
    assert limiter.allow("a")
    assert limiter.allow("b")


def test_memory_is_bounded() -> None:
    limiter = RateLimiter(rate_per_second=1, burst=1, max_clients=2, clock=Clock())
    for client in "abc":
        limiter.allow(client)
    assert len(limiter._buckets) == 2


def test_client_address_ignores_spoofed_entries() -> None:
    assert client_address("6.6.6.6, 1.2.3.4, 34.0.0.1", "10.0.0.1") == "1.2.3.4"


def test_client_address_falls_back_to_peer() -> None:
    assert client_address(None, "10.0.0.1") == "10.0.0.1"
    assert client_address("1.2.3.4", "10.0.0.1") == "10.0.0.1"
