import json
import uuid

import pytest
from fastapi.testclient import TestClient

from api.app import create_app
from api.rate_limit import RateLimiter
from api.store import DocumentNotFound

TOKEN = "test-token"
AUTH = {"Authorization": f"Bearer {TOKEN}"}


class FakeStore:
    def __init__(self) -> None:
        self.documents: dict[str, dict] = {}

    def create_document(self, title: str, content: str) -> str:
        document_id = str(uuid.uuid4())
        self.documents[document_id] = {"id": document_id, "title": title, "latest_revision": 1}
        return document_id

    def add_revision(self, document_id: str, content: str) -> int:
        if document_id not in self.documents:
            raise DocumentNotFound(document_id)
        self.documents[document_id]["latest_revision"] += 1
        return self.documents[document_id]["latest_revision"]

    def get_document(self, document_id: str) -> dict:
        if document_id not in self.documents:
            raise DocumentNotFound(document_id)
        return self.documents[document_id]


@pytest.fixture
def published() -> list[tuple[bytes, str]]:
    return []


@pytest.fixture
def client(published) -> TestClient:
    app = create_app(
        store=FakeStore(),
        publish=lambda data, key: published.append((data, key)),
        request_report=lambda: {"report_object": "reports/x.json"},
        api_token=TOKEN,
        limiter=RateLimiter(rate_per_second=1, burst=5),
    )
    return TestClient(app)


def test_health_needs_no_token(client: TestClient) -> None:
    assert client.get("/healthz").status_code == 200


@pytest.mark.parametrize("headers", [{}, {"Authorization": "Bearer wrong"}])
def test_token_is_required(client: TestClient, headers: dict) -> None:
    response = client.post("/documents", json={"title": "t", "content": "c"}, headers=headers)
    assert response.status_code == 401


def test_document_is_published_with_its_id_as_ordering_key(client, published) -> None:
    response = client.post("/documents", json={"title": "t", "content": "c"}, headers=AUTH)
    assert response.status_code == 202
    document_id = response.json()["id"]
    data, key = published[0]
    assert key == document_id
    assert json.loads(data) == {
        "document_id": document_id,
        "revision": 1,
        "simulate_failure": False,
    }


def test_revision_numbers_grow(client, published) -> None:
    document_id = client.post(
        "/documents", json={"title": "t", "content": "c"}, headers=AUTH
    ).json()["id"]
    response = client.post(
        f"/documents/{document_id}/revisions", json={"content": "c2"}, headers=AUTH
    )
    assert response.json()["revision"] == 2
    assert [key for _, key in published] == [document_id, document_id]


def test_unknown_document(client: TestClient) -> None:
    assert client.get(f"/documents/{uuid.uuid4()}", headers=AUTH).status_code == 404


def test_invalid_document_id(client: TestClient) -> None:
    assert client.get("/documents/not-a-uuid", headers=AUTH).status_code == 422


def test_oversized_body_is_rejected(client: TestClient) -> None:
    body = {"title": "t", "content": "x" * (200 * 1024)}
    assert client.post("/documents", json=body, headers=AUTH).status_code == 413


def test_rate_limit_applies_before_the_token_check(client: TestClient) -> None:
    codes = [client.get("/documents/not-a-uuid").status_code for _ in range(10)]
    assert 429 in codes


def test_publish_failure_is_reported() -> None:
    def failing_publish(data: bytes, key: str) -> None:
        raise RuntimeError("down")

    app = create_app(
        store=FakeStore(),
        publish=failing_publish,
        request_report=dict,
        api_token=TOKEN,
        limiter=RateLimiter(rate_per_second=1, burst=5),
    )
    response = TestClient(app).post("/documents", json={"title": "t", "content": "c"}, headers=AUTH)
    assert response.status_code == 502
