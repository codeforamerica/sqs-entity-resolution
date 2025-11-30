import json
import subprocess
import time
import unittest

import boto3

AWS_PROFILE = 'localstack'
Q_URL = 'http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/sqs-senzing-local-ingest'
S3_BUCKET_NAME = 'sqs-senzing-local-export'

CUSTOMERS_FILENAME = 'test/fixtures/customers.jsonl'
EXPECTED_OUTPUT_FILENAME = 'test/fixtures/flow-output.json'

def slurp_jsonl_data(fname):
    with open(fname) as f:
        return list(map(json.loads, f.readlines())) 

def slurp_json_data(fname):
    with open(fname) as f:
        return json.loads(f.read())

class TestFlow(unittest.TestCase):

    def docker_setup(s):
        ret = subprocess.run(['docker', 'compose', 'down', '-v']).returncode
        s.assertEqual(ret, 0)    
        ret = subprocess.run(['docker', 'compose', 'rm', '-v', '-f']).returncode
        s.assertEqual(ret, 0)    
        ret = subprocess.run(['docker', 'compose', 'build']).returncode
        s.assertEqual(ret, 0)    
        ret = subprocess.run(['docker', 'compose', 'up', '-d']).returncode
        s.assertEqual(ret, 0)    

    def docker_down(s):
        ret = subprocess.run(['docker', 'compose', 'down']).returncode
        s.assertEqual(ret, 0)    

    def load_data_into_sqs(s):
        sess = boto3.Session(profile_name=AWS_PROFILE)
        sqs = sess.client('sqs')
        data = slurp_jsonl_data(CUSTOMERS_FILENAME)
        def f(rcd, sqs, q_url):
            pyld = json.dumps(rcd)
            resp = sqs.send_message(QueueUrl=q_url, MessageBody=pyld)
            print(resp)
        [f(r, sqs, Q_URL) for r in data]
        # Sanity check SQS contents:
        num_msgs = sqs.get_queue_attributes(
            QueueUrl=Q_URL,
            AttributeNames=['ApproximateNumberOfMessages'])['Attributes']['ApproximateNumberOfMessages']
        print(num_msgs)
        s.assertTrue(int(num_msgs) > 115)

    def verify_output(s):
        sess = boto3.Session(profile_name=AWS_PROFILE)
        s3 = sess.client('s3')
        info = s3.list_objects_v2(Bucket=S3_BUCKET_NAME, Prefix='exporter-outputs/')
        s.assertEqual(info['KeyCount'], 1)
        key = info['Contents'][0]['Key'] 
        output = json.loads(s3.get_object(Bucket=S3_BUCKET_NAME, Key=key)['Body'].read())
        expected = slurp_json_data(EXPECTED_OUTPUT_FILENAME)
        s.assertEqual(json.dumps(output, sort_keys=True), json.dumps(expected, sort_keys=True))
    
    def test_flow(s):
        print('Docker setup (db, SQS, S3, consumer, redoer, and exporter trigger) ...')
        s.docker_setup()
        print('Loading data into SQS ...')
        s.load_data_into_sqs()
        print('Pausing to allow consumer / redoer / exporter to process...')
        time.sleep(15)
        print('Comparing actual with expected ...')
        s.verify_output()
        s.docker_down()
       
if __name__ == '__main__':
    unittest.main()
