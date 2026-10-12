extends SceneTree
## 森林遗迹 v002 实机截图 + 帧率采样。图形模式运行：
## Godot_console.exe --path game --resolution 1600x1000 --script res://tests/forest_ruin_capture.gd
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL " + label)
func _initialize() -> void: call_deferred("run")
func _mean_luma(img: Image) -> float:
	img.resize(160, 100)
	var s := 0.0
	for y in 100:
		for x in 160:
			var c := img.get_pixel(x, y); s += c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
	return s / 16000.0
func run() -> void:
	var scene = load("res://app/combat_training.tscn").instantiate()
	scene.build_choices_enabled = false
	root.add_child(scene)
	current_scene = scene
	await create_timer(3.0).timeout
	check(scene.room != null and scene.room.has_method("rift_surfaces"), "room loaded")
	check(scene.room.get_node_or_null("Grass") != null, "grass built")
	check(scene.room.get_node_or_null("Collision") != null, "collision built")
	var missing := 0
	for mi in scene.room.get_node("Art").find_children("*", "MeshInstance3D", true, false):
		if mi.material_override == null: missing += 1
	check(missing == 0, "all meshes have materials (%d missing)" % missing)
	# 帧率：持续 4 秒
	var frames := 0; var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		await process_frame
		frames += 1
	var fps := frames / 4.0
	print("FOREST_RUIN fps=%.1f" % fps)
	if "--diag" in OS.get_cmdline_user_args():
		var env: Environment = scene.room.get_node("Environment").environment
		var sun: DirectionalLight3D = scene.room.get_node("Lights/Sun")
		var steps := [["base", func(): pass], ["no_vfog", func(): env.volumetric_fog_enabled = false],
			["no_fog", func(): env.fog_enabled = false], ["no_glow", func(): env.glow_enabled = false],
			["no_sun", func(): sun.visible = false], ["no_ambient", func(): env.ambient_light_energy = 0.0]]
		for s in steps:
			s[1].call()
			await create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			print("DIAG %s L=%.3f" % [s[0], _mean_luma(root.get_texture().get_image())])
		quit(0); return
	await RenderingServer.frame_post_draw
	var out := "E:/ShopGame/builds/forest_ruin_v002_game.png"
	root.get_texture().get_image().save_png(out)
	scene.get_node("UIRoot").hide()
	scene.get_node("Camera").size = 26.0
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/builds/forest_ruin_v002_wide.png")
	print("FOREST_RUIN failures=%d" % failures)
	quit(1 if failures > 0 else 0)
