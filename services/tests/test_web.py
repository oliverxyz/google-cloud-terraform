import uuid

import httpx
import pytest
from fastapi.testclient import TestClient

from common.rate_limit import RateLimiter
from web.app import MAX_BODY_BYTES, create_app

API = "http://api:8080"
PROBES = {"api": API, "worker": "http://worker:8080"}


class Backend:
    """Stands in for the internal services and records what reaches them."""

    def __init__(self) -> None:
        self.requests: list[httpx.Request] = []
        self.down: set[str] = set()

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        if request.url.host in self.down:
            raise httpx.ConnectError("down")
        if request.url.path == "/healthz":
            return httpx.Response(200, json={"status": "ok"})
        return httpx.Response(202, json={"id": "abc"})


class Clock:
    def __init__(self) -> None:
        self.now = 100.0

    def __call__(self) -> float:
        return self.now


@pytest.fixture
def backend() -> Backend:
    return Backend()


@pytest.fixture
def clock() -> Clock:
    return Clock()


def client_for(backend, clock, burst: int = 100) -> TestClient:
    app = create_app(
        client=httpx.AsyncClient(transport=httpx.MockTransport(backend)),
        api_url=API,
        probes=PROBES,
        limiter=RateLimiter(rate_per_second=1, burst=burst),
        clock=clock,
    )
    return TestClient(app)


def test_page_is_public_and_restricted_by_csp(backend, clock) -> None:
    response = client_for(backend, clock).get("/")
    assert response.status_code == 200
    assert "Service console" in response.text
    assert "script-src 'self'" in response.headers["content-security-policy"]
    assert response.headers["x-content-type-options"] == "nosniff"


def test_static_files_are_served(backend, clock) -> None:
    client = client_for(backend, clock)
    assert client.get("/static/app.js").status_code == 200
    assert client.get("/static/style.css").status_code == 200


def test_page_has_no_inline_code(backend, clock) -> None:
    text = client_for(backend, clock).get("/").text
    assert "<script>" not in text
    assert "onclick" not in text


def test_status_reports_names_and_states_only(backend, clock) -> None:
    backend.down.add("worker")
    response = client_for(backend, clock).get("/status")
    assert response.json() == {
        "services": [{"name": "api", "status": "up"}, {"name": "worker", "status": "down"}]
    }
    assert "http" not in response.text


def test_status_is_cached(backend, clock) -> None:
    client = client_for(backend, clock)
    client.get("/status")
    client.get("/status")
    assert len(backend.requests) == len(PROBES)
    clock.now += 10
    client.get("/status")
    assert len(backend.requests) == 2 * len(PROBES)


def test_token_is_forwarded_but_not_invented(backend, clock) -> None:
    client = client_for(backend, clock)
    client.post("/api/documents", json={"title": "t"})
    assert "authorization" not in backend.requests[-1].headers
    client.post("/api/documents", json={"title": "t"}, headers={"Authorization": "Bearer x"})
    assert backend.requests[-1].headers["authorization"] == "Bearer x"
    assert str(backend.requests[-1].url) == f"{API}/documents"


def test_visitor_address_reaches_the_api_rate_limit(backend, clock) -> None:
    client_for(backend, clock).post(
        "/api/documents",
        json={},
        headers={"X-Forwarded-For": "6.6.6.6, 1.2.3.4, 34.0.0.1"},
    )
    assert backend.requests[-1].headers["x-forwarded-for"] == "1.2.3.4,web"


@pytest.mark.parametrize(
    ("method", "path"),
    [("GET", "/api/documents/not-a-uuid"), ("POST", "/api/documents/..%2fsecrets/revisions")],
)
def test_invalid_document_id_never_reaches_the_api(backend, clock, method, path) -> None:
    response = client_for(backend, clock).request(method, path, json={})
    assert response.status_code in (404, 422)
    assert backend.requests == []


@pytest.mark.parametrize("path", ["/api/healthz", "/api/admin", "/api/documents/x/y/z"])
def test_only_listed_paths_are_forwarded(backend, clock, path) -> None:
    assert client_for(backend, clock).get(path).status_code in (404, 405)
    assert backend.requests == []


def test_valid_document_path_is_forwarded(backend, clock) -> None:
    document_id = uuid.uuid4()
    client_for(backend, clock).get(f"/api/documents/{document_id}")
    assert str(backend.requests[-1].url) == f"{API}/documents/{document_id}"


def test_api_failure_is_reported_without_details(backend, clock) -> None:
    backend.down.add("api")
    response = client_for(backend, clock).post("/api/reports", json={})
    assert response.status_code == 502
    assert "api:8080" not in response.text


def test_oversized_body_is_rejected(backend, clock) -> None:
    body = "x" * (MAX_BODY_BYTES + 1)
    response = client_for(backend, clock).post("/api/documents", content=body)
    assert response.status_code == 413
    assert backend.requests == []


def test_rate_limit_applies_but_not_to_health(backend, clock) -> None:
    client = client_for(backend, clock, burst=2)
    codes = [client.get("/").status_code for _ in range(5)]
    assert 429 in codes
    assert client.get("/healthz").status_code == 200
