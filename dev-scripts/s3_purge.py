import os
import boto3

def purge_s3():
    s3 = boto3.resource('s3', endpoint_url=os.environ['AWS_ENDPOINT_URL'])
    buck = s3.Bucket(os.environ['S3_BUCKET_NAME'])
    print('Purging...') 
    buck.objects.all().delete()

print('Are you sure you want to purge the S3 bucket (' + os.environ['S3_BUCKET_NAME'] + ')? If so, type YES:')
ans = input('>')
if ans == 'YES':
    purge_s3()
    print('Done.')
else:
    print('Nothing was done. Everything was left as-is.')
