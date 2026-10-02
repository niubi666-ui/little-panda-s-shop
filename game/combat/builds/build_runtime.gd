extends RefCounted
## Bounded, queued derived effects. Roots own snapshots and a shared request budget.
const Resolver = preload("res://combat/builds/build_resolver.gd")
const Factory = preload("res://combat/builds/projectile_factory.gd")
const Split = preload("res://combat/builds/projectile_split.gd")
const Statuses = preload("res://combat/status/status_runtime.gd")
var statuses := Statuses.new()
const Impact = preload("res://combat/builds/impact_effects.gd")
const Area = preload("res://combat/effects/area_damage.gd")
const Damage = preload("res://combat/effects/damage_executor.gd")
const Sweep = preload("res://combat/builds/build_sweep.gd")
signal damage_applied(source, target, applied_damage: float, origin: String)
signal area_emitted(center: Vector3, radius: float)
signal chain_emitted(points: PackedVector3Array)

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
	_program = resolver.resolve({})

func set_program(program: Dictionary) -> void:
	# Copy even a caller-owned program: subsequent caller mutation cannot alter a cast.
	_program = program.duplicate(true)
	Resolver.freeze(_program)

func on_committed(cast_id: int, ability_id: String) -> void:
	if not _source_alive(): return
	if _player.runner.cast_id != cast_id or _player.runner.ability.id != ability_id: return
	if _cast_roots.has(cast_id): return
	_next_root += 1
	_roots[_next_root] = {
		"id": _next_root, "cast_id": cast_id, "ability_id": ability_id,
		"room_generation": _room_generation, "source_handle": _player.handle, "team": _player.team,
		"program": _program, "base_damage": _player.runner.ability.damage,
		"damage": _player.runner.ability.damage * float(_program.damage_scale),
		"budget": int(_limits.root_effect_budget), "spawned": 0, "cue_seen": false,
		"impact_counts": {}, "chain_triggers": {},
	}
	_cast_roots[cast_id] = _next_root
	_reclaim_roots()

func on_cue(cast_id: int, ability_id: String) -> void:
	var context := _context_for_cast(cast_id)
	if context.is_empty() or context.ability_id != ability_id or context.cue_seen: return
	if not _source_alive() or not _player.runner.busy() or _player.runner.cast_id != cast_id: return
	context.cue_seen = true
	var direction: Vector3 = Sweep.planar_direction(_player.runner.direction)
	for effect in context.program.effects:
		if effect.type != "projectile": continue
		var params: Dictionary = effect.params
		_enqueue(context, Factory.initial(_catalog.projectile(params.projectile_id), _player.global_position, direction, float(context.damage) * float(params.damage_ratio)))

func fire_attack(attack_id: String, direction: Vector3) -> bool:
	if not _source_alive() or not _player.runner.actions_allowed or not _attack_ids.has(attack_id) or _cooldowns.has(attack_id) or direction.is_zero_approx(): return false
	var attack: Dictionary = _catalog.test_attack(attack_id)
	_next_root += 1
	var context := {"id": _next_root, "cast_id": -_next_root, "ability_id": attack_id,
		"room_generation": _room_generation, "source_handle": _player.handle, "team": _player.team,
		"program": _program, "base_damage": attack.damage, "damage": float(attack.damage) * float(_program.damage_scale),
		"budget": int(_limits.root_effect_budget), "spawned": 0, "cue_seen": true, "impact_counts": {}, "chain_triggers": {}}
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
	statuses.clear()
	_room_generation += 1
	_roots.clear()
	_cast_roots.clear()
	_queue.clear()
	_cooldowns.clear()
	_projectiles.clear()

func projectiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in _projectiles:
		var projectile: Dictionary = _projectiles[id]
		result.append({"id": id, "position": projectile.position, "direction": projectile.direction, "radius": projectile.radius, "definition_id": projectile.definition.id})
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
	_projectiles[_next_projectile] = projectile

func _advance_projectiles(delta: float) -> void:
	# Fixed snapshot: child projectiles begin travelling on the following simulation step.
	for id in _projectiles.keys():
		var projectile: Dictionary = _projectiles[id]
		if float(projectile.lifetime) <= 0.0:
			_projectiles.erase(id)
			continue
		var context: Dictionary = _roots[projectile.root_id]
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
		var contact := _first_contact(context, projectile, start, direction, distance, wall_blocked)
		if not contact.is_empty():
			var target = contact.target
			projectile.position = start + direction * float(contact.distance)
			projectile.lifetime -= float(contact.distance) / float(projectile.speed)
			var point: Vector3 = target.global_position
			var victim: int = target.handle
			var applied: float = Damage.apply(target, float(projectile.damage), context.team)
			_contact(context, {"origin": "direct_projectile" if int(projectile.generation) == 0 else "split_projectile", "parent_id": "projectile:%s" % id, "target_handle": victim, "position": point, "damage": projectile.damage})
			if context.room_generation != _room_generation: return
			if applied > 0.0:
				damage_applied.emit(_player, target, applied, "secondary_projectile")
				if context.room_generation != _room_generation: return
				_schedule_chains(context, target, applied, "secondary_projectile")
			_schedule_splits(context, projectile, target.handle)
			_projectiles.erase(id)
			continue
		projectile.position = finish
		projectile.lifetime -= step
		if wall_blocked or float(projectile.lifetime) <= 0.0: _projectiles.erase(id)

func _first_contact(context: Dictionary, projectile: Dictionary, start: Vector3, direction: Vector3, distance: float, wall_blocked: bool) -> Dictionary:
	var best: Dictionary = {}
	for target in _valid_targets(context):
		if projectile.excluded.has(target.handle): continue
		# A hurt point on the far side of a wall cannot be hit by the projectile's width.
		if wall_blocked and direction.dot(target.global_position - start) >= distance: continue
		var contact := Sweep.contact_distance(start, direction, distance, target.global_position, float(projectile.radius))
		if contact < 0.0 or (wall_blocked and contact >= distance): continue
		if best.is_empty() or contact < float(best.distance) or (contact == float(best.distance) and target.handle < best.target.handle):
			best = {"target": target, "distance": contact}
	return best

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
	if context.is_empty() or context.ability_id != ability_id: return
	_contact(context, {"origin": "direct_melee", "parent_id": "melee:%s" % cast_id, "target_handle": victim, "position": point, "damage": damage})

func _contact(context: Dictionary, fact: Dictionary) -> void:
	if context.room_generation != _room_generation: return
	for request in Impact.requests(context, fact): _enqueue(context, request)

func _area_step(context: Dictionary, request: Dictionary) -> void:
	if request.params.occlusion == "world_ray" and not _wall_query.is_valid():
		_rejected += 1
		return
	var plan := Area.plan(request.position, context.team, request.primary, request.damage, request.params, _targets.call(), _wall_query)
	area_emitted.emit(request.position, float(request.params.radius_m))
	for hit in plan:
		if context.room_generation != _room_generation: return
		var applied := Damage.apply(hit.target, hit.damage, context.team)
		if context.room_generation != _room_generation: return
		if applied > 0.0: damage_applied.emit(_player, hit.target, applied, "explosion")
	# Deliberately no contact/chain/status emission from area damage.

func _status_step(context: Dictionary, request: Dictionary) -> void:
	for target in _valid_targets(context):
		if target.handle != request.target_handle: continue
		statuses.apply(target, request.status_id, request.duration, {"source_handle": context.source_handle, "team": context.team, "root_id": context.id, "room_generation": context.room_generation, "ability_id": context.ability_id})
		return
