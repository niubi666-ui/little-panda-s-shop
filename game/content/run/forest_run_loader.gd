extends RefCounted
## 一局冒险（原型）的配置：data/run/forest_run.json。只校验与解码，不含流程逻辑。
## map 字段与 M 键地图同一格式（data/schemas/map_preview.schema.json），用同一个 Loader 校验。
const Reader = preload("res://content/common/schema_reader.gd")
const MapLoader = preload("res://content/run/map_preview_loader.gd")

var errors: PackedStringArray = []

## build_catalog：BuildCatalog（检查开局预设）；reward_groups：品质分组；enemy_catalog：检查 Boss
func load_run(build_catalog, reward_groups: Dictionary, enemy_catalog, manifest_path := "res://data/manifest.json") -> Dictionary:
	errors.clear()
	var reader := Reader.new()
	var manifest: Variant = reader.read_json(manifest_path)
	if not manifest is Dictionary or not manifest.has("forest_run_file") or not manifest.forest_run_file is String:
		errors.append(manifest_path + ": missing forest_run_file")
		return {}
	var path: String = manifest.forest_run_file
	if not path.begins_with("res://data/run/") or not path.ends_with(".json") or path.contains(".."):
		errors.append(manifest_path + ": invalid forest_run_file")
		return {}
	var data: Variant = reader.read_json(path)
	var schema: Variant = reader.read_json("res://data/schemas/forest_run.schema.json")
	var map_schema: Variant = reader.read_json("res://data/schemas/map_preview.schema.json")
	if reader.errors.is_empty(): reader.check(data, schema, path)
	if not reader.errors.is_empty():
		errors = reader.errors
		return {}
	var map_loader := MapLoader.new()
	var map: Dictionary = map_loader.decode(data.map, map_schema, path + ".map")
	if map.is_empty():
		errors = map_loader.errors
		return {}
	if build_catalog.test_preset(data.start_preset).is_empty(): errors.append(path + ": unknown start_preset")
	for key in ["battle_profile", "elite_profile", "boss_profile", "upgrade_profile"]:
		if not reward_groups.reward_profiles.has(data[key]): errors.append(path + ": unknown " + key)
	for key in ["card_profile", "blood_card_profile"]:
		if not reward_groups.reward_profiles.has(data.event[key]): errors.append(path + ": unknown event." + key)
	if not reward_groups.reward_profiles.has(data.shop.card_profile): errors.append(path + ": unknown shop.card_profile")
	for area in data.areas:
		if not enemy_catalog.profiles.has(area.boss_actor_id): errors.append(path + ": unknown boss_actor_id " + area.boss_actor_id)
	if int(data.awakening_after_area) >= data.areas.size(): errors.append(path + ": awakening_after_area outside areas")
	var kinds: Dictionary = {}
	var total := 0.0
	for outcome in data.event.outcomes:
		if kinds.has(outcome.kind): errors.append(path + ": duplicate event outcome " + outcome.kind)
		kinds[outcome.kind] = true
		total += float(outcome.weight)
	if total <= 0.0: errors.append(path + ": event outcomes need a positive total weight")
	if not errors.is_empty(): return {}
	var result: Dictionary = data.duplicate(true)
	result.map = map
	result.make_read_only()
	return result
