import os
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
