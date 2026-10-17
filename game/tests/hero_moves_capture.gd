extends SceneTree
## 主角出刀截图（图形模式，周围没有敌人遮挡）：左键三段、R 重击，每招按时间均匀取 8 格拼成一张。
## 输出 builds/visual_pass/hero_moves_<招式>.png
## godot --path game --resolution 1280x800 --script res://tests/hero_moves_capture.gd
const OUT := "E:/ShopGame/builds/visual_pass/"
var arena
var player

class AimSink:
	var movement := Vector3.ZERO
	var facing := Vector3(1, 0, -1).normalized()
	var global_position := Vector3.ZERO
	func clear_intents() -> void: pass

func _initialize() -> void: call_deferred("run")

func run() -> void:
	create_timer(120.0).timeout.connect(func(): quit(1))
	arena = load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	await create_timer(1.0).timeout
	arena.training_tools.panel.hide()
	arena.encounter.cancel()
	player = arena.player
	player.set_damage_immunity(true)
	arena.input_adapter.actor = AimSink.new()
	for actor in arena.actors:
		if actor != player: actor.global_position = Vector3(60, 0.12, 60)
	for move in [["primary", "attack_1"], ["primary", "attack_2"], ["primary", "attack_3"], ["special", "heavy"]]:
		await _capture(move[0], move[1])
	quit(0)

func _capture(action: String, name: String) -> void:
	while player.runner.busy(): await physics_frame
	player.global_position = Vector3(0, player.global_position.y, 1.5)
	player.facing = Vector3(1, 0, -1).normalized()
	for i in 4: await physics_frame
	Engine.time_scale = 0.1
	player.request_action(action)
	var frames: Array[Image] = []
	var total := 0.0
	var next := 0.0
	for i in 4000:
		await RenderingServer.frame_post_draw
		if player.runner.busy():
			var ability = player.runner.ability
			total = ability.windup + ability.active + ability.recovery
			if player.runner.elapsed + 0.0001 < next: continue
			next += total / 8.0
			var image := root.get_texture().get_image()
			var center := (arena.get_node("Camera") as Camera3D).unproject_position(player.global_position + Vector3.UP * 0.9)
			image = image.get_region(Rect2i(int(center.x) - 150, int(center.y) - 150, 300, 300))
			image.convert(Image.FORMAT_RGBA8)
			frames.append(image)
		elif not frames.is_empty(): break
	Engine.time_scale = 1.0
	var sheet := Image.create(300 * frames.size(), 300, false, Image.FORMAT_RGBA8)
	for index in frames.size(): sheet.blit_rect(frames[index], Rect2i(0, 0, 300, 300), Vector2i(index * 300, 0))
	sheet.save_png(OUT + "hero_moves_" + name + ".png")
	print("SHOT ", name, " ", frames.size())
	# 连段：第二、三段要在上一段收招里接上
	for i in 30: await physics_frame
