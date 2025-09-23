import json
import os
import time
import sys
import boto3
import senzing as sz

from loglib import *
log = retrieve_logger()

try:
    log.info('Importing senzing_core library . . .')
    import senzing_core as sz_core
    log.info('Imported senzing_core successfully.')
except Exception as e:
    log.error('Importing senzing_core library failed.')
    log.error(e)
    sys.exit(1)

# TODO add DLQ logic (see DLG_TAG logging)

Q_URL = os.environ['Q_URL']
SZ_CONFIG = json.loads(os.environ['SENZING_ENGINE_CONFIGURATION_JSON'])

POLL_SECONDS = 20                   # 20 seconds is SQS max
HIDE_MESSAGE_SECONDS = 600          # SQS visibility timeout

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
        sqs = sess.client('sqs')
        log.info(AWS_TAG + 'SQS client object instantiated.')
        return sqs
    except Exception as e:
        log.error(AWS_TAG + str(e))
        sys.exit(1)

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
                                       WaitTimeSeconds=POLL_SECONDS)
            if 'Messages' in resp and len(resp['Messages']) == 1:
                yield resp['Messages'][0]
        except Exception as e:
            log.error(AWS_TAG + str(e))
   
def del_msg(sqs, q_url, receipt_handle):
    try:
        log.debug(AWS_TAG + 'Deleting message having ReceiptHandle: ' + receipt_handle)
        return sqs.delete_message(QueueUrl=q_url, ReceiptHandle=receipt_handle)
    except Exception as e:
        log.error(AWS_TAG + DLQ_TAG + 'SQS delete failure for ReceiptHandle: ' +
                  ReceiptHandle + ' Additional info: ' + str(e))

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
        log.error(AWS_TAG + str(e))

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
        log.error(SZ_TAG + str(err))
        sys.exit(1)

#-------------------------------------------------------------------------------

def go():
    '''Starts the Consumer process; runs indefinitely.'''

    # SQS client
    sqs = init()

    # Spin up msgs generator
    log.info('Spinning up messages generator')
    msgs = get_msgs(sqs, Q_URL)

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
        log.error(SZ_TAG + str(sz_err))
        sys.exit(1)
    except Exception as e:
        log.error(str(e))
        sys.exit(1)

    while 1:
        try:
            # Get next message.
            msg = next(msgs)
            receipt_handle, body = msg['ReceiptHandle'], msg['Body']
            log.debug('SQS message retrieved, having ReceiptHandle: '
                     + receipt_handle)
            rcd = json.loads(body)

            try:
                # Process and send to Senzing.
                resp = sz_eng.add_record(rcd['DATA_SOURCE'], rcd['RECORD_ID'], body)
                log.info(SZ_TAG + 'Successful add_record having ReceiptHandle: '
                         + receipt_handle)
            except sz.SzUnknownDataSourceError as sz_uds_err:
                try:
                    log.info(SZ_TAG + str(sz_uds_err))
                    # Encountered a new data source name; register it.
                    register_data_source(rcd['DATA_SOURCE'])

                    # Then try again: process and send to Senzing.
                    resp = sz_eng.add_record(rcd['DATA_SOURCE'], rcd['RECORD_ID'], body)
                    log.info(SZ_TAG + 'Successful add_record having ReceiptHandle: '
                             + receipt_handle)
                except sz.SzError as sz_err:
                    raise sz_err
            except sz.SzError as sz_err:
                log.error(SZ_TAG + DLQ_TAG + str(sz_err))
                # "Toss back" this message to be re-consumed; we rely on AWS
                # config to move out-of-order messages into the DLQ at some point.
                make_msg_visible(sqs, Q_URL, receipt_handle)

            # Lastly, delete msg if no errors.
            else:
                del_msg(sqs, Q_URL, receipt_handle)

        except Exception as e:
            log.error(str(e))
            sys.exit(1)

#-------------------------------------------------------------------------------

def main():
    log.info('====================')
    log.info('     CONSUMER')
    log.info('     STARTED')
    log.info('====================')
    go()

if __name__ == '__main__': main()
