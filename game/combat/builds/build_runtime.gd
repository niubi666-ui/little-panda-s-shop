extends RefCounted
## Bounded, queued derived effects. Roots own snapshots and a shared request budget.
const Resolver = preload("res://combat/builds/build_resolver.gd")
const Factory = preload("res://combat/builds/projectile_factory.gd")
const Split = preload("res://combat/builds/projectile_split.gd")
const Pierce = preload("res://combat/builds/projectile_pierce.gd")
const Contacts = preload("res://combat/builds/projectile_contacts.gd")
const Capabilities = preload("res://combat/builds/projectile_capabilities.gd")
const Statuses = preload("res://combat/status/status_runtime.gd")
const Frost = preload("res://combat/builds/frost_effects.gd")
const Elements = preload("res://combat/builds/element_effects.gd")
var frost := Frost.new()
var elements := Elements.new()
var statuses := Statuses.new()
const Conditional = preload("res://combat/builds/conditional_damage.gd")
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
signal conditional_damage_applied(fact: Dictionary)
## 元素事实（挂状态、放电、反应、区域结束、清除），供表现层使用
signal element_presented(fact: Dictionary)

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
var _conditional_hits := 0
var _last_conditional: Dictionary = {}
var _pending_conditionals: Array[Dictionary] = []

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
	# The dodge-configured slash is a primary variant, with the same immutable build plan.
	if not plan.ability_ids.has(ability_id) and not (action_id == "primary" and plan.executor == "melee" and _player.is_roll_attack_cast()): return
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
		"damage_request": _player.runner.damage_snapshot.duplicate(true),
	}
	_roots[_next_root].damage_request.source_scale *= float(plan.damage_scale)
	_cast_roots[cast_id] = _next_root
	var charge := Frost.params(plan, "charge_projectile")
	if _player.runner.cast_charged and not charge.is_empty():
		_roots[_next_root].charged = true
		_roots[_next_root].base_damage *= float(charge.damage_ratio)
		_roots[_next_root].damage *= float(charge.damage_ratio)
		_roots[_next_root].radius_scale = charge.radius_ratio
		_player.runner.cooldown *= float(charge.cooldown_ratio)
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
		_enqueue(context, Factory.initial(_catalog.projectile(context.program.projectile_id), _player.global_position, direction, context.base_damage))
	for effect in context.program.effects:
		if effect.type != "projectile": continue
		var params: Dictionary = effect.params
		_enqueue(context, Factory.initial(_catalog.projectile(params.projectile_id), _player.global_position, direction, float(context.base_damage) * float(params.damage_ratio)))

func fire_attack(attack_id: String, direction: Vector3) -> bool:
	if not _source_alive() or not _player.runner.actions_allowed or not _attack_ids.has(attack_id) or _cooldowns.has(attack_id) or direction.is_zero_approx(): return false
	var attack: Dictionary = _catalog.test_attack(attack_id)
	if not _program.actions.has(attack.action_id): return false
	var plan: Dictionary = _program.actions[attack.action_id]
	_next_root += 1
	var basis: float = Damage.Formula.linear(_player.attribute_catalog.profile(attack.damage_profile_id), _player.attributes.final)
	var context := {"id": _next_root, "cast_id": -_next_root, "ability_id": attack_id,
		"room_generation": _room_generation, "source_handle": _player.handle, "team": _player.team,
		"action_id": attack.action_id, "revision": _program.revision, "form_id": plan.form_id,
		"program": plan, "base_damage": basis, "damage": basis * float(plan.damage_scale),
		"budget": int(_limits.root_effect_budget), "spawned": 0, "cue_seen": true, "impact_counts": {}, "chain_triggers": {}, "control_attempts": {}}
	_roots[_next_root] = context
	context.damage_request = Damage.request(_player, attack.damage_profile_id, basis, context.id, attack.action_id, _player.roll_critical(attack.damage_profile_id))
	context.damage_request.source_scale *= float(plan.damage_scale)
	if not _enqueue(context, Factory.initial(_catalog.projectile(attack.projectile_id), _player.global_position, Sweep.planar_direction(direction), context.base_damage)):
		_roots.erase(_next_root)
		return false
	_cooldowns[attack_id] = float(attack.cooldown_sec)
	return true

func melee_damage(source, base_damage: float) -> float:
	if source != _player: return base_damage
	var context := _context_for_cast(source.runner.cast_id)
	if context.is_empty(): return base_damage
	return base_damage

func on_melee_hit(source, target, cast_id: int, ability_id: String, applied_damage: float) -> void:
	if source != _player or not is_instance_valid(target): return
	var context := _context_for_cast(cast_id)
	if context.is_empty() or context.ability_id != ability_id: return
	_schedule_chains(context, target, context.base_damage, "direct_melee")

func tick(delta: float) -> void:
	if delta <= 0.0: return
	if is_instance_valid(_player): _player.tick_protection(delta)
	frost.tick(delta, self)
	elements.tick(delta, self)
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
	_flush_conditional_facts()
	_reclaim_roots()

func clear_room() -> void:
	frost.clear(_player)
	elements.clear()
	var ended: Array = []
	for projectile in _projectiles.values():
		ended.append(_projectile_fact(projectile, _roots[projectile.root_id], "terminated", "room_clear"))
	statuses.clear()
	_conditional_hits = 0
	_last_conditional = {}
	_pending_conditionals.clear()
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
	var result := {"roots": _roots.size(), "projectiles": _projectiles.size(), "queued": _queue.size(), "rejected": _rejected, "executed": _executed, "budgets": budgets, "room_generation": _room_generation, "conditional_hits": _conditional_hits, "last_conditional": _last_conditional.duplicate(true)}
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
	if int(projectile.generation) == 0: projectile.radius *= float(context.get("radius_scale", 1.0))
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
			if not _begin_return(projectile): _terminate_projectile(id, "expired")
			continue
		var context: Dictionary = _roots[projectile.root_id]
		if not _context_live(context): return
		var lifetime_before := float(projectile.lifetime)
		var step := minf(delta, float(projectile.lifetime))
		var start: Vector3 = projectile.position
		if projectile.get("returning", false):
			var p := Frost.params(context.program, "return_projectile")
			var toward: Vector3 = _player.global_position - start; toward.y = 0.0
			if toward.length() <= float(p.catch_radius_m): _terminate_projectile(id, "caught"); continue
			var angle: float = projectile.direction.signed_angle_to(toward.normalized(), Vector3.UP)
			projectile.direction = projectile.direction.rotated(Vector3.UP, clampf(angle, -float(p.turn_radians_per_sec) * step, float(p.turn_radians_per_sec) * step))
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
			var origin: String = "direct_projectile" if int(projectile.generation) == 0 and context.program.executor == "projectile" else "split_projectile"
			var hit := _apply_direct_damage(context, target, float(projectile.damage), origin)
			if not _context_live(context): return
			var presentation := _projectile_fact(projectile, context, "contact")
			presentation.target_handle = victim
			presentation.position = point
			projectile_presented.emit(presentation)
			if not _context_live(context): return
			if hit.valid_hit: _contact(context, {"origin": "direct_projectile" if int(projectile.generation) == 0 else "split_projectile", "parent_id": "projectile:%s" % id, "target_handle": victim, "position": point, "damage": projectile.damage})
			if not _context_live(context): return
			if hit.valid_hit:
				damage_applied.emit(_player, target, hit.health_loss, "secondary_projectile")
				if not _context_live(context): return
				if is_instance_valid(target): _schedule_chains(context, target, projectile.damage, "secondary_projectile")
				_schedule_splits(context, projectile, victim)
			if int(projectile.remaining_hits) <= 0:
				frost.sample_path(context, projectile, start, projectile.position)
				if not _begin_return(projectile): _terminate_projectile(id, "contact_limit")
				break
		if not _projectiles.has(id): continue
		if projectile.get("just_returned", false):
			projectile.just_returned = false
			continue
		frost.sample_path(context, projectile, start, finish)
		projectile.position = finish
		projectile.lifetime = lifetime_before - step
		if wall_blocked: _terminate_projectile(id, "wall")
		elif float(projectile.lifetime) <= 0.0:
			if not _begin_return(projectile): _terminate_projectile(id, "expired")

func _begin_return(projectile: Dictionary) -> bool:
	var context: Dictionary = _roots[projectile.root_id]
	var p := Frost.params(context.program, "return_projectile")
	if p.is_empty() or projectile.get("returning", false) or int(projectile.generation) != 0 or context.budget <= 0: return false
	context.budget -= 1
	projectile.returning = true
	projectile.just_returned = true
	projectile.excluded = {}
	projectile.direction = -projectile.direction
	projectile.speed = p.return_speed_mps
	projectile.lifetime = p.return_lifetime_sec
	projectile.remaining_hits = Pierce.max_hits(projectile.definition, context.program, _limits)
	return true

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
		"charged": bool(context.get("charged", false)) and int(projectile.generation) == 0,
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
	var hit := Damage.submit(target, _damage_request(context, request.damage, "chain", "chain"))
	if context.room_generation != _room_generation: return
	if hit.valid_hit:
		damage_applied.emit(_player, target, hit.health_loss, "chain")
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
	for path in frost.paths: held[path.root_id] = true
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
		var result := Damage.submit(hit.target, _damage_request(context, hit.damage, "explosion", "impact_blast"))
		if not _context_live(context): return
		if result.valid_hit: damage_applied.emit(_player, hit.target, result.health_loss, "explosion")
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
	var source := {"runtime_id": get_instance_id(), "source_handle": context.source_handle, "team": context.team, "root_id": context.id, "room_generation": context.room_generation, "ability_id": context.ability_id, "action_id": context.action_id, "revision": context.revision, "presentation_key": context.program.presentation_key}
	var definition: Dictionary = _catalog.status(status_id)
	if not str(definition.linked_mark_id).is_empty():
		var mark: Dictionary = _catalog.status(definition.linked_mark_id)
		statuses.apply(target, mark.id, mark.duration_sec, source)
	var applied: bool = statuses.apply(target, status_id, duration, source, context.control_attempts)
	if applied and definition.kind == "freeze" and _context_live(context): frost.froze(context, _player)

# MeleeResolver passes the unmodified formula basis; the request applies bonuses once.
func apply_melee_damage(source, target, amount: float) -> Dictionary:
	if source != _player: return Damage.submit(target, source.runner.damage_snapshot)
	var context := _context_for_cast(source.runner.cast_id)
	if context.is_empty(): return Damage.submit(target, source.runner.damage_snapshot)
	return _apply_direct_damage(context, target, amount, "direct_melee")

func _apply_direct_damage(context: Dictionary, target, amount: float, origin: String) -> Dictionary:
	var result := Conditional.evaluate(context, target, amount, origin, statuses, _catalog, get_instance_id())
	var shatter := Frost.params(context.program, "consume_freeze")
	var consumes := false
	if origin == "direct_melee" and not shatter.is_empty() and int(context.get("shatters", 0)) < int(shatter.max_targets):
		var snapshot := statuses.snapshot(target)
		consumes = snapshot.has(shatter.status_id) and Frost.own_earlier(snapshot[shatter.status_id], context, get_instance_id())
		if consumes:
			var status_source: Dictionary = snapshot[shatter.status_id].source
			var source_action: String = status_source.get("action_id", "")
			consumes = status_source.get("team", -1) == context.team and _catalog.has_action(source_action) and not _catalog.action(source_action).test_only
		if consumes: result.damage += amount * float(shatter.bonus)
	var point: Vector3 = target.global_position
	var handle: int = target.handle
	var request := _damage_request(context, amount, origin)
	request.conditional_bonus = result.damage / amount - 1.0 if amount > 0.0 else 0.0
	var hit := Damage.submit(target, request)
	if hit.valid_hit and _context_live(context):
		var element: Dictionary = elements.element_of(context.program)
		if not element.is_empty():
			var impact := _action_fact(context, "element_hit")
			impact.element = element.element_id
			impact.position = point
			impact.target_handle = handle
			action_presented.emit(impact)
		elements.on_direct_hit(self, context, target, hit.poise_basis)
	if hit.valid_hit and consumes and _context_live(context):
		context.shatters = int(context.get("shatters", 0)) + 1
		statuses.remove(target, shatter.status_id)
	if hit.valid_hit and result.bonus > 0.0 and _context_live(context):
		var fact := _action_fact(context, "conditional_damage")
		fact.position = point
		fact.target_handle = handle
		fact.origin = origin
		fact.bonus = result.bonus
		fact.base_damage = amount
		fact.damage = result.damage
		fact.applied_damage = hit.health_loss
		fact.effect_ids = result.effect_ids
		fact.room_generation = context.room_generation
		Resolver.freeze(fact)
		_pending_conditionals.append(fact)
	return hit

func _damage_request(context: Dictionary, basis: float, origin: String, derived_id: String = "") -> Dictionary:
	var request: Dictionary = context.damage_request.duplicate(true)
	request.components[0].basis = basis
	request.root_id = context.id
	request.runtime = weakref(self)
	request.runtime_id = get_instance_id()
	request.room_generation = context.room_generation
	request.origin = origin
	request.event_id = _next_event
	if not derived_id.is_empty():
		var profile: Dictionary = _player.attribute_catalog.profile(derived_id)
		if profile.damage_type != "inherit_parent": request.components[0].type = profile.damage_type
		if profile.crit_policy == "never": request.critical = false
		request.profile_id = derived_id
	return request

func apply_element_damage(context: Dictionary, target, profile_id: String, amount: float) -> Dictionary:
	var owner = context.damage_request.source.get_ref()
	if owner == null or not owner.health.alive() or context.room_generation != _room_generation: return {"valid_hit": false}
	var profile: Dictionary = owner.attribute_catalog.profile(profile_id)
	var growth := Damage.Formula.elemental_growth(owner.attribute_catalog, owner.attributes.final, owner.attributes.base)
	var request := Damage.request(owner, profile_id, amount * growth, context.id, context.action_id)
	_next_event += 1
	request.runtime = weakref(self)
	request.runtime_id = get_instance_id()
	request.room_generation = context.room_generation
	request.event_id = _next_event
	request.origin = profile_id
	request.allows_on_hit = profile.allows_element_retrigger
	return Damage.submit(target, request)

func _flush_conditional_facts() -> void:
	# Publish after this step's committed contact/status work; never feed presentation
	# back into damage. Clearing rooms from a listener invalidates remaining old facts.
	var pending := _pending_conditionals
	_pending_conditionals = []
	for fact in pending:
		if fact.room_generation != _room_generation: continue
		_conditional_hits += 1
		_last_conditional = fact.duplicate(true)
		conditional_damage_applied.emit(fact)
