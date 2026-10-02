extends RefCounted
## Owns local auras and swept projectiles. No JSON access, scene paths, or inventory.
const Damage = preload("res://combat/effects/damage_executor.gd")
const Melee = preload("res://combat/ai/melee_brain.gd")
const Crossbow = preload("res://combat/enemies/crossbow_brain.gd")
const Charger = preload("res://combat/enemies/charger_brain.gd")
const Banner = preload("res://combat/enemies/banner_brain.gd")
signal confirmed_hit(source, target, damage: float)
var brains: Array = []
var profiles: Dictionary = {}
var projectiles: Array = []
var target
var target_radius: float
var origin: Callable
var sweep_world: Callable
var _next_projectile := 0
var _control_hooks: Dictionary = {}
func configure(player, radius: float, query_origin: Callable, sweep: Callable) -> void:
	target = player
	target_radius = radius
	origin = query_origin
	sweep_world = sweep
func add(actor, profile: Dictionary, route: Callable, sight: Callable, safe_motion: Callable):
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
	update_auras()
	for brain in brains: brain.tick(delta)
func after_motion(delta: float) -> void:
	for brain in brains.duplicate():
		if brain is Charger: brain.after_motion(target_radius)
	if not target.health.alive(): return
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		var step_time := minf(delta, p.life)
		var from: Vector3 = p.position
		var to: Vector3 = from + p.direction * p.config.projectile_speed_mps * step_time
		var fraction: float = sweep_world.call(from, to, p.config.projectile_radius_m)
		var end := from.lerp(to, fraction)
		var center: Vector3 = origin.call(target)
		var closest := Geometry3D.get_closest_point_to_segment(center, from, end)
		var hit: bool = target.health.alive() and closest.distance_to(center) <= target_radius + p.config.projectile_radius_m
		if hit: _impact(p.source, target, p.config.damage, p.direction, 0.0, 0.0)
		if not target.health.alive(): return
		p.life -= step_time
		p.position = end
		if hit or fraction < 1.0 or p.life <= 0.0: projectiles.remove_at(i)
func _shoot(source, direction: Vector3, settings: Dictionary) -> void:
	_next_projectile += 1
	projectiles.append({"id":_next_projectile,"source":source,"position":origin.call(source),"direction":direction,"config":settings,"life":settings.projectile_lifetime_sec})
func _impact(source, victim, damage: float, direction: Vector3, speed: float, duration: float) -> void:
	if not victim.health.alive(): return
	var applied: float = Damage.apply(victim, damage, source.team)
	if applied > 0.0:
		victim.apply_knockback(direction, speed, duration)
		confirmed_hit.emit(source, victim, applied)
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

