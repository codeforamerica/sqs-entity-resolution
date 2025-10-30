import json
import os
import time
import sys
import boto3
import senzing as sz

# --- BEGIN OTEL SETUP --- #
# Refs:
#  https://opentelemetry.io/docs/languages/python/instrumentation/#metrics
#  https://opentelemetry.io/docs/languages/python/exporters/#console
#  https://opentelemetry.io/docs/languages/sdk-configuration/otlp-exporter/
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import (
    ConsoleMetricExporter,
    PeriodicExportingMetricReader)
resource = Resource.create(attributes={
    SERVICE_NAME: "redoer"
})
metric_reader = PeriodicExportingMetricReader(ConsoleMetricExporter())
meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
# Set the global default meter provider:
metrics.set_meter_provider(meter_provider)
# Create a meter from the global meter provider:
meter = metrics.get_meter('redoer.meter')

### Set up specific metric instrument objects:
otel_msgs_counter = meter.create_counter(
    'redoer.messages.count',
    description='Counter incremented with each message processed by the redoer.')
otel_durations = meter.create_histogram(
    'redoer.messages.duration',
    'Message processing duration for the redoer.')
otel_queue_count = meter.create_up_down_counter(
    name='redoer.queue.count',
    description='Current number of items in the redo queue.')
SUCCESS = 'success'
FAILURE = 'failure'
# ---- END OTEL SETUP ---- #

from loglib import *
log = retrieve_logger()

from timeout_handling import *

try:
    log.info('Importing senzing_core library . . .')
    import senzing_core as sz_core
    log.info('Imported senzing_core successfully.')
except Exception as e:
    log.error('Importing senzing_core library failed.')
    log.error(fmterr(e))

SZ_CALL_TIMEOUT_SECONDS = int(os.environ.get('SZ_CALL_TIMEOUT_SECONDS', 420))
SZ_CONFIG = json.loads(os.environ['SENZING_ENGINE_CONFIGURATION_JSON'])
RUNTIME_ENV = os.environ.get('RUNTIME_ENV', 'unknown') # For OTel

# How long to wait before attempting next Senzing op.
WAIT_SECONDS = int(os.environ.get('WAIT_SECONDS', 10))

# How many times to attempt process_redo_record before giving up and moving on
# (see README).
MAX_REDO_ATTEMPTS = int(os.environ.get('MAX_REDO_ATTEMPTS', 20))

#-------------------------------------------------------------------------------

def go():
    '''Starts the Redoer process; runs indefinitely.'''

    sz_eng = None
    try:
        sz_factory = sz_core.SzAbstractFactoryCore("ERS", SZ_CONFIG)

        # Init senzing engine object.
        # Senzing engine object cannot be passed around between functions,
        # else it will be eagerly cleaned up / destroyed and no longer usable.
        sz_eng = sz_factory.create_engine()
        log.info(SZ_TAG + 'Senzing engine object instantiated.')
    except sz.SzError as sz_err:
        log.error(SZ_TAG + fmterr(sz_err))
    except Exception as e:
        log.error(fmterr(e))

    log.info('Starting primary loop.')

    # Approach:
    # - We don't try to both 'get' and 'process' in a single loop; instead we
    #   'get', then 'continue' to the next loop; the have_rcd flag is used to
    #   facilitate this.
    #   - Rationale: the approach is simple and allows for the use of a single while-loop.
    #     (An alternative would be to have two inner while-loops housed within
    #     an outer while-loop.)
    # - Each Senzing call (3 distinct calls) is couched in its own try-except block for
    #   robustness.
    tally = None
    have_rcd = 0
    rcd = None
    attempts_left = MAX_REDO_ATTEMPTS
    while 1:
        try:
            if have_rcd:
                start = time.perf_counter()
                success_status = FAILURE # initial default value
                try:
                    start_alarm_timer(SZ_CALL_TIMEOUT_SECONDS)
                    sz_eng.process_redo_record(rcd)
                    cancel_alarm_timer()
                    sucess_status = SUCCESS
                    have_rcd = 0
                    log.debug(SZ_TAG + 'Successfully redid one record via process_redo_record().')
                    continue
                except sz.SzRetryableError as sz_ret_err:
                    # We'll try to process this record again.
                    log.error(SZ_TAG + fmterr(sz_ret_err))
                    attempts_left -= 1
                    log.debug(SZ_TAG + f'Remaining attempts for this record: {attempts_left}')
                    if not attempts_left:
                        have_rcd = 0
                        log.error(SZ_TAG + f'Max redo attempts ({MAX_REDO_ATTEMPTS}) reached'
                                  + ' for this record; dropping on the floor and moving on.')
                    time.sleep(WAIT_SECONDS)
                    continue
                except LongRunningCallTimeoutEx as lrex:
                    # Abandon and move on.
                    have_rcd = 0
                    log.error(build_sz_timeout_msg(
                        type(lrex).__module__,
                        type(lrex).__qualname__,
                        SZ_CALL_TIMEOUT_SECONDS,
                        receipt_handle))
                except sz.SzError as sz_err:
                    log.error(SZ_TAG + fmterr(sz_err))

            finish = time.perf_counter()
            otel_msgs_counter.add(1,
                {'status': success_status,
                'service': 'redoer',
                'environment': RUNTIME_ENV})
            otel_durations.record(finish - start,
                {'status':  success_status,
                 'service': 'redoer',
                 'environment': RUNTIME_ENV})

            else:
                try:
                    tally = sz_eng.count_redo_records()
                    log.debug(SZ_TAG + 'Current redo count: ' + str(tally))
                except sz.SzRetryableError as sz_ret_err:
                    log.error(SZ_TAG + fmterr(sz_ret_err))
                    time.sleep(WAIT_SECONDS)
                    continue
                except sz.SzError as sz_err:
                    log.error(SZ_TAG + fmterr(sz_err))

                if tally:

                    try:
                        rcd = sz_eng.get_redo_record()
                        if rcd:
                            have_rcd = 1
                            attempts_left = MAX_REDO_ATTEMPTS
                            # At this point, rcd var holds a record, and have_rcd flag
                            # raised. Will process in the next loop.
                            log.debug(SZ_TAG + 'Retrieved 1 record via get_redo_record()')
                        else:
                            log.debug(SZ_TAG + 'Redo count was greater than 0, but got '
                                      + 'nothing from get_redo_record')
                    except sz.SzRetryableError as sz_ret_err:
                        # No additional action needed; we'll just try getting again.
                        log.error(SZ_TAG + fmterr(sz_ret_err))
                    except sz.SzError as sz_err:
                        log.error(SZ_TAG + fmterr(sz_err))

                else:
                    log.debug('No redo records. Will wait ' + str(WAIT_SECONDS) + ' seconds.')
                    time.sleep(WAIT_SECONDS)

        except Exception as e:
            log.error(fmterr(e))

#-------------------------------------------------------------------------------

def main():
    log.info('====================')
    log.info(' ------->')
    log.info('   REDOER    ')
    log.info('       STARTED')
    log.info('          ------->')
    log.info('====================')
    go()

if __name__ == '__main__': main()
