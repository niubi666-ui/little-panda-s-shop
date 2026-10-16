extends SceneTree
## 一局冒险界面截图（图形模式）：开局元素觉醒、地图出口、M 键本局路线。输出到 builds/visual_pass/run_*.png。
## godot --path game --resolution 1280x800 --script res://tests/run_capture.gd
const OUT := "E:/ShopGame/builds/visual_pass/"

func _initialize() -> void: call_deferred("run")

func _shot(name: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("SHOT ", name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var scene = load("res://app/forest_run.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 60: await physics_frame
	await _shot("run_awakening")
	var offer: Dictionary = scene.builds.session.snapshot().offer
	scene.builds._choose(offer.id, offer.candidates[0].choice_id)
	await _shot("run_exits")
	var preview = scene.get_node("MapPreview")
	preview.open()
	await _shot("run_map")
	preview.close()
	scene.forest_run.state.room = "shop"
	scene.forest_run.state.gold = 70
	scene.forest_run._enter_room()
	await _shot("run_shop")
	quit(0)
