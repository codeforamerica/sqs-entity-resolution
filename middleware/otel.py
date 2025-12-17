# References:
#  https://opentelemetry.io/docs/languages/python/instrumentation/#metrics
#  https://opentelemetry.io/docs/languages/python/exporters/#console
#  https://opentelemetry.io/docs/languages/sdk-configuration/otlp-exporter/

import os

from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import (
    ConsoleMetricExporter,
    PeriodicExportingMetricReader)
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter

from opentelemetry.sdk.metrics import Histogram
from opentelemetry.sdk.metrics.export import AggregationTemporality
# See: https://docs.datadoghq.com/opentelemetry/guide/otlp_delta_temporality/?tab=python

INTERVAL_MS = 30000

TEMPORALITY = {
    Histogram: AggregationTemporality.DELTA
}

metric_reader = None

def init(service_name):
    '''Perform general OTel setup and return meter obj.'''
    global metric_reader
    resource = Resource.create(attributes={SERVICE_NAME: service_name})
    if os.getenv('OTEL_USE_OTLP_EXPORTER', 'false').lower() == 'true':
        metric_reader = PeriodicExportingMetricReader(
            OTLPMetricExporter(preferred_temporality=TEMPORALITY),
            export_interval_millis=INTERVAL_MS)
    else:
        metric_reader = PeriodicExportingMetricReader(
            ConsoleMetricExporter(preferred_temporality=TEMPORALITY),
            export_interval_millis=INTERVAL_MS)
    meter_provider = MeterProvider(resource=resource,
                                   metric_readers=[metric_reader])

    # Set the global default meter provider:
    metrics.set_meter_provider(meter_provider)

    # Create a meter from the global meter provider:
    return metrics.get_meter(service_name+'.meter')

def force_flush():
    if metric_reader:
        metric_reader.force_flush()

SUCCESS = 'success'
FAILURE = 'failure'
UNKNOWN = 'unknown'
