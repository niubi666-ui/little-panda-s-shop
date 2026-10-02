extends RefCounted
const Catalog = preload("res://content/rooms/room_prop_catalog.gd")
## All coordinates stored in the plan are room-local, JSON-compatible values.
# SHA256 stream derivation is versioned; engine RNG output itself is not a save format.
static func stream_seed(seed_value: int, template: String, version: int, stream: String) -> int:
	return ("%s|%s|%s|%s" % [seed_value, template, version, stream]).sha256_text().substr(0, 15).hex_to_int()
static func footprint(entry: Dictionary, visuals: Resource, padding: float) -> Rect2:
	var size: Vector3 = visuals.visual(entry.prop_id).bounds
	var angle: float = entry.yaw_radians
	var extent := Vector2(absf(cos(angle)) * size.x + absf(sin(angle)) * size.z, absf(sin(angle)) * size.x + absf(cos(angle)) * size.z)
	return Rect2(Vector2(entry.position[0], entry.position[2]) - extent / 2.0, extent).grow(padding)
static func grid_for(placements: Array, surface: Resource, visuals: Resource, rules: Dictionary, removed: Dictionary = {}) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	var cell: float = rules.cell_size_m
	grid.region = Rect2i(Vector2i.ZERO, Vector2i((surface.bounds.size / cell).floor()))
	grid.cell_size = Vector2.ONE * cell
	grid.offset = surface.bounds.position + Vector2.ONE * cell / 2.0
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for entry in placements:
		if removed.has(entry.id): continue
		var rect := footprint(entry, visuals, rules.actor_clearance_m + cell / 2.0)
		for x in grid.region.size.x:
			for y in grid.region.size.y:
				var point := Vector2i(x, y)
				if rect.has_point(grid.get_point_position(point)): grid.set_point_solid(point)
	return grid
static func cell_at(grid: AStarGrid2D, point: Vector2) -> Vector2i:
	return Vector2i(((point - grid.offset) / grid.cell_size).round()).clamp(grid.region.position, grid.region.end - Vector2i.ONE)
static func connected(grid: AStarGrid2D, required_points: Array[Vector3], placements: Array, visuals: Resource, rules: Dictionary) -> bool:
	var start := cell_at(grid, Vector2(required_points[0].x, required_points[0].z))
	if grid.is_point_solid(start): return false
	var reached := {start: true}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + direction
			if not grid.region.has_point(next) or reached.has(next) or grid.is_point_solid(next): continue
			reached[next] = true
			queue.append(next)
	for point in required_points:
		if not reached.has(cell_at(grid, Vector2(point.x, point.z))): return false
	# No isolated navigable pockets, including gaps behind a wall.
	for x in grid.region.size.x:
		for y in grid.region.size.y:
			var point := Vector2i(x, y)
			if not grid.is_point_solid(point) and not reached.has(point): return false
	for entry in placements:
		if entry.kind != "searchable": continue
		var accessible := false
		var rect := footprint(entry, visuals, 0.0)
		for point in queue:
			var position := grid.get_point_position(point)
			var nearest := position.clamp(rect.position, rect.end)
			if position.distance_to(nearest) <= rules.interaction_range_m and search_sight_clear(position, entry, placements, visuals):
				accessible = true
				break
		if not accessible: return false
	return true
static func search_sight_clear(from: Vector2, target: Dictionary, placements: Array, visuals: Resource) -> bool:
	var to := Vector2(target.position[0], target.position[2])
	for entry in placements:
		if entry.id == target.id: continue
		var rect := footprint(entry, visuals, 0.0)
		var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for index in corners.size():
			if Geometry2D.segment_intersects_segment(from, to, corners[index], corners[(index + 1) % corners.size()]) != null: return false
	return true
static func validate_compositions(catalog: Catalog, surface: Resource, visuals: Resource) -> PackedStringArray:
	var errors: PackedStringArray = []
	var known_props: Dictionary = {}
	for prop in catalog.rules.props: known_props[prop.id] = true
	var known_compositions: Dictionary = {}
	for preset in visuals.compositions:
		if preset.id.is_empty() or known_compositions.has(preset.id) or preset.members.is_empty() or preset.decoration == null:
			errors.append("Invalid composition resource: " + preset.id)
		known_compositions[preset.id] = true
		var members: Dictionary = {}
		for member in preset.members:
			if member.id.is_empty() or members.has(member.id) or not known_props.has(member.prop_id) or not member.position.is_finite() or not is_finite(member.yaw_radians):
				errors.append("Invalid composition member: " + preset.id + "/" + member.id)
			members[member.id] = true
	for id in catalog.rules.composition_ids:
		if not known_compositions.has(id): errors.append("Missing composition resource: " + id)
	var anchors: Dictionary = {}
	if surface.composition_anchors.is_empty(): errors.append("Room has no composition anchors")
	for anchor in surface.composition_anchors:
		if anchor.id.is_empty() or anchors.has(anchor.id) or anchor.yaw_options.is_empty() or not anchor.position.is_finite(): errors.append("Invalid composition anchor")
		for yaw in anchor.yaw_options:
			if not is_finite(yaw): errors.append("Invalid anchor yaw")
		anchors[anchor.id] = true
	return errors

static func members_for(preset: Resource, group_id: String, position: Vector3, yaw: float, catalog: Catalog) -> Array:
	var result: Array = []
	for member in preset.members:
		var point: Vector3 = position + member.position.rotated(Vector3.UP, yaw)
		result.append({"id": group_id + "__" + member.id, "composition_instance_id": group_id, "prop_id": member.prop_id, "kind": catalog.prop(member.prop_id).kind, "position": [point.x, point.y, point.z], "yaw_radians": yaw + member.yaw_radians, "loot": []})
	return result

static func shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var swap = values[index]
		values[index] = values[other]
		values[other] = swap

func generate(seed_value: int, catalog: Catalog, surface: Resource, visuals: Resource, reserved: Array[Vector3]) -> Dictionary:
	var rules := catalog.rules
	var rng := RandomNumberGenerator.new()
	rng.seed = stream_seed(seed_value, surface.template_id, rules.generation_version, "compositions")
	var placements: Array = []
	var compositions: Array = []
	var used_anchors: Dictionary = {}
	var omitted := 0
	var requests: Array = []
	for group in rules.groups:
		var choices: Array = group.choices.duplicate()
		shuffle(choices, rng)
		requests.append_array(choices.slice(0, rng.randi_range(group.count_min, group.count_max)))
	for id in requests:
		var preset: Resource = visuals.composition(id)
		var candidates: Array = []
		for anchor in surface.composition_anchors:
			if used_anchors.has(anchor.id): continue
			for yaw in anchor.yaw_options: candidates.append({"anchor": anchor, "yaw": yaw})
		shuffle(candidates, rng)
		var accepted := false
		for candidate in candidates.slice(0, int(rules.placement_attempts)):
			var anchor: Resource = candidate.anchor
			var group_id: String = "composition_" + anchor.id
			var members := members_for(preset, group_id, anchor.position, candidate.yaw, catalog)
			var blocked := false
			for entry in members:
				var rect := footprint(entry, visuals, rules.placement_gap_m)
				if not surface.bounds.encloses(rect): blocked = true
				for point in reserved:
					var spawn := Vector2(point.x, point.z)
					if spawn.distance_to(spawn.clamp(rect.position, rect.end)) < rules.spawn_clearance_m: blocked = true
				for other in placements:
					if rect.intersects(footprint(other, visuals, rules.placement_gap_m)): blocked = true
			if blocked: continue
			var proposed := placements + members
			if not connected(grid_for(proposed, surface, visuals, rules), reserved, proposed, visuals, rules): continue
			for entry in members:
				var loot_rng := RandomNumberGenerator.new()
				loot_rng.seed = stream_seed(seed_value, surface.template_id, rules.generation_version, "loot/" + entry.id)
				for reward in catalog.prop(entry.prop_id).loot:
					entry.loot.append({"item_id": reward.item_id, "count": float(loot_rng.randi_range(reward.count_min, reward.count_max))})
			placements = proposed
			compositions.append({"id": group_id, "composition_id": id, "anchor_id": anchor.id, "position": [anchor.position.x, anchor.position.y, anchor.position.z], "yaw_radians": candidate.yaw})
			used_anchors[anchor.id] = true
			accepted = true
			break
		if not accepted: omitted += 1
	# A failed candidate never scatters its children as fallback.
	return Catalog.frozen({"seed": str(seed_value), "template_id": surface.template_id, "generation_version": rules.generation_version, "content_version": rules.content_version, "placements": placements, "compositions": compositions, "omitted": float(omitted)})
