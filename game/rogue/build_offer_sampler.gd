extends RefCounted
## RNG and reward weighting only. Combat's evaluator owns all legality.
const Catalog = preload("res://content/builds/build_catalog.gd")
var _catalog: Catalog
var _operations: Callable
var _rewards: Dictionary = {}

func configure(catalog: Catalog, operations: Callable, rewards: Dictionary = {}) -> void:
	assert(catalog != null and operations.is_valid())
	_catalog = catalog
	_operations = operations
	_rewards = rewards

## filter（可选）：{"element": 元素 ID} 只出与该元素相关的卡；{"operation": "rank"} 只出升级已有卡的选项
func sample(state: Dictionary, rng: RandomNumberGenerator, profile_id: String = "training_all", filter: Dictionary = {}) -> Array[Dictionary]:
	assert(_catalog != null and rng != null)
	if not _rewards.is_empty(): return _sample_profile(state, rng, profile_id, filter)
	var rules: Dictionary = _catalog.offer_rules()
	assert(rules.target_weighting == "uniform", "Unknown authored binding weighting")
	var bindings: Dictionary = {}
	var eligible: Array[String] = []
	var candidates: Array[Dictionary] = []
	var selected: Dictionary = {}
	for id in rules.pool_ids:
		var options: Array = _operations.call(state, str(id))
		if not options.is_empty() and float(_catalog.upgrade(id).weight) > 0.0:
			bindings[id] = options
			eligible.append(id)
	# Select upgrade identity first: two legal action bindings never double its
	# pool weight, and can never consume two cards in the same offer.
	while candidates.size() < int(rules.count) and not eligible.is_empty():
		var index := _weighted_index(eligible, rng)
		var id: String = eligible[index]
		candidates.append(_pick_binding(bindings[id], rng))
		selected[id] = true
		eligible.remove_at(index)
	for id in rules.fallback_ids:
		if candidates.size() >= int(rules.count): break
		if selected.has(id): continue
		var options: Array = _operations.call(state, str(id))
		if options.is_empty(): continue
		candidates.append(_pick_binding(options, rng))
		selected[id] = true
	return candidates

## 一张卡涉及的元素：元素核心/元素强化看 element_id，反应强化看反应的两种元素；其他卡不属于任何元素
func upgrade_elements(entry: Dictionary) -> Array:
	match String(entry.effect_type):
		"element", "element_boost": return [entry.ranks[0].element_id]
		"reaction_boost":
			if not _catalog.has_elements(): return []
			for element_id in _catalog.element_order():
				for other in _catalog.element_order():
					var reaction: Dictionary = _catalog.reaction_between(element_id, other)
					if not reaction.is_empty() and reaction.id == entry.ranks[0].reaction_id: return reaction.elements
	return []

func _passes(id: String, options: Array, filter: Dictionary) -> Array:
	if filter.has("element") and not upgrade_elements(_catalog.upgrade(id)).has(filter.element): return []
	if filter.has("operation"): return options.filter(func(option): return option.operation == filter.operation)
	return options

func _sample_profile(state: Dictionary, rng: RandomNumberGenerator, profile_id: String, filter: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _rewards.reward_profiles.has(profile_id): return result
	var profile: Dictionary = _rewards.reward_profiles[profile_id]
	var buckets: Dictionary = {}
	var bindings: Dictionary = {}
	for id in _rewards.upgrade_groups:
		var rarity: String = _rewards.upgrade_groups[id]
		if not profile.rarity_weights.has(rarity) or float(_catalog.upgrade(id).weight) <= 0.0: continue
		var options: Array = _passes(id, _operations.call(state, id), filter)
		if options.is_empty(): continue
		if not buckets.has(rarity): buckets[rarity] = []
		if filter.get("per_binding", false):
			# 元素祝福：同一张卡挂在不同按键上算不同选项（火普攻 / 火重击 / 火剑气）
			for option in options:
				var key := "%s|%s" % [id, option.action_id]
				bindings[key] = [option]
				buckets[rarity].append(key)
		else:
			bindings[id] = options
			buckets[rarity].append(id)
	while result.size() < int(profile.count) and not buckets.is_empty():
		var rarities: Array = buckets.keys(); rarities.sort()
		var total := 0.0
		for rarity in rarities: total += float(profile.rarity_weights[rarity])
		var roll := rng.randf() * total
		var chosen: String = rarities.back()
		for rarity in rarities:
			roll -= float(profile.rarity_weights[rarity])
			if roll < 0.0: chosen = rarity; break
		var ids: Array[String] = []; ids.assign(buckets[chosen]); ids.sort()
		var id: String = ids[_weighted_index(ids, rng)]
		var option := _pick_binding(bindings[id], rng)
		option.rarity_id = chosen
		result.append(option)
		buckets[chosen].erase(id)
		if buckets[chosen].is_empty(): buckets.erase(chosen)
	return result

func is_eligible(id: String, state: Dictionary) -> bool:
	return not _operations.call(state, id).is_empty()

## 键可能带着“|动作”后缀（per_binding 模式），权重按卡本身算
func _weight(key: String) -> float:
	return float(_catalog.upgrade(key.get_slice("|", 0)).weight)

func _pick_binding(options: Array, rng: RandomNumberGenerator) -> Dictionary:
	return options[rng.randi_range(0, options.size() - 1)].duplicate(true)

func _weighted_index(ids: Array[String], rng: RandomNumberGenerator) -> int:
	var scale := 0.0
	for id in ids: scale = maxf(scale, _weight(id))
	var total := 0.0
	for id in ids: total += _weight(id) / scale
	var remaining := rng.randf() * total
	for index in ids.size():
		remaining -= _weight(ids[index]) / scale
		if remaining < 0.0: return index
	return ids.size() - 1
