extends SceneTree
## Focused action arbitration tests. The real bound Build program is integration-tested separately.
const Loader = preload("res://content/combat/combat_loader.gd")
const Catalog = preload("res://content/combat/combat_catalog.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const Runner = preload("res://combat/abilities/ability_runner.gd")
const Resolver = preload("res://combat/effects/melee_resolver.gd")
const InputAdapter = preload("res://presentation/combat/combat_input.gd")
const View = preload("res://presentation/combat/actor_view.gd")
const Style = preload("res://presentation/combat/training_style.tres")
var failures: Array[String] = []
var _catalog: Catalog
var _next_handle := 0
var _cues := 0
var _contacts := 0
var _finished: Array[String] = []


func _initialize() -> void: run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func run() -> void:
	var loader := Loader.new()
	_catalog = loader.load_catalog()
	check(_catalog != null, "combat schema 3 loads")
	if _catalog == null:
		print(loader.errors)
		quit(1)
		return
	check_schema()
	check_priority()
	check_combo_and_cooldowns()
	check_buffer()
	check_cancellation()
	check_projectile_execution()
	check_snapshots()
	check_motion_resources()
	await check_focus()
	print("DUAL_ACTIONS ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)


func _plans(wave: bool = false, revision: int = 1) -> Dictionary:
	return {
		"primary": {"action_id": "primary", "form_id": "sword_primary", "executor": "melee", "ability_ids": ["slash.1", "slash.2", "slash.3"], "projectile_id": "", "presentation_key": "sword_primary", "revision": revision},
		"special": {"action_id": "special", "form_id": "sword_wave" if wave else "sword_heavy", "executor": "projectile" if wave else "melee", "ability_ids": ["wave_cast" if wave else "heavy_slash"], "projectile_id": "sword_wave" if wave else "", "presentation_key": "wave_cast" if wave else "heavy_slash", "revision": revision},
	}


func _actor(player: bool = true) -> Actor:
	var actor := Actor.new()
	var definition: Catalog.Actor = _catalog.player() if player else _catalog.actor("brute")
	var abilities: Array[Catalog.Ability] = []
	for id in definition.attacks: abilities.append(_catalog.ability(id))
	_next_handle += 1
	actor.configure(definition, abilities, _catalog.dodge() if player else null, _next_handle, 0 if player else 1)
	root.add_child(actor)
	if player: check(actor.set_action_program(_plans(), _catalog), "base dual-action plan installs")
	return actor


func _finish(actor: Actor) -> void:
	var ability := actor.runner.ability
	actor.runner.tick(maxf(ability.windup + ability.active + ability.recovery, actor.runner.cooldown) + 0.01)


func check_schema() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/prototype.json"))
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/schemas/combat_prototype.schema.json"))
	for defect in ["old_version", "buffer_missing", "buffer_negative", "phase_unknown", "phase_duplicate"]:
		var bad: Dictionary = data.duplicate(true)
		match defect:
			"old_version": bad.schema_version = 2
			"buffer_missing": bad.abilities[0].erase("buffer_sec")
			"buffer_negative": bad.abilities[0].buffer_sec = -1
			"phase_unknown": bad.abilities[0].dodge_cancel_phases = ["late"]
			"phase_duplicate": bad.abilities[0].dodge_cancel_phases = ["windup", "windup"]
		var validator := Loader.new()
		check(validator.decode(bad, schema, defect) == null and not validator.errors.is_empty(), "reject " + defect)
	check(_catalog.ability("heavy_slash").dodge_cancel_phases.is_read_only(), "cancel phases immutable")
	check(_catalog.ability("wave_cast").damage > 0, "projectile cast retains real ability damage")


func check_priority() -> void:
	for reversed_order in [false, true]:
		var actor := _actor()
		actor.request_action("special" if reversed_order else "primary", 10)
		actor.request_action("primary" if reversed_order else "special", 10)
		actor.step(0.01)
		check(actor.runner.action_id == "special" and actor.runner.ability.id == "heavy_slash", "same-frame special wins independent of event order")
		actor.free()
	var actor := _actor()
	actor.request_action("primary", 20)
	actor.request_action("special", 20)
	actor.request_dodge()
	actor.step(0.01)
	check(not actor.runner.busy() and actor.dodge_left > 0.0 and actor.buffered_action_id.is_empty(), "dodge wins and clears both attacks")
	actor.free()


func check_combo_and_cooldowns() -> void:
	var actor := _actor()
	for index in 3:
		actor.request_action("primary", 30 + index)
		actor.step(0.01)
		check(actor.runner.ability.id == "slash." + str(index + 1), "primary retains three-step combo " + str(index))
		_finish(actor)
	actor.request_action("primary", 34)
	actor.step(0.01)
	_finish(actor)
	check(actor.combo_index == 1, "primary combo advances")
	actor.request_action("special", 35)
	check(actor.combo_index == 1, "request alone does not reset primary")
	actor.step(0.01)
	check(actor.combo_index == 0, "actual special start resets primary")
	actor.runner.tick(_catalog.ability("heavy_slash").windup + _catalog.ability("heavy_slash").active + _catalog.ability("heavy_slash").recovery)
	check(not actor.runner.busy() and actor.runner.cooldown_for("special") > 0, "special has remaining independent cooldown")
	actor.request_action("primary", 36)
	actor.step(0.01)
	check(actor.runner.action_id == "primary" and actor.runner.ability.id == "slash.1", "special cooldown does not lock primary")
	actor.free()


func check_buffer() -> void:
	var actor := _actor()
	actor.request_action("primary", 40)
	actor.step(0.01)
	actor.runner.tick(0.11)
	actor.request_action("special", 41)
	actor.request_action("primary", 42)
	check(actor.buffered_action_id == "primary", "later valid primary replaces special buffer")
	actor.request_action("special", 43)
	actor.request_action("unknown", 44)
	check(actor.buffered_action_id == "special", "invalid action cannot replace valid buffer")
	actor.step(_catalog.ability("heavy_slash").buffer_sec + 0.01)
	check(actor.buffered_action_id.is_empty(), "buffer expires while current action consumes elapsed time")
	var cast := actor.runner.cast_id
	actor.step(0.01)
	check(actor.runner.cast_id == cast, "expired buffer does not start later")
	actor.request_action("primary", 45)
	actor.request_dodge()
	actor.clear_intents()
	check(actor.buffered_action_id.is_empty() and not actor._dodge_requested, "UI clear removes attack and dodge intent")
	actor.free()
	actor = _actor()
	actor.request_action("special", 46)
	actor.step(0.01)
	actor.request_action("primary", 47)
	actor.request_action("special", 47)
	check(actor.buffered_action_id == "primary", "long cooldown special is invalid and cannot displace ready primary")
	actor.set_control(1.0, true)
	check(actor.buffered_action_id.is_empty() and not actor.runner.busy(), "control lock cancels action and buffered intent")
	actor.request_action("primary", 48)
	check(actor.buffered_action_id.is_empty(), "locked player cannot buffer for thaw")
	actor.free()


func check_cancellation() -> void:
	for wave in [false, true]:
		var actor := _actor()
		actor.set_action_program(_plans(wave), _catalog)
		_cues = 0
		_finished.clear()
		actor.runner.cue_reached.connect(func(_cast, _id): _cues += 1)
		actor.runner.finished.connect(func(_cast, _id, reason): _finished.append(reason))
		actor.request_special()
		actor.step(0.01)
		actor.request_dodge()
		actor.step(0.01)
		check(_cues == 0 and not actor.runner.busy() and _finished == ["dodge"], "windup dodge cancels before cue")
		check(actor.runner.cooldown_for("special") > 0, "committed cooldown never refunded")
		actor.free()
		actor = _actor()
		actor.set_action_program(_plans(wave), _catalog)
		actor.request_special()
		actor.step(0.01)
		actor.runner.tick(actor.runner.ability.windup - actor.runner.elapsed)
		var charges := actor.charges
		actor.request_dodge()
		actor.step(0.001)
		check(actor.runner.busy() and actor.charges == charges and actor.dodge_left == 0, "active phase rejects dodge according to explicit policy")
		actor.runner.tick(actor.runner.ability.active)
		actor.request_dodge()
		actor.step(0.001)
		check(not actor.runner.busy() and actor.charges == charges - 1, "recovery permits dodge")
		actor.free()
	var actor := _actor()
	actor.request_special()
	actor.step(0.01)
	var age := actor.runner.elapsed
	var cooldown := actor.runner.cooldown_for("special")
	actor.step(0.0)
	check(actor.runner.elapsed == age and actor.runner.cooldown_for("special") == cooldown, "zero delta does not advance timeline or cooldown")
	actor.request_action("primary", 60)
	actor.receive_hit(actor.health.maximum)
	check(not actor.runner.busy() and actor.buffered_action_id.is_empty(), "death clears active and buffered attacks")
	actor.free()
	var runner := Runner.new()
	var runner_ref: WeakRef = weakref(runner)
	runner.cue_reached.connect(func(_cast, _id): runner_ref.get_ref().cancel("room_changed"))
	runner.start(_catalog.ability("wave_cast"), Vector3.FORWARD, _plans(true).special)
	runner.tick(2.0)
	check(not runner.active_this_step and not runner.busy(), "reentrant cue cancellation cannot restore active hit")


func check_projectile_execution() -> void:
	var actor := _actor()
	var target := _actor(false)
	target.position = Vector3(0, 0, -1)
	actor.set_action_program(_plans(true), _catalog)
	actor.request_special()
	actor.step(0.01)
	actor.runner.tick(actor.runner.ability.windup)
	var resolver := Resolver.new()
	_contacts = 0
	resolver.enemy_contact.connect(func(_source, _cast, _ability, _target, _point, _damage): _contacts += 1)
	var health := target.health.current
	resolver.resolve(actor, [target])
	check(target.health.current == health and _contacts == 0, "projectile executor bypasses shared actor/room-prop melee path completely")
	check(actor.runner.cast_context.projectile_id == "sword_wave" and actor.runner.executor == "projectile", "wave cue carries explicit projectile definition")
	actor.free()
	target.free()
	actor = _actor()
	target = _actor(false)
	target.position = Vector3(0, 0, -1)
	actor.request_special()
	actor.step(0.01)
	actor.runner.tick(actor.runner.ability.windup)
	resolver.resolve(actor, [target])
	check(target.health.maximum - target.health.current == _catalog.ability("heavy_slash").damage, "base right click is a real damaging heavy melee action")
	actor.free()
	target.free()


func check_snapshots() -> void:
	var actor := _actor()
	var source_plans := _plans(false, 7)
	actor.set_action_program(source_plans, _catalog)
	actor.request_special()
	actor.step(0.01)
	var old_context: Dictionary = actor.runner.cast_context
	var left := actor.runner.cooldown_for("special")
	source_plans.special.presentation_key = "mutated"
	actor.set_action_program(_plans(true, 8), _catalog)
	check(actor.runner.cast_context == old_context and old_context.revision == 7 and old_context.form_id == "sword_heavy", "committed cast keeps old form and revision after program swap")
	check(old_context.is_read_only() and old_context.ability_ids.is_read_only(), "cast snapshot is deeply immutable")
	check(actor.runner.cooldown_for("special") == left, "form swap preserves special cooldown")
	_finish(actor)
	actor.request_special()
	actor.step(0.01)
	check(actor.runner.form_id == "sword_wave" and actor.runner.cast_context.revision == 8, "next cast uses new form and revision")
	var malformed := _plans()
	malformed.special.ability_ids = ["missing"]
	check(not actor.set_action_program(malformed, _catalog), "invalid action wiring rejected before mutation")
	actor.free()


func check_motion_resources() -> void:
	var heavy = Style.attack_motions.heavy_slash
	var wave = Style.attack_motions.wave_cast
	heavy.validate()
	wave.validate()
	check(heavy.motion_kind == "overhead" and heavy.sample_pose("windup", 1.0).pitch_deg > heavy.sample_pose("active", 1.0).pitch_deg, "heavy resource raises then drops sword")
	check(wave.motion_kind == "cast" and not wave.trail_enabled, "wave resource has separate launch pose and explicit VFX policy")
	var damage := _catalog.ability("heavy_slash").damage
	var replacement = heavy.duplicate()
	replacement.pitch_start_deg += 15.0
	replacement.sample_pose("active", 0.5)
	check(_catalog.ability("heavy_slash").damage == damage, "motion sampling and replacement do not mutate gameplay damage")
	var view := View.new()
	view.blade = Node3D.new()
	view.add_child(view.blade)
	view.set_weapon_effect(null)
	check(view.weapon_effect == null, "explicit empty sword VFX slot supported")
	view.free()


func check_focus() -> void:
	var actor := _actor()
	var camera := Camera3D.new()
	root.add_child(camera)
	var field := LineEdit.new()
	root.add_child(field)
	field.grab_focus()
	await process_frame
	var adapter := InputAdapter.new(actor, camera)
	actor.movement = Vector3.RIGHT
	actor.request_attack()
	Input.action_press("move_right")
	adapter.update()
	check(actor.movement == Vector3.ZERO and actor.buffered_action_id.is_empty(), "text focus blocks polled movement and clears queued attack")
	var attack := InputEventAction.new()
	attack.action = "combat_special"
	attack.pressed = true
	adapter.event(attack)
	check(actor.buffered_action_id.is_empty(), "text focus blocks right-click action intent")
	field.release_focus()
	adapter.event(attack)
	check(actor.buffered_action_id == "special", "unfocused special input maps to stable action identity")
	var gate := {"blocked": true}
	var blocked_adapter := InputAdapter.new(actor, camera, func(): return gate.blocked)
	actor.movement = Vector3.RIGHT
	actor.request_dodge()
	blocked_adapter.update()
	check(actor.movement == Vector3.ZERO and actor.buffered_action_id.is_empty() and not actor._dodge_requested, "injected popup gate blocks polled movement and clears all intent without Control focus")
	blocked_adapter.event(attack)
	check(actor.buffered_action_id.is_empty(), "injected popup gate blocks action events")
	gate.blocked = false
	blocked_adapter.event(attack)
	check(actor.buffered_action_id == "special", "closing injected popup restores input")
	Input.action_release("move_right")
	field.free()
	camera.free()
	actor.free()
