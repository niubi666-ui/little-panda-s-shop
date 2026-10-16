extends RefCounted
## RNG and reward weighting only. Combat's evaluator owns all legality.
const Catalog = preload("res://content/builds/build_catalog.gd")
var _catalog: Catalog
var _operations: Callable
var _rewards: Dictionary = {}
## 本次抽取里每张卡的相关度倍率（只在 card 模式下有值）
var _scales: Dictionary = {}

func configure(catalog: Catalog, operations: Callable, rewards: Dictionary = {}) -> void:
	assert(catalog != null and operations.is_valid())
	_catalog = catalog
	_operations = operations
	_rewards = rewards

## filter（可选）：
## - {"mode": "awakening", "count", "guarantee_same", "guarantee_new"}：元素觉醒，只出“元素 × 空按键”，永不替换
## - {"mode": "card", "owned_element_scale", "elemental_action_scale", "max_per_action"}：平时三选一，全卡池按相关度加权，不含元素核心、不含升级
## - {"operation": "rank"}：只出升级已有卡；{"element": 元素 ID}：只出与该元素相关的卡（训练用）
func sample(state: Dictionary, rng: RandomNumberGenerator, profile_id: String = "training_all", filter: Dictionary = {}) -> Array[Dictionary]:
	assert(_catalog != null and rng != null)
	if String(filter.get("mode", "")) == "awakening": return _sample_awakening(state, rng, filter)
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

## 元素关联从真实元素/状态定义取得；普通武技不伪造元素归属。
func upgrade_elements(entry: Dictionary) -> Array:
	match String(entry.effect_type):
		"element", "element_boost", "element_mastery": return [entry.ranks[0].element_id]
		"reaction_boost":
			if not _catalog.has_elements(): return []
			for element_id in _catalog.element_order():
				for other in _catalog.element_order():
					var reaction: Dictionary = _catalog.reaction_between(element_id, other)
					if not reaction.is_empty() and reaction.id == entry.ranks[0].reaction_id: return reaction.elements
	var result: Array = []
	if not _catalog.has_elements(): return result
	for element_id in _catalog.element_order():
		var freeze_id: String = _catalog.element(element_id).freeze_status_id
		if freeze_id.is_empty(): continue
		if entry.effect_type in ["projectile_path", "freeze_shield"] or (entry.effect_type in ["conditional_damage", "consume_freeze"] and entry.ranks[0].status_id == freeze_id):
			result.append(element_id)
	return result

## 每个按键当前带的元素（动作 ID → 元素 ID）
func action_elements(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for selected in state.selections:
		var entry: Dictionary = _catalog.upgrade(selected.upgrade_id)
		if entry.effect_type == "element": result[selected.action_id] = entry.ranks[int(selected.rank) - 1].element_id
	return result

## 元素觉醒：候选 = 所有元素核心在“还没有元素的按键”上的新增操作；尽量元素、按键都不重复。
## guarantee_same / guarantee_new：已有元素时，至少一个与已有元素相同、至少一个是新元素（能满足才满足）。
func _sample_awakening(state: Dictionary, rng: RandomNumberGenerator, filter: Dictionary) -> Array[Dictionary]:
	var owned: Array = action_elements(state).values()
	var pool: Array = []
	for entry in _catalog.entries():
		if entry.effect_type != "element" or float(entry.weight) <= 0.0: continue
		for option in _operations.call(state, entry.id):
			if option.operation == "add" and option.replaced.is_empty():
				pool.append({"option": option, "element": entry.ranks[0].element_id})
	pool.sort_custom(func(a, b): return "%s|%s" % [a.option.upgrade_id, a.option.action_id] < "%s|%s" % [b.option.upgrade_id, b.option.action_id])
	for index in range(pool.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held = pool[index]
		pool[index] = pool[other]
		pool[other] = held
	var picked: Array = []
	var take := func(test: Callable) -> void:
		for candidate in pool:
			if picked.size() >= int(filter.count) or picked.has(candidate): continue
			if test.call(candidate):
				picked.append(candidate)
				return
	if not owned.is_empty():
		if filter.guarantee_same: take.call(func(c): return owned.has(c.element))
		if filter.guarantee_new: take.call(func(c): return not owned.has(c.element))
	while picked.size() < int(filter.count):
		var before := picked.size()
		var elements: Array = picked.map(func(c): return c.element)
		var actions: Array = picked.map(func(c): return c.option.action_id)
		take.call(func(c): return not elements.has(c.element) and not actions.has(c.option.action_id))
		if picked.size() == before: take.call(func(c): return not elements.has(c.element))
		if picked.size() == before: take.call(func(c): return true)
		if picked.size() == before: break
	var result: Array[Dictionary] = []
	for candidate in picked:
		var option: Dictionary = candidate.option.duplicate(true)
		option.rarity_id = "awakening"
		result.append(option)
	return result

## 平时三选一的相关度：和已有元素相关的卡、挂在带元素按键上的卡权重更高
func _relevance(id: String, options: Array, elements: Dictionary, filter: Dictionary) -> float:
	var entry: Dictionary = _catalog.upgrade(id)
	if upgrade_elements(entry).any(func(id): return elements.values().has(id)) or not str(entry.required_element).is_empty():
		return float(filter.owned_element_scale)
	if options.any(func(option): return elements.has(option.action_id)): return float(filter.elemental_action_scale)
	return 1.0

func _passes(id: String, options: Array, filter: Dictionary) -> Array:
	if String(filter.get("mode", "")) == "card":
		if _catalog.upgrade(id).effect_type == "element": return []
		return options.filter(func(option): return option.operation == "add")
	if filter.has("element") and not upgrade_elements(_catalog.upgrade(id)).has(filter.element): return []
	if filter.has("operation"): return options.filter(func(option): return option.operation == filter.operation)
	return options

func _sample_profile(state: Dictionary, rng: RandomNumberGenerator, profile_id: String, filter: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _rewards.reward_profiles.has(profile_id): return result
	var profile: Dictionary = _rewards.reward_profiles[profile_id]
	var buckets: Dictionary = {}
	var bindings: Dictionary = {}
	var card_mode := String(filter.get("mode", "")) == "card"
	var elements := action_elements(state) if card_mode else {}
	_scales.clear()
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
			if card_mode: _scales[id] = _relevance(id, options, elements, filter)
	var per_action: Dictionary = {}
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
		buckets[chosen].erase(id)
		if buckets[chosen].is_empty(): buckets.erase(chosen)
		var choices: Array = bindings[id]
		if card_mode:
			# 同一次三选一里同一个按键最多 max_per_action 张
			choices = choices.filter(func(option): return option.action_id == "global" or int(per_action.get(option.action_id, 0)) < int(filter.max_per_action))
			if choices.is_empty(): continue
		var option := _pick_binding(choices, rng)
		per_action[option.action_id] = int(per_action.get(option.action_id, 0)) + 1
		option.rarity_id = chosen
		result.append(option)
	_scales.clear()
	return result

func is_eligible(id: String, state: Dictionary) -> bool:
	return not _operations.call(state, id).is_empty()

## 键可能带着“|动作”后缀（per_binding 模式），权重按卡本身算
func _weight(key: String) -> float:
	return float(_catalog.upgrade(key.get_slice("|", 0)).weight) * float(_scales.get(key, 1.0))

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
