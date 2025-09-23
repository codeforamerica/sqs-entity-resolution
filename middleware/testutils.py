import json
import os
import sys
import time
import boto3

# Primary function of interest here is load_dat(), which loads data from
# sample-data/customers.jsonl into SQS.

# For live AWS, can set these to other values.
AWS_PROFILE = 'localstack'
Q_URL = 'http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/sqs-senzing-local-ingest'
S3_BUCKET_NAME = 'sqs-senzing-local-export'

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
        # Here we pass in profile_name explicitly since it's not necessarily an env
        # var in this context.
        return boto3.Session(profile_name=AWS_PROFILE)

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

#-------------------------------------------------------------------------------

def make_s3_client():
    try:
        # Here we pass in profile_name explicitly since it's not necessarily an env
        # var in this context.
        sess = boto3.Session(profile_name=AWS_PROFILE)
        if 'AWS_ENDPOINT_URL' in os.environ:
            return sess.client('s3', endpoint_url=os.environ['AWS_ENDPOINT_URL'])
        else:
            return sess.client('s3')
    except Exception as e:
        print(e)

def upload_test_file_to_s3():
    print("Starting test upload to S3 ...")
    s3 = make_s3_client()
    print(s3)
    fname = 'sample-data/hemingway.txt'
    resp = s3.upload_file(fname, S3_BUCKET_NAME, fname[fname.rfind('/')+1:])
    print(resp) 
    print('Upload successful.')
