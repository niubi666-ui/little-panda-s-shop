extends "res://tests/action_build_runtime.gd"
## Real input adapter, actor, cooldowns and projectile cues; no preview files.
const InputAdapter = preload("res://presentation/combat/combat_input.gd")
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	super.check(ok, message)

func run() -> void:
	create_timer(30.0).timeout.connect(func(): push_error("skill input buffer timeout"); quit(1))
	builds = BuildLoader.new().load_catalog()
	combat = CombatLoader.new().load_catalog()
	if builds == null or combat == null: quit(1); return
	resolver.configure(builds)
	await physics_frame
	for dt in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0]:
		for charge in [false, true]:
			check_roll_click(charge, dt)
			check_roll_left_cancel(charge, dt)
	check_roll_hold()
	check_cooldown_click(false)
	check_cooldown_click(true)
	check_cooldown_hold()
	check_roll_cooldown_overlap()
	check_early_input_and_expiry()
	check_cancellation()
	check_last_active_frame()
	print("SKILL_INPUT_BUFFER ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func fixture(charge: bool = false) -> Dictionary:
	var f := setup([select("charged_wave", "skill")] if charge else [])
	f.player.collision_mask = 0
	f["camera"] = Camera3D.new(); root.add_child(f.camera)
	f["gate"] = {"blocked": false}
	var gate: Dictionary = f.gate
	f["input"] = InputAdapter.new(f.player, f.camera, func(): return gate.blocked)
	f["waves"] = []
	var waves: Array = f.waves
	var player = f.player
	f.player.runner.cue_reached.connect(func(_cast_id, ability_id):
		if ability_id == "wave_cast": waves.append({"charged": player.runner.cast_charged, "direction": player.runner.direction}))
	return f

func clean(f: Dictionary) -> void:
	f.camera.free()
	super.clean(f)

func mouse(f: Dictionary, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button; event.pressed = pressed
	f.input.event(event)

func advance(f: Dictionary, seconds: float, dt: float = 1.0 / 60.0) -> void:
	var left := seconds
	while left > 0.000001:
		var step := minf(dt, left)
		f.player.step(step); f.melee.resolve(f.player, actors); f.runtime.tick(step)
		left -= step

func roll(f: Dictionary, dt: float) -> void:
	f.player.request_dodge(); advance(f, dt, dt)
	check(f.player.dodge_left > combat.ability("wave_cast").buffer_sec, "roll starts earlier than ordinary input window")

func finish_roll(f: Dictionary, dt: float) -> void:
	while f.player.dodge_left > dt:
		advance(f, dt, dt)
		check(f.waves.is_empty(), "roll cannot emit a queued projectile early")
	f.player.facing = Vector3.RIGHT
	advance(f, f.player.dodge_left + dt * 0.25, dt)

func wait_for_wave(f: Dictionary) -> void:
	advance(f, combat.ability("wave_cast").windup + 0.02)

func check_roll_click(charge: bool, dt: float) -> void:
	var f := fixture(charge)
	roll(f, dt)
	mouse(f, MOUSE_BUTTON_RIGHT, true)
	advance(f, dt, dt)
	mouse(f, MOUSE_BUTTON_RIGHT, false)
	check(f.player.buffered_action_id == "skill", "roll click remains queued with/without charge card")
	finish_roll(f, dt)
	check(f.player.runner.busy() and f.player.runner.action_id == "skill", "wave starts on roll completion frame")
	wait_for_wave(f)
	check(f.waves.size() == 1 and not f.waves[0].charged and f.waves[0].direction == Vector3.RIGHT, "single click emits one normal wave using latest aim")
	advance(f, 2.0)
	check(f.waves.size() == 1, "single click cannot repeat automatically")
	clean(f)

func check_roll_hold() -> void:
	var f := fixture(true)
	roll(f, 1.0 / 60.0)
	mouse(f, MOUSE_BUTTON_RIGHT, true)
	check(f.player.charging_skill, "holding during a ready roll starts accumulating charge")
	finish_roll(f, 1.0 / 60.0)
	check(f.player.charging_skill and f.player.charge_elapsed > 0.0 and f.waves.is_empty(), "roll end preserves held charge without automatic release")
	f.player.movement = Vector3.RIGHT
	advance(f, float(f.player.charge_parameters().max_charge_sec))
	check(f.player.charging_skill and f.waves.is_empty(), "full charge while moving still waits for release")
	mouse(f, MOUSE_BUTTON_RIGHT, false); wait_for_wave(f)
	check(f.waves.size() == 1 and f.waves[0].charged, "release after roll emits charged wave")
	clean(f)

func check_roll_left_cancel(charge: bool, dt: float) -> void:
	var f := fixture(charge)
	roll(f, dt)
	mouse(f, MOUSE_BUTTON_RIGHT, true)
	if not charge: mouse(f, MOUSE_BUTTON_RIGHT, false)
	mouse(f, MOUSE_BUTTON_LEFT, true)
	advance(f, dt, dt)
	check(f.player.is_roll_attack_cast() and not f.player.charging_skill, "later left click cancels queued/held skill and uses existing roll attack")
	mouse(f, MOUSE_BUTTON_RIGHT, false)
	advance(f, 3.0, dt)
	check(f.waves.is_empty(), "right release after left cancellation cannot produce a ghost wave")
	clean(f)

func cooldown_fixture(charge: bool, remaining: float) -> Dictionary:
	var f := fixture(charge)
	cast(f, "skill")
	advance(f, f.player.runner.cooldown_for("skill") - remaining)
	check(f.waves.size() == 1, "cooldown fixture has one committed real wave")
	return f

func check_cooldown_click(charge: bool) -> void:
	var window: float = combat.ability("wave_cast").buffer_sec
	var f := cooldown_fixture(charge, window)
	mouse(f, MOUSE_BUTTON_RIGHT, true)
	mouse(f, MOUSE_BUTTON_RIGHT, false)
	check(f.player.buffered_action_id == "skill", "click accepted exactly at cooldown buffer boundary")
	f.player.step(0.0)
	check(is_equal_approx(f.player.runner.cooldown_for("skill"), window) and f.player.buffered_action_id == "skill", "pause preserves cooldown and pending click")
	advance(f, window, window)
	check(f.player.runner.cast_id == 2 and f.player.runner.busy(), "cooldown expiry consumes pending click in the same step")
	wait_for_wave(f)
	check(f.waves.size() == 2 and not f.waves[1].charged, "released cooldown click fires once instead of entering held charge")
	clean(f)

func check_cooldown_hold() -> void:
	var window: float = combat.ability("wave_cast").buffer_sec
	var f := cooldown_fixture(true, window)
	mouse(f, MOUSE_BUTTON_RIGHT, true)
	check(not f.player.charging_skill and f.player.buffered_action_id == "skill", "held cooldown input is pending until skill becomes ready")
	advance(f, window, window)
	check(f.player.charging_skill and is_zero_approx(f.player.charge_elapsed) and f.waves.size() == 1, "cooldown expiry begins charge without counting cooldown waiting time")
	advance(f, float(f.player.charge_parameters().max_charge_sec))
	mouse(f, MOUSE_BUTTON_RIGHT, false); wait_for_wave(f)
	check(f.waves.size() == 2 and f.waves[1].charged, "buffered held input releases a full charged wave")
	clean(f)

func check_early_input_and_expiry() -> void:
	var window: float = combat.ability("wave_cast").buffer_sec
	for charge in [false, true]:
		var f := cooldown_fixture(charge, window + 0.1)
		mouse(f, MOUSE_BUTTON_RIGHT, true)
		advance(f, 2.0)
		mouse(f, MOUSE_BUTTON_RIGHT, false)
		check(f.waves.size() == 1 and not f.player.charging_skill and f.player.buffered_action_id.is_empty(), "too-early held/click input never fires much later")
		clean(f)
	var f := fixture(true)
	f.player.request_special(); advance(f, 0.01)
	mouse(f, MOUSE_BUTTON_RIGHT, true)
	advance(f, window + 0.01)
	check(f.player.buffered_action_id.is_empty(), "unavailable action expires the charge-start buffer")
	mouse(f, MOUSE_BUTTON_RIGHT, false); advance(f, 2.0)
	check(f.waves.is_empty(), "expired charge request cannot be revived by release")
	clean(f)

func check_roll_cooldown_overlap() -> void:
	# The charged cast's real extended cooldown can finish just after the roll.
	var f := fixture(true)
	mouse(f, MOUSE_BUTTON_RIGHT, true)
	advance(f, float(f.player.charge_parameters().max_charge_sec))
	mouse(f, MOUSE_BUTTON_RIGHT, false); wait_for_wave(f)
	var window: float = combat.ability("wave_cast").buffer_sec
	advance(f, f.player.runner.cooldown_for("skill") - f.player.dodge.duration - window)
	roll(f, 1.0 / 60.0)
	mouse(f, MOUSE_BUTTON_RIGHT, true); mouse(f, MOUSE_BUTTON_RIGHT, false)
	check(f.player.buffered_action_id == "skill", "roll input may wait for cooldown within post-roll window")
	# Deliberately cross the roll boundary inside a physics step.
	advance(f, f.player.dodge_left + 0.005)
	check(f.player.buffered_action_id == "skill" and f.waves.size() == 1, "crossing roll boundary keeps the remaining cooldown buffer")
	advance(f, f.player.runner.cooldown_for("skill") + 0.001)
	check(f.player.runner.cast_id == 2, "roll and cooldown overlap consumes one intent without early expiry")
	wait_for_wave(f)
	check(f.waves.size() == 2 and not f.waves[1].charged, "queued click after charged cooldown produces an ordinary wave")
	clean(f)
	# Held input starts charging as soon as cooldown ends, even if still rolling.
	f = cooldown_fixture(true, 0.5)
	roll(f, 1.0 / 60.0)
	mouse(f, MOUSE_BUTTON_RIGHT, true)
	advance(f, f.player.runner.cooldown_for("skill") + 0.02)
	check(f.player.dodge_left > 0.0 and f.player.charging_skill and f.waves.size() == 1, "ready held input begins charging during remaining roll")
	advance(f, f.player.dodge_left + 0.02)
	check(f.player.charging_skill and f.waves.size() == 1, "overlapped cooldown and roll never auto-release a held charge")
	clean(f)

func check_cancellation() -> void:
	for reason in ["left", "ui", "control", "death", "room", "build"]:
		var f := cooldown_fixture(true, combat.ability("wave_cast").buffer_sec)
		mouse(f, MOUSE_BUTTON_RIGHT, true)
		match reason:
			"left": mouse(f, MOUSE_BUTTON_LEFT, true)
			"ui": f.gate.blocked = true; f.input.update(); f.gate.blocked = false
			"control": f.player.set_control(1.0, true); f.player.set_control(1.0, false)
			"death": f.player.health.apply(f.player.health.current, false)
			"room": f.player.cancel("room")
			"build": f.player.set_action_program(f.program.actions, combat)
		mouse(f, MOUSE_BUTTON_RIGHT, false)
		advance(f, 3.0)
		check(f.waves.size() == 1 and not f.player.charging_skill and f.player.buffered_action_id.is_empty(), "pending right input cancelled by " + reason)
		clean(f)

func check_last_active_frame() -> void:
	var f := fixture()
	roll(f, 1.0 / 60.0)
	mouse(f, MOUSE_BUTTON_LEFT, true); advance(f, 0.01)
	advance(f, f.player.runner.ability.windup)
	mouse(f, MOUSE_BUTTON_RIGHT, true)
	advance(f, combat.ability("wave_cast").buffer_sec, combat.ability("wave_cast").buffer_sec)
	check(f.player.is_roll_attack_cast() and f.player.runner.active_this_step, "buffered skill preserves previous attack's final damage sweep")
	advance(f, 1.0 / 60.0)
	check(f.player.runner.action_id == "skill", "valid skill follows the final damage sweep on next frame")
	wait_for_wave(f)
	check(f.waves.size() == 1, "boundary queue emits exactly once")
	clean(f)
