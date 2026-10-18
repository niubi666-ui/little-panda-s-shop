extends RefCounted
var errors: PackedStringArray = []
func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append(path + ": file missing")
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append(path + ": " + parser.get_error_message())
		return null
	return parser.data
func check(value: Variant, schema: Dictionary, path: String) -> void:
	if schema.has("enum") and not schema.enum.has(value):
		errors.append(path + ": unsupported enum value")
	if schema.has("const") and value != schema.const:
		errors.append(path + ": unsupported constant")
	if not schema.has("type"): return
	if schema.type is Array:
		if schema.type != ["number", "null"]:
			errors.append(path + ": unsupported schema type union")
			return
		if value == null and schema.type.has("null"): return
		var concrete := schema.duplicate()
		concrete.type = "number"
		check(value, concrete, path)
		return
	match schema.type:
		"object":
			if not value is Dictionary:
				errors.append(path + ": expected object")
				return
			for key in schema.required:
				if not value.has(key): errors.append(path + "." + key + ": required")
			for key in value:
				if not schema.properties.has(key): errors.append(path + "." + key + ": unknown field")
				else: check(value[key], schema.properties[key], path + "." + key)
		"array":
			if not value is Array:
				errors.append(path + ": expected array")
				return
			if value.size() < schema.minItems: errors.append(path + ": too few entries")
			if schema.has("maxItems") and value.size() > schema.maxItems: errors.append(path + ": too many entries")
			if schema.get("uniqueItems", false):
				var seen: Array = []
				for item in value:
					if seen.has(item): errors.append(path + ": duplicate entry")
					seen.append(item)
			for i in value.size(): check(value[i], schema.items, path + "[%s]" % i)
		"number", "integer":
			if not (value is float or value is int) or not is_finite(float(value)):
				errors.append(path + ": expected finite number")
				return
			if value < schema.minimum or value > schema.maximum: errors.append(path + ": out of range")
			if schema.type == "integer" and value != floor(value): errors.append(path + ": expected integer")
		"string":
			# 默认要求非空；schema 显式写 "minLength": 0 时允许空字符串（表示“不使用”）
			if not value is String or (value.is_empty() and int(schema.get("minLength", 1)) > 0): errors.append(path + ": expected nonempty string")
		"boolean":
			if not value is bool: errors.append(path + ": expected boolean")
		_:
			errors.append(path + ": unsupported schema keyword/type")
