import json
import subprocess
import time
import unittest

import boto3

AWS_PROFILE = 'localstack'
Q_URL = 'http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/sqs-senzing-local-ingest'
S3_BUCKET_NAME = 'sqs-senzing-local-export'

CUSTOMERS_FILENAME = 'test/fixtures/customers.jsonl'
EXPECTED_OUTPUT_FILENAME = 'test/fixtures/flow-output.jsonl'

# After loading SQS, duration in seconds to wait for consumer/redoer
# to fully process data
PROCESSING_DURATION = 45

FULL = 'full'
DELTA = 'delta'

def slurp_jsonl_data(fname):
    with open(fname) as f:
        return list(map(json.loads, f.readlines()))

def slurp_json_data(fname):
    with open(fname) as f:
        return json.loads(f.read())

def slurp_text(fname):
    with open(fname) as f:
        return f.read()

def diff_jsonl_linecount(blob_1, blob_2):
    blob_1_lines = str(blob_1).strip().split("\n")
    blob_2_lines = str(blob_2).strip().split("\n")
    print(f'Blob 1 linecount: {len(blob_1_lines)}, blob 2 linecount: {len(blob_2_lines)}.')
    return abs(len(blob_2_lines) - len(blob_1_lines))

class TestFlow(unittest.TestCase):

    def docker_setup(s):
        ret = subprocess.run(['docker', 'compose', 'down', '-v']).returncode
        s.assertEqual(ret, 0)
        ret = subprocess.run(['docker', 'compose', 'rm', '-v', '-f']).returncode
        s.assertEqual(ret, 0)
        ret = subprocess.run(['docker', 'compose', 'build']).returncode
        s.assertEqual(ret, 0)
        ret = subprocess.run(['docker', 'compose', '--profile', 'exporter', 'build']).returncode
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

    def run_exporter(s, mode=None):
        ret = None
        if mode:
            ret = subprocess.run(['docker', 'compose', 'run', '--env', f'EXPORT_MODE={mode}', 'exporter']).returncode
        else:
            ret = subprocess.run(['docker', 'compose', 'run', 'exporter']).returncode
        s.assertEqual(ret, 0)

    def verify_output(s):
        sess = boto3.Session(profile_name=AWS_PROFILE)
        s3 = sess.client('s3')
        info = s3.list_objects_v2(Bucket=S3_BUCKET_NAME, Prefix='exporter-outputs/')
        s.assertEqual(info['KeyCount'], 1) # Check that one file made it into S3.
        key = info['Contents'][0]['Key']
        output = s3.get_object(Bucket=S3_BUCKET_NAME, Key=key)['Body'].read().decode('utf-8')
        expected = slurp_text(EXPECTED_OUTPUT_FILENAME)
        s.assertTrue(diff_jsonl_linecount(output, expected) == 0) # Entity count should be equal.
        s.assertEqual(len(str(output).strip().split("\n")), 74) # Testing entity count another way.

    def verify_delta_export(s):
        sess = boto3.Session(profile_name=AWS_PROFILE)
        s3 = sess.client('s3')
        # Add a record
        # docker compose run tools python dev/add_1_record.py
        ret = subprocess.run(['docker', 'compose', 'run', 'tools', 'python', 'dev/add_1_record.py']).returncode
        s.assertEqual(ret, 0)
        # Run delta, confirm 1 entity.
        s.run_exporter(DELTA)
        info = s3.list_objects_v2(Bucket=S3_BUCKET_NAME, Prefix='exporter-outputs/')
        s.assertEqual(info['KeyCount'], 2) # Should be 2 files in S3 now.
        key = info['Contents'][1]['Key']
        output = s3.get_object(Bucket=S3_BUCKET_NAME, Key=key)['Body'].read().decode('utf-8')
        s.assertTrue(len(str(output).strip()) > 0)  # Should *not* be empty string.
        s.assertEqual(len(str(output).strip().split("\n")), 1) # Only 1 row in the delta -- test is only worthwhile
                                                               # once we know is non-empty (prior test above).
        # Run again, confirm export file is empty.
        s.run_exporter(DELTA)
        info = s3.list_objects_v2(Bucket=S3_BUCKET_NAME, Prefix='exporter-outputs/')
        s.assertEqual(info['KeyCount'], 3) # Should be 3 files in S3 now.
        key = info['Contents'][2]['Key']
        output = s3.get_object(Bucket=S3_BUCKET_NAME, Key=key)['Body'].read().decode('utf-8')
        s.assertEqual(len(str(output).strip()), 0) # latest delta should be empty string
        # Run a full export, confirm has all entities.
        s.run_exporter(FULL)
        info = s3.list_objects_v2(Bucket=S3_BUCKET_NAME, Prefix='exporter-outputs/')
        s.assertEqual(info['KeyCount'], 4) # Should be 4 files in S3 now.
        key = info['Contents'][3]['Key']
        output = s3.get_object(Bucket=S3_BUCKET_NAME, Key=key)['Body'].read().decode('utf-8')
        s.assertEqual(len(str(output).strip().split("\n")), 75)

    def test_flow(s):
        print('Docker setup (db, SQS, S3, consumer, redoer, and exporter trigger) ...')
        s.docker_setup()
        print('Loading data into SQS ...')
        s.load_data_into_sqs()
        print(f'Pausing to allow consumer & redoer to process ({PROCESSING_DURATION} seconds) ...')
        time.sleep(PROCESSING_DURATION)
        print('Launching exporter ...')
        s.run_exporter()
        print('Comparing actual with expected ...')
        s.verify_output()
        print('Exercise delta export functionality ...')
        s.verify_delta_export()
        # s.docker_down()

if __name__ == '__main__':
    unittest.main()
