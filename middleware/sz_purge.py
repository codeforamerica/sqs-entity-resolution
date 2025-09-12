import json
import os

import senzing as sz
try:
    print('Importing senzing_core library . . .')
    import senzing_core as sz_core
    print('Imported senzing_core successfully.')
except Exception as e:
    print('Importing senzing_core library failed.')
    print(e)
    sys.exit(1)
 
senzing_engine_configuration_json = json.loads(os.environ['SENZING_ENGINE_CONFIGURATION_JSON'])

sz_factory = sz_core.SzAbstractFactoryCore("sz_factory_1", senzing_engine_configuration_json)
sz_diagnostic = sz_factory.create_diagnostic()

print('Are you sure you want to purge the repository? If so, type YES:')
ans = input('>')
if ans == 'YES':
    sz_diagnostic.purge_repository()
else:
    print('Everything left as-is.')
