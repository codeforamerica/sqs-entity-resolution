import json
import sys
import time
import boto3

# Primary function of interest here is load_dat(), which loads data from
# sample-data/customers.jsonl into SQS.

# Suggestion: set custom values for these in a REPL.
AWS_PROFILE_NAME = None
Q_URL = None

#------------------------------------------------------------------------------

def make_boto_session(fpath=None):
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

def make_sqs_client(boto_session):
    return boto_session.client('sqs')

def init():
    sess = make_boto_session()
    sqs = sess.client('sqs')
    return sqs

def make_q(name):
    sqs = init()
    # defaults: standard, 30 visibility timeout
    return sqs.create_queue(QueueName=name)

#------------------------------------------------------------------------------

def slurp_cust_data():
    fname = 'sample-data/customers.jsonl'
    f = open(fname)
    return list(map(json.loads, f.readlines())) 

#------------------------------------------------------------------------------

def send_rcd_to_q(rcd, sqs, q_url):
    # TEMP
    #time.sleep(1)
    print(rcd)

    pyld = json.dumps(rcd)
    resp = sqs.send_message(QueueUrl=q_url, MessageBody=pyld)
    return resp

def empty_q(sqs, q_url):
    return sqs.purge_queue(QueueUrl=q_url)
    
def load_dat():
    '''Load some test data into SQS.'''
    sqs = init()
    dat = slurp_cust_data()
    return [send_rcd_to_q(r, sqs, Q_URL) for r in dat]

def _get_1_msg(sqs, q_url):
    resp = sqs.receive_message(QueueUrl=q_url, MaxNumberOfMessages=1,
                               WaitTimeSeconds=POLL_SECONDS)
    print(resp)
    return resp

