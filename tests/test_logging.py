"""ch.6's test: the log CONTRACT, not just "did it log".

The whole point of structured logging is that every line the app emits is a
JSON object a *machine* can parse. What `make logs` (and ch.10's collector)
reads is exactly `JsonFormatter`'s output - so this test attaches a handler
that runs records through the *same* formatter the app uses, and asserts
every resulting line json.loads()s.
"""

import json
import logging

from fastapi.testclient import TestClient

from notes_app import main  # noqa: F401 - importing main runs setup_logging()
from notes_app.logging_config import JsonFormatter

client = TestClient(main.app)


class _Capture(logging.Handler):
    """Collects formatted log lines exactly as the app's stdout handler does."""

    def __init__(self):
        super().__init__()
        self.lines: list[str] = []
        self.setFormatter(JsonFormatter())

    def emit(self, record: logging.LogRecord) -> None:
        self.lines.append(self.format(record))


def test_every_log_line_is_a_valid_json_object():
    cap = _Capture()
    root = logging.getLogger()
    root.addHandler(cap)
    try:
        r = client.post("/notes", json={"title": "log me", "body": "into json"})
        assert r.status_code == 201
    finally:
        root.removeHandler(cap)

    lines = [ln for ln in cap.lines if ln.strip()]
    assert lines, "expected log lines from the request"

    for line in lines:
        entry = json.loads(line)  # <- the whole contract: every line parses
        assert {"time", "level", "logger", "message"} <= entry.keys()

    # ...and our business event is there, with a queryable field:
    events = [json.loads(ln) for ln in lines if "note_created" in ln]
    assert events and events[-1]["note_id"] == r.json()["id"]
