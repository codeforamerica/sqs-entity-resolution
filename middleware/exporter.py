import json
import io
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

SZ_CONFIG = json.loads(os.environ['SENZING_ENGINE_CONFIGURATION_JSON'])
S3_BUCKET = 'sqs-senzing-local-export'

# TODO which flags do we need?
EXPORT_FLAGS =  sz.SzEngineFlags.SZ_EXPORT_DEFAULT_FLAGS

#-------------------------------------------------------------------------------

def ts():
    '''Return current timestamp in ms as a str'''
    return str(int(round(time.time() * 1000)))

def make_s3_client():
    sess = boto3.Session()
    if 'AWS_ENDPOINT_URL'in os.environ:
        return sess.client('s3', endpoint_url=os.environ['AWS_ENDPOINT_URL'])
    else:
        return sess.client('s3')

def go():
    '''
    Exports Senzing JSON entity report data into a buffer, then
    uploads the buffer as a file into the output S3 bucket.

    References:
    - https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.export_json_entity_report
    - https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3/client/upload_fileobj.html
    '''

    # Init S3 client
    s3 = make_s3_client()
    
    # Init senzing engine object.
    # Note that Senzing engine object cannot be passed around between functions,
    # else it will be eagerly cleaned up / destroyed and no longer usable. 
    sz_eng = None
    try:
        sz_factory = sz_core.SzAbstractFactoryCore("ERS", SZ_CONFIG)
        sz_eng = sz_factory.create_engine()
        log.info(SZ_TAG + 'Senzing engine object instantiated.')
    except sz.SzError as sz_err:
        log.error(SZ_TAG + str(sz_err))
        sys.exit(1)
    except Exception as e:
        log.error(str(e))
        sys.exit(1)

    # init buffer
    buff = io.BytesIO()
    
    # Retrieve output from sz into buff
    # sz will export JSONL lines; we add the chars necessary to make
    # the output as a whole be a single JSON blob.
    try:
        export_handle = sz_eng.export_json_entity_report(EXPORT_FLAGS)
        buff.write('['.encode('utf-8'))
        while 1:
            chunk = sz_eng.fetch_next(export_handle)
            if not chunk:
                break
            buff.write(chunk.encode('utf-8'))
            buff.write(','.encode('utf-8'))
        sz_eng.close_export_report(export_handle)
        buff.seek(-1, os.SEEK_CUR) # toss out last comma
        buff.write(']'.encode('utf-8'))
    except sz.SzError as err:
        print(err)

    # rewind buffer
    buff.seek(0)

    # write buff to S3 using upload_fileobj
    fname = 'output-' + ts() + '.json'
    resp = s3.upload_fileobj(buff, S3_BUCKET, fname)

    print(resp)
    return resp

#-------------------------------------------------------------------------------

def main():
    log.info('====================')
    log.info('     EXPORTER')
    log.info('     *STARTED*')
    log.info('====================')
    go()

if __name__ == '__main__': main()

#-------------------------------------------------------------------------------
# test funcs (to maybe relocate)

def upload_test_file():
    print("Start test upload to S3 ...")
    s3 = make_s3_client()
    print(s3)
    fname = 'hemingway.txt'
    resp = s3.upload_file(fname, S3_BUCKET, fname)
    print(resp) 
    print("SUCCESSFUL")

def get_file():
    key = 'output-1758036760013.json'
    print('Grabbing file...') 
    s3 = make_s3_client()
    resp = s3.download_file(S3_BUCKET, key, '/tmp/'+key)
    print(resp)
    print('done grabbing file.')
    #f = open('/tmp/'+key)
    #print(f.readlines())

#upload_test_file()
#get_file()
