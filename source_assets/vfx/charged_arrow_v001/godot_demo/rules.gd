extends RefCounted
## Standalone demonstration only. The main game's combat/AI is never loaded.
## Continuous relative sweeps prevent an ultra-fast projectile tunnelling through a target.
signal released
signal damaged(kind: String, amount: float, timestamp: float)
var config: Dictionary
var clock := 0.0
var fire_time := -1.0
var locked := false
var mode := "stand"
var origin := Vector3.ZERO
var direction := Vector3.RIGHT
var target := Vector3.ZERO
var health := 0.0
var dodge_until := 0.0
var dodge_ready := 0.0
var dodge_direction := Vector3.ZERO
var dodge_started := false
var arrow_hit := false
var arrow_count := 0
var scar_count := 0
var pulse_index := 0
var last_damage_time := -1.0
var events: Array[Dictionary] = []
var muzzle_offset := Vector3.ZERO
const SIMULATION_STEP := 1.0 / 240.0
const TIME_EPSILON := 0.000001

static func load_config(path: String) -> Dictionary:
	assert(FileAccess.file_exists(path), "Missing demo data: " + path)
	var parser := JSON.new()
	assert(parser.parse(FileAccess.get_file_as_string(path)) == OK, "Invalid demo JSON: " + path)
	var data: Dictionary = parser.data
	assert(data.keys().size() == 4 and data.version == 1)
	var required := {
		"skill": ["charge_sec", "lock_sec", "speed_mps", "range_m", "arrow_radius_m", "arrow_damage", "trail_half_width_m", "trail_duration_sec", "trail_tick_sec", "trail_damage"],
		"target": ["health", "radius_m", "walk_mps", "dodge_mps", "dodge_sec", "dodge_cooldown_sec", "dodge_lead_sec", "test_walk_distance_m", "trail_entry_delay_sec", "trail_entry_distance_m"]
	}
	for section in required:
		assert(data[section].size() == required[section].size(), "Unknown field in " + section)
		for field in required[section]:
			assert(data[section].has(field), "Missing demo data: " + section + "." + field)
			var value: float = data[section][field]
			assert(is_finite(value) and value > 0.0, "Invalid demo number: " + section + "." + field)
	assert(data.stage.size() == 3)
	for field in ["ranger_position", "target_position"]:
		assert(data.stage.has(field) and data.stage[field].size() == 3)
		for value in data.stage[field]: assert(is_finite(float(value)))
	assert(data.stage.movement_bounds.size() == 4)
	assert(data.skill.lock_sec < data.skill.charge_sec)
	assert(data.target.dodge_lead_sec < data.skill.lock_sec)
	assert(data.target.dodge_sec > data.target.dodge_lead_sec)
	assert(data.skill.range_m / data.skill.speed_mps < data.skill.trail_tick_sec)
	for section in data.values():
		if section is Dictionary:
			for item in section.values():
				if item is Array: item.make_read_only()
			section.make_read_only()
	data.make_read_only()
	return data

func configure(value: Dictionary, offset: Vector3) -> void:
	config = value
	muzzle_offset = offset
	reset("stand")

func vec(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func reset(value: String) -> void:
	assert(value in ["stand", "walk", "dodge", "trail", "manual"])
	mode = value
	clock = 0.0
	fire_time = -1.0
	locked = false
	var base: Vector3 = vec(config.stage.ranger_position)
	origin = base + muzzle_offset
	target = vec(config.stage.target_position)
	direction = (target - base).normalized()
	if mode == "trail": target.z += config.target.trail_entry_distance_m
	health = config.target.health
	dodge_until = 0.0
	dodge_ready = 0.0
	dodge_started = false
	dodge_direction = Vector3.ZERO
	arrow_hit = false
	arrow_count = 0
	scar_count = 0
	pulse_index = 0
	last_damage_time = -1.0
	events.clear()

func dodge(axis: Vector3) -> bool:
	if clock < dodge_ready or health <= 0.0: return false
	dodge_direction = axis.normalized() if axis.length_squared() > 0.0 else Vector3.FORWARD
	dodge_until = clock + config.target.dodge_sec
	dodge_ready = clock + config.target.dodge_cooldown_sec
	dodge_started = true
	return true

func invulnerable() -> bool:
	return clock < dodge_until

func travelled() -> float:
	if fire_time < 0.0: return 0.0
	return clampf((clock-fire_time)*config.skill.speed_mps,0.0,config.skill.range_m)

func scar_active() -> bool:
	return fire_time >= 0.0 and clock < fire_time + config.skill.trail_duration_sec

func in_scar(point: Vector3) -> bool:
	var start := Vector2(origin.x, origin.z)
	var end := start + Vector2(direction.x, direction.z) * travelled()
	return Geometry2D.get_closest_point_to_segment(Vector2(point.x, point.z), start, end).distance_to(Vector2(point.x, point.z)) <= config.skill.trail_half_width_m + config.target.radius_m

func _damage(kind: String, amount: float, timestamp: float) -> void:
	if invulnerable() or health <= 0.0: return
	health = maxf(0.0, health - amount)
	if kind == "arrow": arrow_count += 1
	else: scar_count += 1
	last_damage_time = timestamp
	events.append({"kind":kind, "damage":amount, "time":timestamp, "health":health})
	damaged.emit(kind, amount, timestamp)

func step(delta: float, manual_axis: Vector3 = Vector3.ZERO) -> void:
	assert(delta >= 0.0)
	var left := delta
	while left > 0.000001:
		var dt := minf(left, SIMULATION_STEP)
		_substep(dt, manual_axis)
		left -= dt

func _substep(dt: float, manual_axis: Vector3) -> void:
	var previous_clock := clock
	var previous_target := target
	clock += dt
	if mode == "dodge" and not dodge_started and clock >= config.skill.charge_sec - config.target.dodge_lead_sec:
		dodge(Vector3.FORWARD)
	var axis := Vector3.ZERO
	if mode == "manual": axis = manual_axis
	elif mode == "walk" and clock >= config.skill.charge_sec:
		if absf(target.z - config.stage.target_position[2]) < config.target.test_walk_distance_m: axis = Vector3.FORWARD
	elif mode == "trail" and clock >= config.skill.charge_sec + config.target.trail_entry_delay_sec:
		var gap: float = config.stage.target_position[2] - target.z
		if absf(gap) > config.target.walk_mps * dt: axis = Vector3(0, 0, signf(gap))
		else: target.z = config.stage.target_position[2]
	if clock < dodge_until:
		target += dodge_direction * config.target.dodge_mps * dt
	elif axis.length_squared() > 0.0:
		target += axis.normalized() * config.target.walk_mps * dt
	var bounds: Array = config.stage.movement_bounds
	target.x = clampf(target.x, bounds[0], bounds[2])
	target.z = clampf(target.z, bounds[1], bounds[3])
	if fire_time < 0.0:
		if not locked:
			var aim_point := vec(config.stage.target_position) if mode == "trail" else target
			var base := vec(config.stage.ranger_position)
			var aim := aim_point - base
			aim.y = 0.0
			if aim.length_squared() > 0.0: direction = aim.normalized()
			origin = base + Vector3.UP * muzzle_offset.y + direction * muzzle_offset.z
			locked = clock + TIME_EPSILON >= config.skill.charge_sec - config.skill.lock_sec
		if clock + TIME_EPSILON >= config.skill.charge_sec:
			fire_time = config.skill.charge_sec
			events.append({"kind":"release", "time":fire_time})
			released.emit()
	if fire_time >= 0.0:
		var age := clock - fire_time
		var previous_distance := clampf((previous_clock - fire_time) * config.skill.speed_mps, 0.0, config.skill.range_m)
		if not arrow_hit and previous_distance < config.skill.range_m:
			var p := Vector2(origin.x, origin.z) + Vector2(direction.x, direction.z) * previous_distance - Vector2(previous_target.x, previous_target.z)
			var q := Vector2(origin.x, origin.z) + Vector2(direction.x, direction.z) * travelled() - Vector2(target.x, target.z)
			var closest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, p, q)
			if closest.length() <= config.skill.arrow_radius_m + config.target.radius_m:
				arrow_hit = true
				_damage("arrow", config.skill.arrow_damage, clock)
		while (pulse_index + 1) * config.skill.trail_tick_sec <= minf(age, config.skill.trail_duration_sec - 0.000001):
			pulse_index += 1
			var timestamp: float = fire_time + pulse_index * config.skill.trail_tick_sec
			if in_scar(target): _damage("scar", config.skill.trail_damage, timestamp)
