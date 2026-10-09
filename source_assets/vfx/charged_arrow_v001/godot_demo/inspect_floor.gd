extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var room=load("res://courtyard.tscn").instantiate()
	root.add_child(room)
	for visual: MeshInstance3D in room.find_children("*","MeshInstance3D",true,false):
		var a: AABB=visual.global_transform*visual.get_aabb()
		if a.position.y<0.3 and a.end.y>-1.5 and a.position.x<7 and a.end.x>-6 and a.position.z<3 and a.end.z>0:
			var materials: Array=[]
			for i in visual.mesh.get_surface_count():
				var m=visual.mesh.surface_get_material(i)
				materials.append(m.resource_name if m else "none")
			print(visual.name," ",a," ",materials)
	room.queue_free()
	await process_frame
	quit()
