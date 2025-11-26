# Basic usage:
#   docker compose run tools python dev/check_export_tracker.py
# To dump contents of export_tracker to stdout:
#   docker compose run tools python dev/check_export_tracker.py dump
# Choose which export_status (1, 2, or 3) to dump (default is 1):
#   docker compose run tools python dev/check_export_tracker.py dump 2

import os
import sys
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

params = {
    'dbname': 'sqs_entity_resolution',
    'user': os.environ['PGUSER'],
    'password': os.environ['PGPASSWORD'],
    'host': os.environ['PGHOST'],
    'port':'5432'}

conn = psycopg2.connect(**params)
conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
curs = conn.cursor()

print('==================================================')
print('Checking that export_tracker was set up ...')

try:
    curs.execute('SELECT current_database()')
    if curs.fetchone()[0] == 'sqs_entity_resolution':
        print('o sqs_entity_resolution database exists OK')
    else:
        print('o ERROR: sqs_entity_resolution database does not exist')
except Exception as e:
    print(str(e))

rslt = None
try:
    curs.execute('select * from export_tracker')    
    rslt = curs.fetchall()
    if rslt == [] or len(rslt):
        print('o export_tracker table exists OK')
    else:
        print('o ERROR: export_tracker table does not exist')
except Exception as e:
    print(str(e))

print('==================================================')

if len(sys.argv) > 1 and sys.argv[1] == 'dump':
    print(rslt)
    print(f'Total: {len(rslt)}')
    export_status = sys.argv[2] if len(sys.argv) > 2 else 1 # 1 == EXPORT_STATUS_TODO
    curs.execute('select distinct(entity_id) from export_tracker where export_status = %s',
        export_status)
    out = list(map(lambda x: x[0], curs.fetchall()))
    print(type(out))
    print(out)
