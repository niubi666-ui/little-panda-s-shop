extends RefCounted
## 一局冒险（原型）的配置：data/run/forest_run.json。只校验与解码，不含流程逻辑。
const Reader = preload("res://content/common/schema_reader.gd")

var errors: PackedStringArray = []

## build_catalog：BuildCatalog（检查开局预设与元素）；reward_groups：品质分组；enemy_catalog：检查 Boss
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
	if reader.errors.is_empty(): reader.check(data, schema, path)
	if not reader.errors.is_empty():
		errors = reader.errors
		return {}
	if build_catalog.test_preset(data.start_preset).is_empty(): errors.append(path + ": unknown start_preset")
	for element in data.boon_elements:
		if not build_catalog.has_element(element): errors.append(path + ": unknown boon element " + element)
	for key in ["boon_profile", "upgrade_profile"]:
		if not reward_groups.reward_profiles.has(data[key]): errors.append(path + ": unknown " + key)
	if not enemy_catalog.profiles.has(data.boss_actor_id): errors.append(path + ": unknown boss_actor_id")
	if data.exit_count_min > data.exit_count_max: errors.append(path + ": exit_count_min exceeds exit_count_max")
	var kinds: Dictionary = {}
	var total := 0.0
	for reward in data.rewards:
		if kinds.has(reward.kind): errors.append(path + ": duplicate reward kind " + reward.kind)
		kinds[reward.kind] = true
		total += float(reward.weight)
	if total <= 0.0: errors.append(path + ": rewards need a positive total weight")
	if not errors.is_empty(): return {}
	var result: Dictionary = data.duplicate(true)
	result.make_read_only()
	return result
