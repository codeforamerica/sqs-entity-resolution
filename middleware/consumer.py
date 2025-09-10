import json
import os
import time
import sys
import boto3
import senzing as sz
try:
    print('Importing senzing_core library . . .')
    import senzing_core as sz_core
    print('Imported senzing_core successfully.')
except Exception as e:
    print('Importing senzing_core library failed.')
    print(e)
    sys.exit(1)
    
# TODO add DLQ logic (needs jira ticket probably).

AWS_PROFILE_NAME = os.environ['AWS_PROFILE_NAME']
Q_URL = os.environ['Q_URL']
SZ_CONFIG = json.loads(os.environ['SENZING_ENGINE_CONFIGURATION_JSON'])

POLL_SECONDS = 20                   # 20 seconds is SQS max
HIDE_MESSAGE_SECONDS = 600          # SQS visibility timeout

#-------------------------------------------------------------------------------

def _make_boto_session(fpath=None):
    '''fpath is path to json file with keys:
        - aws_access_key_id
        - aws_secret_access_key
        - aws_session_token
        - region
    (Same keys should typically be present in .aws/credentials file
    if using profile.)'''
    if fpath:
        return boto3.Session(**json.load(open(fpath)))
    else:
        return boto3.Session(profile_name=AWS_PROFILE_NAME)

def _make_sqs_client(boto_session):
    return boto_session.client('sqs')

# TODO add try/except code
# TODO add logging
def init():
    '''Returns sqs client object'''
    sess = _make_boto_session()
    sqs = sess.client('sqs')
    return sqs

# TODO add try/except code
# TODO add logging
def get_msgs(sqs, q_url):
    '''Generator function; returns a single SQS msg at a time.
    Pertinent keys in an SQS message include:
    - MessageId
    - ReceiptHandle -- you'll need this to delete the msg later
    - Body -- here, should be the JSONL record as a string
    '''
    while 1:
        print('waiting for msg')
        resp = sqs.receive_message(QueueUrl=q_url, MaxNumberOfMessages=1,
                                   WaitTimeSeconds=POLL_SECONDS)
        if 'Messages' in resp and len(resp['Messages']) == 1:
            yield resp['Messages'][0]
   
# TODO add try/except code
# TODO add logging
def del_msg(sqs, q_url, receipt_handle):
    return sqs.delete_message(QueueUrl=q_url, ReceiptHandle=receipt_handle)

#-------------------------------------------------------------------------------

# TODO add more try/except code as needed
# TODO add logging
def go():
    '''Starts the Consumer process; runs indefinitely.'''

    # SQS client
    sqs = init()

    # Spin up msgs generator
    msgs = get_msgs(sqs, Q_URL)

    # Senzing init tasks.
    sz_eng = None
    try:
        sz_factory = sz_core.SzAbstractFactoryCore("ERS", SZ_CONFIG)

        # Init data source list.
        # TODO data source registry logic should be set up as a one-time task
        # outside of this app somewhere else.
        sz_config_mgr = sz_factory.create_configmanager()
        sz_config = sz_config_mgr.create_config_from_config_id(
            sz_config_mgr.get_default_config_id())
        sz_config.register_data_source("CUSTOMERS")
        sz_config_mgr.set_default_config(sz_config.export(), 'default')

        # Init senzing engine object.
        # Senzing engine object cannot be passed around between functions,
        # else it will be eagerly cleaned up / destroyed and no longer usable. 
        sz_eng = sz_factory.create_engine()
    except sz.SzError as err:
        # TODO log error
        print(err)
        sys.exit(1)

    # TODO log ReceiptHandle, other *generic* debug-facing information as appropriate.
    while 1:
        print('Starting primary loop iteration . . .')
        msg = next(msgs)
        receipt_handle, body = msg['ReceiptHandle'], msg['Body']
        rcd = json.loads(body)
        try:
            # TODO add logging
            # TODO Use signal lib to handle stalled records (i.e., still 
            #      processing >5 minutes)
            resp = sz_eng.add_record(rcd['DATA_SOURCE'], rcd['RECORD_ID'], body,
                                     sz.SzEngineFlags.SZ_WITH_INFO)
            print(resp)
        except sz.SzError as err:
            # TODO log / handle
            print(err)
        del_msg(sqs, Q_URL, receipt_handle)

def main():
    print('====================')
    print('     CONSUMER')
    print('     STARTED')
    print('====================')
    go()

if __name__ == '__main__': main()
