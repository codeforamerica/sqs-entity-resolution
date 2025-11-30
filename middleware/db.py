import psycopg2

from loglib import *
log = retrieve_logger()

EXPORT_STATUS_TODO = 1
EXPORT_STATUS_IN_PROGRESS = 2
EXPORT_STATUS_DONE = 3

_params = {
    'dbname': 'sqs_entity_resolution',
    'user': os.environ['PGUSER'],
    'password': os.environ['PGPASSWORD'],
    'host': os.environ['PGHOST'],
    'port':'5432'}

# ASSUMPTION here is that db.py is being used in a single-threaded manner
# and the usage patterns are those of the middleware modules (consumer,
# redoer, exporter). In other scenarios, it might not be advised to use
# *module-level* connection and/or cursor objects.

_conn = psycopg2.connect(**_params)
_curs = _conn.cursor()

def add_entity_id(entity_id):
    '''Inserts an entity_id into export_tracker with initial status of
    EXPORT_STATUS_TODO.'''
    if type(entity_id) is not int: raise TypeError
    log.debug(f'Entity ID: {entity_id}')
    try:
        _curs.execute(
            'insert into export_tracker (entity_id, export_status) values (%s, %s)',
            [entity_id, EXPORT_STATUS_TODO])
        _conn.commit()
    except Exception as e:
        _conn.rollback()
        log.error(fmterr(e))

def tag_todo_as_in_progress_and_retrieve():
    '''This function does two things:
    1. For all rows with status of EXPORT_STATUS_TODO, updates them
       to be EXPORT_STATUS_IN_PROGRESS.
    2. Returns a *distinct* (no duplicates) list of those entity IDs.'''
    out = []
    log.debug('tag_todo_as_in_progress_and_retrieve called.')
    try:
        _curs.execute(
            'update export_tracker set export_status = %s where export_status = %s',
            [EXPORT_STATUS_TODO, EXPORT_STATUS_IN_PROGRESS])
        log.debug('db update ran ok.')
        _curs.execute(
            'select distinct(entity_id) from export_tracker where export_status = %s',
            [EXPORT_STATUS_IN_PROGESS])
        out = list(map(lambda x: x[0], _curs.fetchall()))
        log.debug('db select distinct ran ok.')
        _conn.commit()
        log.debug('db commit ran ok.')
        return out
    except Exception as e:
        _conn.rollback()
        log.error(fmterr(e))

def tag_in_progress_as_done(export_id=None):
    '''For all rows with status of EXPORT_STATUS_IN_PROGRESS, updates them
    to be EXPORT_STATUS_DONE (and, optionally, updates their export_id value).
    Suggestion: export_id can be used to save the name of the output file that
    was exported.'''
    log.debug('tag_in_progress_as_done called.')
    if export_id and type(export_id) is not str: raise TypeError
    try:
        _curs.execute(
            'update export_tracker set export_status = %s where export_status = %s',
            [EXPORT_STATUS_IN_PROGRESS, EXPORT_STATUS_DONE])
        log.debug('db update export_status ran ok.')
        if export_id:
            _curs.execute('update export_tracker set export_id = %s', [export_id])
            log.debug('db update export_id ran ok.')
        _conn.commit()
        log.debug('db commit ran ok.')
    except Exception as e:
        _conn.rollback()
        log.error(fmterr(e))

def rewind_in_progress_to_todo():
    log.debug('rewind_in_progress_to_todo called.')
    try:
        _curs.execute(
            'update export_tracker set export_status = %s where export_status = %s',
            [EXPORT_STATUS_TODO, EXPORT_STATUS_IN_PROGRESS])
        log.debug('db update export_status ran ok.')
        _conn.commit()
        log.debug('db commit ran ok.')
    except Exception as e:
        _conn.rollback()
        log.error(fmterr(e))
