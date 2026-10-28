"""ch.6's test: the log CONTRACT, not just the logging.

The whole point of structured logging is that every line an app emits is
a JSON object a *machine* can parse. So this test doesn't check "did we
log" - it checks "can the log be parsed", which is what ch.7's CI,
ch.13's SigNoz receiver, and any `jq` you run by hand will actually do.

conftest.py points LOG_FILE at a temp dir before notes_app imports, so
this reads the file the test run itself wrote - never the repo's logs/.
"""

import json
import os
from pathlib import Path

from fastapi.testclient import TestClient

from notes_app.main import app

client = TestClient(app)


def test_every_log_line_is_a_valid_json_object():
    log_file = Path(os.environ["LOG_FILE"])

    # Trigger our own structured event through the API (not a stray log):
    r = client.post("/notes", json={"title": "log me", "body": "into json"})
    assert r.status_code == 201

    lines = [ln for ln in log_file.read_text().splitlines() if ln.strip()]
    assert lines, "expected log lines in the rotating file"

    for line in lines:
        entry = json.loads(line)  # <- the whole contract: every line parses
        # ...and it has the fields a pipeline would query:
        assert {"time", "level", "logger", "message"} <= entry.keys()

    # ...and our business event is there with queryable fields:
    events = [json.loads(ln) for ln in lines if '"note_created"' in ln]
    assert events and events[-1]["note_id"] == r.json()["id"]
