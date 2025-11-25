import json
import os
import signal
import time
import sys
import boto3
import senzing as sz

from loglib import *
log = retrieve_logger()

from timeout_handling import *

import otel
import util
import db

try:
    log.info('Importing senzing_core library . . .')
    import senzing_core as sz_core
    log.info('Imported senzing_core successfully.')
except Exception as e:
    log.error('Importing senzing_core library failed.')
    log.error(fmterr(e))

Q_URL = os.environ['Q_URL']
SZ_CALL_TIMEOUT_SECONDS = int(os.environ.get('SZ_CALL_TIMEOUT_SECONDS', 420))
SZ_CONFIG = json.loads(os.environ['SENZING_ENGINE_CONFIGURATION_JSON'])
RUNTIME_ENV = os.environ.get('RUNTIME_ENV', 'unknown') # For OTel

POLL_SECONDS = 20                   # 20 seconds is SQS max

#-------------------------------------------------------------------------------

def _make_boto_session(fpath=None):
    '''
    If `AWS_PROFILE` environment variable is set, then `Session()` can be
    called with no arguments.

    fpath is path to json file with keys:
        - aws_access_key_id
        - aws_secret_access_key
        - aws_session_token
        - region
    (Same keys should typically be present in .aws/credentials file
    if using profile.)'''
    if fpath:
        return boto3.Session(**json.load(open(fpath)))
    else:
        return boto3.Session()

def _make_sqs_client(boto_session):
    return boto_session.client('sqs')

def init():
    '''Returns sqs client object'''
    try:
        sess = _make_boto_session()
        if 'AWS_ENDPOINT_URL' in os.environ:
            return sess.client('sqs', endpoint_url=os.environ['AWS_ENDPOINT_URL'])
        else:
            return sess.client('sqs')
    except Exception as e:
        log.error(AWS_TAG + fmterr(e))

def get_msgs(sqs, q_url):
    '''Generator function; emits a single SQS msg at a time.
    Pertinent keys in an SQS message include:
    - MessageId
    - ReceiptHandle -- you'll need this to delete the msg later
    - Body -- here, should be the JSONL record as a string
    '''
    while 1:
        try:
            log.debug(AWS_TAG + 'Polling SQS for the next message')
            resp = sqs.receive_message(QueueUrl=q_url, MaxNumberOfMessages=1,
                                       WaitTimeSeconds=POLL_SECONDS,
                                       VisibilityTimeout=SZ_CALL_TIMEOUT_SECONDS)
            if 'Messages' in resp and len(resp['Messages']) == 1:
                yield resp['Messages'][0]
        except Exception as e:
            log.error(f'{AWS_TAG} {type(e).__module__}.{type(e).__qualname__} :: {fmterr(e)}')
   
def del_msg(sqs, q_url, receipt_handle):
    try:
        log.debug(AWS_TAG + 'Deleting message having ReceiptHandle: ' + receipt_handle)
        return sqs.delete_message(QueueUrl=q_url, ReceiptHandle=receipt_handle)
    except Exception as e:
        log.error(AWS_TAG + DLQ_TAG + 'SQS delete failure for ReceiptHandle: ' +
                  ReceiptHandle + ' Additional info: ' + fmterr(e))

def make_msg_visible(sqs, q_url, receipt_handle):
    '''Setting visibility timeout to 0 on an SQS message makes it visible again,
    making it available (again) for consuming.'''
    try:
        log.debug(AWS_TAG + 'Restoring message visibility for ReceiptHandle: ' + receipt_handle)
        sqs.change_message_visibility(
            QueueUrl=q_url,
            ReceiptHandle=receipt_handle,
            VisibilityTimeout=0)
    except Exception as e:
        log.error(AWS_TAG + fmterr(e))

#-------------------------------------------------------------------------------

def register_data_source(data_source_name):
    '''References:
        - https://github.com/senzing-garage/knowledge-base/blob/main/lists/environment-variables.md#senzing_tools_datasources
        - https://github.com/senzing-garage/knowledge-base/blob/4c397efacdb0d2feecd89fa0f00ec10f99320d0c/proposals/working-with-config/mjd.md?plain=1#L98
    '''
    def f():
        sz_factory = sz_core.SzAbstractFactoryCore("ERS", SZ_CONFIG)
        sz_config_mgr = sz_factory.create_configmanager()
        default_config_id = sz_config_mgr.get_default_config_id()
        sz_config = sz_config_mgr.create_config_from_config_id(default_config_id)
        sz_config.register_data_source(data_source_name)
        sz_config_mgr.set_default_config(sz_config.export(), 'default')
        sz_factory.reinitialize(default_config_id)
    try:
        log.info(SZ_TAG + 'Registering new data_source: ' + data_source_name)
        # For reasons unknown to me, this has to be done 2x before it sticks.
        f()
        f()
        log.info(SZ_TAG + 'Successfully registered data_source: ' + data_source_name)
    except sz.SzError as err:
        log.error(SZ_TAG + fmterr(err))

#-------------------------------------------------------------------------------

def go():
    '''Starts the Consumer process; runs indefinitely.'''

    # SQS client
    sqs = init()

    # Spin up msgs generator
    log.info('Spinning up messages generator')
    msgs = get_msgs(sqs, Q_URL)

    receipt_handle = None

    def clean_up(signum, frm):
        log.info('***************************')
        log.info('SIGINT or SIGTERM received.')
        log.info('***************************')
        sys.exit(0)
    signal.signal(signal.SIGINT, clean_up)
    signal.signal(signal.SIGTERM, clean_up)

    # Senzing init tasks.
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

    # OTel setup #
    log.info('Starting OTel setup.')
    meter = otel.init('consumer')
    otel_msgs_counter = meter.create_counter('consumer.messages.count')
    otel_durations = meter.create_histogram('consumer.messages.duration')
    log.info('Finished OTel setup.')
    # end OTel setup #

    while 1:
        try:
            # Get next message.
            msg = next(msgs)
            receipt_handle, body = msg['ReceiptHandle'], msg['Body']
            log.debug('SQS message retrieved, having ReceiptHandle: '
                     + receipt_handle)
            rcd = json.loads(body)

            start = time.perf_counter()
            success_status = otel.FAILURE # initial default value

            try:
                # Process and send to Senzing.
                start_alarm_timer(SZ_CALL_TIMEOUT_SECONDS)
                resp = sz_eng.add_record(rcd['DATA_SOURCE'], rcd['RECORD_ID'], body,
                                         sz.SzEngineFlags.SZ_WITH_INFO)
                cancel_alarm_timer()
                success_status = otel.SUCCESS
                log.debug(SZ_TAG + 'Successful add_record having ReceiptHandle: '
                         + receipt_handle)

                # Save affected entity IDs to tracker table for exporting later.
                affected = util.parse_affected_entities_resp(resp)
                log.debug(SZ_TAG + 'Affected entities: ' + str(affected))
                for entity_id in affected: db.add_entity_id(entity_id)

            except KeyError as ke:
                log.error(fmterr(ke))
                make_msg_visible(sqs, Q_URL, receipt_handle)
            except sz.SzUnknownDataSourceError as sz_uds_err:
                log.info(SZ_TAG + str(sz_uds_err))
                # Encountered a new data source name; register it.
                register_data_source(rcd['DATA_SOURCE'])
                # Toss back message for now.
                make_msg_visible(sqs, Q_URL, receipt_handle)
            except LongRunningCallTimeoutEx as lrex:
                log.error(build_sz_timeout_msg(
                    type(lrex).__module__,
                    type(lrex).__qualname__,
                    SZ_CALL_TIMEOUT_SECONDS,
                    receipt_handle))
            except sz.SzError as sz_err:
                log.error(SZ_TAG + DLQ_TAG + fmterr(sz_err))
                # "Toss back" this message to be re-consumed; we rely on AWS
                # config to move out-of-order messages into the DLQ at some point.
                make_msg_visible(sqs, Q_URL, receipt_handle)

            # Lastly, delete msg if no errors.
            else:
                del_msg(sqs, Q_URL, receipt_handle)

            finish = time.perf_counter()
            otel_msgs_counter.add(1,
                {'status': success_status,
                'service': 'consumer',
                'environment': RUNTIME_ENV})
            otel_durations.record(finish - start,
                {'status':  success_status,
                 'service': 'consumer',
                 'environment': RUNTIME_ENV})

        except Exception as e:
            log.error(fmterr(e))

#-------------------------------------------------------------------------------

def main():
    log.info('====================')
    log.info('     CONSUMER')
    log.info('     STARTED')
    log.info('====================')
    go()

if __name__ == '__main__': main()
