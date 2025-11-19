# Launch a Python console with an instantiated Senzing engine object:
# docker compose run tools python -i dev/sz_eng.py

import json
import os
import senzing as sz
import senzing_core as sz_core

SZ_CONFIG = json.loads(os.environ['SENZING_ENGINE_CONFIGURATION_JSON'])
sz_factory = sz_core.SzAbstractFactoryCore('ERS', SZ_CONFIG)
sz_eng = sz_factory.create_engine()

# sz_eng.get_entity_by_entity_id(1)
