extends SceneTree
## 调试用：在对照机位下列出画面某个区域里有哪些摆件（名字、位置、包围盒）。
##   godot --path game --script res://tests/fairy_lookdev_probe.gd -- <视图> <x0> <y0> <x1> <y1>
const Capture = preload("res://tests/fairy_lookdev_capture.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	root.size = Capture.SIZE
	var arena = load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	await create_timer(1.0).timeout
	var camera: Camera3D = arena.get_node("Camera")
	var view: Array = Capture.VIEWS[args[0]]
	camera.position = view[0]
	camera.look_at(view[1])
	var region := Rect2(Vector2(float(args[1]), float(args[2])), Vector2(float(args[3]) - float(args[1]), float(args[4]) - float(args[2])))
	for node in arena.room.find_children("*", "GeometryInstance3D", true, false):
		if not node.is_visible_in_tree(): continue
		var instances: Array = []
		if node is MultiMeshInstance3D:
			for index in node.multimesh.instance_count:
				instances.append(node.global_transform * node.multimesh.get_instance_transform(index))
		else:
			instances.append(node.global_transform)
		var aabb: AABB = node.multimesh.mesh.get_aabb() if node is MultiMeshInstance3D else node.get_aabb()
		for xform in instances:
			var box: AABB = xform * aabb
			var centre: Vector3 = box.get_center()
			if camera.is_position_behind(centre): continue
			var screen := camera.unproject_position(centre)
			if region.has_point(screen) and box.size.y > 2.0:
				print("PROBE %s at %s size %s screen %s" % [node.name, centre.snapped(Vector3.ONE * 0.1), box.size.snapped(Vector3.ONE * 0.1), screen.round()])
	quit(0)
