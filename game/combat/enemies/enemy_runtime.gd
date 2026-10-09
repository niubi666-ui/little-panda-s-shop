extends RefCounted
## Owns local auras and swept projectiles. No JSON access, scene paths, or inventory.
const Damage = preload("res://combat/effects/damage_executor.gd")
const Melee = preload("res://combat/ai/melee_brain.gd")
const Crossbow = preload("res://combat/enemies/crossbow_brain.gd")
const Charger = preload("res://combat/enemies/charger_brain.gd")
const Banner = preload("res://combat/enemies/banner_brain.gd")
const Ranger = preload("res://combat/enemies/ranger_brain.gd")
const ChargedRifts = preload("res://combat/enemies/charged_rifts.gd")
var charged_rifts := ChargedRifts.new()
var _target_before_motion := Vector3.ZERO
var _has_motion_sample := false
signal confirmed_hit(source, target, damage: float)
## Facts consumed by local presentation; these signals do not choose or resolve hits.
signal projectile_spawned(projectile: Dictionary)
signal projectile_finished(id: int, point: Vector3, direction: Vector3, source_handle: int, reason: String)
signal rain_started(rain: Dictionary)
signal rain_pulsed(id: int, center: Vector3, source_handle: int, pulse_index: int, last: bool)
signal actor_attacks_removed(handle: int)
signal attacks_cleared
var brains: Array = []
var profiles: Dictionary = {}
var projectiles: Array = []
var target
var target_radius: float
var origin: Callable
var sweep_world: Callable
var _next_projectile := 0
var _control_hooks: Dictionary = {}
var rains: Array = []
var _volley_hits: Dictionary = {}
var _next_rain := 0
func configure(player, radius: float, query_origin: Callable, sweep: Callable) -> void:
	target = player
	target_radius = radius
	origin = query_origin
	sweep_world = sweep
func add(actor, profile: Dictionary, route: Callable, sight: Callable, safe_motion: Callable, ranger_queries: Dictionary = {}):
	var brain
	match profile.role:
		"melee":
			brain = Melee.new(actor, target)
			brain.configure_navigation(route, sight)
		"ranged":
			brain = Crossbow.new()
			brain.configure(actor, target, profile.config, route, sight, safe_motion)
			brain.shot_requested.connect(_shoot)
		"charger":
			brain = Charger.new()
			brain.configure(actor, target, profile.config, route, sight, safe_motion)
			brain.impact.connect(_impact)
		"support":
			brain = Banner.new()
			brain.configure(actor, target, profile.config, route, sight, safe_motion)
		"ranger":
			actor.hit_reaction_immune = profile.config.hit_reaction_immune
			brain = Ranger.new()
			brain.configure(actor, target, profile.config, route, sight, safe_motion)
			var queries := ranger_queries.duplicate()
			queries.rain_admission = func(source, point, settings): return _can_start_rain(source, point, settings, ranger_queries.ground, ranger_queries.rain_escape)
			queries.rain_busy = func(source): return rains.any(func(rain): return rain.source == source)
			queries.charged_admission = func(settings): return charged_rifts.items.size()<int(settings.charged_rift_max_areas)
			brain.configure_queries(queries)
			brain.shot_requested.connect(_shoot)
			brain.rain_requested.connect(_rain)
		_: assert(false, "Unimplemented validated role")
	var brain_ref: WeakRef = weakref(brain)
	var hook := func():
		var current = brain_ref.get_ref()
		if current != null: current.cancel()
	_control_hooks[actor.handle] = hook
	actor.control_interrupted.connect(hook)
	profiles[actor.handle] = profile
	brains.append(brain)
	return brain
func update_auras() -> void:
	for recipient in brains:
		var actor = recipient.actor
		actor.enemy_move_multiplier = 1.0
		actor.enemy_attack_multiplier = 1.0
		actor.aura_active = false
		if not actor.health.alive(): continue
		for emitter in brains:
			if emitter == recipient or not emitter.actor.health.alive() or emitter.actor.control_locked or profiles[emitter.actor.handle].role != "support": continue
			var settings: Dictionary = profiles[emitter.actor.handle].config
			if actor.global_position.distance_to(emitter.actor.global_position) <= settings.aura_radius_m:
				actor.enemy_move_multiplier = maxf(actor.enemy_move_multiplier, 1.0 + settings.move_speed_bonus)
				actor.enemy_attack_multiplier = maxf(actor.enemy_attack_multiplier, 1.0 + settings.attack_speed_bonus)
				actor.aura_active = true
func before_motion(delta: float) -> void:
	_target_before_motion=origin.call(target)
	_has_motion_sample=true
	update_auras()
	for brain in brains: brain.tick(delta)
func after_motion(delta: float) -> void:
	if delta<=0.0:return
	for brain in brains.duplicate():
		if brain is Charger: brain.after_motion(target_radius)
	if not target.health.alive(): return
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		if not is_instance_valid(p.source) or not p.source.health.alive():
			projectile_finished.emit(p.id,p.position,p.direction,p.source.handle if is_instance_valid(p.source) else 0,"cancelled")
			projectiles.remove_at(i)
			continue
		var step_time := minf(delta, p.life)
		var from: Vector3 = p.position
		var to: Vector3 = from + p.direction * p.config.projectile_speed_mps * step_time
		var fraction: float = sweep_world.call(from, to, p.config.projectile_radius_m)
		var end := from.lerp(to, fraction)
		var center: Vector3 = origin.call(target)
		var closest := Geometry3D.get_closest_point_to_segment(center, from, end)
		var hit: bool = target.health.alive() and closest.distance_to(center) <= target_radius + p.config.projectile_radius_m
		var charged: bool=p.config.get("charged",false)
		if charged:
			var previous: Vector3=_target_before_motion if _has_motion_sample else center
			var end_center:=previous.lerp(center,clampf(step_time*fraction/maxf(delta,0.000001),0,1))
			var relative:=Geometry3D.get_closest_point_to_segment(Vector3.ZERO,from-previous,end-end_center)
			hit=not p.contact and relative.length()<=target_radius+p.config.projectile_radius_m
			if hit:p.contact=true
		var volley: String = p.config.get("volley_id", "")
		if hit and (volley.is_empty() or not _volley_hits.has(volley)):
			var applied := _impact(p.source, target, p.config.damage, p.direction, 0.0, 0.0)
			if applied > 0.0 and not volley.is_empty(): _volley_hits[volley] = true
		p.finished=(hit and not charged) or fraction<1.0 or p.life<=step_time
		if p.finished:
			projectile_finished.emit(p.id,closest if hit and not charged else end,p.direction,p.source.handle,"hit" if hit and not charged else ("world" if fraction < 1.0 else "expired"))
		if not target.health.alive(): return
		p.life -= step_time
		p.position = end
		if (hit and not charged) or fraction < 1.0 or p.life <= 0.0: projectiles.remove_at(i)
	_has_motion_sample=false
	charged_rifts.step(delta,target,target_radius,origin,sweep_world,_impact)
	if not target.health.alive():return
	var active_volleys: Dictionary = {}
	for p in projectiles: active_volleys[p.config.get("volley_id", "")] = true
	for key in _volley_hits.keys():
		if not active_volleys.has(key): _volley_hits.erase(key)
	for i in range(rains.size() - 1, -1, -1):
		var rain: Dictionary = rains[i]
		if not is_instance_valid(rain.source) or not rain.source.health.alive():
			rains.remove_at(i)
			continue
		rain.time_left -= delta
		while rain.time_left <= 0.0 and rain.remaining > 0:
			rain.remaining -= 1
			rain.pulses += 1
			rain.time_left += rain.config.rain_interval_sec
			var offset: Vector3 = target.global_position - rain.center
			offset.y = 0.0
			if offset.length() <= rain.config.rain_radius_m + target_radius:
				_impact(rain.source, target, rain.config.rain_damage, Vector3.ZERO, 0.0, 0.0)
			rain_pulsed.emit(rain.id,rain.center,rain.source.handle,rain.pulses,rain.remaining==0)
			if not target.health.alive(): return
		if rain.remaining == 0: rains.remove_at(i)

func _rain(source, center: Vector3, settings: Dictionary) -> void:
	_next_rain += 1
	rains.append({"id":_next_rain,"source":source,"center":center,"launch":source.global_position + Vector3.UP * settings.arrow_height_m,"config":settings,"time_left":settings.rain_delay_sec - settings.rain_windup_sec,"remaining":int(settings.rain_pulses),"pulses":0})
	rain_started.emit(rains.back())

func _can_start_rain(source, center: Vector3, settings: Dictionary, ground: Callable, escape: Callable) -> bool:
	if not ground.call(center): return false
	var hazards: Array[Dictionary] = []
	for rain in rains:
		hazards.append({"center":rain.center,"radius":rain.config.rain_radius_m,"active":rain.pulses > 0})
	for brain in brains:
		if brain.actor == source or not brain is Ranger: continue
		if brain.state == "windup" and brain.attack_id == "rain":
			hazards.append({"center":brain.target_point,"radius":brain.config.rain_radius_m,"active":false})
	if hazards.size() >= int(settings.rain_max_areas): return false
	hazards.append({"center":center,"radius":settings.rain_radius_m,"active":false})
	return escape.call(hazards, settings)
func _shoot(source, direction: Vector3, settings: Dictionary) -> void:
	if settings.has("rift") and charged_rifts.items.size()>=int(settings.rift.max_areas):return
	_next_projectile += 1
	var position: Vector3 = origin.call(source)
	var launch_offset := Vector3.ZERO
	if settings.get("ranger_arrow", false):
		# Ground telegraphs describe planar travel; bow height is presentation only.
		direction.y = 0.0
		direction = direction.normalized()
		position = source.global_position
		position.y = origin.call(target).y
		launch_offset.y = source.global_position.y + settings.spawn_height_m - position.y
		var offset: Vector3 = direction * minf(settings.spawn_forward_m, settings.aim_distance_m / 2.0)
		if sweep_world.call(position, position + offset, settings.projectile_radius_m) < 1.0: return
		position += offset
	projectiles.append({"id":_next_projectile,"source":source,"position":position,"start_position":position,"visual_launch_offset":launch_offset,"direction":direction,"config":settings,"life":settings.projectile_lifetime_sec,"contact":false,"finished":false})
	if settings.has("rift"):charged_rifts.add(projectiles.back())
	projectile_spawned.emit(projectiles.back())
func _impact(source, victim, damage: float, direction: Vector3, speed: float, duration: float) -> float:
	if not victim.health.alive(): return 0.0
	var applied: float = Damage.apply(victim, damage, source.team)
	if applied > 0.0:
		victim.apply_knockback(direction, speed, duration)
		confirmed_hit.emit(source, victim, applied)
	return applied
func clear() -> void:
	for brain in brains:
		var hook: Callable = _control_hooks[brain.actor.handle]
		if brain.actor.control_interrupted.is_connected(hook): brain.actor.control_interrupted.disconnect(hook)
		brain.actor.forced_velocity = Vector3.ZERO
		brain.actor.enemy_move_multiplier = 1.0
		brain.actor.enemy_attack_multiplier = 1.0
		brain.actor.aura_active = false
	brains.clear()
	profiles.clear()
	_control_hooks.clear()
	projectiles.clear()
	charged_rifts.clear()
	_has_motion_sample=false
	rains.clear()
	_volley_hits.clear()
	attacks_cleared.emit()

func remove_actor(actor) -> void:
	for index in range(brains.size() - 1, -1, -1):
		if brains[index].actor != actor: continue
		brains[index].cancel()
		var hook: Callable = _control_hooks[actor.handle]
		if actor.control_interrupted.is_connected(hook): actor.control_interrupted.disconnect(hook)
		_control_hooks.erase(actor.handle)
		profiles.erase(actor.handle)
		brains.remove_at(index)
	projectiles = projectiles.filter(func(p): return p.source != actor)
	charged_rifts.remove_source(actor.handle)
	rains = rains.filter(func(r): return r.source != actor)
	actor_attacks_removed.emit(actor.handle)

func remove_dead() -> void:
	for index in range(brains.size() - 1, -1, -1):
		var actor = brains[index].actor
		if actor.health.alive(): continue
		var hook: Callable = _control_hooks[actor.handle]
		if actor.control_interrupted.is_connected(hook): actor.control_interrupted.disconnect(hook)
		_control_hooks.erase(actor.handle)
		profiles.erase(actor.handle)
		brains.remove_at(index)
		charged_rifts.remove_source(actor.handle)
		actor_attacks_removed.emit(actor.handle)
	# Enemy projectiles reference their source actor. Retire those of discarded corpses.
	projectiles = projectiles.filter(func(p): return is_instance_valid(p.source) and p.source.health.alive())

