extends RefCounted
## Ephemeral layout authority. No inventory, money, file writes, or scene references.
const Catalog = preload("res://content/decorating/decorating_catalog.gd")
const Rules = preload("res://shop/decorating/layout_rules.gd")
var _catalog: Catalog
var _rules: Rules
var _layout: Array[Dictionary] = []
var _revision := 0
var _sequence := 0
func _init(catalog: Catalog) -> void: _catalog = catalog
func set_rules(rules: Rules) -> void: _rules = rules
func revision() -> int: return _revision
func snapshot() -> Array[Dictionary]: return _layout.duplicate(true)
func find(id: String) -> Dictionary:
	for entry in _layout:
		if entry.instance_id == id: return entry.duplicate(true)
	return {}
func next_id() -> String: return "shop.decorating.%s" % (_sequence + 1)
func preview(candidate: Dictionary, moving: bool) -> Dictionary:
	if _rules == null or not candidate.has("definition_id"): return {"ok":false, "code":"invalid"}
	if not candidate.definition_id is String or not _catalog.has_id(candidate.definition_id): return {"ok":false, "code":"invalid"}
	for field in ["instance_id", "cell", "quarter_turn"]:
		if not candidate.has(field): return {"ok":false, "code":"invalid"}
	if not candidate.instance_id is String: return {"ok":false, "code":"invalid"}
	if moving:
		var previous := find(candidate.instance_id)
		if previous.is_empty() or previous.definition_id != candidate.definition_id: return {"ok":false, "code":"invalid"}
	elif candidate.instance_id != next_id(): return {"ok":false, "code":"invalid"}
	if not moving and _layout.size() >= _catalog.maximum_instances(): return {"ok":false, "code":"limit"}
	var footprint := _catalog.furniture(candidate.definition_id).footprint
	return _rules.evaluate(_layout, candidate, footprint, candidate.instance_id if moving else "")
func apply(candidate: Dictionary, moving: bool, expected_revision: int) -> Dictionary:
	if expected_revision != _revision: return {"ok":false, "code":"stale"}
	var result := preview(candidate, moving)
	if not result.ok: return result
	# Publish a complete isolated candidate, never mutate the live array in place.
	var updated: Array[Dictionary] = []
	for entry in _layout:
		if not moving or entry.instance_id != candidate.instance_id: updated.append(entry.duplicate(true))
	var placed := candidate.duplicate(true)
	placed.footprint = _catalog.furniture(candidate.definition_id).footprint
	updated.append(placed)
	_layout = updated
	_revision += 1
	if not moving: _sequence += 1
	return {"ok":true, "code":"applied"}
func remove(id: String, expected_revision: int) -> Dictionary:
	if expected_revision != _revision: return {"ok":false, "code":"stale"}
	if find(id).is_empty(): return {"ok":false, "code":"invalid"}
	var updated: Array[Dictionary] = []
	for entry in _layout:
		if entry.instance_id != id: updated.append(entry.duplicate(true))
	_layout = updated
	_revision += 1
	return {"ok":true, "code":"removed"}
