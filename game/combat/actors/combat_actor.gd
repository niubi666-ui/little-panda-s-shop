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
var _queued_action := ""
var _queued_frame := -1
var _buffer_left := 0.0
var _action_program: Dictionary = {}
var _action_abilities: Dictionary = {}
var _attack_queued: bool:
	get: return not _queued_action.is_empty()
var buffered_action_id: String:
	get: return _queued_action
var _dodge_requested := false
var _build_move_scale := 1.0
var _damage_immunity := false
var hit_reaction_immune := false
var enemy_move_multiplier := 1.0
var enemy_attack_multiplier := 1.0
var aura_active := false
var _cast_tempo := 1.0
var forced_velocity := Vector3.ZERO
func set_build_movement_multiplier(value: float) -> void:
	assert(is_finite(value) and value > 0.0)
	_build_move_scale = value
func clear_intents() -> void:
	_clear_attack_intent()
	_dodge_requested = false
func _clear_attack_intent() -> void:
	_queued_action = ""
	_queued_frame = -1
	_buffer_left = 0.0
func _age_attack_intent(delta: float) -> void:
	if _queued_action.is_empty(): return
	_buffer_left = maxf(0.0, _buffer_left - delta)
	if _buffer_left <= 0.0: _clear_attack_intent()
func set_action_program(actions: Dictionary, catalog: Catalog) -> bool:
	# Plans are already evaluated by combat/builds; reject malformed wiring before mutation.
	if not actions.has_all(["primary", "special", "skill"]): return false
	var decoded: Dictionary = {}
	for id in ["primary", "special", "skill"]:
		var plan: Dictionary = actions[id]
		for key in ["action_id", "form_id", "executor", "ability_ids", "projectile_id", "presentation_key", "revision"]:
			if not plan.has(key): return false
		if plan.action_id != id or plan.ability_ids.is_empty() or plan.executor not in ["melee", "projectile"]: return false
		var definitions: Array[Catalog.Ability] = []
		for ability_id in plan.ability_ids:
			if not catalog.has_ability(ability_id): return false
			definitions.append(catalog.ability(ability_id))
		decoded[id] = definitions
	_action_program = actions.duplicate(true)
	_freeze_plan(_action_program)
	_action_abilities = decoded
	# A form change keeps committed casts and independent action cooldowns, but drops old buffered intent.
	clear_intents()
	combo_index = 0
	combo_idle = 0.0
	return true
func _freeze_plan(value: Variant) -> void:
	if value is Dictionary:
		for child in value.values(): _freeze_plan(child)
		value.make_read_only()
	elif value is Array:
		for child in value: _freeze_plan(child)
		value.make_read_only()
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
	request_action("primary")
func request_skill() -> void:
	request_action("skill")
func request_special() -> void:
	request_action("special")
func request_action(id: String, input_frame: int = -1) -> void:
	if control_locked or health == null or not health.alive(): return
	var definitions := _abilities_for(id)
	if definitions.is_empty(): return
	var index := combo_index % definitions.size() if id == "primary" else 0
	var buffer_sec: float = definitions[index].buffer_sec
	if runner.cooldown_for(id) > buffer_sec: return
	var frame := Engine.get_process_frames() if input_frame < 0 else input_frame
	# Same rendered frame has a stable priority even if OS event order is reversed.
	var priorities := {"primary": 0, "special": 1, "skill": 2}
	if frame == _queued_frame and priorities.get(_queued_action, -1) > priorities.get(id, -1): return
	_queued_action = id
	_queued_frame = frame
	_buffer_left = buffer_sec
func _abilities_for(id: String) -> Array[Catalog.Ability]:
	if _action_abilities.has(id): return _action_abilities[id]
	if id == "primary": return attacks
	var empty: Array[Catalog.Ability] = []
	return empty
func request_dodge() -> void:
	if not control_locked and health != null and health.alive(): _dodge_requested = true
func set_damage_immunity(enabled: bool) -> void:
	_damage_immunity = enabled
func invulnerable() -> bool:
	return _damage_immunity or (dodge != null and dodge_left > 0.0 and dodge_age < dodge.invulnerable)
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
	if _dodge_requested and dodge != null and charges > 0 and dodge_left <= 0.0 and stagger_left <= 0.0 and runner.can_cancel_for_dodge():
		runner.cancel("dodge")
		_clear_attack_intent()
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
		_age_attack_intent(delta)
		return
	if not runner.busy():
		combo_idle += delta
		if combo_idle > definition.combo_reset: combo_index = 0
	if not _queued_action.is_empty() and stagger_left <= 0.0 and not runner.busy() and runner.cooldown_for(_queued_action) <= 0.0:
		var id := _queued_action
		var definitions := _abilities_for(id)
		var index := combo_index % definitions.size() if id == "primary" else 0
		var context: Dictionary = _action_program[id] if _action_program.has(id) else {}
		if runner.start(definitions[index], facing, context):
			_cast_tempo = enemy_attack_multiplier
			combo_index = (index + 1) % definitions.size() if id == "primary" else 0
			combo_idle = 0.0
			_clear_attack_intent()
	if not health.alive(): return
	runner.tick(delta * _cast_tempo)
	_age_attack_intent(delta)
	var move_multiplier := runner.ability.movement_multiplier if runner.busy() else 1.0
	if not forced_velocity.is_zero_approx() and stagger_left <= 0.0:
		motor.step(forced_velocity.normalized(), forced_velocity.length(), delta, false)
	else:
		motor.step(movement if stagger_left <= 0.0 else Vector3.ZERO, definition.speed * move_multiplier * _build_move_scale * enemy_move_multiplier, delta)
func receive_hit(amount: float) -> float:
	var applied := health.apply(amount, invulnerable())
	if applied > 0.0 and health.alive() and not hit_reaction_immune:
		if not runner.busy() or runner.ability.interruptible:
			stagger_left = definition.stagger
			runner.cancel("hit")
			_clear_attack_intent()
	return applied
func apply_knockback(direction: Vector3, speed: float, duration: float) -> void:
	if health.alive() and not hit_reaction_immune: motor.knockback(direction, speed, duration)
func cancel(reason: String = "cancelled") -> void:
	motor.clear_impulse()
	runner.cancel(reason)
	clear_intents()
	movement = Vector3.ZERO
	forced_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
func _die() -> void:
	cancel("death")
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
		cancel("control")
		dodge_left = 0.0
		dodge_age = 0.0
		control_interrupted.emit()
