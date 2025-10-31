# References:
#  https://opentelemetry.io/docs/languages/python/instrumentation/#metrics
#  https://opentelemetry.io/docs/languages/python/exporters/#console
#  https://opentelemetry.io/docs/languages/sdk-configuration/otlp-exporter/

from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import (
    ConsoleMetricExporter,
    PeriodicExportingMetricReader)

def init(service_name):
    '''Perform general OTel setup and return meter obj.'''
    resource = Resource.create(attributes={SERVICE_NAME: service_name})
    metric_reader = PeriodicExportingMetricReader(ConsoleMetricExporter(), export_interval_millis=5000)
    meter_provider = MeterProvider(resource=resource,
                                   metric_readers=[metric_reader])

    # Set the global default meter provider:
    metrics.set_meter_provider(meter_provider)

    # Create a meter from the global meter provider:
    return metrics.get_meter(service_name+'.meter')

SUCCESS = 'success'
FAILURE = 'failure'
