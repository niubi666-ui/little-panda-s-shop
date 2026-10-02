extends RefCounted
const Catalog = preload("res://content/decorating/decorating_catalog.gd")
var errors: PackedStringArray = []
func load_catalog(path: String) -> Catalog:
	errors.clear()
	if not FileAccess.file_exists(path):
		errors.append(path + ": file missing")
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append(path + ": " + parser.get_error_message())
		return null
	var schema = JSON.parse_string(FileAccess.get_file_as_string("res://data/schemas/decorating.schema.json"))
	if not schema is Dictionary:
		errors.append(path + ": schema unavailable")
		return null
	_check(parser.data, schema, path)
	if not errors.is_empty(): return null
	var ids: Dictionary = {}
	for entry in parser.data.furniture:
		if ids.has(entry.id): errors.append(path + ": duplicate ID " + entry.id)
		ids[entry.id] = true
	if not errors.is_empty(): return null
	return Catalog.new(parser.data)
## Runtime subset exactly matches this module's schema; full strict JSON validation
## (including duplicate keys) runs in build_decorating_content.py.
func _check(value: Variant, schema: Dictionary, path: String) -> void:
	if schema.has("const") and value != schema.const: errors.append(path + ": wrong version")
	if not schema.has("type"): return
	match schema.type:
		"object":
			if not value is Dictionary:
				errors.append(path + ": expected object")
				return
			for field in schema.required:
				if not value.has(field): errors.append(path + "." + field + ": required")
			for field in value:
				if not schema.properties.has(field): errors.append(path + "." + field + ": unknown")
				else: _check(value[field], schema.properties[field], path + "." + field)
		"array":
			if not value is Array:
				errors.append(path + ": expected array")
				return
			if value.size() < schema.minItems or (schema.has("maxItems") and value.size() > schema.maxItems): errors.append(path + ": invalid length")
			for i in value.size(): _check(value[i], schema.items, path + "[%s]" % i)
		"number", "integer":
			if not (value is int or value is float) or not is_finite(float(value)):
				errors.append(path + ": expected finite number")
				return
			if value < schema.minimum or value > schema.maximum: errors.append(path + ": out of range")
			if schema.type == "integer" and value != floor(value): errors.append(path + ": expected integer")
		"string":
			if not value is String or value.is_empty(): errors.append(path + ": expected nonempty string")
