"""Strict validation for the minimal room prop / transient loot prototype."""
from build_shop_preview_content import DATA, ROOT, read_json, validate

def validate_room_props(manifest):
    path = ROOT / 'game' / manifest['room_props_file'].removeprefix('res://')
    data = read_json(path)
    validate(data, read_json(DATA/'schemas/room_props.schema.json'), 'room_props')
    ids = [p['id'] for p in data['props']]
    if len(data['composition_ids']) != len(set(data['composition_ids'])):
        raise ValueError('Duplicate composition ID')
    items = [p['id'] for p in data['loot_items']]
    if len(ids) != len(set(ids)) or len(items) != len(set(items)):
        raise ValueError('Duplicate room prop or loot item ID')
    for prop in data['props']:
        if (prop['kind'] == 'destructible') != (prop['health'] > 0):
            raise ValueError('Only destructibles have health')
        if (prop['kind'] == 'searchable') != bool(prop['loot']):
            raise ValueError('Only searchable props have loot tables in this prototype')
        for loot in prop['loot']:
            if loot['item_id'] not in items or loot['count_min'] > loot['count_max']:
                raise ValueError('Invalid loot reference/count')
    for group in data['groups']:
        if group['count_min'] > group['count_max'] or group['count_max'] > len(set(group['choices'])) or not set(group['choices']) <= set(data['composition_ids']):
            raise ValueError('Invalid prop group')
    for locale in ['zh_CN', 'en']:
        messages = read_json(DATA/f'locales/{locale}.json')['messages']
        for entry in data['props'] + data['loot_items']:
            if entry['name_key'] not in messages:
                raise ValueError('Missing room prop translation: ' + entry['name_key'])
