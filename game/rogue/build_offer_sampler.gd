extends RefCounted
## Chooses candidates only; never mutates player ranks or commits rewards.

const Catalog = preload("res://content/builds/build_catalog.gd")
var _catalog: Catalog
var _compatible: Callable


func configure(catalog: Catalog, compatible: Callable) -> void:
	assert(catalog != null)
	_catalog = catalog
	assert(compatible.is_valid(), "Combat compatibility policy must be injected")
	_compatible = compatible


func sample(ranks: Dictionary, tags: Array, rng: RandomNumberGenerator) -> Array[String]:
	assert(_catalog != null and rng != null)
	var candidates: Array[String] = []
	var eligible: Array[String] = []
	var rules: Dictionary = _catalog.offer_rules()
	for id in rules.pool_ids:
		if is_eligible(id, ranks, tags) and float(_catalog.upgrade(id).weight) > 0.0:
			eligible.append(id)
	while candidates.size() < int(rules.count) and not eligible.is_empty():
		var index := _weighted_index(eligible, rng)
		candidates.append(eligible[index])
		eligible.remove_at(index)
	# Explicit fallback ordering remains deterministic. A zero-weight fallback is
	# allowed here: weight controls the random pool, not the authored fallback list.
	for id in rules.fallback_ids:
		if candidates.size() >= int(rules.count):
			break
		if not candidates.has(id) and is_eligible(id, ranks, tags):
			candidates.append(id)
	return candidates


func is_eligible(id: String, ranks: Dictionary, tags: Array) -> bool:
	if not _catalog.has_upgrade(id):
		return false
	var entry: Dictionary = _catalog.upgrade(id)
	if _rank(ranks, id) >= int(entry.max_rank):
		return false
	for required in entry.requires:
		if _rank(ranks, required) < 1:
			return false
	for excluded in entry.excludes:
		if _rank(ranks, excluded) > 0:
			return false
	for tag in entry.required_tags:
		if not tags.has(tag):
			return false
	return _compatible.call(entry, ranks)


func _weighted_index(ids: Array[String], rng: RandomNumberGenerator) -> int:
	var scale := 0.0
	for id in ids:
		scale = maxf(scale, float(_catalog.upgrade(id).weight))
	var total := 0.0
	for id in ids:
		total += float(_catalog.upgrade(id).weight) / scale
	var remaining := rng.randf() * total
	for index in ids.size():
		remaining -= float(_catalog.upgrade(ids[index]).weight) / scale
		if remaining < 0.0:
			return index
	return ids.size() - 1


func _rank(ranks: Dictionary, id: String) -> int:
	return int(ranks[id]) if ranks.has(id) else 0
