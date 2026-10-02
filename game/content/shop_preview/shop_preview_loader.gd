class_name ShopPreviewLoader
extends RefCounted
## Narrow slice manifest/registry loader; grows only when new content is implemented.

const Definition = preload("res://content/shop_preview/shop_preview_definition.gd")
const Registry = preload("res://content/shop_preview/shop_preview_registry.gd")
const FoliageDefinition = preload("res://content/shop_preview/foliage_preview_definition.gd")
const SCHEMA_VERSION: int = 1

var _errors: PackedStringArray = []
var _source: String


func load_registry(manifest_path: String) -> Registry:
	var manifest: Variant = _read_json(manifest_path)
	if not _errors.is_empty():
		return null
	if not _object(manifest, ["content_schema_version", "content_version", "shop_preview_file", "foliage_preview_file", "combat_prototype_file", "build_prototype_file", "room_props_file", "enemy_roles_file", "encounters_file", "enemy_loot_file"], "$"):
		return null
	if manifest["content_schema_version"] is bool or not (manifest["content_schema_version"] is float or manifest["content_schema_version"] is int) or manifest["content_schema_version"] != SCHEMA_VERSION:
		_fail("content_schema_version", "unsupported manifest schema version")
	if not manifest["content_version"] is String or str(manifest["content_version"]).is_empty():
		_fail("content_version", "expected a nonempty version string")
	var path_pattern := RegEx.create_from_string("^res://data/shop/[a-z0-9_]+\\.json$")
	if not manifest["shop_preview_file"] is String or path_pattern.search(str(manifest["shop_preview_file"])) == null:
		_fail("shop_preview_file", "expected JSON file under res://data/shop/")
	if not manifest["foliage_preview_file"] is String or path_pattern.search(str(manifest["foliage_preview_file"])) == null:
		_fail("foliage_preview_file", "expected JSON file under res://data/shop/")
	if not _errors.is_empty():
		return null
	var definition := load_definition(manifest["shop_preview_file"])
	if definition == null:
		return null
	var foliage_data: Variant = _read_json(manifest["foliage_preview_file"])
	if not _errors.is_empty() or not _object(foliage_data, ["schema_version", "inventory", "orders", "decoration"], "$"):
		return null
	if foliage_data.schema_version is bool or foliage_data.schema_version != SCHEMA_VERSION:
		_fail("schema_version", "unsupported foliage preview version")
	for section: String in ["inventory", "orders", "decoration"]:
		if not foliage_data[section] is Array or foliage_data[section].is_empty():
			_fail(section, "expected nonempty sample catalog")
			continue
		var ids: Dictionary = {}
		for entry: Variant in foliage_data[section]:
			if not _object(entry, ["id", "category", "name_key", "description_key", "icon"], section):
				continue
			var strings_valid := true
			for field: String in entry:
				if not entry[field] is String or entry[field].is_empty():
					_fail(section + "." + field, "expected nonempty string")
					strings_valid = false
			if not strings_valid:
				continue
			if ids.has(entry.id):
				_fail(section, "duplicate sample ID")
			ids[entry.id] = true
			if entry.category not in ["potions", "equipment", "materials", "furniture", "ornaments", "lights", "orders"]:
				_fail(section, "unknown category")
			if not entry.icon.begins_with("res://assets/ui/foliage/") or not entry.icon.ends_with(".svg") or not ResourceLoader.exists(entry.icon):
				_fail(section, "sample icon missing or outside foliage assets")
	if not _errors.is_empty():
		return null
	return Registry.new(manifest["content_version"], definition, FoliageDefinition.new(foliage_data))


func load_definition(path: String) -> Definition:
	var data: Variant = _read_json(path)
	if not _errors.is_empty():
		return null
	return decode(data, path)


func _read_json(path: String) -> Variant:
	_errors.clear()
	_source = path
	if not FileAccess.file_exists(path):
		_fail("$", "file is missing")
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("$", "cannot open file: %s" % error_string(FileAccess.get_open_error()))
		return null
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK:
		_fail("$", "line %s: %s" % [parser.get_error_line(), parser.get_error_message()])
		return null
	return parser.data


func decode(value: Variant, source: String) -> Definition:
	_errors.clear()
	_source = source
	if not _object(value, ["schema_version", "id", "movement", "interaction", "localization", "decorating_file"], "$"):
		return null
	var data: Dictionary = value
	if not data.decorating_file is String or RegEx.create_from_string("^res://data/shop/decorating/[a-z0-9_]+\\.json$").search(str(data.decorating_file)) == null:
		_fail("decorating_file", "expected decoration catalog under res://data/shop/decorating/")
	if data["schema_version"] is bool or not (data["schema_version"] is float or data["schema_version"] is int) or data["schema_version"] != SCHEMA_VERSION:
		_fail("schema_version", "expected version %s" % SCHEMA_VERSION)
	if not data["id"] is String or data["id"] != "preview.shop_interior":
		_fail("id", "expected preview.shop_interior")
	if _object(data["movement"], ["speed_mps", "turn_speed_radps", "gravity_mps2"], "movement"):
		for field: String in ["speed_mps", "turn_speed_radps", "gravity_mps2"]:
			_positive_number(data["movement"][field], "movement." + field)
	if _object(data["interaction"], ["distance_m"], "interaction"):
		_positive_number(data["interaction"]["distance_m"], "interaction.distance_m")
	if _object(data["localization"], ["default_locale"], "localization"):
		if not data["localization"]["default_locale"] is String or data["localization"]["default_locale"] not in ["zh_CN", "en"]:
			_fail("localization.default_locale", "expected zh_CN or en")
	if not _errors.is_empty():
		return null
	return Definition.new(data)


func get_errors() -> PackedStringArray:
	return _errors.duplicate()


func _object(value: Variant, required: Array, field: String) -> bool:
	if not value is Dictionary:
		_fail(field, "expected object")
		return false
	var valid := true
	for key: Variant in required:
		if not value.has(key):
			_fail(field + "." + str(key), "required field is missing")
			valid = false
	for key: Variant in value:
		if key not in required:
			_fail(field + "." + str(key), "unknown field")
			valid = false
	return valid


func _positive_number(value: Variant, field: String) -> void:
	if value is bool or not (value is float or value is int):
		_fail(field, "expected finite positive number")
	elif not is_finite(float(value)) or float(value) <= 0.0:
		_fail(field, "expected finite positive number")


func _fail(field: String, reason: String) -> void:
	_errors.append("%s [preview.shop_interior] %s: %s" % [_source, field, reason])
