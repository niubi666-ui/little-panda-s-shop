"""Validate the isolated map preview manifest, rules and bilingual PO sources."""
import argparse
from build_shop_preview_content import ROOT, DATA, read_json, validate, build_po, placeholders

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    manifest = read_json(DATA / 'run/map_preview_manifest.json')
    if set(manifest) != {'rules_file', 'schema_file'}:
        raise ValueError('invalid map preview manifest')
    for value in manifest.values():
        if not value.startswith('res://data/') or '..' in value or not value.endswith('.json'):
            raise ValueError('invalid content path')
    rules = read_json(ROOT / 'game' / manifest['rules_file'].removeprefix('res://'))
    schema = read_json(ROOT / 'game' / manifest['schema_file'].removeprefix('res://'))
    validate(rules, schema, 'map preview')
    kinds = {item['id']: item for item in rules['room_types']}
    if len(kinds) != 6 or len(rules['room_types']) != 6:
        raise ValueError('six unique room kinds required')
    for kind in kinds.values():
        if not 0 <= kind['min_layer'] <= kind['max_layer'] < rules['rows']:
            raise ValueError('invalid room layer range')
        if kind['name_key'] != 'map_preview.kind.' + kind['id']:
            raise ValueError('invalid room name key')
    fixed = {}
    for row in rules['fixed_layers']:
        kind = kinds[row['kind']]
        if row['layer'] in fixed or not kind['min_layer'] <= row['layer'] <= kind['max_layer']:
            raise ValueError('invalid fixed layer')
        fixed[row['layer']] = row['kind']
    for layer, kind in fixed.items():
        if fixed.get(layer + 1) == kind and kinds[kind]['avoid_consecutive']:
            raise ValueError('consecutive fixed special rooms')
    locales = {loc: read_json(DATA / f'locales/map_preview/{loc}.json') for loc in ('zh_CN', 'en')}
    for loc, data in locales.items():
        validate(data, read_json(DATA / 'schemas/shop_preview_locale.schema.json'), loc)
        if data['locale'] != loc: raise ValueError('locale mismatch')
    if locales['zh_CN']['messages'].keys() != locales['en']['messages'].keys():
        raise ValueError('locale keys differ')
    for key, text in locales['zh_CN']['messages'].items():
        if placeholders(text, key) != placeholders(locales['en']['messages'][key], key):
            raise ValueError('placeholder mismatch: ' + key)
    for kind in kinds.values():
        if kind['name_key'] not in locales['en']['messages']: raise ValueError('untranslated kind')
    for loc, data in locales.items():
        target = ROOT / f'game/generated/locales/map_preview/{loc}.po'
        expected = build_po(loc, data['messages'])
        if args.check:
            if not target.exists() or target.read_text(encoding='utf-8') != expected:
                raise ValueError('regenerate ' + str(target))
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(expected, encoding='utf-8')
    print(f'MAP_PREVIEW_CONTENT: six kinds, {len(locales["en"]["messages"])} bilingual keys validated')

if __name__ == '__main__': main()
