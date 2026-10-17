extends SceneTree
## 火元素附魔接入检查（图形模式）：构筑第一个元素是火 → 剑上常驻火焰；第一个元素换成别的 → 附魔撤掉。
## 截图输出到 builds/visual_pass/fire_enchant_*.png
## godot --path game --resolution 1280x800 --script res://tests/fire_enchant_capture.gd
const OUT := "E:/ShopGame/builds/visual_pass/"
var arena
var player
var _failures: Array[String] = []

class AimSink:
	var movement := Vector3.ZERO
	var facing := Vector3.FORWARD
	var global_position := Vector3.ZERO
	func clear_intents() -> void: pass

func _initialize() -> void: call_deferred("run")

func run() -> void:
	create_timer(90.0).timeout.connect(func(): print("TIMEOUT"); quit(2))
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
	var view = arena.views[0]
	_check(not is_instance_valid(view.weapon_enchant), "no enchant before any element is picked")

	# 第一个元素是火：剑一直燃烧
	_check(arena.builds.apply_test_preset("elem_fire_build").ok, "fire preset applies")
	await create_timer(1.2).timeout
	_check(is_instance_valid(view.weapon_enchant) and view._enchant_element == "fire", "fire enchant attached")
	await _shot("fire_enchant_idle")
	for d in arena.actors:
		if d != player and d.health.alive(): d.global_position = Vector3(60, 0.12, 60)
	for i in 3:
		while player.runner.busy(): await physics_frame
		player.facing = Vector3(sin(i * 2.1), 0, -cos(i * 2.1)).normalized()
		player.request_action("primary")
		while player.runner.phase() != "active": await physics_frame
		for f in 4:
			await physics_frame
		await _shot("fire_enchant_swing_%d" % i)
		await create_timer(0.12).timeout
		await _shot("fire_enchant_trail_%d" % i)
	# 连拍一刀：检查挥砍拖尾是否连续
	while player.runner.busy(): await physics_frame
	await create_timer(0.6).timeout
	player.facing = Vector3(1, 0, -0.3).normalized()
	player.request_action("primary")
	while player.runner.phase() != "active": await physics_frame
	for n in 6:
		await physics_frame
		await physics_frame
		await _shot("fire_enchant_burst_%d" % n)
		print("ARC ", view.weapon_enchant.arc_emitted, " size ", view.weapon_enchant.arc_flames.draw_pass_1.size, " len ", view.weapon_enchant._length)
	# 火 + 冰：第二个元素不顶替，附魔仍是火
	_check(arena.builds.apply_test_preset("elem_steam").ok, "steam preset applies")
	await create_timer(0.3).timeout
	_check(view._enchant_element == "fire", "second element keeps the fire enchant")
	# 第一个元素是雷：撤掉火附魔，换成雷附魔
	_check(arena.builds.apply_test_preset("elem_superconduct").ok, "thunder preset applies")
	await create_timer(0.3).timeout
	_check(is_instance_valid(view.weapon_enchant) and view._enchant_element == "thunder", "fire enchant replaced by thunder")
	print("FIRE_ENCHANT ", "OK" if _failures.is_empty() else "FAIL " + str(_failures))
	quit(0 if _failures.is_empty() else 1)

func _check(ok: bool, what: String) -> void:
	if not ok: _failures.append(what)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("SHOT ", name)
