import json

def parse_affected_entities_resp(resp):
    '''Returns array of ints (entity IDs)'''
    r = json.loads(resp)
    return list(map(lambda m: m['ENTITY_ID'], r['AFFECTED_ENTITIES']))
