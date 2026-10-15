extends SceneTree
## 元素原型：在真实训练场里套用元素预设、真实出招，检查状态与六种反应。
## godot --path game --resolution 1280x800 --script res://tests/element_reactions.gd   （也可加 --headless）
const STEP := 1.0 / 60.0

var arena
var player
var failures: Array = []
var facts: Array = []

## 测试只用代码控制朝向：把输入适配器接到这个空对象上，鼠标位置不再影响玩家
class AimSink:
	var movement := Vector3.ZERO
	var facing := Vector3.FORWARD
	var global_position := Vector3.ZERO
	func clear_intents() -> void: pass

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> bool:
	if not ok: failures.append(label)
	return ok

func run() -> void:
	arena = load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	await create_timer(1.0).timeout
	player = arena.player
	player.set_damage_immunity(true)
	arena.input_adapter.actor = AimSink.new()
	arena.builds.runtime.element_presented.connect(func(fact): facts.append(fact))
	var cases := [
		["elem_steam", ["primary", "skill"], "steam"],
		["elem_overload", ["primary", "skill"], "overload"],
		["elem_lava", ["skill", "special"], "lava"],
		["elem_superconduct", ["primary", "skill"], "superconduct"],
		["elem_shatter", ["skill", "special"], "shatter"],
		["elem_magnet", ["skill", "special"], "magnet"],
	]
	for case in cases:
		await _reaction_case(case[0], case[1], case[2])
	await _burn_case()
	await _freeze_case()
	await _discharge_case()
	await _earth_case()
	await _boost_cases()
	print("ELEMENT_REACTIONS ", JSON.stringify({"failures": failures, "facts": facts.size()}))
	quit(0 if failures.is_empty() else 1)

## 清场后放一个血很厚的斥候在玩家正前方
func _dummy(actor_id := "scout", health := 5000.0):
	for actor in arena.actors:
		if actor != player and actor.health.alive(): actor.global_position = Vector3(60, 0.12, 60)
	var dummy = arena._spawn(arena.catalog.actor(actor_id), player.global_position + Vector3(0, 0, -1.8), 1)
	arena._register_enemy_brain(dummy)
	dummy.health.maximum = health
	dummy.health.current = health
	await physics_frame
	return dummy

func _apply(preset: String) -> bool:
	var result: Dictionary = arena.builds.apply_test_preset(preset)
	return check(result.get("ok", false), preset + " preset applies: " + str(result.get("error", "")))

## 按顺序出招，每一招等到收招结束；敌人每帧拉回玩家正前方，避免走位导致打空
func _attack(dummy, action: String) -> void:
	var guard := 0
	while player.runner.cooldown_for(action) > 0.0 and guard < 180:
		guard += 1
		await physics_frame
	_hold(dummy)
	player.request_action(action)
	for tick in 90:
		_hold(dummy)
		await physics_frame
		if tick > 4 and not player.runner.busy(): break
	for tick in 20:
		_hold(dummy)
		await physics_frame

## 训练场每帧按鼠标瞄准，所以把鼠标移到敌人在屏幕上的位置
func _hold(dummy) -> void:
	if not is_instance_valid(dummy) or not dummy.health.alive(): return
	dummy.global_position = player.global_position + Vector3(0, 0, -1.8)
	player.facing = Vector3.FORWARD
	var camera: Camera3D = arena.get_node("Camera")
	if DisplayServer.get_name() != "headless": root.warp_mouse(camera.unproject_position(dummy.global_position + Vector3.UP * 0.5))

func _reaction_case(preset: String, actions: Array, expected: String) -> void:
	if not _apply(preset): return
	var dummy = await _dummy()
	facts.clear()
	for action in actions: await _attack(dummy, action)
	var seen: Array = facts.filter(func(f): return f.event == "reaction").map(func(f): return f.reaction_id)
	check(seen.has(expected), "%s triggers %s (saw %s)" % [preset, expected, seen])
	dummy.receive_hit(dummy.health.current + 1.0)

func _burn_case() -> void:
	if not _apply("elem_steam"): return
	var dummy = await _dummy()
	await _attack(dummy, "primary")
	var before: float = dummy.health.current
	for tick in 90: await physics_frame
	check(dummy.health.current < before, "fire burn keeps dealing damage after the hit")
	dummy.receive_hit(dummy.health.current + 1.0)

func _freeze_case() -> void:
	if not _apply("elem_steam"): return
	var dummy = await _dummy()
	facts.clear()
	for i in 3: await _attack(dummy, "skill")
	check(facts.any(func(f): return f.event == "applied" and f.element == "ice"), "ice wave applies chill")
	check(dummy.control_locked or arena.builds.runtime.statuses.snapshot(dummy).has("test_freeze"), "three chill stacks freeze the enemy")
	dummy.receive_hit(dummy.health.current + 1.0)

func _discharge_case() -> void:
	if not _apply("elem_overload"): return
	var dummy = await _dummy()
	var second = arena._spawn(arena.catalog.actor("scout"), dummy.global_position + Vector3(1.5, 0, -0.5), 1)
	arena._register_enemy_brain(second)
	second.health.maximum = 5000.0
	second.health.current = 5000.0
	facts.clear()
	await _attack(dummy, "skill")
	await _attack(dummy, "skill")
	check(facts.any(func(f): return f.event == "discharge"), "a second thunder hit discharges shock")
	check(second.health.current < 5000.0, "discharge arcs to a nearby enemy")
	dummy.receive_hit(dummy.health.current + 1.0)
	second.receive_hit(second.health.current + 1.0)

func _earth_case() -> void:
	if not _apply("elem_lava"): return
	var brute = await _dummy("brute")
	await _attack(brute, "special")
	var scale: float = arena.builds.runtime.elements.incoming_scale(arena.builds.runtime, brute)
	check(scale > 1.0, "earth fracture increases damage taken (scale %.2f)" % scale)
	check(brute.break_left > 0.0 or brute.poise_taken > 0.0, "earth hit adds poise damage to armored enemies")
	brute.receive_hit(brute.health.current + 1.0)

## 被动卡与双元素卡：深寒（2 层冻结）、沸腾（蒸腾被强化）、烈焰（灼烧可叠到 8 层）
func _boost_cases() -> void:
	if not _apply("elem_steam_build"): return
	var program: Dictionary = arena.builds.session.program()
	check(program.global.element_boosts.has("ice") and program.global.reaction_boosts.has("steam"), "passive and dual cards compile into global boosts")
	var dummy = await _dummy()
	for i in 2: await _attack(dummy, "skill")
	check(dummy.control_locked or arena.builds.runtime.statuses.snapshot(dummy).has("test_freeze"), "Deep Cold freezes after two chill stacks")
	dummy.receive_hit(dummy.health.current + 1.0)
	dummy = await _dummy()
	facts.clear()
	await _attack(dummy, "primary")
	await _attack(dummy, "skill")
	check(facts.any(func(f): return f.event == "reaction" and f.reaction_id == "steam" and f.boosted), "Boiling boosts the steam reaction")
	dummy.receive_hit(dummy.health.current + 1.0)
	if not _apply("elem_fire_build"): return
	dummy = await _dummy()
	for i in 4:
		await _attack(dummy, "primary")
		await _attack(dummy, "special")
	var stacks: Dictionary = arena.builds.runtime.elements.stacks_on(dummy.handle)
	check(int(stacks.get("fire", 0)) > 5, "Blaze lets burn stack past 5 (got %s)" % stacks)
	dummy.receive_hit(dummy.health.current + 1.0)
