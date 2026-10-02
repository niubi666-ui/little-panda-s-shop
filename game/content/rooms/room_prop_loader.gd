extends RefCounted
const Reader = preload("res://content/common/schema_reader.gd")
const Catalog = preload("res://content/rooms/room_prop_catalog.gd")
var errors: PackedStringArray = []
func load_catalog() -> Catalog:
	var reader := Reader.new()
	var manifest = reader.read_json("res://data/manifest.json")
	if not manifest is Dictionary or not manifest.has("room_props_file"):
		errors.append("Manifest missing room_props_file")
		return null
	var path = manifest.room_props_file
	if not path is String or not path.begins_with("res://data/rooms/") or not path.ends_with(".json"):
		errors.append("Invalid room prop content path")
		return null
	var data = reader.read_json(path)
	var schema = reader.read_json("res://data/schemas/room_props.schema.json")
	if reader.errors.is_empty(): reader.check(data, schema, path)
	errors = reader.errors
	if not errors.is_empty(): return null
	var ids: Dictionary = {}
	var composition_ids: Dictionary = {}
	for id in data.composition_ids:
		if composition_ids.has(id): errors.append("Duplicate composition ID")
		composition_ids[id] = true
	var items: Dictionary = {}
	for item in data.loot_items:
		if items.has(item.id): errors.append("Duplicate loot item: " + item.id)
		items[item.id] = true
	for entry in data.props:
		if ids.has(entry.id): errors.append("Duplicate prop: " + entry.id)
		ids[entry.id] = true
		if (entry.kind == "destructible") != (entry.health > 0): errors.append("Invalid health: " + entry.id)
		if (entry.kind == "searchable") != (not entry.loot.is_empty()): errors.append("Invalid loot: " + entry.id)
		for reward in entry.loot:
			if not items.has(reward.item_id) or reward.count_min > reward.count_max: errors.append("Invalid reward: " + entry.id)
	for group in data.groups:
		if group.count_min > group.count_max or group.count_max > group.choices.size(): errors.append("Invalid unique composition count")
		for id in group.choices:
			if not data.composition_ids.has(id): errors.append("Unknown composition: " + id)
	if not errors.is_empty(): return null
	return Catalog.new(data)
