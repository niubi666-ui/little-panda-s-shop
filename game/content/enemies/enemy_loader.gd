extends RefCounted
const Reader = preload("res://content/combat/combat_loader.gd")
const Catalog = preload("res://content/enemies/enemy_catalog.gd")
var errors: PackedStringArray = []
func load_catalog(combat) -> Catalog:
	errors.clear()
	var reader := Reader.new()
	var manifest = reader._read("res://data/manifest.json")
	if not manifest is Dictionary:
		errors.append("manifest missing or invalid")
		return null
	var loaded: Array = []
	for pair in [["enemy_roles_file", "enemy_roles"], ["encounters_file", "encounters"], ["enemy_loot_file", "enemy_loot"]]:
		if not manifest.has(pair[0]):
			errors.append("manifest missing " + pair[0])
			return null
		var data = reader._read(manifest[pair[0]])
		var schema = reader._read("res://data/schemas/" + pair[1] + ".schema.json")
		if not reader.errors.is_empty():
			errors = reader.errors
			return null
		reader._check(data, schema, manifest[pair[0]])
		loaded.append(data)
	if not reader.errors.is_empty():
		errors = reader.errors
		return null
	var role_schema = reader._read("res://data/schemas/enemy_roles.schema.json")
	var roles: Dictionary = loaded[0]
	var enc: Dictionary = loaded[1]
	var loot: Dictionary = loaded[2]
	var ids: Dictionary = {}
	var table_ids: Dictionary = {}
	var props = reader._read(manifest.room_props_file)
	if not props is Dictionary or not props.has("loot_items"):
		errors.append("room props loot item catalog missing")
		return null
	var items: Array = props.loot_items.map(func(i): return i.id)
	for table in loot.tables:
		if table_ids.has(table.id): errors.append("duplicate loot table " + table.id)
		table_ids[table.id] = true
		for entry in table.entries:
			if not items.has(entry.item_id) or entry.count_min > entry.count_max: errors.append("invalid enemy loot " + table.id)
	for p in roles.profiles:
		reader._check(p.config, role_schema["$defs"][p.role], "enemy " + p.actor_id + ".config")
		if ids.has(p.actor_id) or not combat.has_actor(p.actor_id) or p.actor_id == combat.player().id: errors.append("invalid enemy actor " + p.actor_id)
		if not table_ids.has(p.loot_table_id): errors.append("missing enemy loot table " + p.actor_id)
		ids[p.actor_id] = p
	if not reader.errors.is_empty(): errors.append_array(reader.errors)
	if not errors.is_empty(): return null
	for p in roles.profiles:
		var c: Dictionary = p.config
		if (p.role == "melee") != (not combat.actor(p.actor_id).attacks.is_empty()): errors.append("actor/role attack mismatch " + p.actor_id)
		for key in c:
			if c[key] is bool: continue
			if c[key] <= 0.0: errors.append(p.actor_id + "." + key + " must be positive")
		match p.role:
			"ranged":
				if not (c.safe_min_m < c.safe_max_m and c.safe_max_m <= c.fire_range_m and c.windup_sec + c.recovery_sec < c.shot_interval_sec and c.minimum_windup_sec <= c.windup_sec): errors.append("ranged distance/timing order")
			"charger":
				if c.minimum_range_m >= c.trigger_range_m or c.minimum_windup_sec > c.windup_sec or c.cooldown_sec < c.windup_sec + c.charge_distance_m / c.charge_speed_mps + c.recovery_sec: errors.append("charge distance/timing order")
			"support":
				if c.retreat_range_m >= c.safe_max_m: errors.append("support distances")
			"ranger":
				if c.charged_range_m>c.fire_range_m or c.charged_rift_interval_sec>=c.charged_rift_duration_sec or c.charged_range_m/c.charged_speed_mps>=c.charged_rift_interval_sec: errors.append("ranger charged range/rift timing")
				if c.roll_min_distance_m > c.roll_distance_m: errors.append("ranger roll distance order")
				if not (c.safe_min_m < c.safe_max_m and c.safe_max_m <= c.fire_range_m and c.roll_trigger_m < c.safe_min_m and c.rain_min_range_m < c.fire_range_m): errors.append("ranger distances")
				if c.rain_delay_sec <= c.rain_windup_sec or c.volley_count < 2 or c.volley_angle_deg >= 180.0 or c.roll_cooldown_sec <= c.roll_duration_sec: errors.append("ranger attack/roll timing")
				for id in ["fast", "volley", "rain", "charged"]:
					if c[id + "_cooldown_sec"] < c[id + "_windup_sec"] + c[id + "_recovery_sec"]: errors.append("ranger cooldown " + id)
				for id in ["fast", "volley", "charged"]:
					if c[id + "_lock_sec"] > c[id + "_windup_sec"]: errors.append("ranger aim lock " + id)
				if c.rain_sequence_count > c.rain_max_areas or c.rain_escape_margin_sec >= c.rain_delay_sec: errors.append("ranger rain capacity/escape timing")
				var rain_length: float = c.rain_sequence_count * c.rain_windup_sec + (c.rain_sequence_count - 1) * c.rain_gap_sec
				var burst_length: float = c.burst_fast_count * (c.fast_windup_sec + c.burst_gap_sec) + c.charged_windup_sec
				if c.rain_cooldown_sec < rain_length + c.rain_recovery_sec or c.burst_cooldown_sec < burst_length + c.burst_recovery_sec or c.combo_cooldown_sec < rain_length + c.rain_gap_sec + c.charged_windup_sec + c.combo_recovery_sec: errors.append("ranger sequence cooldown")
				if c.charged_speed_mps <= c.fast_speed_mps or c.charged_damage <= c.fast_damage or c.charged_recovery_sec <= c.fast_recovery_sec or c.burst_recovery_sec < c.charged_recovery_sec or c.combo_recovery_sec < c.charged_recovery_sec: errors.append("ranger charged contrast/recovery")
	var combination_ids: Dictionary = {}
	for combination in enc.combinations:
		if combination_ids.has(combination.id): errors.append("duplicate encounter " + combination.id)
		combination_ids[combination.id] = true
		var counts: Dictionary = {}
		for id in combination.enemy_ids:
			if not ids.has(id):
				errors.append("unknown encounter enemy " + id)
				continue
			var role: String = ids[id].role
			counts[role] = counts.get(role, 0) + 1
		for role in enc.role_caps:
			if counts.get(role, 0) > enc.role_caps[role]: errors.append("encounter exceeds role cap " + combination.id)
		for rule in enc.escort_rules:
			if not role_schema["$defs"].has(rule.role): errors.append("unknown escort role " + rule.role)
			if not ids.has(rule.requires_actor_id): errors.append("unknown escort actor " + rule.requires_actor_id)
			if counts.has(rule.role) and not combination.enemy_ids.has(rule.requires_actor_id): errors.append("missing required escort " + combination.id)
		if counts.get("support", 0) == combination.enemy_ids.size(): errors.append("support-only encounter " + combination.id)
	var previous_depth := 0
	var previous_budget := 0
	for band in enc.depth_bands:
		if band.min_depth <= previous_depth or band.budget < previous_budget: errors.append("depth bands must ascend")
		previous_depth = band.min_depth
		previous_budget = band.budget
		var eligible := false
		for team in enc.combinations:
			var cost := 0
			for id in team.enemy_ids:
				if ids.has(id): cost += int(ids[id].budget_cost)
			if cost <= band.budget and cost >= band.budget * enc.minimum_budget_fraction and team.enemy_ids.size() <= band.max_enemies: eligible = true
		if not eligible: errors.append("depth band has no legal encounter")
	if enc.depth_bands[0].min_depth != 1 or enc.training_depth > enc.training_max_depth: errors.append("invalid training depth")
	_validate_training_tools(enc)
	if not errors.is_empty(): return null
	return Catalog.new(roles, enc, loot)

func _validate_training_tools(enc: Dictionary) -> void:
	# Called only after schema validation. Never replace invalid training config with defaults.
	var config: Dictionary = enc.training_tools
	if config.spawn_step_m > config.spawn_search_radius_m:
		errors.append("encounters.training_tools.spawn_step_m must not exceed spawn_search_radius_m")
	if config.spawn_search_radius_m / config.spawn_step_m > 8.0:
		errors.append("encounters.training_tools search radius/step must not exceed 8")
	for band in enc.depth_bands:
		if config.max_alive_enemies < band.max_enemies:
			errors.append("encounters.training_tools.max_alive_enemies must cover every depth_bands.max_enemies")
			break
