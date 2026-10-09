extends RefCounted
## Memory-only run authority. Room loading is staged outside published state.
## Only commit_enter advances room_count; Build remains fixed for this route slice.
var _route: Dictionary = {}
var _nodes: Dictionary = {}
var _successors: Dictionary = {}
var _state: Dictionary = {}
var _pending_ticket: Dictionary = {}
var _plan_builder: Callable
var _commit: Callable
var _busy := false
var _epoch := 0
var _ticket_sequence := 0

func configure(route: Dictionary, seed: int, hp: float, build_state: Dictionary, program: Dictionary, plan_builder: Callable, commit: Callable) -> bool:
	if _busy or not plan_builder.is_valid() or not commit.is_valid(): return false
	if not is_finite(hp) or hp <= 0.0 or not _valid_route_shape(route) or not _valid_build_snapshot(build_state, program): return false
	var nodes: Dictionary = {}
	var successors: Dictionary = {}
	for node in route.nodes:
		nodes[node.id] = node.duplicate(true)
		successors[node.id] = []
	for edge in route.edges: successors[edge.from].append(str(edge.to))
	_epoch += 1
	_route = _freeze_copy(route)
	_nodes = _freeze_copy(nodes)
	_successors = _freeze_copy(successors)
	_plan_builder = plan_builder
	_commit = commit
	_state = _freeze_copy({
		"run_id": "%s:%s:%s" % [seed, get_instance_id(), _epoch], "revision": 0,
		"phase": "map", "seed": str(seed), "current_node_id": "", "room_count": 0,
		"active_entry_id": "", "active_room_plan": {}, "visited_node_ids": [],
		"cleared_node_ids": [], "hp": hp, "build_state": build_state, "build_program": program,
	})
	_pending_ticket = {}
	return true

func snapshot() -> Dictionary: return _freeze_copy(_state)

func map_snapshot() -> Dictionary:
	if _state.is_empty(): return {}
	var available := _available_node_ids()
	var nodes: Array = []
	for definition in _route.nodes:
		var node_state := "locked"
		if definition.id == _state.current_node_id: node_state = "current"
		elif _state.cleared_node_ids.has(definition.id): node_state = "completed"
		elif available.has(definition.id): node_state = "available"
		nodes.append({"id": definition.id, "layer": definition.layer, "column": definition.column,
			"kind": definition.kind, "state": node_state})
	return _freeze_copy({"nodes": nodes, "edges": _route.edges,
		"current_node_id": _state.current_node_id, "room_count": _state.room_count,
		"phase": _state.phase, "available_node_ids": available})

func prepare_enter(node_id: String) -> Dictionary:
	var guard := _guard()
	if not guard.is_empty(): return guard
	if _state.phase != "map": return _result(false, "run.error.wrong_phase")
	if not _available_node_ids().has(node_id): return _result(false, "run.error.invalid_node")
	if not _pending_ticket.is_empty() and _pending_ticket.node_id == node_id and _pending_ticket.base_revision == _state.revision:
		return _prepared_result(_pending_ticket)
	_busy = true
	# A detached input and retained return value cannot mutate route/state later.
	var planned: Variant = _plan_builder.call(_nodes[node_id].duplicate(true), int(_state.seed))
	_busy = false
	if not planned is Dictionary or not _valid_plan(planned, _nodes[node_id]): return _result(false, "run.error.plan_failed")
	_ticket_sequence += 1
	_pending_ticket = _freeze_copy({
		"id": "%s:entry:%s" % [_state.run_id, _ticket_sequence],
		"run_id": _state.run_id, "base_revision": _state.revision, "node_id": node_id,
		"room_ordinal": int(_state.room_count) + 1, "plan": planned,
	})
	return _prepared_result(_pending_ticket)

func commit_enter(ticket_id: String) -> Dictionary:
	var guard := _guard()
	if not guard.is_empty(): return guard
	if ticket_id == _state.active_entry_id and not ticket_id.is_empty():
		return _result(_state.phase != "defeated", "run.error.run_over" if _state.phase == "defeated" else "")
	if _pending_ticket.is_empty() or _pending_ticket.id != ticket_id: return _result(false, "run.error.stale_ticket")
	if _state.phase != "map" or _pending_ticket.run_id != _state.run_id or _pending_ticket.base_revision != _state.revision:
		return _result(false, "run.error.stale_ticket")
	if not _available_node_ids().has(_pending_ticket.node_id): return _result(false, "run.error.invalid_node")
	var candidate: Dictionary = _state.duplicate(true)
	candidate.revision += 1
	candidate.phase = "combat"
	candidate.current_node_id = _pending_ticket.node_id
	candidate.room_count = _pending_ticket.room_ordinal
	candidate.active_entry_id = ticket_id
	candidate.active_room_plan = _pending_ticket.plan.duplicate(true)
	candidate.visited_node_ids.append(candidate.current_node_id)
	if not _submit(candidate): return _result(false, "run.error.commit_failed")
	_pending_ticket = {}
	return _result(true, "", true)

func cancel_enter(ticket_id: String) -> Dictionary:
	var guard := _guard()
	if not guard.is_empty(): return guard
	if _pending_ticket.is_empty() or _pending_ticket.id != ticket_id: return _result(false, "run.error.stale_ticket")
	_pending_ticket = {}
	return _result(true)

func complete_room(entry_id: String, hp: float) -> Dictionary:
	var guard := _guard()
	if not guard.is_empty(): return guard
	if entry_id.is_empty() or entry_id != _state.active_entry_id: return _result(false, "run.error.stale_entry")
	if not is_finite(hp) or hp < 0.0: return _result(false, "run.error.invalid_health")
	if hp == 0.0: return defeat(entry_id)
	if _state.phase == "defeated": return _result(false, "run.error.run_over")
	if _state.cleared_node_ids.has(_state.current_node_id): return _result(true)
	if _state.phase != "combat": return _result(false, "run.error.wrong_phase")
	var candidate: Dictionary = _state.duplicate(true)
	candidate.revision += 1
	candidate.hp = hp
	candidate.cleared_node_ids.append(candidate.current_node_id)
	candidate.phase = "completed" if _nodes[candidate.current_node_id].kind == "terminal" else "cleared"
	if not _submit(candidate): return _result(false, "run.error.commit_failed")
	return _result(true, "", true)

func return_to_map(entry_id: String) -> Dictionary:
	var guard := _guard()
	if not guard.is_empty(): return guard
	if entry_id.is_empty() or entry_id != _state.active_entry_id: return _result(false, "run.error.stale_entry")
	if _state.phase == "map" and _state.cleared_node_ids.has(_state.current_node_id): return _result(true)
	if _state.phase != "cleared": return _result(false, "run.error.wrong_phase")
	var candidate: Dictionary = _state.duplicate(true)
	candidate.revision += 1
	candidate.phase = "map"
	if not _submit(candidate): return _result(false, "run.error.commit_failed")
	return _result(true, "", true)

func defeat(entry_id: String) -> Dictionary:
	var guard := _guard()
	if not guard.is_empty(): return guard
	if entry_id.is_empty() or entry_id != _state.active_entry_id: return _result(false, "run.error.stale_entry")
	if _state.phase == "defeated": return _result(true)
	# The latest room can report death after its clear/map callback in the same
	# frame. Entry identity, not callback order, decides whether it is still live.
	var candidate: Dictionary = _state.duplicate(true)
	candidate.revision += 1
	candidate.phase = "defeated"
	candidate.hp = 0.0
	candidate.cleared_node_ids.erase(candidate.current_node_id)
	if not _submit(candidate): return _result(false, "run.error.commit_failed")
	_pending_ticket = {}
	return _result(true, "", true)

func _available_node_ids() -> Array:
	if _state.phase != "map": return []
	var result: Array = []
	var candidates: Array = _route.start_node_ids if _state.current_node_id.is_empty() else _successors[_state.current_node_id]
	if not _state.current_node_id.is_empty() and not _state.cleared_node_ids.has(_state.current_node_id): return result
	for id in candidates:
		if not _state.visited_node_ids.has(id): result.append(str(id))
	return result

func _submit(candidate: Dictionary) -> bool:
	_busy = true
	var receipt: Variant = _commit.call(candidate.duplicate(true))
	_busy = false
	if not receipt is int or receipt != OK: return false
	_state = _freeze_copy(candidate)
	return true

func _guard() -> Dictionary:
	if _busy: return _result(false, "run.error.busy")
	if _state.is_empty(): return _result(false, "run.error.not_configured")
	return {}

func _prepared_result(ticket: Dictionary) -> Dictionary:
	return _freeze_copy({"ok": true, "error_key": "", "ticket": ticket})

func _result(ok: bool, error_key: String = "", changed: bool = false) -> Dictionary:
	return _freeze_copy({"ok": ok, "error_key": error_key, "changed": changed})

func _valid_plan(plan: Dictionary, node: Dictionary) -> bool:
	if not plan.has_all(["node_id", "template_id", "depth", "kind", "reward_id", "encounter_plan"]): return false
	if not plan.encounter_plan is Dictionary or plan.encounter_plan.is_empty(): return false
	return plan.node_id == node.id and plan.template_id == node.template_id and plan.depth == node.depth and plan.kind == node.kind and plan.reward_id == node.reward_id

func _valid_build_snapshot(build_state: Dictionary, program: Dictionary) -> bool:
	# The injected app compiler owns gameplay validation. This seam checks that
	# state and its already validated program are the same immutable snapshot.
	if not build_state.has_all(["selections", "revision"]) or not build_state.selections is Array or not _nonnegative_integer(build_state.revision): return false
	if not program.has_all(["selections", "revision", "global", "actions"]): return false
	if not program.actions is Dictionary or not program.actions.has_all(["primary", "special", "skill"]): return false
	if not program.global is Dictionary: return false
	return program.selections == build_state.selections and program.revision == build_state.revision

func _valid_route_shape(route: Dictionary) -> bool:
	if not route.has_all(["id", "nodes", "edges", "start_node_ids"]): return false
	if not route.nodes is Array or route.nodes.is_empty() or not route.edges is Array or not route.start_node_ids is Array or route.start_node_ids.is_empty(): return false
	var ids: Dictionary = {}
	for node in route.nodes:
		if not node is Dictionary or not node.has_all(["id", "layer", "column", "kind", "depth", "template_id", "reward_id"]): return false
		if not node.id is String or node.id.is_empty() or ids.has(node.id): return false
		if not _nonnegative_integer(node.layer) or not _nonnegative_integer(node.column) or not _nonnegative_integer(node.depth): return false
		if node.kind not in ["battle", "elite", "terminal"] or node.reward_id != "none": return false
		ids[node.id] = true
	for edge in route.edges:
		if not edge is Dictionary or not edge.has_all(["from", "to"]) or not ids.has(edge.from) or not ids.has(edge.to): return false
	for id in route.start_node_ids:
		if not ids.has(id): return false
	return true

static func _nonnegative_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) == floorf(float(value)) and float(value) <= 9007199254740991.0

static func _freeze_copy(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = _freeze_copy(value[key])
		result.make_read_only()
		return result
	if value is Array:
		var result: Array = []
		for item in value: result.append(_freeze_copy(item))
		result.make_read_only()
		return result
	return value
