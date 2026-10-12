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

func sample(state: Dictionary, rng: RandomNumberGenerator, profile_id: String = "training_all") -> Array[Dictionary]:
	assert(_catalog != null and rng != null)
	if not _rewards.is_empty(): return _sample_profile(state, rng, profile_id)
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

func _sample_profile(state: Dictionary, rng: RandomNumberGenerator, profile_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _rewards.reward_profiles.has(profile_id): return result
	var profile: Dictionary = _rewards.reward_profiles[profile_id]
	var buckets: Dictionary = {}
	var bindings: Dictionary = {}
	for id in _rewards.upgrade_groups:
		var rarity: String = _rewards.upgrade_groups[id]
		if not profile.rarity_weights.has(rarity) or float(_catalog.upgrade(id).weight) <= 0.0: continue
		var options: Array = _operations.call(state, id)
		if options.is_empty(): continue
		bindings[id] = options
		if not buckets.has(rarity): buckets[rarity] = []
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

func _pick_binding(options: Array, rng: RandomNumberGenerator) -> Dictionary:
	return options[rng.randi_range(0, options.size() - 1)].duplicate(true)

func _weighted_index(ids: Array[String], rng: RandomNumberGenerator) -> int:
	var scale := 0.0
	for id in ids: scale = maxf(scale, float(_catalog.upgrade(id).weight))
	var total := 0.0
	for id in ids: total += float(_catalog.upgrade(id).weight) / scale
	var remaining := rng.randf() * total
	for index in ids.size():
		remaining -= float(_catalog.upgrade(ids[index]).weight) / scale
		if remaining < 0.0: return index
	return ids.size() - 1
