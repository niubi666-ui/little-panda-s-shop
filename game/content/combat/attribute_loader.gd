extends RefCounted
const Reader = preload("res://content/common/schema_reader.gd")
const Catalog = preload("res://content/combat/attribute_catalog.gd")
var errors: PackedStringArray = []
func load_catalog() -> Catalog:
	var reader := Reader.new()
	var manifest = reader.read_json("res://data/manifest.json")
	if not manifest is Dictionary or not manifest.has("combat_attributes_file"):
		errors.append("manifest: missing combat_attributes_file")
		return null
	var data = reader.read_json(manifest.combat_attributes_file)
	var schema = reader.read_json("res://data/schemas/combat_attributes.schema.json")
	if not reader.errors.is_empty():
		errors = reader.errors
		return null
	return decode(data, schema)
func decode(value: Variant, schema: Dictionary) -> Catalog:
	errors.clear()
	var reader := Reader.new()
	reader.check(value, schema, "attributes")
	errors = reader.errors
	if not errors.is_empty(): return null
	for id in value.actors:
		for stat in value.stat_keys:
			var number: float = value.actors[id][stat]
			var bounds: Dictionary = value.stat_bounds[stat]
			if number < bounds.min or (bounds.max != null and number > bounds.max): errors.append(id + "." + stat + ": outside stat bounds")
	if not errors.is_empty(): return null
	return Catalog.new(value)
