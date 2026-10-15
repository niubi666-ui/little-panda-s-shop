extends RefCounted
## 元素与反应定义（data/builds/elements.json）。由 BuildLoader.load_catalog 调用，结果挂到 BuildCatalog 上。
## 只校验与解码，不含战斗逻辑。字段含义见 elements.json 的 _comment 与 docs/TECH.md。
const Reader = preload("res://content/common/schema_reader.gd")

## 元素强化卡（element_boost）允许修改的字段
const BOOSTABLE := ["max_stacks", "duration_sec", "damage_per_tick_per_stack", "discharge_damage", "discharge_radius_m", "discharge_max_targets", "damage_taken_per_stack", "poise_damage_ratio"]

var errors: PackedStringArray = []

## statuses：BuildCatalog 已校验的状态表（id → 定义），用来检查元素引用的减速/冻结状态
func load_elements(manifest: Dictionary, statuses: Dictionary) -> Dictionary:
	errors.clear()
	if not manifest.has("build_elements_file") or not manifest.build_elements_file is String:
		errors.append("manifest: missing build_elements_file")
		return {}
	var path: String = manifest.build_elements_file
	if not path.begins_with("res://data/builds/") or not path.ends_with(".json") or path.contains(".."):
		errors.append("manifest: invalid build_elements_file")
		return {}
	var reader := Reader.new()
	var data: Variant = reader.read_json(path)
	var schema: Variant = reader.read_json("res://data/schemas/build_elements.schema.json")
	if reader.errors.is_empty(): reader.check(data, schema, path)
	if not reader.errors.is_empty():
		errors = reader.errors
		return {}
	var elements: Dictionary = {}
	for element in data.elements:
		var where: String = path + ": element " + element.id
		if elements.has(element.id): errors.append(where + " duplicated")
		elements[element.id] = element
		if (element.tick_sec > 0.0) != (element.damage_per_tick_per_stack > 0.0): errors.append(where + " tick_sec and damage_per_tick_per_stack must both be set or both 0")
		if (element.discharge_damage > 0.0) != (element.discharge_radius_m > 0.0 and element.discharge_max_targets > 0): errors.append(where + " discharge fields must all be set or all 0")
		if element.freeze_status_id != "" and element.max_stacks < 2: errors.append(where + " freezing at max stacks needs max_stacks >= 2")
		for key in ["slow_status_id", "freeze_status_id"]:
			var id: String = element[key]
			if id.is_empty(): continue
			var kind := "slow" if key == "slow_status_id" else "freeze"
			if not statuses.has(id) or statuses[id].kind != kind: errors.append(where + "." + key + " must name a " + kind + " status")
	var pairs: Dictionary = {}
	var reactions: Array = []
	for reaction in data.reactions:
		var where: String = path + ": reaction " + reaction.id
		var a: String = reaction.elements[0]
		var b: String = reaction.elements[1]
		if a == b or not elements.has(a) or not elements.has(b): errors.append(where + " needs two different known elements")
		var key := pair_key(a, b)
		if pairs.has(key): errors.append(where + " duplicates the reaction for " + key)
		pairs[key] = reaction
		reactions.append(reaction)
		var area: bool = reaction.radius_m > 0.0
		if area != (reaction.max_targets > 0): errors.append(where + " radius_m and max_targets must both be set or both 0")
		if (reaction.area_damage > 0.0 or reaction.knockback_mps != 0.0 or reaction.vulnerability > 0.0 or reaction.slow_status_id != "") and not area: errors.append(where + " area effects need radius_m")
		if (reaction.knockback_mps != 0.0) != (reaction.knockback_sec > 0.0): errors.append(where + " knockback speed and duration must both be set or both 0")
		if (reaction.vulnerability > 0.0) != (reaction.vulnerability_sec > 0.0): errors.append(where + " vulnerability and vulnerability_sec must both be set or both 0")
		var zone_fields: Array = [reaction.zone_radius_m, reaction.zone_sec, reaction.zone_tick_sec, reaction.zone_damage_per_tick]
		if zone_fields.any(func(v): return v > 0.0) and not zone_fields.all(func(v): return v > 0.0): errors.append(where + " zone fields must all be set or all 0")
		if reaction.slow_status_id != "" and (not statuses.has(reaction.slow_status_id) or statuses[reaction.slow_status_id].kind != "slow"): errors.append(where + ".slow_status_id must name a slow status")
	if not errors.is_empty(): return {}
	return {"max_zones": int(data.max_zones), "elements": elements, "reactions": reactions, "pairs": pairs, "order": data.elements.map(func(e): return e.id)}

static func pair_key(a: String, b: String) -> String:
	return a + "+" + b if a < b else b + "+" + a
