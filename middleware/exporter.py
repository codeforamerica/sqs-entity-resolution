import datetime
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

if 'SENZING_ENGINE_CONFIGURATION_JSON' not in os.environ:
    log.error('SENZING_ENGINE_CONFIGURATION_JSON environment variable required.')
    sys.exit(1)
SZ_CONFIG = json.loads(os.environ['SENZING_ENGINE_CONFIGURATION_JSON'])

if 'S3_BUCKET_NAME' not in os.environ:
    log.error('S3_BUCKET_NAME environment variable required.')
    sys.exit(1)
S3_BUCKET_NAME = os.environ['S3_BUCKET_NAME']
FOLDER_NAME = os.environ.get('FOLDER_NAME', 'exporter-outputs')

EXPORT_FLAGS =  sz.SzEngineFlags.SZ_EXPORT_DEFAULT_FLAGS

#-------------------------------------------------------------------------------

def ts():
    '''Return current timestamp in ms as a str'''
    return str(int(round(time.time() * 1000)))

def make_s3_client():
    try:
        sess = boto3.Session()
        if 'AWS_ENDPOINT_URL' in os.environ:
            return sess.client('s3', endpoint_url=os.environ['AWS_ENDPOINT_URL'])
        else:
            return sess.client('s3')
    except Exception as e:
        log.error(AWS_TAG + str(e))
        sys.exit(1)

def build_output_filename(tag='exporter-output', kind='json'):
    '''Returns a str, e.g.,
        '2025-10-07T23:15:54-UTC-exporter-output.json'
    '''
    return (
        datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SUTC")
        + '-' + tag
        + '.' + kind)

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
    log.info(SZ_TAG + 'Starting export from Senzing.')
    try:
        export_handle = sz_eng.export_json_entity_report(EXPORT_FLAGS)
        log.info(SZ_TAG + 'Obtained export_json_entity_report handle.')
        buff.write('['.encode('utf-8'))
        while 1:
            log.debug(SZ_TAG + 'Fetching chunk...')
            chunk = sz_eng.fetch_next(export_handle)
            if not chunk:
                break
            buff.write(chunk.encode('utf-8'))
            log.debug('Wrote chunk to buffer.')
            buff.write(','.encode('utf-8'))
        sz_eng.close_export_report(export_handle)
        log.info(SZ_TAG + 'Closed export handle.')
        buff.seek(-1, os.SEEK_CUR) # toss out last comma
        buff.write(']'.encode('utf-8'))
        log.info('Total bytes exported/buffered: ' + str(buff.getbuffer().nbytes))
    except sz.SzError as err:
        log.error(SZ_TAG + str(err))
    except Exception as e:
        log.error(str(e))

    # rewind buffer
    buff.seek(0)
    buff.flush()

    # write buff to S3 using upload_fileobj
    full_path = FOLDER_NAME + '/' + build_output_filename()
    log.info(AWS_TAG + 'About to upload JSON file ' + full_path + ' to S3 ...')
    try:
        s3.upload_fileobj(buff, S3_BUCKET_NAME, full_path)
        log.info(AWS_TAG + 'Successfully uploaded file.')
    except Exception as e:
        log.error(AWS_TAG + str(e))

#-------------------------------------------------------------------------------

def main():
    log.info('====================')
    log.info('     EXPORTER')
    log.info('     *STARTED*')
    log.info('====================')
    go()

if __name__ == '__main__': main()

