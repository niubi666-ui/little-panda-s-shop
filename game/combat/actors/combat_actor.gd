extends CharacterBody3D
const Catalog = preload("res://content/combat/combat_catalog.gd")
const Runner = preload("res://combat/abilities/ability_runner.gd")
const Health = preload("res://combat/actors/health_runtime.gd")
const Motor = preload("res://combat/actors/character_motor.gd")
enum BodyLayer { WORLD = 1, PLAYER = 2, ENEMY = 4 }
signal killed(actor)
signal control_interrupted
var control_locked := false
var control_move_scale := 1.0
var definition: Catalog.Actor
var health: Health
var runner := Runner.new()
var motor: Motor
var attacks: Array[Catalog.Ability] = []
var dodge: Catalog.Dodge
var handle: int
var team: int
var facing := Vector3.FORWARD
var movement := Vector3.ZERO
var stagger_left := 0.0
var dodge_left := 0.0
var dodge_age := 0.0
var dodge_direction := Vector3.ZERO
var charges := 0
var recharge_left := 0.0
var combo_index := 0
var combo_idle := 0.0
var _attack_queued := false
var _dodge_requested := false
var _build_move_scale := 1.0
var enemy_move_multiplier := 1.0
var enemy_attack_multiplier := 1.0
var aura_active := false
var _cast_tempo := 1.0
var forced_velocity := Vector3.ZERO
func set_build_movement_multiplier(value: float) -> void:
	assert(is_finite(value) and value > 0.0)
	_build_move_scale = value
func clear_intents() -> void:
	_attack_queued = false
	_dodge_requested = false
func configure(actor_def: Catalog.Actor, ability_defs: Array[Catalog.Ability], dodge_def: Catalog.Dodge, actor_handle: int, faction: int) -> void:
	definition = actor_def
	attacks = ability_defs
	dodge = dodge_def
	handle = actor_handle
	team = faction
	# Enemy bodies never block one another; world and opposing bodies still do.
	collision_layer = BodyLayer.PLAYER if team == 0 else BodyLayer.ENEMY
	collision_mask = BodyLayer.WORLD | (BodyLayer.ENEMY if team == 0 else BodyLayer.PLAYER)
	health = Health.new(definition.health)
	motor = Motor.new(self)
	if dodge != null: charges = dodge.charges
	health.died.connect(_die)
func request_attack() -> void:
	if not control_locked: _attack_queued = true
func request_dodge() -> void:
	if not control_locked: _dodge_requested = true
func invulnerable() -> bool:
	return dodge != null and dodge_left > 0.0 and dodge_age < dodge.invulnerable
func step(delta: float) -> void:
	if not health.alive(): return
	if control_locked:
		clear_intents()
		return
	stagger_left = maxf(0.0, stagger_left - delta)
	if dodge != null and charges < dodge.charges:
		recharge_left -= delta
		while recharge_left <= 0.0 and charges < dodge.charges:
			charges += 1
			recharge_left += dodge.recharge
	if _dodge_requested and dodge != null and charges > 0 and dodge_left <= 0.0 and stagger_left <= 0.0:
		runner.cancel()
		_attack_queued = false
		if charges == dodge.charges: recharge_left = dodge.recharge
		charges -= 1
		dodge_left = dodge.duration
		dodge_age = 0.0
		dodge_direction = movement.normalized() if not movement.is_zero_approx() else facing
	_dodge_requested = false
	if dodge_left > 0.0:
		dodge_left = maxf(0.0, dodge_left - delta)
		dodge_age += delta
		motor.step(dodge_direction, dodge.speed, delta)
		runner.tick(delta)
		return
	if not runner.busy():
		combo_idle += delta
		if combo_idle > definition.combo_reset: combo_index = 0
	if _attack_queued and not attacks.is_empty() and stagger_left <= 0.0 and not runner.busy() and runner.cooldown <= 0.0:
		if runner.start(attacks[combo_index], facing):
			_cast_tempo = enemy_attack_multiplier
			combo_index = (combo_index + 1) % attacks.size()
			combo_idle = 0.0
			_attack_queued = false
	runner.tick(delta * _cast_tempo)
	var move_multiplier := runner.ability.movement_multiplier if runner.busy() else 1.0
	if not forced_velocity.is_zero_approx() and stagger_left <= 0.0:
		motor.step(forced_velocity.normalized(), forced_velocity.length(), delta, false)
	else:
		motor.step(movement if stagger_left <= 0.0 else Vector3.ZERO, definition.speed * move_multiplier * _build_move_scale * enemy_move_multiplier, delta)
func receive_hit(amount: float) -> float:
	var applied := health.apply(amount, invulnerable())
	if applied > 0.0 and health.alive():
		if not runner.busy() or runner.ability.interruptible:
			stagger_left = definition.stagger
			runner.cancel()
			_attack_queued = false
	return applied
func apply_knockback(direction: Vector3, speed: float, duration: float) -> void:
	if health.alive(): motor.knockback(direction, speed, duration)
func cancel() -> void:
	motor.clear_impulse()
	runner.cancel()
	_attack_queued = false
	_dodge_requested = false
	movement = Vector3.ZERO
	forced_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
func _die() -> void:
	cancel()
	set_control(1.0, false)
	collision_layer = 0
	collision_mask = 0
	killed.emit(self)

func set_control(move_scale: float, locked: bool) -> void:
	var interrupt := locked and not control_locked and health.alive()
	control_locked = locked and health.alive()
	control_move_scale = move_scale if health.alive() else 1.0
	motor.control_scale = control_move_scale
	motor.control_locked = control_locked
	runner.actions_allowed = not control_locked and health.alive()
	if interrupt:
		cancel()
		dodge_left = 0.0
		dodge_age = 0.0
		control_interrupted.emit()
