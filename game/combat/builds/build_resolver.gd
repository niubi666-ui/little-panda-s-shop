extends RefCounted
## One pure authority for bound choices, replacement, compilation and program checks.
const Capabilities = preload("res://combat/builds/projectile_capabilities.gd")
const Catalog = preload("res://content/builds/build_catalog.gd")
var _catalog

func configure(catalog) -> void:
	_catalog = catalog

func resolve(state: Dictionary) -> Dictionary:
	if not validate_state(state).is_empty(): return {}
	return Catalog.freeze_copy(_compile(state))

func validate_state(state: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not state.has("selections") or not state.selections is Array or not state.has("revision") or not _integer(state.revision, 0):
		return ["build.reason.invalid_state"]
	if state.selections.size() > 512: return ["build.reason.invalid_state"]
	var bound: Dictionary = {}
	var slots: Dictionary = {}
	for selected in state.selections:
		if not selected is Dictionary or selected.size() != 3 or not selected.has_all(["upgrade_id", "action_id", "rank"]): return ["build.reason.invalid_state"]
		if not selected.upgrade_id is String or not _catalog.has_upgrade(selected.upgrade_id): return ["build.reason.unknown_upgrade"]
		var entry: Dictionary = _catalog.upgrade(selected.upgrade_id)
		if not _integer(selected.rank, 1) or int(selected.rank) > int(entry.max_rank): return ["build.reason.invalid_rank"]
		if not selected.action_id is String: return ["build.reason.wrong_action"]
		var action_id: String = selected.action_id
		if entry.scope == "global":
			if action_id != "global": return ["build.reason.wrong_action"]
		elif not _catalog.has_action(action_id) or not entry.action_ids.has(action_id): return ["build.reason.wrong_action"]
		var identity := _identity(selected)
		if bound.has(identity): return ["build.reason.invalid_state"]
		bound[identity] = selected
		if entry.layer in ["form", "core"]:
			var slot := action_id + ":" + str(entry.layer)
			if slots.has(slot): return ["build.reason.slot_conflict"]
			slots[slot] = identity
	for selected in state.selections:
		var entry: Dictionary = _catalog.upgrade(selected.upgrade_id)
		for required in entry.requires:
			var target: String = "global" if _catalog.upgrade(required).scope == "global" else selected.action_id
			if not bound.has(target + ":" + str(required)): errors.append("build.reason.dependency")
		for excluded in entry.excludes:
			if bound.has(str(selected.action_id) + ":" + str(excluded)): errors.append("build.reason.incompatible")
	if not errors.is_empty(): return errors
	var program := _compile(state)
	for action_id in program.actions:
		var plan: Dictionary = program.actions[action_id]
		if not Capabilities.valid_plan(plan, _catalog): errors.append("build.reason.incompatible")
		var summary: Array = Capabilities.summarize_plan(_catalog, plan)
		for selected in state.selections:
			if selected.action_id != action_id: continue
			var entry: Dictionary = _catalog.upgrade(selected.upgrade_id)
			for tag in entry.required_tags:
				if not plan.tags.has(tag): errors.append("build.reason.dependency")
			if not Capabilities.eligible(entry, summary): errors.append("build.reason.capability")
	return errors

func valid_program(program: Dictionary) -> bool:
	if not program.has_all(["revision", "selections", "global", "actions"]) or program.size() != 4: return false
	var state := {"selections": program.selections, "revision": program.revision}
	if not validate_state(state).is_empty(): return false
	return program == _compile(state)

func evaluate(state: Dictionary, operation: Dictionary) -> Dictionary:
	var errors := validate_state(state)
	if not errors.is_empty(): return _failure(errors[0])
	if not operation.has_all(["upgrade_id", "action_id", "operation", "rank", "replaced", "base_revision"]): return _failure("build.reason.invalid_operation")
	if not _integer(operation.base_revision, 0) or int(operation.base_revision) != int(state.revision): return _failure("build.reason.stale")
	if not operation.upgrade_id is String or not _catalog.has_upgrade(operation.upgrade_id): return _failure("build.reason.unknown_upgrade")
	if not operation.action_id is String or not operation.operation is String or not operation.replaced is Dictionary or not _integer(operation.rank, 1): return _failure("build.reason.invalid_operation")
	var entry: Dictionary = _catalog.upgrade(operation.upgrade_id)
	if entry.test_only: return _failure("build.reason.wrong_action")
	if operation.action_id != "global":
		if not _catalog.has_action(operation.action_id) or _catalog.action(operation.action_id).test_only: return _failure("build.reason.wrong_action")
	if (entry.scope == "global" and operation.action_id != "global") or (entry.scope == "action" and not entry.action_ids.has(operation.action_id)): return _failure("build.reason.wrong_action")
	var expected := _operation(state, entry, operation.action_id)
	for field in ["operation", "rank", "replaced"]:
		if operation[field] != expected[field]: return _failure("build.reason.invalid_operation")
	if int(operation.rank) > int(entry.max_rank): return _failure("build.reason.invalid_rank")
	var candidate := {"selections": state.selections.duplicate(true), "revision": int(state.revision) + 1}
	if not operation.replaced.is_empty(): candidate.selections.erase(operation.replaced)
	if operation.operation == "rank":
		for selected in candidate.selections:
			if selected.upgrade_id == operation.upgrade_id and selected.action_id == operation.action_id: selected.rank = int(operation.rank)
	else:
		candidate.selections.append({"upgrade_id": operation.upgrade_id, "action_id": operation.action_id, "rank": int(operation.rank)})
	# Do not offer a base-form card that cannot change the current form.
	if entry.effect_type == "form":
		var before: Dictionary = _compile(state).actions[operation.action_id]
		if before.form_id == entry.ranks[int(operation.rank) - 1].form_id: return _failure("build.reason.invalid_operation")
	errors = validate_state(candidate)
	if not errors.is_empty(): return _failure(errors[0])
	candidate.selections = _ordered(candidate.selections)
	return {"ok": true, "error_key": "", "state": Catalog.freeze_copy(candidate), "program": resolve(candidate), "change": Catalog.freeze_copy(expected)}

func legal_operations(state: Dictionary, upgrade_id: String = "") -> Array:
	var result: Array = []
	if not validate_state(state).is_empty(): return result
	var pool: Array = _catalog.offer_rules().pool_ids.duplicate()
	for fallback in _catalog.offer_rules().fallback_ids:
		if not pool.has(fallback): pool.append(fallback)
	if not upgrade_id.is_empty(): pool = [upgrade_id] if pool.has(upgrade_id) else []
	pool.sort()
	for id in pool:
		var entry: Dictionary = _catalog.upgrade(id)
		if entry.test_only: continue
		var targets: Array = ["global"] if entry.scope == "global" else entry.action_ids
		for action_id in targets:
			if action_id != "global" and _catalog.action(action_id).test_only: continue
			var operation := _operation(state, entry, action_id)
			if evaluate(state, operation).ok: result.append(operation)
	return Catalog.freeze_copy(result)

func _operation(state: Dictionary, entry: Dictionary, action_id: String) -> Dictionary:
	var result := {"upgrade_id": str(entry.id), "action_id": action_id, "operation": "add", "rank": 1, "replaced": {}, "base_revision": int(state.revision)}
	for selected in state.selections:
		if selected.action_id != action_id: continue
		if selected.upgrade_id == entry.id:
			result.operation = "rank"
			result.rank = int(selected.rank) + 1
			return result
		if entry.layer in ["form", "core"] and _catalog.upgrade(selected.upgrade_id).layer == entry.layer:
			result.operation = "replace"
			result.replaced = selected.duplicate(true)
	return result

func _compile(state: Dictionary) -> Dictionary:
	var selected: Array = _ordered(state.selections)
	var global_damage := 0.0
	var global_move := 0.0
	for item in selected:
		if item.action_id != "global": continue
		var definition: Dictionary = _catalog.upgrade(item.upgrade_id)
		var params: Dictionary = definition.ranks[int(item.rank) - 1]
		if definition.effect_type == "damage_scale": global_damage += float(params.bonus)
		if definition.effect_type == "move_scale": global_move += float(params.bonus)
	var limits: Dictionary = _catalog.stat_limits()
	var global_stats := {"damage_scale": clampf(1.0 + global_damage, limits.damage_scale_min, limits.damage_scale_max), "move_scale": clampf(1.0 + global_move, limits.move_scale_min, limits.move_scale_max)}
	var program := {"revision": int(state.revision), "selections": selected, "global": global_stats, "actions": {}}
	for action in _catalog.actions():
		var form_id: String = action.base_form_id
		for item in selected:
			if item.action_id != action.id: continue
			var entry: Dictionary = _catalog.upgrade(item.upgrade_id)
			if entry.effect_type == "form": form_id = entry.ranks[int(item.rank) - 1].form_id
		var form: Dictionary = _catalog.form(form_id)
		var plan := {"revision": int(state.revision), "action_id": str(action.id), "form_id": form_id, "executor": str(form.executor), "ability_ids": form.ability_ids.duplicate(), "projectile_id": str(form.projectile_id), "presentation_key": str(form.presentation_key), "damage_scale": 1.0, "move_scale": global_stats.move_scale, "tags": [], "effects": []}
		var damage_bonus := global_damage
		var durations: Dictionary = {}
		var area_grants: Array = []
		for item in selected:
			if item.action_id != action.id: continue
			var entry: Dictionary = _catalog.upgrade(item.upgrade_id)
			var params: Dictionary = entry.ranks[int(item.rank) - 1].duplicate(true)
			for tag in entry.granted_tags:
				if not plan.tags.has(tag): plan.tags.append(tag)
			match str(entry.effect_type):
				"damage_scale": damage_bonus += float(params.bonus)
				"status_duration": durations[params.status_id] = float(durations.get(params.status_id, 0.0)) + float(params.bonus)
				"area_status": area_grants.append({"upgrade_id": str(item.upgrade_id), "rank": int(item.rank), "params": params})
				"projectile", "chain", "split", "pierce", "explosion", "status": plan.effects.append({"upgrade_id": str(item.upgrade_id), "type": str(entry.effect_type), "rank": int(item.rank), "params": params})
		for effect in plan.effects:
			if effect.type == "status": effect.params.duration_sec = _duration(effect.params.status_id, durations)
			if effect.type != "explosion": continue
			var params: Dictionary = effect.params
			params.payloads = [{"type": "damage", "edge_ratio": params.edge_ratio, "include_primary": params.include_primary, "max_targets": params.max_targets}]
			for grant in area_grants:
				if grant.params.source_effect_id != effect.upgrade_id: continue
				params.payloads.append({"type": "apply_status", "status_id": grant.params.status_id, "duration_sec": _duration(grant.params.status_id, durations), "include_primary": grant.params.include_primary, "max_targets": grant.params.max_targets, "allowed_origins": grant.params.allowed_origins, "upgrade_id": grant.upgrade_id, "rank": grant.rank})
		plan.damage_scale = clampf(1.0 + damage_bonus, limits.damage_scale_min, limits.damage_scale_max)
		plan.tags.sort()
		program.actions[action.id] = plan
	return program

func _duration(status_id: String, bonuses: Dictionary) -> float:
	var definition: Dictionary = _catalog.status(status_id)
	return minf(float(definition.max_duration_sec), float(definition.duration_sec) * (1.0 + float(bonuses.get(status_id, 0.0))))

static func _ordered(selections: Array) -> Array:
	var result: Array = selections.duplicate(true)
	result.sort_custom(func(a, b): return _identity(a) < _identity(b))
	return result

static func _identity(selection: Dictionary) -> String:
	return str(selection.action_id) + ":" + str(selection.upgrade_id)

static func _integer(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= 9007199254740991.0

static func _failure(key: String) -> Dictionary:
	return {"ok": false, "error_key": key, "state": {}, "program": {}, "change": {}}

static func freeze(value: Variant) -> void:
	if value is Dictionary:
		for item in value.values(): freeze(item)
		value.make_read_only()
	elif value is Array:
		for item in value: freeze(item)
		value.make_read_only()
