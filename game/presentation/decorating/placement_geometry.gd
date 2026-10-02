extends RefCounted
## Converts authored room geometry to a grid once on entering decoration mode.
## Furniture business footprints are NOT inferred from visual collision proxies.
var bounds: Rect2
var grid: float
var floor_y: float
var floor_epsilon: float
var board_size: Vector2i
var errors: PackedStringArray = []
func configure(style, grid_size: float) -> void:
	bounds = style.floor_bounds
	grid = grid_size
	floor_y = style.floor_height
	floor_epsilon = style.floor_epsilon
	board_size = Vector2i(roundi(bounds.size.x / grid), roundi(bounds.size.y / grid))
	if not is_equal_approx(board_size.x * grid, bounds.size.x) or not is_equal_approx(board_size.y * grid, bounds.size.y): errors.append("Floor bounds must be a multiple of the grid size")
func world_cell(point: Vector3) -> Vector2i:
	return Vector2i(floori((point.x - bounds.position.x) / grid), floori((point.z - bounds.position.y) / grid))
func cell_center(cell: Vector2i) -> Vector3:
	var point := bounds.position + (Vector2(cell) + Vector2.ONE / 2.0) * grid
	return Vector3(point.x, floor_y, point.y)
func placement_center(entry: Dictionary) -> Vector3:
	var extent: Vector2i = entry.footprint
	if entry.quarter_turn % 2 != 0: extent = Vector2i(extent.y, extent.x)
	var point := bounds.position + (Vector2(entry.cell) + Vector2(extent) / 2.0) * grid
	return Vector3(point.x, floor_y, point.y)
func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < board_size.x and cell.y < board_size.y
func snapshot(shop: Node3D, player: CharacterBody3D, targets: Array[Node3D], interaction_distance: float) -> Dictionary:
	errors.clear()
	var shape: CapsuleShape3D = player.get_node("Body").shape
	var radius := shape.radius * maxf(player.global_basis.get_scale().x, player.global_basis.get_scale().z)
	var blocked: Array[Vector2i] = []
	var navigation: Array[Vector2i] = []
	var physical_rects: Array[Rect2] = []
	for branch in ["Architecture", "FixedFixtures", "Furnishings"]:
		for collider in shop.get_node(branch).find_children("*", "CollisionShape3D", true, false):
			if collider.disabled: continue
			if not collider.shape is BoxShape3D:
				errors.append("Unsupported fixed collider: " + str(collider.get_path()))
				continue
			var world: AABB = collider.global_transform * AABB(-collider.shape.size / 2.0, collider.shape.size)
			if world.end.y <= floor_y + floor_epsilon or world.position.y >= floor_y + shape.height: continue
			physical_rects.append(Rect2(Vector2(world.position.x, world.position.z), Vector2(world.size.x, world.size.z)))
	for y in board_size.y:
		for x in board_size.x:
			var cell := Vector2i(x, y)
			var corner := bounds.position + Vector2(cell) * grid
			var area := Rect2(corner, Vector2.ONE * grid)
			var center := corner + Vector2.ONE * grid / 2.0
			for rect in physical_rects:
				if area.intersects(rect) and not blocked.has(cell): blocked.append(cell)
				if rect.grow(radius).has_point(center) and not navigation.has(cell): navigation.append(cell)
	if not errors.is_empty(): return {}
	# Origin and required cells must be valid for both placement and navigation.
	var unavailable: Dictionary = {}
	for cell in navigation: unavailable[cell] = true
	for cell in blocked: unavailable[cell] = true
	var origin := world_cell(player.global_position)
	if not inside(origin) or unavailable.has(origin):
		errors.append("Player must stand on a clear grid cell before decorating")
		return {}
	var reachable := _reachable(origin, unavailable)
	var required: Array[Vector2i] = [origin]
	var important: Array[Vector3] = [shop.get_node("PlayerSpawn").global_position]
	for target in targets:
		important.append(target.global_position)
		for approach in target.find_children("*", "Marker3D", true, false):
			important.append(approach.global_position)
	for point in important:
		var found := false
		var nearest := origin
		var distance := INF
		for cell: Vector2i in reachable:
			var candidate_distance := cell_center(cell).distance_to(point)
			if candidate_distance < distance:
				nearest = cell
				distance = candidate_distance
				found = true
		if not found or distance > interaction_distance:
			errors.append("No safe approach cell for fixed interaction at " + str(point))
			return {}
		if not required.has(nearest): required.append(nearest)
	return {"blocked":blocked, "navigation":navigation, "origin":origin, "required":required, "clearance":ceili(radius / grid)}
func _reachable(origin: Vector2i, blocked: Dictionary) -> Array[Vector2i]:
	var visited: Dictionary = {origin:true}
	var queue: Array[Vector2i] = [origin]
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := current + direction
			if inside(next) and not blocked.has(next) and not visited.has(next):
				visited[next] = true
				queue.append(next)
	return queue
