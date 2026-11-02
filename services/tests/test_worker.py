import json
from contextlib import contextmanager

import pytest
from google.api_core.exceptions import PreconditionFailed

from worker.handler import RetryLater, object_name, process_message, write_once

DOCUMENT = "11111111-1111-1111-1111-111111111111"


class FakeResult:
    def __init__(self, row) -> None:
        self._row = row

    def fetchone(self):
        return self._row


class FakeConnection:
    def __init__(self, processed, content="body") -> None:
        self.processed = processed
        self.content = content
        self.updates = []

    def execute(self, query, params=None):
        if "SELECT processed_revision" in query:
            return FakeResult(None if self.processed is None else (self.processed,))
        if "SELECT content" in query:
            return FakeResult(None if self.content is None else (self.content,))
        self.updates.append(params)
        return FakeResult(None)


class FakePool:
    def __init__(self, connection) -> None:
        self._connection = connection

    @contextmanager
    def connection(self):
        yield self._connection


def message(revision: int, simulate_failure: bool = False) -> bytes:
    return json.dumps(
        {"document_id": DOCUMENT, "revision": revision, "simulate_failure": simulate_failure}
    ).encode()


def test_next_revision_is_written_and_recorded() -> None:
    connection = FakeConnection(processed=0)
    written = {}
    result = process_message(message(1), FakePool(connection), written.__setitem__)
    assert result == "processed"
    assert written == {object_name(DOCUMENT, 1): "body"}
    assert len(connection.updates) == 2


def test_redelivered_revision_changes_nothing() -> None:
    connection = FakeConnection(processed=3)
    written = {}
    assert process_message(message(2), FakePool(connection), written.__setitem__) == "duplicate"
    assert written == {}
    assert connection.updates == []


def test_revision_out_of_order_is_retried() -> None:
    with pytest.raises(RetryLater):
        process_message(message(3), FakePool(FakeConnection(processed=1)), lambda *_: None)


def test_simulated_failure_is_retried_without_touching_the_database() -> None:
    connection = FakeConnection(processed=0)
    with pytest.raises(RetryLater):
        process_message(message(1, simulate_failure=True), FakePool(connection), lambda *_: None)
    assert connection.updates == []


def test_unknown_document_is_retried() -> None:
    with pytest.raises(RetryLater):
        process_message(message(1), FakePool(FakeConnection(processed=None)), lambda *_: None)


def test_write_once_tolerates_an_existing_object() -> None:
    class Blob:
        def upload_from_string(self, content, if_generation_match):
            assert if_generation_match == 0
            raise PreconditionFailed("exists")

    class Bucket:
        def blob(self, name):
            return Blob()

    write_once(Bucket(), "name", "content")
