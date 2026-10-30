"""Shared pytest fixtures - and ch.2's first use of one.

`models.py` reads DATABASE_URL *at import time* (that's intentional - it's the
one place the storage choice lives), so the env var must be set **before**
notes_app is imported anywhere. The import-time table creation then runs
against this file, not the repo's notes.db.
"""

import os
import tempfile
from pathlib import Path

# A fresh DB file per test run, in the system temp dir - never in the repo,
# so a half-finished run can't corrupt the one the app uses.
_tmp_db_dir = tempfile.mkdtemp(prefix="notes-test-db-")
os.environ["DATABASE_URL"] = f"sqlite:///{Path(_tmp_db_dir) / 'test-notes.db'}"

# ch.9: keep the OpenTelemetry machinery OUT of the test process. Two
# reasons: a TracerProvider with a BatchSpanProcessor would keep background
# flush threads alive between tests, and span output (Console exporter)
# would interleave with pytest's output. The env var is the off switch
# otel.py checks at import time - so tests exercise the app exactly like a
# production deployment would, minus the exporter.
os.environ["OTEL_ENABLED"] = "false"
