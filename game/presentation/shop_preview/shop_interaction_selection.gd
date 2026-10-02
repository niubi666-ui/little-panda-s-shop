class_name ShopInteractionSelection
extends RefCounted
## Targets are injected accessible interaction markers, independent of furniture meshes.


static func find_nearest(origin: Vector3, targets: Array[Node3D], distance_m: float) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance_squared := distance_m * distance_m
	for target: Node3D in targets:
		if not is_instance_valid(target) or not target.is_inside_tree():
			continue
		var offset := target.global_position - origin
		# Reachable surface anchors use full 3D distance, including vertical separation.
		var distance_squared := offset.length_squared()
		# One furniture identity may expose several reachable surface anchors.
		for approach: Node in target.get_children():
			if approach is Marker3D:
				distance_squared = minf(distance_squared, origin.distance_squared_to(approach.global_position))
		if distance_squared > nearest_distance_squared:
			continue
		if nearest != null and is_equal_approx(distance_squared, nearest_distance_squared):
			if str(target.get_meta("instance_id")) >= str(nearest.get_meta("instance_id")):
				continue
		nearest = target
		nearest_distance_squared = distance_squared
	return nearest
