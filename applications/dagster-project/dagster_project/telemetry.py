"""
OpenTelemetry setup for Dagster user code — exports traces to the ADOT collector → AWS X-Ray.
Runs at import time when OTEL_EXPORTER_OTLP_ENDPOINT is set (e.g. in EKS).
"""
import os
import sys

# Only configure tracing if we have an OTLP endpoint (e.g. set by Helm in EKS)
_OTEL_ENDPOINT = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT")


def setup_otel() -> None:
    if not _OTEL_ENDPOINT:
        return
    try:
        from opentelemetry import trace
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor
        from opentelemetry.sdk.resources import Resource

        # OTLP/gRPC exporter (reads OTEL_EXPORTER_OTLP_* from env)
        from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

        resource = Resource.create(
            {
                "service.name": os.environ.get("OTEL_SERVICE_NAME", "dagster-user-code"),
                "service.namespace": os.environ.get("OTEL_SERVICE_NAMESPACE", "dagster"),
            }
        )
        provider = TracerProvider(resource=resource)
        provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
        trace.set_tracer_provider(provider)

        # Emit one span on load so X-Ray gets at least one trace (validates pipeline)
        tracer = trace.get_tracer(__name__, "1.0")
        with tracer.start_as_current_span("dagster.user_code.loaded"):
            pass
        provider.force_flush(timeout_millis=5000)

        # Auto-instrument HTTP requests (e.g. HackerNews API) so spans are sent
        try:
            from opentelemetry.instrumentation.requests import RequestsInstrumentor
            RequestsInstrumentor().instrument()
        except Exception:
            pass
    except Exception as e:
        # Avoid breaking Dagster load; log so pod logs show why X-Ray has no traces
        print(f"[OTEL] setup skipped: {e}", file=sys.stderr)
