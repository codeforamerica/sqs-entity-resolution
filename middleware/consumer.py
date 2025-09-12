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
    '''Generator function; returns a single SQS msg at a time.
    Pertinent keys in an SQS message include:
    - MessageId
    - ReceiptHandle -- you'll need this to delete the msg later
    - Body -- here, should be the JSONL record as a string
    '''
    while 1:
        print('waiting for msg')
        try:
            log.info(AWS_TAG + 'Polling SQS for the next message')
            resp = sqs.receive_message(QueueUrl=q_url, MaxNumberOfMessages=1,
                                       WaitTimeSeconds=POLL_SECONDS)
            if 'Messages' in resp and len(resp['Messages']) == 1:
                yield resp['Messages'][0]
        except Exception as e:
            log.error(AWS_TAG + str(e))
   
def del_msg(sqs, q_url, receipt_handle):
    try:
        return sqs.delete_message(QueueUrl=q_url, ReceiptHandle=receipt_handle)
    except Exception as e:
        log.error(AWS_TAG + DLQ_TAG + 'SQS delete failure for ReceiptHandle: ' +
                  ReceiptHandle + ' Additional info: ' + str(e))

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
            log.info('SQS message retrieved, having ReceiptHandle: '
                     + receipt_handle)
            rcd = json.loads(body)

            # Process and send to Senzing.
            resp = sz_eng.add_record(rcd['DATA_SOURCE'], rcd['RECORD_ID'], body,
                                     sz.SzEngineFlags.SZ_WITH_INFO)
            log.info(SZ_TAG + 'Successful add_record having ReceiptHandle: '
                     + receipt_handle)

            # Delete msg from queue.
            del_msg(sqs, Q_URL, receipt_handle)
        except sz.SzError as sz_err:
            log.error(SZ_TAG + DLQ_TAG + str(sz_err))
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
