import json
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

# How long to wait before attempting next Senzing op.
WAIT_SECONDS = int(os.environ.get('WAIT_SECONDS', 10))

MAX_REDO_ATTEMPTS = int(os.environ.get('MAX_REDO_ATTEMPTS', 20))

#-------------------------------------------------------------------------------

def go():
    '''Starts the Redoer process; runs indefinitely.'''

    sz_eng = None
    try:
        sz_factory = sz_core.SzAbstractFactoryCore("ERS", SZ_CONFIG)

        # Init senzing engine object.
        # Senzing engine object cannot be passed around between functions,
        # else it will be eagerly cleaned up / destroyed and no longer usable.
        sz_eng = sz_factory.create_engine()
        log.info(SZ_TAG + 'Senzing engine object instantiated.')
    except sz.SzError as sz_err:
        log.error(SZ_TAG + str(sz_err))
        sys.exit(1)
    except Exception as e:
        log.error(str(e))
        sys.exit(1)

    log.info('Starting primary loop.')

    # Approach:
    # - We don't try to both 'get' and 'process' in a single loop; instead we
    #   'get', then 'continue' to the next loop; the have_rcd flag is used to
    #   facilitate this.
    # - Each Senzing call (3 distinct calls) is couched in its own try-except block for
    #   robustness.
    tally = None
    have_rcd = 0
    rcd = None
    attempts_left = MAX_REDO_ATTEMPTS
    while 1:
        try:

            if have_rcd:
                try:
                    sz_eng.process_redo_record(rcd)
                    have_rcd = 0
                    log.debug(SZ_TAG + 'Successfully redid one record via process_redo_record().')
                    continue
                except sz.SzRetryableError as sz_ret_err:
                    # We'll try to process this record again.
                    log.error(SZ_TAG + str(sz_ret_err))
                    attempts_left -= 1
                    log.debug(SZ_TAG + f'Remaining attempts for this record: {attempts_left}')
                    if not attempts_left:
                        have_rcd = 0
                        log.error(SZ_TAG + f'Max redo attempts ({MAX_REDO_ATTEMPTS}) reached'
                                  + ' for this record; dropping on the floor and moving on.')
                    time.sleep(WAIT_SECONDS)
                    continue
                except sz.SzError as sz_err:
                    log.error(SZ_TAG + str(sz_err))
                    sys.exit(1)

            else:
                try:
                    tally = sz_eng.count_redo_records()
                    log.debug(SZ_TAG + 'Current redo count: ' + str(tally))
                except sz.SzRetryableError as sz_ret_err:
                    log.error(SZ_TAG + str(sz_ret_err))
                    time.sleep(WAIT_SECONDS)
                    continue
                except sz.SzError as sz_err:
                    log.error(SZ_TAG + str(sz_err))
                    sys.exit(1)

                if tally:

                    try:
                        rcd = sz_eng.get_redo_record()
                        if rcd:
                            have_rcd = 1
                            attempts_left = MAX_REDO_ATTEMPTS
                            # At this point, rcd var holds a record, and have_rcd flag
                            # raised. Will process in the next loop.
                            log.debug(SZ_TAG + 'Retrieved 1 record via get_redo_record()')
                        else:
                            log.debug(SZ_TAG + 'Redo count was greater than 0, but got '
                                      + 'nothing from get_redo_record')
                    except sz.SzRetryableError as sz_ret_err:
                        # No additional action needed; we'll just try getting again.
                        log.error(SZ_TAG + str(sz_ret_err))
                    except sz.SzError as sz_err:
                        log.error(SZ_TAG + str(sz_err))
                        sys.exit(1)

                else:
                    log.debug('No redo records. Will wait ' + str(WAIT_SECONDS) + ' seconds.')
                    time.sleep(WAIT_SECONDS)

        except Exception as e:
            log.error(str(e))
            sys.exit(1)

#-------------------------------------------------------------------------------

def main():
    log.info('====================')
    log.info(' ------->')
    log.info('   REDOER    ')
    log.info('       STARTED')
    log.info('          ------->')
    log.info('====================')
    go()

if __name__ == '__main__': main()
