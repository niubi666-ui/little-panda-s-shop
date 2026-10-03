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
        if p['role']=='ranger':
            if c['roll_min_distance_m']>c['roll_distance_m']:raise ValueError('ranger roll distance order')
            if not(c['safe_min_m']<c['safe_max_m']<=c['fire_range_m'] and c['roll_trigger_m']<c['safe_min_m'] and c['rain_min_range_m']<c['fire_range_m']):raise ValueError('ranger distances')
            if c['rain_delay_sec']<=c['rain_windup_sec'] or c['volley_count']<2 or c['volley_angle_deg']>=180 or c['roll_cooldown_sec']<=c['roll_duration_sec']:raise ValueError('ranger attack/roll timing')
            for ability in ['fast','volley','rain']:
                if c[ability+'_cooldown_sec']<c[ability+'_windup_sec']+c[ability+'_recovery_sec']:raise ValueError('ranger cooldown')
            for ability in ['fast','volley']:
                if c[ability+'_lock_sec']>c[ability+'_windup_sec']:raise ValueError('ranger aim lock')
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
    validate_training_tools(enc)


def validate_training_tools(enc):
    """Business constraints after the encounter schema has accepted all required fields."""
    config = enc['training_tools']
    if config['spawn_step_m'] > config['spawn_search_radius_m']:
        raise ValueError('encounters.training_tools.spawn_step_m must not exceed spawn_search_radius_m')
    if config['spawn_search_radius_m'] / config['spawn_step_m'] > 8:
        raise ValueError('encounters.training_tools search radius/step must not exceed 8')
    if any(config['max_alive_enemies'] < band['max_enemies'] for band in enc['depth_bands']):
        raise ValueError('encounters.training_tools.max_alive_enemies must cover every depth_bands.max_enemies')
