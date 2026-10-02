extends RefCounted
## Ephemeral training state, never writes the shop inventory or a real save.
const Catalog = preload("res://content/rooms/room_prop_catalog.gd")
var _plan: Dictionary
var _state: Dictionary = {"searched": {}, "destroyed": {}, "items": {}}
var _commit: Callable
var _committing := false
func configure(plan: Dictionary, commit: Callable) -> void:
	assert(commit.is_valid())
	_plan = Catalog.frozen(plan)
	_commit = commit
func snapshot() -> Dictionary: return Catalog.frozen(_state)
func _submit(candidate: Dictionary) -> bool:
	_committing = true
	var accepted: bool = _commit.call(candidate.duplicate(true))
	if accepted: _state = candidate
	_committing = false
	return accepted
func search(id: String) -> bool:
	if _committing or _state.searched.has(id): return false
	for entry in _plan.placements:
		if entry.id != id or entry.kind != "searchable": continue
		var candidate := _state.duplicate(true)
		candidate.searched[id] = true
		for reward in entry.loot:
			if not candidate.items.has(reward.item_id): candidate.items[reward.item_id] = 0
			candidate.items[reward.item_id] += reward.count
		return _submit(candidate)
	return false
func destroy(id: String) -> bool:
	if _committing or _state.destroyed.has(id): return false
	for entry in _plan.placements:
		if entry.id != id or entry.kind != "destructible": continue
		var candidate := _state.duplicate(true)
		candidate.destroyed[id] = true
		return _submit(candidate)
	return false
