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
        log.error(f'Failure to insert for entity ID: {entity_id}')

def tag_todo_as_in_progress_and_retrieve():
    '''This function does two things:
    1. For all rows with status of EXPORT_STATUS_TODO, updates them
       to be EXPORT_STATUS_IN_PROGRESS.
    2. Returns a *distinct* (no duplicates) list of those entity IDs.'''
    ...

def tag_in_progress_as_done(export_id):
    '''For all rows with status of EXPORT_STATUS_IN_PROGRESS, updates them
    to be EXPORT_STATUS_DONE and collectively updates their export_id value.
    In Practice, export_id will usually be the name of the output file that
    was exported.'''
    ...
