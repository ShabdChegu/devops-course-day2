"""Structured logging - one module owns "what shape logs have and where they go".

ch.6's story:
- Every log line is a single **JSON object on stdout**. That is the shape a
  *machine* wants (``docker logs``, ``jq``, ch.13's SigNoz log receiver):
  queryable fields, not sentences you have to eyeball. In production you
  never parse logs by reading words.
- The same line also goes to a **rotating file** (``logs/notes.log`` by
  default). Rotation is the concept: files are capped (5 MB here, keep 3
  backups) so they can never grow unbounded. In a container stdout is the
  main road; the file is the fallback for "grep on disk".

The *only* thing that changes later: ch.10 adds ``trace_id`` to every line
(one extra key in ``JsonFormatter.format`` - the bridge between the log
world and the trace world). This module exists so that moment is one line.
"""

import json
import logging
import os
from datetime import UTC, datetime
from logging.handlers import RotatingFileHandler

# Environment knobs - the ch.5 habit: behavior comes from the environment,
# not from editing code.
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()
LOG_FILE = os.environ.get("LOG_FILE", "logs/notes.log")

# The "rotation" knobs: cap each file at 5 MB, keep 3 old ones.
# notes.log -> notes.log.1 -> .2 -> .3, oldest deleted.
ROTATE_BYTES = 5 * 1024 * 1024
ROTATE_BACKUPS = 3

# Standard LogRecord attributes - anything else on the record is a field
# the app attached (which is exactly what ch.10's trace_id will be). The
# goal: a line is time/level/logger/message + OUR extras, nothing else.
_STANDARD = {
    "name",
    "msg",
    "args",
    "levelname",
    "levelno",
    "pathname",
    "filename",
    "module",
    "exc_info",
    "exc_text",
    "stack_info",
    "lineno",
    "funcName",
    "process",
    "processName",
    "thread",
    "threadName",
    "message",
    # standard numeric/built-in fields that would just be noise:
    "created",
    "msecs",
    "relativeCreated",
    # uvicorn attaches these per-record; they are not app data:
    "taskName",
    "color_message",
}


class JsonFormatter(logging.Formatter):
    """Render every log record as ONE JSON object, one line.

    "One line per event" matters: ``docker logs`` and any log collector
    treat newlines as event boundaries. A pretty-printed or multi-line
    record glues two events into one - the classic broken-pipeline bug.
    """

    def format(self, record: logging.LogRecord) -> str:
        entry = {
            # UTC, ISO-8601 - consistent with ch.2's timestamps.
            "time": datetime.fromtimestamp(record.created, UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if record.exc_info:
            entry["exc_info"] = self.formatException(record.exc_info)
        # App-attached fields ride along too (ch.10: trace_id lands here).
        for key, value in record.__dict__.items():
            if key not in _STANDARD and not key.startswith("_"):
                entry[key] = value
        return json.dumps(entry)


def setup_logging() -> None:
    """Configure the root logger once, at app startup (main.py calls this)."""
    formatter = JsonFormatter()

    # 1. stdout - the primary path in a container: `docker logs` /
    #    `make logs` read exactly this stream.
    stream = logging.StreamHandler()
    stream.setFormatter(formatter)

    # 2. rotating file - capped, so a chatty app can never fill the disk.
    #    makedirs so the first write in a fresh container doesn't crash.
    os.makedirs(os.path.dirname(LOG_FILE) or ".", exist_ok=True)
    file_handler = RotatingFileHandler(LOG_FILE, maxBytes=ROTATE_BYTES, backupCount=ROTATE_BACKUPS)
    file_handler.setFormatter(formatter)

    handlers = [stream, file_handler]

    root = logging.getLogger()
    root.setLevel(LOG_LEVEL)
    # Wipe default handlers so a re-import can't double-log every line.
    for old in list(root.handlers):
        root.removeHandler(old)
    for handler in handlers:
        root.addHandler(handler)

    # uvicorn logs request lines through its *own* loggers (uvicorn.access),
    # not root's. Give them the same handlers so every request line has the
    # same JSON shape as app lines - one shape to parse, period.
    for name in ("uvicorn", "uvicorn.access", "uvicorn.error"):
        logger = logging.getLogger(name)
        logger.handlers = list(handlers)
        logger.propagate = False  # don't also bubble into root (double-log)


logger = logging.getLogger(__name__)


def log_note_event(kind: str, note_id: int, title: str) -> None:
    """A demo app log event, so "JSON from *our* code" is visible.

    `kind` is "created" or "deleted". ch.10 will add trace_id to this
    exact call site without touching the formatter.
    """
    if kind == "created":
        logger.info(
            "note created", extra={"event": "note_created", "note_id": note_id, "title": title}
        )
    else:
        logger.info("note deleted", extra={"event": "note_deleted", "note_id": note_id})
