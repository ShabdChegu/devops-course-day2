"""ch.9 & ch.10 — OpenTelemetry: Tracing, Metrics, and Logging.

The question this chapter answers is "which request was slow, and what did
it do while it was slow?". The answer has three moving parts:

- A **span** is one unit of work. Here: one HTTP request = one server span,
  named like `GET /notes`, carrying its duration, the request attributes, and
  the response status.
- A **trace** is the whole tree of spans for one request.
- An **exporter** is where finished telemetry goes.
  - "console": spans print to stdout, right next to ch.6's JSON log lines.
  - "otlp": gRPC to SigNoz collector (OTEL_OTLP_ENDPOINT, e.g. http://localhost:4317 or http://signoz:4317).

Environment knobs:
  OTEL_ENABLED       default "true". Set "false" to skip the whole machinery
                     (tests/conftest.py sets this).
  OTEL_EXPORTER      "console" (default) or "otlp" (SigNoz).
  OTEL_OTLP_ENDPOINT default "http://localhost:4317" (in compose: http://signoz:4317).
  OTEL_SERVICE_NAME  default "notes-app".
"""

import os
import time

SERVICE_NAME = os.environ.get("OTEL_SERVICE_NAME", "notes-app")


def setup_otel(app) -> None:
    """Instrument the app for traces, metrics, and logs with OpenTelemetry."""
    if os.environ.get("OTEL_ENABLED", "true").lower() in ("0", "false", "no"):
        return

    from opentelemetry import metrics, trace
    from opentelemetry.sdk.resources import Resource

    resource = Resource({"service.name": SERVICE_NAME})
    exporter_mode = os.environ.get("OTEL_EXPORTER", "console").lower()
    endpoint = os.environ.get("OTEL_OTLP_ENDPOINT", "http://localhost:4317")

    # ------------------------------------------------------------------
    # 1. Traces
    # ------------------------------------------------------------------
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor

    tracer_provider = TracerProvider(resource=resource)

    if exporter_mode == "otlp":
        from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

        span_exporter = OTLPSpanExporter(endpoint=endpoint, insecure=True)
    else:
        from opentelemetry.sdk.trace.export import ConsoleSpanExporter

        span_exporter = ConsoleSpanExporter()

    tracer_provider.add_span_processor(BatchSpanProcessor(span_exporter))
    trace.set_tracer_provider(tracer_provider)

    from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

    FastAPIInstrumentor.instrument_app(app)

    try:
        from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

        from .models import engine

        SQLAlchemyInstrumentor().instrument(engine=engine)
    except Exception:
        pass

    from .logging_config import set_trace_id_provider

    set_trace_id_provider(_current_trace_id)

    # ------------------------------------------------------------------
    # 2. Metrics
    # ------------------------------------------------------------------
    from opentelemetry.sdk.metrics import MeterProvider
    from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader

    if exporter_mode == "otlp":
        from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter

        metric_exporter = OTLPMetricExporter(endpoint=endpoint, insecure=True)
        metric_reader = PeriodicExportingMetricReader(metric_exporter, export_interval_millis=2000)
    else:
        from opentelemetry.sdk.metrics.export import ConsoleMetricExporter

        metric_exporter = ConsoleMetricExporter()
        metric_reader = PeriodicExportingMetricReader(metric_exporter, export_interval_millis=60000)

    meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
    metrics.set_meter_provider(meter_provider)

    meter = metrics.get_meter("notes_app")
    requests_counter = meter.create_counter(
        "http_requests_total",
        description="Total HTTP requests processed by notes-app",
        unit="1",
    )
    request_duration = meter.create_histogram(
        "http_request_duration_seconds",
        description="Duration of HTTP requests in seconds",
        unit="s",
    )

    # HTTP middleware to automatically record request metrics
    @app.middleware("http")
    async def record_metrics_middleware(request, call_next):
        start_time = time.perf_counter()
        status_code = 500
        try:
            response = await call_next(request)
            status_code = response.status_code
            return response
        finally:
            duration = time.perf_counter() - start_time
            route = request.scope.get("route")
            route_path = getattr(route, "path", request.url.path) if route else request.url.path
            attrs = {
                "http.method": request.method,
                "http.route": route_path,
                "http.status_code": str(status_code),
            }
            requests_counter.add(1, attrs)
            request_duration.record(duration, attrs)

    # ------------------------------------------------------------------
    # 3. Logs (OTLP export to SigNoz)
    # ------------------------------------------------------------------
    if exporter_mode == "otlp":
        import logging

        from opentelemetry._logs import set_logger_provider
        from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
        from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
        from opentelemetry.sdk._logs.export import BatchLogRecordProcessor

        log_exporter = OTLPLogExporter(endpoint=endpoint, insecure=True)
        logger_provider = LoggerProvider(resource=resource)
        logger_provider.add_log_record_processor(BatchLogRecordProcessor(log_exporter))
        set_logger_provider(logger_provider)

        # Connect standard Python logging to OTel log pipeline
        otel_handler = LoggingHandler(level=logging.INFO, logger_provider=logger_provider)
        root_logger = logging.getLogger()
        root_logger.addHandler(otel_handler)


def _current_trace_id(record) -> str | None:
    """The trace id of the span active when this log line was written."""
    from opentelemetry.trace import get_current_span

    context = get_current_span().get_span_context()
    if not context.is_valid:
        return None
    return format(context.trace_id, "032x")
