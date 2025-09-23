# Based on: https://senzing.com/docs/python/4/3calls/

import json
import os
import sys
from senzing import SzEngine, SzError
from senzing_core import SzAbstractFactoryCore

senzing_engine_configuration_json = json.loads(os.environ['SENZING_ENGINE_CONFIGURATION_JSON'])

record = '{ "NAME_FULL": "ROBERT SMITH", "ADDR_FULL": "123 Main St, Las Vegas NV" }'

try:
  # Create a Senzing engine
  sz_factory = SzAbstractFactoryCore("DoIT", senzing_engine_configuration_json)
  sz_engine = sz_factory.create_engine()

  # Entity resolve a record
  sz_engine.add_record("TEST", "1", record)

  # Get the entity it resolved to
  response = sz_engine.get_entity_by_record_id("TEST", "1")

  # Display entity JSON
  print(response)

  # Search for entities
  response = sz_engine.search_by_attributes('{"NAME_FIRST": "ROBERT", "NAME_LAST": "SMITH", "ADDR_FULL": "123 Main St, Las Vegas NV"}')

  # Display result JSON
  print(response)

except SzError as err:
  print(err)

