extends RefCounted
const Catalog = preload("res://content/combat/combat_catalog.gd")
var errors: PackedStringArray = []
func load_catalog(manifest_path: String = "res://data/manifest.json") -> Catalog:
	errors.clear()
	var manifest = _read(manifest_path)
	if not manifest is Dictionary or not manifest.has("combat_prototype_file"):
		errors.append(manifest_path + ": missing combat_prototype_file")
		return null
	var path = manifest.combat_prototype_file
	if not path is String or not path.begins_with("res://data/combat/") or not path.ends_with(".json"):
		errors.append(manifest_path + ": invalid combat content path")
		return null
	var data = _read(path)
	var schema = _read("res://data/schemas/combat_prototype.schema.json")
	if not errors.is_empty(): return null
	return decode(data, schema, path)
func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append(path + ": file missing")
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append(path + ": " + parser.get_error_message())
		return null
	return parser.data
func decode(data: Variant, schema: Dictionary, path: String) -> Catalog:
	_check(data, schema, path)
	if not errors.is_empty(): return null
	var abilities: Dictionary = {}
	var actors: Dictionary = {}
	for entry in data.abilities:
		if abilities.has(entry.id): errors.append(path + ": duplicate ability " + entry.id)
		abilities[entry.id] = entry
		if entry.hit_shape == "sector" and (entry.angle_deg <= 0.0 or entry.thrust_width_m != 0.0):
			errors.append(path + ": " + entry.id + " sector requires positive angle and zero thrust width")
		if entry.hit_shape == "thrust" and (entry.angle_deg != 0.0 or entry.thrust_width_m <= 0.0):
			errors.append(path + ": " + entry.id + " thrust requires zero angle and positive width")
		if (entry.knockback_speed_mps == 0.0) != (entry.knockback_duration_sec == 0.0):
			errors.append(path + ": " + entry.id + " knockback speed/duration must both be zero or positive")
	for entry in data.actors:
		if actors.has(entry.id): errors.append(path + ": duplicate actor " + entry.id)
		actors[entry.id] = entry
		for id in entry.attack_ids:
			if not abilities.has(id): errors.append(path + ": " + entry.id + " missing attack " + id)
	if not actors.has(data.player_id): errors.append(path + ": unknown player_id")
	for wave in data.waves:
		for id in wave:
			if not actors.has(id) or id == data.player_id: errors.append(path + ": invalid enemy " + id)
	if data.dodge.invulnerable_sec > data.dodge.duration_sec:
		errors.append(path + ": dodge.invulnerable_sec exceeds duration_sec")
	if not errors.is_empty(): return null
	return Catalog.new(data)
## Deliberately implements only the schema keywords used by this slice; build-time
## validation uses full Draft202012 with strict duplicate-key JSON parsing.
func _check(value: Variant, schema: Dictionary, path: String) -> void:
	if schema.has("enum") and not schema.enum.has(value):
		errors.append(path + ": unsupported enum value")
	if schema.has("const") and value != schema.const:
		errors.append(path + ": unsupported constant")
	if not schema.has("type"): return
	match schema.type:
		"object":
			if not value is Dictionary:
				errors.append(path + ": expected object")
				return
			for key in schema.required:
				if not value.has(key): errors.append(path + "." + key + ": required")
			for key in value:
				if not schema.properties.has(key): errors.append(path + "." + key + ": unknown field")
				else: _check(value[key], schema.properties[key], path + "." + key)
		"array":
			if not value is Array:
				errors.append(path + ": expected array")
				return
			if value.size() < schema.minItems: errors.append(path + ": too few entries")
			for i in value.size(): _check(value[i], schema.items, path + "[%s]" % i)
		"number", "integer":
			if not (value is float or value is int) or not is_finite(float(value)):
				errors.append(path + ": expected finite number")
				return
			if value < schema.minimum or value > schema.maximum: errors.append(path + ": out of range")
			if schema.type == "integer" and value != floor(value): errors.append(path + ": expected integer")
		"string":
			if not value is String or value.is_empty(): errors.append(path + ": expected nonempty string")
		"boolean":
			if not value is bool: errors.append(path + ": expected boolean")
		_:
			errors.append(path + ": unsupported schema keyword/type")
