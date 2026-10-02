extends SceneTree
const Host = preload("res://app/combat_training.tscn")
const Planner = preload("res://rogue/rooms/prop_planner.gd")
const Loader = preload("res://content/rooms/room_prop_loader.gd")
const Visuals = preload("res://presentation/rooms/props/forest_props.tres")
const Surface = preload("res://presentation/rooms/forest_courtyard_v001/placement_surface.tres")
const Prop = preload("res://presentation/rooms/props/room_prop.gd")
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/docs/previews/presets_v004_" + label + ".png")
func run() -> void:
	var catalog = Loader.new().load_catalog()
	var reserved: Array[Vector3] = [Vector3(0,0,3),Vector3(-3,0,-3),Vector3(3,0,-3),Vector3(0,0,-5)]
	for seed_value in [7,91]:
		var arena = Host.instantiate()
		arena.build_choices_enabled = false
		arena.initial_room_plan = Planner.new().generate(seed_value, catalog, Surface, Visuals, reserved)
		root.add_child(arena)
		current_scene = arena
		arena.set_physics_process(false)
		arena.get_node("UIRoot").hide()
		arena.get_node("RoomActors").hide()
		await capture("layout_" + str(seed_value))
		arena.queue_free()
		await process_frame
	var arena = Host.instantiate()
	arena.room_presentation = arena.room_presentation.duplicate()
	arena.room_presentation.placement_surface = null
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	arena.get_node("UIRoot").hide()
	arena.get_node("RoomActors").hide()
	arena.player.hide()
	var camera: Camera3D = arena.get_node("Camera")
	var offset: Vector3 = arena.room_presentation.camera_offset
	for preset in Visuals.compositions:
		var container := Node3D.new()
		arena.room.runtime_prop_container().add_child(container)
		container.add_child(preset.decoration.instantiate())
		for entry in Planner.members_for(preset, "review", Vector3.ZERO, 0.0, catalog):
			var prop := Prop.new()
			prop.configure(entry, catalog.prop(entry.prop_id), Visuals.visual(entry.prop_id), -1, func(_id): return false)
			container.add_child(prop)
		camera.size = 6.0
		camera.position = Vector3(0,0.5,0) + offset
		camera.look_at(Vector3(0,0.5,0))
		await capture(preset.id)
		container.queue_free()
		await process_frame
	print("ROOM_PRESETS_CAPTURE complete: four presets and two runtime plans")
	quit()
