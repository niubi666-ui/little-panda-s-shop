extends SceneTree
const Host = preload("res://app/combat_training.tscn")
const Loader = preload("res://content/rooms/room_prop_loader.gd")
const Planner = preload("res://rogue/rooms/prop_planner.gd")
const Surface = preload("res://presentation/rooms/forest_courtyard_v001/placement_surface.tres")
const Visuals = preload("res://presentation/rooms/props/forest_props.tres")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var reserved: Array[Vector3] = [Vector3(0,0,3),Vector3(-3,0,-3),Vector3(3,0,-3),Vector3(0,0,-5)]
	for seed_value in [7, 91]:
		var arena := Host.instantiate()
		arena.build_choices_enabled = false
		arena.initial_room_plan = Planner.new().generate(seed_value, Loader.new().load_catalog(), Surface, Visuals, reserved)
		root.add_child(arena)
		current_scene = arena
		arena.set_physics_process(false)
		arena.get_node("UIRoot").hide()
		await create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("E:/ShopGame/docs/previews/room_scatter_seed_%s.png" % seed_value)
		arena.queue_free()
		await process_frame
	quit()
