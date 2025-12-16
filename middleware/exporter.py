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

import otel
import db

try:
    log.info('Importing senzing_core library . . .')
    import senzing_core as sz_core
    log.info('Imported senzing_core successfully.')
except Exception as e:
    log.error('Importing senzing_core library failed.')
    log.error(fmterr(e))

if 'SENZING_ENGINE_CONFIGURATION_JSON' not in os.environ:
    log.error('SENZING_ENGINE_CONFIGURATION_JSON environment variable required.')
    sys.exit(1)
SZ_CONFIG = json.loads(os.environ['SENZING_ENGINE_CONFIGURATION_JSON'])

if 'S3_BUCKET_NAME' not in os.environ:
    log.error('S3_BUCKET_NAME environment variable required.')
    sys.exit(1)
S3_BUCKET_NAME = os.environ['S3_BUCKET_NAME']
FOLDER_NAME = os.environ.get('FOLDER_NAME', 'exporter-outputs')
RUNTIME_ENV = os.environ.get('RUNTIME_ENV', 'unknown') # For OTel

#EXPORT_FLAGS = sz.SzEngineFlags.SZ_EXPORT_DEFAULT_FLAGS
FULL_EXPORT_FLAGS = sz.SzEngineFlags.SZ_ENTITY_BRIEF_DEFAULT_FLAGS | sz.SzEngineFlags.SZ_EXPORT_INCLUDE_ALL_ENTITIES
DELTA_EXPORT_FLAGS = sz.SzEngineFlags.SZ_ENTITY_BRIEF_DEFAULT_FLAGS

EXPORT_MODE = os.environ.get('EXPORT_MODE', 'delta').lower()
log.info(f"Export mode is: {EXPORT_MODE}")
DELTA_MODE = None
if EXPORT_MODE == 'delta':
    DELTA_MODE = True
else:
    DELTA_MODE = False

# The output file is accumulated chunk by chunk from Senzing; this is how
# many bytes we put together before sending those combined chunks as a 'part'
# to S3 via multipart S3 upload.
BYTES_PER_PART = (1024 ** 2) * 10

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
        log.error(AWS_TAG + fmterr(e))

def build_output_filename(tag='exporter-output'):
    '''Returns a str, e.g.,
        '2025-10-07T23:15:54-UTC-exporter-output.json'
    '''
    kind = 'json' # Technically JSONL, but we're attempting to follow precedent here.
    return (
        datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S-UTC")
        + '-' + tag
        + '-' + EXPORT_MODE
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
        log.error(SZ_TAG + fmterr(sz_err))
    except Exception as e:
        log.error(fmterr(e))

    # OTel setup #
    log.info('Starting OTel setup.')
    meter = otel.init('exporter')
    otel_exp_counter = meter.create_counter('exporter.export.count')
    otel_duration = meter.create_histogram('exporter.export.duration')
    log.info('Finished OTel setup.')
    # end OTel setup #

    # Retrieve output from sz into buff
    # sz will export JSONL lines; we add the chars necessary to make
    # the output as a whole be a single JSON blob.
    log.info(SZ_TAG + 'Starting export from Senzing.')

    start = time.perf_counter()
    success_status = otel.FAILURE # initial default state

    # For multipart S3 upload, S3 will hand back to us an etag for each
    # part we upload to it. We need to accumulate the part IDs (which we
    # set) and the etags (which S3 gives) and provide it all to S3 at the very
    # end when wrapping up the upload.
    # This is a list of maps:
    part_ids_and_tags = []

    FETCH_COMPLETE = False

    key = FOLDER_NAME + '/' + build_output_filename()
    upload_id = None

    # Specific to delta mode:
    db_has_in_progress_rows = False
    entity_ids = []
    entity_ids_idx = -1
    try:

        if DELTA_MODE:
            log.info('Export tracker table before doing anything: ' + str(db.get_tallies()))
            log.info('Shifting export-tracker entity IDs from TODO to IN PROGRESS ...')
            entity_ids = db.shift_todo_to_in_progress_and_retrieve()
            db_has_in_progress_rows = True
            log.info('Successfully called db.shift_todo_to_in_progress_and_retrieve(); '
                     + f'Total count of entity IDs in progress: {len(entity_ids)}')
            log.info('Export tracker table AFTER shift to IN PROGRESS: ' + str(db.get_tallies()))
        else:
            export_handle = sz_eng.export_json_entity_report(FULL_EXPORT_FLAGS)
            log.info(SZ_TAG + 'Obtained export_json_entity_report handle.')

        mup_resp = s3.create_multipart_upload(
            Bucket=S3_BUCKET_NAME,
            ContentType='application/jsonl',
            Key=key)

        upload_id = mup_resp['UploadId']
        log.debug(f'Initialized a multipart S3 upload. UploadId: {upload_id}')
        #print(mup_resp)

        part_id = 0

        # Each loop we put together a "part" of the file and send it to S3.
        while 1:
            # init buffer
            buff = io.BytesIO()
            # Set up the ID for this particular part.
            part_id += 1
            # Inner loop lets us accumulate up to BYTES_PER_PART before
            # sending off to S3.
            while 1:
                chunk = ''
                if DELTA_MODE:
                    entity_ids_idx += 1
                    if entity_ids_idx == len(entity_ids):
                        FETCH_COMPLETE = True
                        log.info('All entities have been fetched.')
                    else:
                        current_entity_id = entity_ids[entity_ids_idx]
                        log.debug(f'Fetching info for entity ID {current_entity_id} ...')
                        try:
                            # Ref: https://garage.senzing.com/sz-sdk-python/senzing.html#senzing.szengine.SzEngine.get_entity_by_entity_id
                            #chunk = sz_eng.get_entity_by_entity_id(current_entity_id)
                            chunk = sz_eng.get_entity_by_entity_id(current_entity_id, DELTA_EXPORT_FLAGS)
                            buff.write(chunk.encode('utf-8'))
                            buff.write("\n".encode('utf-8'))
                            log.debug(f'Wrote data for entity {current_entity_id} to buffer.')
                        except sz.SzNotFoundError as sz_not_found_err:
                            log.debug(f'Entity {current_entity_id} has been deleted. Skipping.')
                else:
                    log.debug(SZ_TAG + 'Fetching chunk...')
                    chunk = sz_eng.fetch_next(export_handle)
                    if not chunk:
                        FETCH_COMPLETE = True
                        log.info('Fetch from Senzing complete.')
                    else:
                        buff.write(chunk.encode('utf-8'))
                        log.debug('Wrote chunk to buffer.')
                # Send this part to S3, and save the etag it gives us back.
                if buff.getbuffer().nbytes >= BYTES_PER_PART or FETCH_COMPLETE:
                    log.debug(f'Preparing and uploading part {part_id} to S3.')
                    # rewind to start of buff
                    buff.seek(0)
                    buff.flush()
                    resp = s3.upload_part(
                        Bucket=S3_BUCKET_NAME,
                        Key=key,
                        UploadId=upload_id,
                        PartNumber=part_id,
                        Body=buff.read())
                    log.debug(f'Sent part {part_id} to S3. ETag: {resp["ETag"]}')
                    part_ids_and_tags.append({
                        'PartNumber': part_id,
                        'ETag': resp['ETag']})
                    # We start with a new buff obj at next iteration.
                    buff.close()
                    break
            # end inner while
            if FETCH_COMPLETE:
                break
        # end outer while

        if DELTA_MODE:
            pass
        else:
            sz_eng.close_export_report(export_handle)
            log.info(SZ_TAG + 'Closed Senzing export handle.')
        # Wrap up the S3 upload via complete_multipart_upload
        rslt = s3.complete_multipart_upload(
            Bucket=S3_BUCKET_NAME,
            Key=key,
            MultipartUpload={'Parts':part_ids_and_tags},
            UploadId=upload_id)
        log.info('Finished uploading all parts to S3. All done.')
        log.info(f'Full path in S3: {key}')

        if DELTA_MODE:
            log.info('Current export tracker table state: ' + str(db.get_tallies()))
            log.info('Shifting export-tracker entity IDs from IN PROGRESS to DONE ...')
            db.shift_in_progress_to_done(export_id=key)
            log.info('Export tracker table AFTER shift to DONE: ' + str(db.get_tallies()))

        success_status = otel.SUCCESS

    except sz.SzError as err:
        log.error(SZ_TAG + fmterr(err))
        if upload_id:
            s3.abort_multipart_upload(
                Bucket=S3_BUCKET_NAME,
                Key=key,
                UploadId=upload_id)
        if db_has_in_progress_rows:
            db.rewind_in_progress_to_todo()
    except Exception as e:
        log.error(fmterr(e))
        if upload_id:
            s3.abort_multipart_upload(
                Bucket=S3_BUCKET_NAME,
                Key=key,
                UploadId=upload_id)
        if db_has_in_progress_rows:
            db.rewind_in_progress_to_todo()

    finally:
        finish = time.perf_counter()
        otel_exp_counter.add(1,
            {'status': success_status,
            'service': 'exporter',
            'environment': RUNTIME_ENV})
        otel_duration.record(finish - start,
            {'status':  success_status,
             'service': 'exporter',
             'environment': RUNTIME_ENV})

#-------------------------------------------------------------------------------

def main():
    log.info('====================')
    log.info('     EXPORTER')
    log.info('     *STARTED*')
    log.info('====================')
    go()

if __name__ == '__main__': main()
