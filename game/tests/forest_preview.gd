extends SceneTree
var scene
var frame_ms: Array[float] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	scene = load("res://app/combat_training.tscn").instantiate()
	scene.build_choices_enabled = false
	root.add_child(scene)
	current_scene = scene
	scene.paused = true
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/builds/forest_godot_hud.png")
	scene.get_node("UIRoot").hide()
	var room = scene.room
	var reference: Camera3D = room.get_node("ReferenceCamera")
	scene.get_node("RunActors").hide()
	scene.get_node("RoomActors").hide()
	reference.make_current()
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/builds/forest_godot_reference.png")
	if "--diagnose" in OS.get_cmdline_user_args():
		var env = room.get_node("Environment").environment
		var sun = room.get_node("Lights/Sun_Warm_Left_Back")
		for setting in ["ssao", "ssr", "shadow"]:
			if setting == "ssao": env.ssao_enabled = false
			if setting == "ssr": env.ssr_enabled = false
			if setting == "shadow": sun.shadow_enabled = false
			await create_timer(.5).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("E:/ShopGame/builds/forest_without_" + setting + ".png")
			if setting == "ssao": env.ssao_enabled = true
			if setting == "ssr": env.ssr_enabled = true
			if setting == "shadow": sun.shadow_enabled = true
	scene.get_node("RunActors").show()
	scene.get_node("RoomActors").show()
	scene.get_node("Camera").make_current()
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/builds/forest_godot_gameplay.png")
	scene.get_node("UIRoot").show()
	await create_timer(1.0).timeout
	for frame in 60:
		var start := Time.get_ticks_usec()
		await process_frame
		frame_ms.append((Time.get_ticks_usec()-start)/1000.0)
	var total := 0.0
	for value in frame_ms: total += value
	print("FOREST_PREVIEW ", JSON.stringify({"mean_frame_ms":total/frame_ms.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}))
	quit()
