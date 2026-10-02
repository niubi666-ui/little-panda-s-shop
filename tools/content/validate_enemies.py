"""Enemy roles, authored encounter teams, depth bands and deferred loot contracts."""
from build_shop_preview_content import ROOT, DATA, read_json, validate

def validate_enemies(manifest):
    def load(key):return read_json(ROOT/'game'/manifest[key].removeprefix('res://'))
    roles,enc,loot=load('enemy_roles_file'),load('encounters_file'),load('enemy_loot_file')
    rs=read_json(DATA/'schemas/enemy_roles.schema.json')
    for data,schema in [(roles,rs),(enc,read_json(DATA/'schemas/encounters.schema.json')),(loot,read_json(DATA/'schemas/enemy_loot.schema.json'))]:validate(data,schema,'enemies')
    actors={a['id']:a for a in load('combat_prototype_file')['actors']}
    props=load('room_props_file');items={e['id'] for e in props['loot_items']}
    tables={t['id']:t for t in loot['tables']};profiles={p['actor_id']:p for p in roles['profiles']}
    if len(tables)!=len(loot['tables']) or len(profiles)!=len(roles['profiles']):raise ValueError('duplicate enemy/loot IDs')
    for table in tables.values():
        for e in table['entries']:
            if e['item_id'] not in items or e['count_min']>e['count_max']:raise ValueError('invalid enemy loot entry')
    for p in profiles.values():
        validate(p['config'],rs['$defs'][p['role']],p['actor_id'])
        if p['actor_id'] not in actors or p['actor_id']==load('combat_prototype_file')['player_id'] or p['loot_table_id'] not in tables:raise ValueError('invalid enemy references')
        if (p['role']=='melee')!=bool(actors[p['actor_id']]['attack_ids']):raise ValueError('role/attack mismatch')
        c=p['config']
        if any(v<=0 for v in c.values()):raise ValueError('enemy behavior parameters must be positive')
        if p['role']=='ranged' and not(c['safe_min_m']<c['safe_max_m']<=c['fire_range_m'] and c['windup_sec']+c['recovery_sec']<c['shot_interval_sec'] and c['minimum_windup_sec']<=c['windup_sec']):raise ValueError('ranged ordering')
        if p['role']=='charger' and not(c['minimum_range_m']<c['trigger_range_m'] and c['minimum_windup_sec']<=c['windup_sec'] and c['cooldown_sec']>=c['windup_sec']+c['charge_distance_m']/c['charge_speed_mps']+c['recovery_sec']):raise ValueError('charge ordering')
        if p['role']=='support' and c['retreat_range_m']>=c['safe_max_m']:raise ValueError('support distances')
    seen=set();costs=[]
    for team in enc['combinations']:
        ids=team['enemy_ids']
        if team['id'] in seen or any(i not in profiles for i in ids):raise ValueError('encounter ID/reference')
        seen.add(team['id']);counts={role:sum(profiles[i]['role']==role for i in ids) for role in rs['$defs']}
        if any(counts[r]>cap for r,cap in enc['role_caps'].items()):raise ValueError('role cap')
        for rule in enc['escort_rules']:
            if rule['requires_actor_id'] not in profiles or counts[rule['role']] and rule['requires_actor_id'] not in ids:raise ValueError('required escort')
        if counts['support']==len(ids):raise ValueError('support-only team')
        for lang in ['zh_CN','en']:
            if team['name_key'] not in read_json(DATA/f'locales/{lang}.json')['messages']:raise ValueError('encounter translation')
        costs.append((sum(profiles[i]['budget_cost'] for i in ids),len(ids)))
    previous_depth=0;previous_budget=0
    for band in enc['depth_bands']:
        if band['min_depth']<=previous_depth or band['budget']<previous_budget:raise ValueError('depth/budget must ascend')
        previous_depth,previous_budget=band['min_depth'],band['budget']
        if not any(band['budget']*enc['minimum_budget_fraction']<=cost<=band['budget'] and count<=band['max_enemies'] for cost,count in costs):raise ValueError('empty legal encounter band')
    if enc['depth_bands'][0]['min_depth']!=1 or enc['training_depth']>enc['training_max_depth']:raise ValueError('training depth')
