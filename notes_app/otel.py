"""ch.9 — OpenTelemetry: the tracing foundation.

The question this chapter answers is "which request was slow, and what did
it do while it was slow?". The answer has three moving parts:

- A **span** is one unit of work. Here: one HTTP request = one server span,
  named like `GET /notes`, carrying its duration, the request attributes, and
  the response status.
- A **trace** is the whole tree of spans for one request. Today that tree is
  a single span per request; ch.10's database span grows it.
- An **exporter** is where finished spans go. ch.9's answer is **console**:
  they print to stdout, right next to ch.6's JSON log lines. No new
  containers, no configuration — the whole point of the chapter is that a
  trace starts out as "just one more thing on stdout". Ch.10 swaps the
  destination, not the code: `OTEL_EXPORTER=otlp` (the flip is one line).

Two knobs, both in the environment (ch.5's "behavior from the environment"
rule):

  OTEL_ENABLED   default "true". Set "false" to skip the whole machinery —
                 that's what tests/conftest.py does, on purpose.
  OTEL_EXPORTER  "console" (the ch.9 default) or "otlp" (ch.10: gRPC to
                 OTEL_OTLP_ENDPOINT, e.g. http://signoz:4317).

And the log↔trace link you can see in `docker logs`: ch.6's formatter now
carries a `trace_id` field. A log line emitted while a request span is
active gets that request's trace id — so "find every log line request X
emitted" is one grep, and in ch.10 the same id is how SigNoz joins its
logs to its traces.
"""

import os

# The service.name attribute: how a backend (SigNoz in ch.10) groups and
# labels everything this app reports.
SERVICE_NAME = os.environ.get("OTEL_SERVICE_NAME", "notes-app")


def setup_otel(app) -> None:
    """Instrument the app and install the trace_id hook in logging_config.

    Called once, at the very end of main.py, so `make run` (local dev), the
    ch.4 container, ch.5's compose service, and ch.8's deploy target all
    carry exactly this one wiring.
    """
    # The off switch, checked first: when it's set, none of the OpenTelemetry
    # machinery is even imported. (That's why every otel import lives inside
    # this function, not at module top — "off" must mean truly off.)
    if os.environ.get("OTEL_ENABLED", "true").lower() in ("0", "false", "no"):
        return

    from opentelemetry import trace
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor

    # Resource = "who am I" (the service.name attribute). TracerProvider is
    # where spans are created; it hands finished spans to its processors.
    provider = TracerProvider(resource=Resource({"service.name": SERVICE_NAME}))

    if os.environ.get("OTEL_EXPORTER", "console") == "otlp":
        # Ch.10's shape: OTLP over gRPC to the collector inside the SigNoz
        # container. Note the scheme: gRPC transport speaks over `http://`,
        # not `https://` — a classic foot-gun when copy-pasting endpoint
        # values.
        from opentelemetry.exporter.otlp.proto.grpc.trace import OTLPSpanExporter

        endpoint = os.environ.get("OTEL_OTLP_ENDPOINT", "http://localhost:4317")
        span_exporter = OTLPSpanExporter(endpoint=endpoint, insecure=True)
    else:
        # Ch.9's shape: spans print to stdout as JSON objects, one per line,
        # in the exact same stream as ch.6's logs. `make up` + `make logs`
        # and you are watching your first trace waterfall, with zero new
        # infrastructure.
        from opentelemetry.sdk.trace.export import ConsoleSpanExporter

        span_exporter = ConsoleSpanExporter()

    # Batching, not per-span: spans end into a buffer and the exporter
    # flushes periodically and at process exit.
    provider.add_span_processor(BatchSpanProcessor(span_exporter))
    trace.set_tracer_provider(provider)

    # The actual instrumentation: one server span per request, auto-named
    # ("GET /notes"), with method/url/status attributes attached. This is
    # the whole ch.9 code diff on the app itself — one call.
    from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

    FastAPIInstrumentor.instrument_app(app)

    # The logging ↔ tracing link: ch.6's formatter asks US for the trace id
    # of the span active at log time. One registration, no changes in the
    # views.
    from .logging_config import set_trace_id_provider

    set_trace_id_provider(_current_trace_id)


def _current_trace_id(record) -> str | None:
    """The trace id of the span active when this log line was written.

    A log emitted inside a request handler runs *while* that request's span
    is active, so the "current span" lookup is exactly the answer. Outside a
    request (startup logs, background work) the context is invalid, and we
    return None instead of a fake 0000…0 id — the formatter simply omits the
    field.

    The record argument is unused today (the lookup is context-based); it's
    part of the hook's shape so a later chapter can attach per-record data.
    """
    from opentelemetry.trace import get_current_span

    context = get_current_span().get_span_context()
    if not context.is_valid:
        return None
    # 128-bit id rendered as 32 hex chars — the shape SigNoz and the OTel
    # spec both use, so a grep in logs finds the same id in traces.
    return format(context.trace_id, "032x")
