extends CharacterBody3D
const Catalog = preload("res://content/combat/combat_catalog.gd")
const Runner = preload("res://combat/abilities/ability_runner.gd")
const Health = preload("res://combat/actors/health_runtime.gd")
const Motor = preload("res://combat/actors/character_motor.gd")
enum BodyLayer { WORLD = 1, PLAYER = 2, ENEMY = 4 }
signal killed(actor)
signal control_interrupted
## 霸体被打破的一刻（表现层用来出声音和提示）
signal poise_broken(actor)
var control_locked := false
var control_move_scale := 1.0
var control_action_scale := 1.0
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
## 霸体：已累计的伤害、距上次受击的时间、破防剩余时间
var poise_taken := 0.0
var poise_idle := 0.0
var break_left := 0.0
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
var _roll_attack_queued := false
var _roll_attack_cast := -1
var _roll_attack_blocked := false
var roll_attack_start_age := 0.0
var roll_attack_link_duration := 0.0
var _roll_attack_carry_speed := 0.0
var melee_sweep_from := Vector3.ZERO
var _build_move_scale := 1.0
var _damage_immunity := false
var protection_amount := 0.0
var protection_left := 0.0
var charging_skill := false
var charge_elapsed := 0.0
var _charged_intent := false
var _charge_queued := false
func charge_parameters() -> Dictionary:
	if not _action_program.has("skill"): return {}
	for effect in _action_program.skill.effects:
		if effect.type == "charge_projectile": return effect.params
	return {}
func press_skill() -> void:
	if charging_skill or _charge_queued: return
	if not request_action("skill"): return
	if charge_parameters().is_empty(): return
	_charge_queued = true
	_try_begin_charge()
func release_skill() -> void:
	# 已松键的预输入变为一次普通施放，不在冷却结束后误入持续蓄力。
	if _charge_queued:
		_charge_queued = false
		return
	if not charging_skill: return
	var p := charge_parameters()
	var charged := not p.is_empty() and charge_elapsed >= float(p.threshold_sec)
	charging_skill = false
	if p.is_empty(): return
	if request_action("skill"): _charged_intent = charged
func _try_begin_charge() -> void:
	if not _charge_queued or not _can_start_queued_action(): return
	if runner.busy(): runner.cancel("chain")
	# 可以在翻滚中积累蓄力；翻滚姿势仍优先，冷却等待时间不计入蓄力。
	charging_skill = true
	charge_elapsed = 0.0
	_clear_attack_intent()
func grant_protection(amount: float, duration: float) -> void:
	if not health.alive(): return
	protection_amount = amount
	protection_left = duration
func clear_protection() -> void:
	protection_amount = 0.0
	protection_left = 0.0
func tick_protection(delta: float) -> void:
	protection_left = maxf(0.0, protection_left - delta)
	if protection_left <= 0.0: clear_protection()
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
	charging_skill = false
	charge_elapsed = 0.0
	_clear_attack_intent()
	_dodge_requested = false
func _clear_attack_intent() -> void:
	_roll_attack_queued = false
	_charged_intent = false
	_charge_queued = false
	_queued_action = ""
	_queued_frame = -1
	_buffer_left = 0.0
func _age_attack_intent(delta: float) -> void:
	if _queued_action.is_empty(): return
	# 翻滚中按下的技能保留到翻滚结束，之后才消耗通常的预输入窗口。
	if _queued_action == "skill" and dodge_left > 0.0: return
	# 冲斩途中点下的下一刀保留到完整挥砍结束；末次扫掠结算后再接普攻。
	if _queued_action == "primary" and is_roll_attack_cast() and (runner.busy() or runner.active_this_step): return
	_buffer_left = maxf(0.0, _buffer_left - delta)
	if _buffer_left <= 0.0:
		# 若这一帧刚完成上一招的末次判定，留到下帧接招，避免清掉有效输入或吞掉旧判定。
		if _queued_action == "skill" and runner.active_this_step and _can_start_queued_action(): return
		_clear_attack_intent()
func set_action_program(actions: Dictionary, catalog: Catalog) -> bool:
	# Plans are already evaluated by combat/builds; reject malformed wiring before mutation.
	if not actions.has_all(["primary", "special", "skill"]): return false
	var decoded: Dictionary = {}
	for id in ["primary", "special", "skill"]:
		var plan: Dictionary = actions[id]
		for key in ["action_id", "form_id", "executor", "ability_ids", "projectile_id", "presentation_key", "revision", "reach_scale"]:
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
## 当前出招的攻击范围倍率（构筑卡“长刃/横扫千军”）；敌人没有动作构筑，为 1
func reach_scale() -> float:
	if not _action_program.has(runner.action_id): return 1.0
	return float(_action_program[runner.action_id].reach_scale)
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
	runner.cue_reached.connect(_on_cue_reached)
	health.died.connect(_die)
## 出手瞬间的前冲由技能配置决定（lunge_speed_mps / lunge_duration_sec），速度为 0 时不推。
func _on_cue_reached(_cast_id: int, _ability_id: String) -> void:
	if health.alive() and runner.ability.lunge_speed > 0.0:
		motor.push(runner.direction, runner.ability.lunge_speed, runner.ability.lunge_duration)
func request_attack() -> void:
	request_action("primary")
func request_skill() -> void:
	request_action("skill")
func request_special() -> void:
	request_action("special")
func request_action(id: String, input_frame: int = -1) -> bool:
	if control_locked or health == null or not health.alive(): return false
	var definitions := _abilities_for(id)
	if definitions.is_empty(): return false
	# 左键是明确的取消意图，即便这次普攻本身还在冷却也不留下待发剑气。
	var cancel_skill := id == "primary" and (_queued_action == "skill" or charging_skill)
	if cancel_skill:
		charging_skill = false
		charge_elapsed = 0.0
		_clear_attack_intent()
	var index := combo_index % definitions.size() if id == "primary" else 0
	var roll_attack := id == "primary" and dodge != null and dodge_left > 0.0
	var buffer_sec: float = dodge.attack.buffer_sec if roll_attack else definitions[index].buffer_sec
	var wait_sec := buffer_sec + (dodge_left if id == "skill" else 0.0)
	var cooldown := runner.cooldown_for(id)
	if not roll_attack and cooldown > wait_sec and not is_equal_approx(cooldown, wait_sec): return false
	var frame := Engine.get_process_frames() if input_frame < 0 else input_frame
	# 左键后按时可明确取消待发剑气；其余动作仍保留原来的同帧优先级。
	var priorities := {"primary": 0, "special": 1, "skill": 2}
	if not cancel_skill and frame == _queued_frame and priorities.get(_queued_action, -1) > priorities.get(id, -1): return false
	charging_skill = false
	charge_elapsed = 0.0
	_charge_queued = false
	_queued_action = id
	_roll_attack_queued = roll_attack
	_charged_intent = false
	_queued_frame = frame
	_buffer_left = buffer_sec
	return true

func _can_start_queued_action() -> bool:
	return not _queued_action.is_empty() and health.alive() and not control_locked and stagger_left <= 0.0 and (not runner.busy() or runner.can_chain()) and runner.cooldown_for(_queued_action) <= 0.0

func _start_buffered_action() -> void:
	if not _can_start_queued_action(): return
	if _charge_queued:
		_try_begin_charge()
		return
	if dodge_left > 0.0: return
	var id := _queued_action
	if runner.busy(): runner.cancel("chain")
	var definitions := _abilities_for(id)
	var index := combo_index % definitions.size() if id == "primary" else 0
	var context: Dictionary = _action_program[id] if _action_program.has(id) else {}
	if runner.start(definitions[index], facing, context, _charged_intent):
		_cast_tempo = enemy_attack_multiplier
		combo_index = (index + 1) % definitions.size() if id == "primary" else 0
		combo_idle = 0.0
		_clear_attack_intent()

func _resume_buffered_skill() -> void:
	# 冷却归零/翻滚结束的本帧即可接技能，不让计时到期先清掉输入。
	if _queued_action == "skill" and not runner.active_this_step:
		_start_buffered_action()
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

func is_roll_attack_cast() -> bool:
	return dodge != null and runner.cast_id == _roll_attack_cast and runner.ability != null and runner.ability.id == dodge.attack.id and runner.action_id == "primary"

func roll_attack_finishing_roll() -> bool:
	return is_roll_attack_cast() and runner.busy() and runner.elapsed < roll_attack_link_duration

func roll_attack_roll_age() -> float:
	return roll_attack_start_age + minf(runner.elapsed, roll_attack_link_duration) * dodge.attack_roll_playback_speed

func _roll_attack_distance_at(elapsed: float) -> float:
	var windup := runner.ability.windup
	var carry := _roll_attack_carry_speed * windup
	if elapsed <= windup: return _roll_attack_carry_speed * maxf(0.0, elapsed)
	var t := clampf((elapsed - windup) / dodge.attack_duration, 0.0, 1.0)
	var remaining := dodge.attack_distance - carry
	# Hermite: keep the carry velocity at the join, accelerate into the cut, settle to zero.
	var tangent := _roll_attack_carry_speed * dodge.attack_duration
	return carry + remaining * (3.0*t*t - 2.0*t*t*t) + tangent * (t*t*t - 2.0*t*t + t)

func _start_roll_attack() -> void:
	if not _roll_attack_queued or _queued_action != "primary" or dodge_left <= 0.0 or stagger_left > 0.0: return
	var context: Dictionary = _action_program["primary"] if _action_program.has("primary") else {}
	# Preserve the exact primary build snapshot; only the animation/ability changes.
	if not context.is_empty() and context.executor != "melee": return
	runner.cancel("roll_attack")
	_roll_attack_cast = runner.cast_id + 1
	_roll_attack_blocked = false
	roll_attack_start_age = dodge_age
	roll_attack_link_duration = maxf(0.0, dodge.duration * dodge.attack_roll_exit_fraction - dodge_age) / dodge.attack_roll_playback_speed
	var attack := dodge.attack.with_windup(roll_attack_link_duration + dodge.attack.windup)
	_roll_attack_carry_speed = minf(dodge.attack_carry_speed, dodge.attack_distance * dodge.attack_carry_distance_ratio / attack.windup)
	if runner.start(attack, facing, context, false, true):
		dodge_left = 0.0
		dodge_age = 0.0
		motor.clear_impulse()
		_cast_tempo = enemy_attack_multiplier
		combo_index = 0
		combo_idle = 0.0
		_clear_attack_intent()
	else:
		_roll_attack_cast = -1

func step(delta: float) -> void:
	if not health.alive() or delta <= 0.0: return
	melee_sweep_from = global_position
	if charging_skill:
		charge_elapsed = minf(charge_elapsed + delta, float(charge_parameters().max_charge_sec))
	if control_locked:
		clear_intents()
		return
	stagger_left = maxf(0.0, stagger_left - delta)
	if definition.poise > 0.0:
		break_left = maxf(0.0, break_left - delta)
		poise_idle += delta
		if poise_idle >= definition.poise_recover_sec: poise_taken = 0.0
	if dodge != null and charges < dodge.charges:
		recharge_left -= delta
		while recharge_left <= 0.0 and charges < dodge.charges:
			charges += 1
			recharge_left += dodge.recharge
	if _dodge_requested and dodge != null and charges > 0 and dodge_left <= 0.0 and stagger_left <= 0.0 and runner.can_cancel_for_dodge():
		charging_skill = false
		runner.cancel("dodge")
		_clear_attack_intent()
		if charges == dodge.charges: recharge_left = dodge.recharge
		charges -= 1
		dodge_left = dodge.duration
		dodge_age = 0.0
		dodge_direction = movement.normalized() if not movement.is_zero_approx() else facing
	_dodge_requested = false
	_start_roll_attack()
	if dodge_left > 0.0:
		var buffer_delta := maxf(0.0, delta - dodge_left) if _queued_action == "skill" else delta
		# 强制翻滚位移结束即交还移动；起身姿势和冲斩窗口继续，不再锁方向键。
		var moving_delta := clampf(dodge.movement_duration - dodge_age, 0.0, delta)
		var travel := dodge_direction * dodge.speed * moving_delta
		if stagger_left <= 0.0:
			var free_velocity := forced_velocity if not forced_velocity.is_zero_approx() else movement * definition.speed * _build_move_scale * enemy_move_multiplier
			travel += free_velocity * (delta - moving_delta)
		dodge_left = maxf(0.0, dodge_left - delta)
		dodge_age += delta
		motor.step(travel.normalized(), travel.length() / delta, delta, forced_velocity.is_zero_approx())
		runner.tick(delta)
		_resume_buffered_skill()
		_age_attack_intent(buffer_delta)
		return
	if not runner.busy():
		combo_idle += delta
		if combo_idle > definition.combo_reset: combo_index = 0
	_start_buffered_action()
	if not health.alive(): return
	var before := runner.elapsed
	runner.tick(delta * _cast_tempo * control_action_scale)
	_resume_buffered_skill()
	_age_attack_intent(delta)
	if is_roll_attack_cast() and (runner.busy() or runner.active_this_step):
		# Integrate distance over the actual timeline interval, including partial boundary frames.
		var distance := _roll_attack_distance_at(runner.elapsed) - _roll_attack_distance_at(before)
		motor.travel(Vector3.ZERO if _roll_attack_blocked else runner.direction * distance, delta)
		_roll_attack_blocked = _roll_attack_blocked or motor.blocked
		return
	var move_multiplier := runner.ability.movement_multiplier if runner.busy() else 1.0
	if not forced_velocity.is_zero_approx() and stagger_left <= 0.0:
		motor.step(forced_velocity.normalized(), forced_velocity.length(), delta, false)
	else:
		motor.step(movement if stagger_left <= 0.0 else Vector3.ZERO, definition.speed * move_multiplier * _build_move_scale * enemy_move_multiplier, delta)
## 带霸体且未破防：受击不硬直、不被击退，伤害累计到霸体值时破防
func armored() -> bool:
	return definition.poise > 0.0 and break_left <= 0.0
func receive_hit(amount: float) -> float:
	if not health.alive() or invulnerable() or amount <= 0.0: return 0.0
	if break_left > 0.0: amount *= definition.break_damage_scale
	var absorbed := minf(protection_amount, amount)
	protection_amount -= absorbed
	amount -= absorbed
	var applied := health.apply(amount, invulnerable())
	if applied > 0.0 and health.alive() and not hit_reaction_immune:
		if armored():
			poise_taken += applied
			poise_idle = 0.0
			if poise_taken >= definition.poise: _break_poise()
		else:
			charging_skill = false
			if not runner.busy() or runner.ability.interruptible:
				stagger_left = maxf(stagger_left, definition.stagger)
				runner.cancel("hit")
				_clear_attack_intent()
	return applied
## 额外的破防值（例如土元素）：只对未破防的霸体生效
func add_poise_damage(amount: float) -> void:
	if not health.alive() or not armored() or amount <= 0.0: return
	poise_taken += amount
	poise_idle = 0.0
	if poise_taken >= definition.poise: _break_poise()
func _break_poise() -> void:
	poise_taken = 0.0
	break_left = definition.break_duration_sec
	stagger_left = maxf(stagger_left, definition.break_stagger_sec)
	charging_skill = false
	runner.cancel("break")
	_clear_attack_intent()
	poise_broken.emit(self)
func apply_knockback(direction: Vector3, speed: float, duration: float) -> void:
	if health.alive() and not hit_reaction_immune and not armored(): motor.knockback(direction, speed, duration)
func cancel(reason: String = "cancelled") -> void:
	motor.clear_impulse()
	runner.cancel(reason)
	clear_intents()
	movement = Vector3.ZERO
	forced_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
func _die() -> void:
	clear_protection()
	cancel("death")
	set_control(1.0, false)
	collision_layer = 0
	collision_mask = 0
	killed.emit(self)

func set_control(move_scale: float, locked: bool, action_scale: float = 1.0) -> void:
	control_action_scale = action_scale if health.alive() else 1.0
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
