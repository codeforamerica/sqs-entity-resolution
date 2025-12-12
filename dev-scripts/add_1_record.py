# Based on: https://senzing.com/docs/python/4/3calls/

import json
import os
import sys
from senzing import SzEngine, SzError
from senzing_core import SzAbstractFactoryCore

import senzing as sz
import db
import util

senzing_engine_configuration_json = json.loads(os.environ['SENZING_ENGINE_CONFIGURATION_JSON'])

#record = '{ "NAME_FULL": "ROBERT SMITH", "ADDR_FULL": "123 Main St, Las Vegas NV" }'
record = '{"NAME_FIRST": "ERNEST", "NAME_LAST": "HEMINGWAY", "ADDR_FULL": "453 Orange Blossom Path, Key West FL"}'

try:
  # Create a Senzing engine
  sz_factory = SzAbstractFactoryCore("DoIT", senzing_engine_configuration_json)
  sz_engine = sz_factory.create_engine()

  # Entity resolve a record
  resp = sz_engine.add_record("TEST", "1", record, sz.SzEngineFlags.SZ_WITH_INFO)

  # Save affected entity IDs into export tracker table
  affected = util.parse_affected_entities_resp(resp)
  for entity_id in affected: db.add_entity_id(entity_id)

  # Get the entity it resolved to
  response = sz_engine.get_entity_by_record_id("TEST", "1")

  # Display entity JSON
  print('Output for get_entity_by_record_id:')
  print(response)

  # Search for entities
  #response = sz_engine.search_by_attributes('{"NAME_FIRST": "ROBERT", "NAME_LAST": "SMITH", "ADDR_FULL": "123 Main St, Las Vegas NV"}')
  print('Output for search_by_attributes:')
  response = sz_engine.search_by_attributes('{"NAME_FIRST": "ERNEST", "NAME_LAST": "HEMINGWAY"}')

  # Display result JSON
  print(response)

except SzError as err:
  print(err)

