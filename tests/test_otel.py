"""ch.9: the OTLP exporter flip must keep importing.

ch.10 turns traces to SigNoz with ONE env var — `OTEL_EXPORTER=otlp` —
which takes the OTLP branch of `notes_app/otel.py`. That branch imports
the gRPC exporter from `...grpc.trace_exporter`: a recent OpenTelemetry
release renamed the module (the old `...grpc.trace` was a deprecated
alias that later went away entirely), so the import path is load-bearing.
This test pins it: a uv.lock bump that moves to a version where the path
fails makes `make test` red, not "the app silently stops exporting in
ch.10".
"""

from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter


def test_otlp_exporter_path_pinned():
    # The exact symbol the "otlp" branch of otel.py imports.
    assert OTLPSpanExporter is not None


def test_otlp_exporter_constructs_offline():
    # Constructing does not open a connection (gRPC channels are lazy),
    # so this is safe with no SigNoz running: it proves ch.10's flip
    # path is importable AND usable, not just present.
    exporter = OTLPSpanExporter(endpoint="http://127.0.0.1:4317", insecure=True)
    assert exporter is not None


def test_health_endpoint_excluded_from_traces():
    import os

    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import SimpleSpanProcessor
    from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter

    provider = TracerProvider()
    exporter = InMemorySpanExporter()
    provider.add_span_processor(SimpleSpanProcessor(exporter))

    app = FastAPI()

    @app.get("/health")
    def health():
        return {"status": "ok"}

    @app.get("/api/data")
    def data():
        return {"data": 123}

    FastAPIInstrumentor.instrument_app(
        app,
        tracer_provider=provider,
        excluded_urls=os.environ.get("OTEL_PYTHON_FASTAPI_EXCLUDED_URLS", "health"),
    )

    client = TestClient(app)
    client.get("/health")
    assert len(exporter.get_finished_spans()) == 0

    client.get("/api/data")
    spans = exporter.get_finished_spans()
    assert len(spans) > 0
    assert any("/api/data" in s.name for s in spans)
