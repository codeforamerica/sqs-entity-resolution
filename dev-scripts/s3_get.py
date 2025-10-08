import os
import sys
import boto3

def make_s3_client():
    try:
        sess = boto3.Session()
        return sess.client('s3', endpoint_url=os.environ['AWS_ENDPOINT_URL'])
    except Exception as e:
        print(e)
        sys.exit(1)

def get_file_from_s3(key):
    '''Get file from S3 and write to /tmp (use docker-compose to map this
    to desired directory on host machine).'''
    s3 = make_s3_client()
    print('Grabbing file...') 
    # Note we slice off the S3 folder name when specifying target filename.
    resp = s3.download_file(os.environ['S3_BUCKET_NAME'], key, '/tmp/' + key[key.rfind('/')+1:])
    print ('Got file, put in tmp')

print("Starting util_s3_retrieve ...")
fname = sys.argv[1]
get_file_from_s3(fname)
print("Done")
