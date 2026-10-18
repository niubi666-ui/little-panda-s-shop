"""One authoritative attribute table; complete finite damage policy coverage."""
from build_shop_preview_content import ROOT, DATA, read_json, validate

def validate_attributes(manifest):
    def load(key): return read_json(ROOT/'game'/manifest[key].removeprefix('res://'))
    a=load('combat_attributes_file')
    validate(a,read_json(DATA/'schemas/combat_attributes.schema.json'),'attributes')
    combat=load('combat_prototype_file'); builds=load('build_prototype_file'); roles=load('enemy_roles_file')
    if set(a['actors']) != {x['attribute_profile_id'] for x in combat['actors']}:
        raise ValueError('attributes: actor coverage differs')
    for actor,stats in a['actors'].items():
        for stat,value in stats.items():
            bound=a['stat_bounds'][stat]
            if value < bound['min'] or bound['max'] is not None and value > bound['max']: raise ValueError(f'attributes: {actor}.{stat} outside bounds')
    if {u['id'] for u in builds['upgrades']} != set(a['upgrade_policies']): raise ValueError('attributes: incomplete upgrade policy coverage')
    for entry in combat['abilities']:
        if a['bindings']['combat_ability'][entry['id']] != entry['damage_profile_id']: raise ValueError('attributes: ability profile binding differs')
    for role in roles['profiles']:
        for old,profile in a['bindings']['enemy_role_damage'].get(role['actor_id'],{}).items():
            if role['config'][old+'_profile_id'] != profile: raise ValueError('attributes: enemy profile binding differs')
    for attack in builds['test_attacks']:
        if attack['damage_profile_id'] != a['bindings']['test_attack'][attack['id']]: raise ValueError('attributes: test attack profile differs')
    for ability in combat['abilities']:
        profile=a['linear_profiles'][ability['damage_profile_id']]
        if profile['modifier_policy']=='enemy' and ability['damage_profile_id'] not in a['enemy_telegraph_minimum_sec']:
            raise ValueError('attributes: missing enemy timing policy')
    for policy in a['upgrade_policies'].values():
        if policy not in a['upgrade_policy_definitions']: raise ValueError('attributes: unknown upgrade policy')
    for profile in a['effect_profiles'].values():
        recipe=profile['amount_source']
        if recipe['catalog']=='upgrade_rank':
            fields=next(u['ranks'][0] for u in builds['upgrades'] if u['id']==recipe['id'])
        else:
            elements=load('build_elements_file')
            fields=next(x for x in elements[recipe['catalog']] if x['id']==recipe['id'])
        for key in ['base_field','per_stack_field']:
            if key in recipe and recipe[key] not in fields: raise ValueError('attributes: missing amount recipe field')
