extends SceneTree
## Art-only review: fixed authored compositions, no random generation or rewards.
const Host = preload("res://app/combat_training.tscn")
func _initialize() -> void: call_deferred("run")
func capture(name: String) -> void:
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("E:/ShopGame/docs/previews/composition_" + name + ".png")
func run() -> void:
	for layout_name in ["layout_a", "layout_b"]:
		var arena := Host.instantiate()
		arena.room_presentation = arena.room_presentation.duplicate()
		arena.room_presentation.placement_surface = null
		arena.build_choices_enabled = false
		root.add_child(arena)
		current_scene = arena
		arena.set_physics_process(false)
		arena.get_node("UIRoot").hide()
		arena.get_node("RoomActors").hide()
		var layout: Node3D = load("res://presentation/rooms/composition_review/" + layout_name + ".tscn").instantiate()
		arena.room.runtime_prop_container().add_child(layout)
		await capture(layout_name)
		if layout_name == "layout_a":
			var camera: Camera3D = arena.get_node("Camera")
			var offset: Vector3 = camera.global_position - (arena.room_presentation.camera_target_offset + Vector3(0,0,1.2))
			for cluster in layout.get_children():
				camera.size = 6.5
				var target: Vector3 = cluster.global_position + Vector3.UP * 0.5
				camera.global_position = target + offset
				camera.look_at(target)
				await capture(cluster.name)
		arena.queue_free()
		await process_frame
	print("COMPOSITION_REVIEW_CAPTURE complete: 2 layouts + 3 close-ups; art only")
	quit()
