extends RefCounted
## Bounded, queued derived effects. Roots own snapshots and a shared request budget.
const Resolver = preload("res://combat/builds/build_resolver.gd")
const Factory = preload("res://combat/builds/projectile_factory.gd")
const Split = preload("res://combat/builds/projectile_split.gd")
const Pierce = preload("res://combat/builds/projectile_pierce.gd")
const Contacts = preload("res://combat/builds/projectile_contacts.gd")
const Capabilities = preload("res://combat/builds/projectile_capabilities.gd")
const Statuses = preload("res://combat/status/status_runtime.gd")
var statuses := Statuses.new()
const Impact = preload("res://combat/builds/impact_effects.gd")
const Area = preload("res://combat/effects/area_payloads.gd")
const Damage = preload("res://combat/effects/damage_executor.gd")
const Sweep = preload("res://combat/builds/build_sweep.gd")
signal damage_applied(source, target, applied_damage: float, origin: String)
signal area_emitted(center: Vector3, radius: float)
signal area_payload_emitted(center: Vector3, radius: float, has_status: bool)
signal chain_emitted(points: PackedVector3Array)
signal action_presented(fact: Dictionary)
signal projectile_presented(fact: Dictionary)
signal area_presented(fact: Dictionary)

var _catalog
var _attack_ids: Array = []
var _cooldowns: Dictionary = {}
var _player
var _targets: Callable
var _wall_query: Callable
var _limits: Dictionary
var _program: Dictionary
var _roots: Dictionary = {}
var _cast_roots: Dictionary = {}
var _queue: Array[Dictionary] = []
var _projectiles: Dictionary = {}
var _next_root := 0
var _next_projectile := 0
var _next_event := 0
var _room_generation := 0
var _rejected := 0
var _executed := 0

func configure(catalog, player, targets: Callable, wall_query: Callable, attack_ids: Array = []) -> void:
	clear_room()
	_catalog = catalog
	statuses.configure(catalog)
	_attack_ids = attack_ids.duplicate()
	_player = player
	_targets = targets
	_wall_query = wall_query
	_limits = catalog.limits()
	var resolver := Resolver.new()
	resolver.configure(catalog)
	_program = resolver.resolve({"selections": [], "revision": 0})

func set_program(program: Dictionary) -> bool:
	var evaluator := Resolver.new()
	evaluator.configure(_catalog)
	if not evaluator.valid_program(program): return false
	# Copy even a caller-owned program: subsequent caller mutation cannot alter a cast.
	_program = program.duplicate(true)
	Resolver.freeze(_program)
	return true

func on_committed(cast_id: int, ability_id: String) -> void:
	if not _source_alive(): return
	if _player.runner.cast_id != cast_id or _player.runner.ability.id != ability_id: return
	if _cast_roots.has(cast_id): return
	var action_id: String = _player.runner.action_id
	if not _program.actions.has(action_id): return
	var plan: Dictionary = _program.actions[action_id]
	if not plan.ability_ids.has(ability_id): return
	# Actor and runtime are injected together by app. Reject a mismatched cast plan.
	if not _player.runner.cast_context.is_empty() and _player.runner.cast_context != plan: return
	_next_root += 1
	_roots[_next_root] = {
		"id": _next_root, "cast_id": cast_id, "ability_id": ability_id,
		"room_generation": _room_generation, "source_handle": _player.handle, "team": _player.team,
		"action_id": action_id, "revision": _program.revision, "form_id": plan.form_id,
		"program": plan, "base_damage": _player.runner.ability.damage,
		"damage": _player.runner.ability.damage * float(plan.damage_scale),
		"budget": int(_limits.root_effect_budget), "spawned": 0, "cue_seen": false,
		"impact_counts": {}, "chain_triggers": {}, "control_attempts": {},
	}
	_cast_roots[cast_id] = _next_root
	action_presented.emit(_action_fact(_roots[_next_root], "started"))
	_reclaim_roots()

func on_cue(cast_id: int, ability_id: String) -> void:
	var context := _context_for_cast(cast_id)
	if context.is_empty() or context.ability_id != ability_id or context.cue_seen: return
	if not _source_alive() or not _player.runner.busy() or _player.runner.cast_id != cast_id: return
	context.cue_seen = true
	var direction: Vector3 = Sweep.planar_direction(_player.runner.direction)
	action_presented.emit(_action_fact(context, "cue"))
	if not _context_live(context): return
	if context.program.executor == "projectile":
		_enqueue(context, Factory.initial(_catalog.projectile(context.program.projectile_id), _player.global_position, direction, context.damage))
	for effect in context.program.effects:
		if effect.type != "projectile": continue
		var params: Dictionary = effect.params
		_enqueue(context, Factory.initial(_catalog.projectile(params.projectile_id), _player.global_position, direction, float(context.damage) * float(params.damage_ratio)))

func fire_attack(attack_id: String, direction: Vector3) -> bool:
	if not _source_alive() or not _player.runner.actions_allowed or not _attack_ids.has(attack_id) or _cooldowns.has(attack_id) or direction.is_zero_approx(): return false
	var attack: Dictionary = _catalog.test_attack(attack_id)
	if not _program.actions.has(attack.action_id): return false
	var plan: Dictionary = _program.actions[attack.action_id]
	_next_root += 1
	var context := {"id": _next_root, "cast_id": -_next_root, "ability_id": attack_id,
		"room_generation": _room_generation, "source_handle": _player.handle, "team": _player.team,
		"action_id": attack.action_id, "revision": _program.revision, "form_id": plan.form_id,
		"program": plan, "base_damage": attack.damage, "damage": float(attack.damage) * float(plan.damage_scale),
		"budget": int(_limits.root_effect_budget), "spawned": 0, "cue_seen": true, "impact_counts": {}, "chain_triggers": {}, "control_attempts": {}}
	_roots[_next_root] = context
	if not _enqueue(context, Factory.initial(_catalog.projectile(attack.projectile_id), _player.global_position, Sweep.planar_direction(direction), context.damage)):
		_roots.erase(_next_root)
		return false
	_cooldowns[attack_id] = float(attack.cooldown_sec)
	return true

func melee_damage(source, base_damage: float) -> float:
	if source != _player: return base_damage
	var context := _context_for_cast(source.runner.cast_id)
	if context.is_empty(): return base_damage
	return base_damage * float(context.program.damage_scale)

func on_melee_hit(source, target, cast_id: int, ability_id: String, applied_damage: float) -> void:
	if source != _player or applied_damage <= 0.0 or not is_instance_valid(target): return
	var context := _context_for_cast(cast_id)
	if context.is_empty() or context.ability_id != ability_id: return
	_schedule_chains(context, target, applied_damage, "direct_melee")

func tick(delta: float) -> void:
	if delta <= 0.0: return
	if not _source_alive() and not bool(_limits.projectiles_survive_source_death):
		clear_room()
		return
	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0: _cooldowns.erase(id)
	_advance_projectiles(delta)
	if not _source_alive() and not bool(_limits.projectiles_survive_source_death):
		clear_room()
		return
	var remaining := int(_limits.requests_per_step)
	while remaining > 0 and not _queue.is_empty():
		if not _source_alive() and not bool(_limits.projectiles_survive_source_death):
			clear_room()
			return
		remaining -= 1
		var request: Dictionary = _queue.pop_front()
		if not _roots.has(request.root_id): continue
		var context: Dictionary = _roots[request.root_id]
		if context.room_generation != _room_generation: continue
		_executed += 1
		match str(request.type):
			"spawn": _spawn(context, request)
			"chain": _chain_step(context, request)
			"area": _area_step(context, request)
			"status": _status_step(context, request)
	_reclaim_roots()

func clear_room() -> void:
	var ended: Array = []
	for projectile in _projectiles.values():
		ended.append(_projectile_fact(projectile, _roots[projectile.root_id], "terminated", "room_clear"))
	statuses.clear()
	_room_generation += 1
	_roots.clear()
	_cast_roots.clear()
	_queue.clear()
	_cooldowns.clear()
	_projectiles.clear()
	for fact in ended: projectile_presented.emit(fact)

func projectiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in _projectiles:
		var projectile: Dictionary = _projectiles[id]
		var fact := _projectile_fact(projectile, _roots[projectile.root_id], "snapshot")
		fact.remaining_hits = projectile.remaining_hits
		result.append(fact)
	Resolver.freeze(result)
	return result

func diagnostics() -> Dictionary:
	var budgets: Dictionary = {}
	for id in _roots: budgets[id] = _roots[id].budget
	var result := {"roots": _roots.size(), "projectiles": _projectiles.size(), "queued": _queue.size(), "rejected": _rejected, "executed": _executed, "budgets": budgets, "room_generation": _room_generation}
	Resolver.freeze(result)
	return result

func _source_alive() -> bool:
	return is_instance_valid(_player) and _player.health.alive()

func _context_for_cast(cast_id: int) -> Dictionary:
	if not _cast_roots.has(cast_id): return {}
	return _roots[_cast_roots[cast_id]]

func _enqueue(context: Dictionary, request: Dictionary) -> bool:
	# Signals may synchronously change rooms. An old branch cannot resurrect its root.
	if context.room_generation != _room_generation or not _roots.has(context.id) or (not _source_alive() and not bool(_limits.projectiles_survive_source_death)):
		_rejected += 1
		return false
	if request.type == "spawn" and float(request.lifetime) <= 0.0:
		_rejected += 1
		return false
	if int(context.budget) <= 0 or _queue.size() >= int(_limits.max_queue):
		_rejected += 1
		return false
	context.budget -= 1
	_next_event += 1
	request.root_id = context.id
	request.event_id = _next_event
	_queue.append(request)
	return true

func _spawn(context: Dictionary, request: Dictionary) -> void:
	if float(request.lifetime) <= 0.0: return
	if _projectiles.size() >= int(_limits.max_projectiles) or int(context.spawned) >= int(_limits.max_projectiles_per_root):
		_rejected += 1
		return
	context.spawned += 1
	_next_projectile += 1
	var projectile := request.duplicate(true)
	projectile.id = _next_projectile
	projectile.remaining_hits = Pierce.max_hits(projectile.definition, context.program, _limits)
	_projectiles[_next_projectile] = projectile
	projectile_presented.emit(_projectile_fact(projectile, context, "spawned"))

func _advance_projectiles(delta: float) -> void:
	# Fixed snapshot: child projectiles begin travelling on the following simulation step.
	for id in _projectiles.keys():
		if not _projectiles.has(id): continue
		var projectile: Dictionary = _projectiles[id]
		if float(projectile.lifetime) <= 0.0:
			_terminate_projectile(id, "expired")
			continue
		var context: Dictionary = _roots[projectile.root_id]
		if not _context_live(context): return
		var lifetime_before := float(projectile.lifetime)
		var step := minf(delta, float(projectile.lifetime))
		var start: Vector3 = projectile.position
		var direction: Vector3 = projectile.direction
		var distance := float(projectile.speed) * step
		var finish: Vector3 = start + direction * distance
		var wall: Variant = _wall_query.call(start, finish) if _wall_query.is_valid() else null
		var wall_blocked := wall is Vector3
		if wall_blocked:
			finish = wall
			distance = start.distance_to(finish)
		var contacts := Contacts.collect(projectile, start, direction, distance, wall_blocked, _valid_targets(context))
		for contact in contacts:
			if not _context_live(context): return
			var target = contact.target
			# Earlier damage signals may kill/free a later candidate. Do not debit its hit.
			if not is_instance_valid(target) or not target.health.alive() or target.team == context.team or target.handle != contact.handle: continue
			projectile.position = start + direction * float(contact.distance)
			# Every contact distance is measured from this step's original start.
			projectile.lifetime = lifetime_before - float(contact.distance) / float(projectile.speed)
			var point: Vector3 = target.global_position
			var victim: int = target.handle
			projectile.excluded[victim] = true
			projectile.remaining_hits -= 1
			var applied: float = Damage.apply(target, float(projectile.damage), context.team)
			if not _context_live(context): return
			var presentation := _projectile_fact(projectile, context, "contact")
			presentation.target_handle = victim
			presentation.position = point
			projectile_presented.emit(presentation)
			if not _context_live(context): return
			_contact(context, {"origin": "direct_projectile" if int(projectile.generation) == 0 else "split_projectile", "parent_id": "projectile:%s" % id, "target_handle": victim, "position": point, "damage": projectile.damage})
			if not _context_live(context): return
			if applied > 0.0:
				damage_applied.emit(_player, target, applied, "secondary_projectile")
				if not _context_live(context): return
				if is_instance_valid(target): _schedule_chains(context, target, applied, "secondary_projectile")
			_schedule_splits(context, projectile, victim)
			if int(projectile.remaining_hits) <= 0:
				_terminate_projectile(id, "contact_limit")
				break
		if not _projectiles.has(id): continue
		projectile.position = finish
		projectile.lifetime = lifetime_before - step
		if wall_blocked or float(projectile.lifetime) <= 0.0: _terminate_projectile(id, "wall" if wall_blocked else "expired")

func on_finished(cast_id: int, ability_id: String, reason: String) -> void:
	var context := _context_for_cast(cast_id)
	if context.is_empty() or context.ability_id != ability_id: return
	action_presented.emit(_action_fact(context, reason))

func _action_fact(context: Dictionary, event: String) -> Dictionary:
	return {"event": event, "root_id": context.id, "cast_id": context.cast_id, "action_id": context.action_id,
		"ability_id": context.ability_id, "form_id": context.form_id, "revision": context.revision,
		"presentation_key": context.program.presentation_key, "position": _player.global_position,
		"direction": _player.runner.direction, "executor": context.program.executor,
		"effect_ids": context.program.effects.map(func(effect): return effect.upgrade_id)}

func _projectile_fact(projectile: Dictionary, context: Dictionary, event: String, reason: String = "") -> Dictionary:
	return {"event": event, "reason": reason, "id": projectile.id, "root_id": context.id, "cast_id": context.cast_id,
		"action_id": context.action_id, "ability_id": context.ability_id, "form_id": context.form_id, "revision": context.revision,
		"presentation_key": context.program.presentation_key, "definition_id": projectile.definition.id,
		"generation": projectile.generation, "position": projectile.position, "direction": projectile.direction, "radius": projectile.radius,
		"effect_ids": context.program.effects.map(func(effect): return effect.upgrade_id)}

func _terminate_projectile(id: int, reason: String) -> void:
	if not _projectiles.has(id): return
	var projectile: Dictionary = _projectiles[id]
	var fact := _projectile_fact(projectile, _roots[projectile.root_id], "terminated", reason)
	_projectiles.erase(id)
	projectile_presented.emit(fact)

func _context_live(context: Dictionary) -> bool:
	return context.room_generation == _room_generation and _roots.has(context.id) and (_source_alive() or bool(_limits.projectiles_survive_source_death))

func _valid_targets(context: Dictionary) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for target in _targets.call():
		if not is_instance_valid(target) or target == _player or target.team == context.team or not target.health.alive(): continue
		if seen.has(target.handle): continue
		seen[target.handle] = true
		result.append(target)
	return result

func _schedule_chains(context: Dictionary, target, applied_damage: float, origin: String) -> void:
	if origin not in ["direct_melee", "secondary_projectile"]: return
	for effect in context.program.effects:
		if effect.type != "chain" or context.chain_triggers.has(effect.upgrade_id): continue
		context.chain_triggers[effect.upgrade_id] = true
		var params: Dictionary = effect.params
		_enqueue(context, {"type": "chain", "position": target.global_position,
			"damage": applied_damage * float(params.damage_ratio), "radius": float(params.radius_m),
			"remaining": mini(int(params.jumps), int(_limits.max_chain_jumps)), "falloff": float(params.falloff),
			"visited": {target.handle: true}})

func _chain_step(context: Dictionary, request: Dictionary) -> void:
	if int(request.remaining) <= 0: return
	var candidates: Array[Dictionary] = []
	for target in _valid_targets(context):
		if request.visited.has(target.handle): continue
		var distance: float = request.position.distance_squared_to(target.global_position)
		if distance <= float(request.radius) * float(request.radius): candidates.append({"target": target, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.distance) == float(b.distance): return a.target.handle < b.target.handle
		return float(a.distance) < float(b.distance))
	if candidates.is_empty(): return
	var target = candidates[0].target
	var position: Vector3 = target.global_position
	request.visited[target.handle] = true
	var applied: float = Damage.apply(target, float(request.damage), context.team)
	if context.room_generation != _room_generation: return
	if applied > 0.0:
		damage_applied.emit(_player, target, applied, "chain")
		if context.room_generation != _room_generation: return
		chain_emitted.emit(PackedVector3Array([request.position, position]))
	if int(request.remaining) > 1:
		var next := request.duplicate(true)
		next.position = position
		next.remaining -= 1
		next.damage *= float(request.falloff)
		_enqueue(context, next)

func _schedule_splits(context: Dictionary, projectile: Dictionary, target_handle: int) -> void:
	for request in Split.requests(_catalog, _limits, context.program, projectile, target_handle):
		_enqueue(context, request)

func _reclaim_roots() -> void:
	var held: Dictionary = {}
	if is_instance_valid(_player) and (_player.runner.busy() or _player.runner.active_this_step) and _cast_roots.has(_player.runner.cast_id):
		held[_cast_roots[_player.runner.cast_id]] = true
	for request in _queue: held[request.root_id] = true
	for projectile in _projectiles.values(): held[projectile.root_id] = true
	for id in _roots.keys():
		if held.has(id): continue
		_cast_roots.erase(_roots[id].cast_id)
		_roots.erase(id)

func on_melee_contact(source, cast_id: int, ability_id: String, victim: int, point: Vector3, damage: float) -> void:
	if source != _player: return
	var context := _context_for_cast(cast_id)
	if context.is_empty() or context.ability_id != ability_id or context.program.executor != "melee": return
	_contact(context, {"origin": "direct_melee", "parent_id": "melee:%s" % cast_id, "target_handle": victim, "position": point, "damage": damage})

func _contact(context: Dictionary, fact: Dictionary) -> void:
	if not _context_live(context): return
	for request in Impact.requests(context, fact): _enqueue(context, request)

func _area_step(context: Dictionary, request: Dictionary) -> void:
	if request.params.occlusion == "world_ray" and not _wall_query.is_valid():
		_rejected += 1
		return
	var plan := Area.plan(request, context.team, _targets.call(), _wall_query)
	if not _context_live(context): return
	area_emitted.emit(request.position, float(request.params.radius_m))
	if not _context_live(context): return
	area_payload_emitted.emit(request.position, float(request.params.radius_m), request.payloads.any(func(p): return p.type == "apply_status"))
	var presentation := _action_fact(context, "area")
	presentation.position = request.position
	presentation.radius = float(request.params.radius_m)
	presentation.effect_id = request.effect_id
	presentation.has_status = request.payloads.any(func(p): return p.type == "apply_status")
	area_presented.emit(presentation)
	for hit in plan.damage:
		if not _context_live(context): return
		var applied := Damage.apply(hit.target, hit.damage, context.team)
		if not _context_live(context): return
		if applied > 0.0: damage_applied.emit(_player, hit.target, applied, "explosion")
	# One composite request costs one budget unit. Each finite payload has its own cap.
	for hit in plan.statuses:
		if not _context_live(context): return
		_apply_status(context, hit.target, hit.status_id, hit.duration)
	# No generic contact event: explicit payloads cannot trigger a new effect tree.

func _status_step(context: Dictionary, request: Dictionary) -> void:
	for target in _valid_targets(context):
		if target.handle != request.target_handle: continue
		_apply_status(context, target, request.status_id, request.duration)
		return

func _apply_status(context: Dictionary, target, status_id: String, duration: float) -> void:
	if not _context_live(context) or not is_instance_valid(target) or target.team == context.team: return
	statuses.apply(target, status_id, duration, {"source_handle": context.source_handle, "team": context.team, "root_id": context.id, "room_generation": context.room_generation, "ability_id": context.ability_id, "action_id": context.action_id, "revision": context.revision, "presentation_key": context.program.presentation_key}, context.control_attempts)
