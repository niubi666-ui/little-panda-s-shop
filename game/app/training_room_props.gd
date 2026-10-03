extends Node
## Composition of generation, transient transactions, physical props and UI.
signal new_layout_requested
const Loader = preload("res://content/rooms/room_prop_loader.gd")
const Planner = preload("res://rogue/rooms/prop_planner.gd")
const Session = preload("res://app/session/training_loot_session.gd")
const Prop = preload("res://presentation/rooms/props/room_prop.gd")
const Resolver = preload("res://combat/effects/melee_resolver.gd")
const HUD = preload("res://presentation/rooms/props/room_props_hud.tscn")
var plan: Dictionary
var catalog
var session := Session.new()
var props: Array = []
var destructibles: Array = []
var resolver := Resolver.new()
var player
var room: Node3D
var surface: Resource
var visuals: Resource
var hud
var _grid: AStarGrid2D
var _selected
var _failed := false
var _routes: Dictionary = {}
var _clearance_shape := SphereShape3D.new()
var _query_origin: Callable
func configure(room_node: Node3D, player_node, ui: Node, theme: Theme, placement_surface: Resource, prop_visuals: Resource, initial_plan: Dictionary, query_origin: Callable) -> bool:
	room = room_node
	player = player_node
	surface = placement_surface
	visuals = prop_visuals
	_query_origin = query_origin
	if surface == null or visuals == null or not _query_origin.is_valid() or surface.bounds.size.x <= 0.0 or surface.bounds.size.y <= 0.0:
		push_error("Room props require a valid authored surface, visuals and actor origin adapter")
		return false
	var loader := Loader.new()
	catalog = loader.load_catalog()
	if catalog == null:
		for error in loader.errors: push_error(error)
		return false
	var composition_errors := Planner.validate_compositions(catalog, surface, visuals)
	if not composition_errors.is_empty():
		for error in composition_errors: push_error(error)
		return false
	for definition in catalog.rules.props:
		var visual = visuals.visual(definition.id)
		if visual == null or visual.scene == null or visual.bounds.x <= 0.0 or visual.bounds.y <= 0.0 or visual.bounds.z <= 0.0:
			push_error("Room prop missing visual/bounds: " + definition.id)
			return false
	var reserved: Array[Vector3] = [room.to_local(room.player_spawn())]
	for point in room.enemy_spawns(): reserved.append(room.to_local(point))
	if initial_plan.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		plan = Planner.new().generate(rng.randi(), catalog, surface, visuals, reserved)
	else:
		if initial_plan.template_id != surface.template_id or initial_plan.generation_version != catalog.rules.generation_version or initial_plan.content_version != catalog.rules.content_version:
			push_error("Room plan compatibility mismatch; not silently regenerating")
			return false
		plan = catalog.frozen(initial_plan)
	session.configure(plan, func(_candidate: Dictionary) -> bool: return true)
	_grid = Planner.grid_for(plan.placements, surface, visuals, catalog.rules)
	_clearance_shape.radius = catalog.rules.actor_clearance_m
	if not Planner.connected(_grid, reserved, plan.placements, visuals, catalog.rules):
		push_error("Room plan is not reachable")
		return false
	var container: Node3D = room.runtime_prop_container()
	for group in plan.compositions:
		var decoration: Node3D = visuals.composition(group.composition_id).decoration.instantiate()
		decoration.name = group.id + "_flora"
		decoration.position = Vector3(group.position[0], group.position[1], group.position[2])
		decoration.rotation.y = group.yaw_radians
		container.add_child(decoration)
	for index in plan.placements.size():
		var entry: Dictionary = plan.placements[index]
		var prop := Prop.new()
		prop.name = entry.id
		prop.configure(entry, catalog.prop(entry.prop_id), visuals.visual(entry.prop_id), -(index + 1), _destroy)
		container.add_child(prop)
		props.append(prop)
		if entry.kind == "destructible": destructibles.append(prop)
	resolver.set_hit_filter(has_clear_path)
	hud = HUD.instantiate()
	ui.add_child(hud)
	hud.configure(theme)
	hud.new_layout_requested.connect(func(): new_layout_requested.emit())
	refresh(false)
	print("[room] seed=", plan.seed, " props=", props.size(), " omitted=", plan.omitted)
	return true
func _destroy(id: String) -> bool:
	if not session.destroy(id): return false
	_grid = Planner.grid_for(plan.placements, surface, visuals, catalog.rules, session.snapshot().destroyed)
	_routes.clear()
	return true
func resolve_attack() -> void: resolver.resolve(player, destructibles)
func forget_actor(handle: int) -> void: _routes.erase(handle)
func allows_training_spawn(world_point: Vector3, radius: float) -> bool:
	var point := room.to_local(world_point)
	var flat := Vector2(point.x, point.z)
	if not surface.bounds.grow(-radius).has_point(flat): return false
	return not _grid.is_point_solid(Planner.cell_at(_grid, flat))
func has_clear_path(source, target) -> bool:
	var from: Vector3 = _query_origin.call(source)
	var to: Vector3 = target.global_position
	# At the actor body's midpoint, above floor and below every supported blocker.
	to.y = from.y
	var hit := room.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	return hit.is_empty() or hit.collider == target
func movement_towards(source, target) -> Vector3:
	var delta: Vector3 = target.global_position - source.global_position
	delta.y = 0.0
	var sweep := PhysicsShapeQueryParameters3D.new()
	sweep.shape = _clearance_shape
	sweep.transform.origin = _query_origin.call(source)
	sweep.motion = delta
	sweep.collision_mask = 1
	var fraction := room.get_world_3d().direct_space_state.cast_motion(sweep)
	# cast_motion ignores an initially overlapping shape; retain the centre ray
	# check for actors pushed close to a blocker by knockback.
	if fraction[0] >= 1.0 and has_clear_path(source, target): return delta.normalized()
	var from := room.to_local(source.global_position)
	var to := room.to_local(target.global_position)
	var start := _nearest_free(Vector2(from.x, from.z))
	var end := _nearest_free(Vector2(to.x, to.z))
	var key := Vector4i(start.x, start.y, end.x, end.y)
	if not _routes.has(source.handle) or _routes[source.handle].key != key:
		_routes[source.handle] = {"key": key, "path": _grid.get_point_path(start, end)}
	var path: PackedVector2Array = _routes[source.handle].path
	# Once inside a valid cell, head to its successor. Returning to the current
	# cell centre each frame can oscillate forever when the route turns back.
	var first := 1 if start == Planner.cell_at(_grid, Vector2(from.x, from.z)) else 0
	for index in range(first, path.size()):
		var point := path[index]
		var offset := point - Vector2(from.x, from.z)
		if offset.length() <= catalog.rules.navigation_arrival_m: continue
		return (room.global_basis * Vector3(offset.x, 0.0, offset.y)).normalized()
	return Vector3.ZERO
func _nearest_free(position: Vector2) -> Vector2i:
	var result := Planner.cell_at(_grid, position)
	if not _grid.is_point_solid(result): return result
	var best := INF
	for x in _grid.region.size.x:
		for y in _grid.region.size.y:
			var point := Vector2i(x, y)
			if _grid.is_point_solid(point): continue
			var distance := position.distance_squared_to(_grid.get_point_position(point))
			if distance < best:
				best = distance
				result = point
	return result
func nearest_searchable():
	var nearest = null
	var distance: float = catalog.rules.interaction_range_m
	for prop in props:
		if prop.definition.kind != "searchable": continue
		var point: Vector3 = prop.surface_point(player.global_position)
		var separation: float = point.distance_to(player.global_position)
		if separation <= distance and has_clear_path(player, prop):
			nearest = prop
			distance = separation
	return nearest
func search_nearest() -> bool:
	var target = nearest_searchable()
	if target == null or target.searched: return false
	if not session.search(target.entry.id):
		_failed = true
		return false
	_failed = false
	target.mark_searched()
	return true
func refresh(can_interact: bool) -> void:
	_selected = nearest_searchable() if can_interact else null
	var lines: PackedStringArray = [tr("room.loot_title")]
	var items: Dictionary = session.snapshot().items
	if items.is_empty(): lines.append(tr("room.empty"))
	for id in items: lines.append("%s × %s" % [tr(catalog.item(id).name_key), int(items[id])])
	var prompt: String = tr("room.hint")
	if _selected != null:
		prompt = tr("room.searched" if _selected.searched else "room.search").format({"name": tr(_selected.definition.name_key)})
	if _failed: prompt = tr("room.failed")
	hud.display(tr("room.seed").format({"seed": plan.seed}), "\n".join(lines), prompt, can_interact)
