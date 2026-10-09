extends RefCounted
## Validate isolated preview content before exposing deeply read-only definitions.
const StrictJSON = preload("res://content/run/strict_json.gd")
const Schema = preload("res://content/common/schema_reader.gd")
const Definition = preload("res://content/run/run_definition.gd")
const KINDS = ["battle", "elite", "event", "rest", "treasure", "shop"]
var errors: PackedStringArray = []

func load_rules(manifest_path: String) -> Dictionary:
	errors.clear()
	var manifest: Variant = _read(manifest_path)
	if not errors.is_empty(): return {}
	if not manifest is Dictionary or manifest.keys().size() != 2 or not manifest.has("rules_file") or not manifest.has("schema_file"):
		errors.append(manifest_path + ": expected rules_file/schema_file")
		return {}
	for key in manifest:
		if not manifest[key] is String or not manifest[key].begins_with("res://data/") or manifest[key].contains("..") or not manifest[key].ends_with(".json"):
			errors.append(manifest_path + "." + key + ": invalid content path")
	if not errors.is_empty(): return {}
	var data: Variant = _read(manifest.rules_file)
	var schema: Variant = _read(manifest.schema_file)
	if not errors.is_empty(): return {}
	if not schema is Dictionary:
		errors.append(manifest.schema_file + ": schema must be an object")
		return {}
	return decode(data, schema, manifest.rules_file)

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append(path + ": file missing")
		return null
	var parser := StrictJSON.new()
	var value: Variant = parser.parse(FileAccess.get_file_as_string(path), path)
	errors.append_array(parser.errors)
	return value

func decode(data: Variant, schema: Dictionary, path: String = "map_preview") -> Dictionary:
	errors.clear()
	var reader := Schema.new()
	reader.check(data, schema, path)
	errors.append_array(reader.errors)
	if not errors.is_empty(): return {}
	var kinds: Dictionary = {}
	for item in data.room_types:
		if item.id not in KINDS or kinds.has(item.id): errors.append(path + ".room_types: unknown/duplicate " + item.id)
		kinds[item.id] = item
		if item.min_layer > item.max_layer or item.max_layer >= data.rows: errors.append(path + ".room_types." + item.id + ": invalid layers")
		if item.name_key != "map_preview.kind." + item.id: errors.append(path + ".room_types." + item.id + ": invalid name_key")
	if kinds.size() != KINDS.size(): errors.append(path + ".room_types: all six types required")
	var fixed: Dictionary = {}
	for row in data.fixed_layers:
		if row.layer >= data.rows or fixed.has(row.layer) or not kinds.has(row.kind):
			errors.append(path + ".fixed_layers: invalid/duplicate layer or kind")
			continue
		fixed[row.layer] = row.kind
		if row.layer < kinds[row.kind].min_layer or row.layer > kinds[row.kind].max_layer: errors.append(path + ".fixed_layers: kind outside permitted layers")
	for layer in fixed:
		if fixed.has(layer + 1) and fixed[layer] == fixed[layer + 1] and kinds[fixed[layer]].avoid_consecutive: errors.append(path + ".fixed_layers: prohibited consecutive type")
	return Definition.freeze_copy(data) if errors.is_empty() else {}
