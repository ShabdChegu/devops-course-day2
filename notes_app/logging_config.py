"""Structured logging - one small module: JSON log lines on stdout.

ch.6's whole idea in one place:
- A log line is ONE JSON object on ONE line:
  {"time": "...", "level": "INFO", "logger": "...", "message": "...", "event": "..."}
  Machines (docker logs, ch.10's log collector) parse fields;
  they do not read sentences.
- A container's log IS its stdout: the runtime captures the process's pipe,
  and `docker logs` / `make logs` read exactly that capture. No files.

Later changes stay one line each: ch.9 adds "trace_id" to _FIELDS below.
"""

import json
import logging
import os
import sys
from datetime import UTC, datetime

# The complete list of fields a log line may carry.
# The first four are added by the formatter itself; the rest are
# our own event fields, added when views.py logs with extra={...}.
# ch.9: trace_id — the OpenTelemetry trace of the request that produced
# this line (otel.py registers a provider; the field is absent for logs
# written outside any request, and when OTEL_ENABLED=false).
_FIELDS = ("time", "level", "logger", "message", "event", "note_id", "trace_id")

# ch.9's seam: otel.py hands us a callable that returns the active span's
# trace id for a given log record (or None when there is no active span).
# Keeping it as a hook - instead of importing opentelemetry here - means
# the logging module stays dependency-free, and OTEL_ENABLED=false leaves
# it as None: log lines simply omit trace_id, no import error, no "0…0".
_trace_id_provider = None


def set_trace_id_provider(provider) -> None:
    """Install the callable otel.py provides (called once, at app startup)."""
    global _trace_id_provider
    _trace_id_provider = provider


class JsonFormatter(logging.Formatter):
    """Render a log record as a single-line JSON object.

    One event per line: log collection tools treat newlines as
    event boundaries, so multi-line records will end up merging
    two events into one.
    """

    def format(self, record: logging.LogRecord) -> str:
        entry = {
            # UTC ISO-8601 - same timestamp shape as ch.2's created_at.
            "time": datetime.fromtimestamp(record.created, UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        # Our event fields (event / note_id / title) arrive via
        # logger.info(..., extra={...}) and are picked up by name here.
        for key in _FIELDS:
            if key in record.__dict__:
                entry[key] = record.__dict__[key]
        # ch.9: the active request's trace id, looked up through otel.py's
        # provider (absent when OTEL is off or there is no active span).
        if _trace_id_provider is not None:
            trace_id = _trace_id_provider(record)
            if trace_id is not None:
                entry["trace_id"] = trace_id
        if record.exc_info:
            # The traceback goes inside the same JSON object,
            # not as a separate multi-line block.
            entry["exc_info"] = self.formatException(record.exc_info)
        return json.dumps(entry)


def setup_logging() -> None:
    """Configure logging once, at app startup (called from main.py)."""
    # stdout on purpose: in a container the runtime captures the process's
    # pipes, and that capture *is* the log (`docker logs`). Python's default
    # StreamHandler() writes to stderr - fine for a CLI tool, but our story
    # is "app output -> stdout -> docker logs -> ch.10's collector", so we
    # say it explicitly.
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())

    root = logging.getLogger()
    root.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())
    # Replace (don't append to) the default handler,
    # so a re-import can't cause every line to be logged twice.
    root.handlers = [handler]

    # uvicorn logs HTTP requests on its own loggers (uvicorn.access),
    # so give them the same handler: one JSON format in the whole stream.
    for name in ("uvicorn", "uvicorn.access", "uvicorn.error"):
        logger = logging.getLogger(name)
        logger.handlers = [handler]
        logger.propagate = False  # otherwise every request gets logged twice
