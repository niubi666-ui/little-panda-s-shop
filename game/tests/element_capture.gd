extends SceneTree
## 元素特效截图（图形模式）：每种反应触发后的瞬间各拍一张，输出到 builds/visual_pass/element_*.png。
## godot --path game --resolution 1280x800 --script res://tests/element_capture.gd
const OUT := "E:/ShopGame/builds/visual_pass/"
var arena
var player
var _reaction_at := -1

## 测试只用代码控制朝向：把输入适配器接到这个空对象上，鼠标位置不再影响玩家
class AimSink:
	var movement := Vector3.ZERO
	var facing := Vector3.FORWARD
	var global_position := Vector3.ZERO
	func clear_intents() -> void: pass

func _initialize() -> void: call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	arena = load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	await create_timer(1.0).timeout
	arena.training_tools.panel.hide()
	player = arena.player
	player.set_damage_immunity(true)
	arena.input_adapter.actor = AimSink.new()
	arena.builds.runtime.element_presented.connect(func(fact): if fact.event == "reaction": _reaction_at = Engine.get_physics_frames())
	var cases := [["elem_steam", ["primary", "skill"]], ["elem_overload", ["primary", "skill"]], ["elem_lava", ["skill", "special"]],
		["elem_superconduct", ["primary", "skill"]], ["elem_shatter", ["skill", "special"]], ["elem_magnet", ["skill", "special"]]]
	for case in cases:
		var applied: Dictionary = arena.builds.apply_test_preset(case[0])
		if not applied.ok: print("PRESET ", case[0], " ", applied)
		var dummies := await _dummies()
		_reaction_at = -1
		# 出招时机偶尔会让第一招打空：最多重复 4 轮，直到触发反应
		for attempt in 4:
			for action in case[1]:
				if _reaction_at < 0: await _attack(dummies[0], action, dummies)
			if _reaction_at >= 0: break
		await _shot("element_" + String(case[0]).trim_prefix("elem_"))
		for d in dummies: if is_instance_valid(d) and d.health.alive(): d.receive_hit(d.health.current + 1.0)
		await create_timer(0.8).timeout
	# 状态展示：一个敌人身上同时看得到灼烧
	arena.builds.apply_test_preset("elem_steam")
	var shown := await _dummies()
	await _attack(shown[0], "primary", shown)
	await _attack(shown[0], "primary", shown)
	shown[0].global_position = player.global_position + Vector3(1.9, 0, 0.3)
	await _shot("element_status_fire", false)
	# 挥砍中：剑身的火焰拖尾
	while player.runner.busy(): await physics_frame
	_hold(shown)
	player.request_action("primary")
	while player.runner.phase() != "active":
		_hold(shown)
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "element_blade_fire.png")
	print("SHOT element_blade_fire")
	# 冰：挂上冰寒的敌人
	arena.builds.apply_test_preset("elem_shatter")
	var iced := await _dummies()
	await _attack(iced[0], "skill", iced)
	iced[0].global_position = player.global_position + Vector3(1.9, 0, 0.3)
	await _shot("element_status_ice", false)
	# 雷、土
	arena.builds.apply_test_preset("elem_magnet")
	var other := await _dummies()
	await _attack(other[0], "skill", other)
	other[0].global_position = player.global_position + Vector3(1.9, 0, 0.3)
	await _shot("element_status_thunder", false)
	quit(0)

func _dummies() -> Array:
	for actor in arena.actors:
		if actor != player and actor.health.alive(): actor.global_position = Vector3(60, 0.12, 60)
	var result: Array = []
	for offset in [Vector3(0, 0, -1.8)]:
		var dummy = arena._spawn(arena.catalog.actor("scout"), player.global_position + offset, 1)
		arena._register_enemy_brain(dummy)
		dummy.health.maximum = 5000.0
		dummy.health.current = 5000.0
		result.append(dummy)
	await physics_frame
	return result

func _hold(dummies: Array) -> void:
	var offsets := [Vector3(0, 0, -1.8), Vector3(1.4, 0, -2.6), Vector3(-1.5, 0, -2.4)]
	for i in dummies.size():
		if is_instance_valid(dummies[i]) and dummies[i].health.alive() and _reaction_at < 0:
			dummies[i].global_position = player.global_position + offsets[i]
	var camera: Camera3D = arena.get_node("Camera")
	root.warp_mouse(camera.unproject_position(player.global_position + offsets[0] + Vector3.UP * 0.5))

func _attack(dummy, action: String, dummies: Array) -> void:
	while player.runner.cooldown_for(action) > 0.0: await physics_frame
	_hold(dummies)
	player.request_action(action)
	for tick in 90:
		_hold(dummies)
		await physics_frame
		if _reaction_at >= 0: return
		if tick > 4 and not player.runner.busy(): break
	for tick in 12:
		_hold(dummies)
		await physics_frame
		if _reaction_at >= 0: return

func _shot(name: String, wait_reaction := true) -> void:
	if wait_reaction:
		var guard := 0
		while _reaction_at < 0 and guard < 60:
			guard += 1
			await physics_frame
	for i in 7: await physics_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("SHOT ", name, " reaction=", _reaction_at >= 0)
