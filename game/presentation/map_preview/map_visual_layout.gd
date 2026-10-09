extends RefCounted
## Pure presentation: stable visual RNG, no mutation of the generated MapPlan.
const START = "@visual_start"
const END = "@visual_end"
const VERSION = "map_visual.v1"

func minimum_size(plan: Dictionary, style: Resource) -> Vector2:
	var span: float = (int(plan.columns) - 1) * style.column_pitch
	# The virtual start/end fan needs more vertical room on wide maps. Its outer
	# edge must clear the adjacent same-row icon even before relaxation begins.
	var clearance: float = style.node_radius + style.path_clearance
	var fan_height: float = span * 0.5 * clearance / sqrt(style.column_pitch * style.column_pitch - clearance * clearance)
	var padding: float = maxf(style.canvas_padding, style.marker_inset + fan_height + style.node_jitter.y + style.path_clearance)
	return Vector2(span + style.canvas_padding * 2.0, (int(plan.rows) - 1) * style.row_pitch + padding * 2.0)

func build(plan: Dictionary, style: Resource, canvas_size: Vector2) -> Dictionary:
	var extent := minimum_size(plan, style)
	var vertical_padding: float = (extent.y - (int(plan.rows) - 1) * style.row_pitch) / 2.0
	var positions: Dictionary = {}
	var originals: Dictionary = {}
	var nodes: Dictionary = {}
	var neighbours: Dictionary = {}
	var edges: Array = plan.edges.duplicate(true)
	var min_column := int(plan.columns)
	var max_column := 0
	for node in plan.nodes:
		min_column = mini(min_column, node.column)
		max_column = maxi(max_column, node.column)
	var occupied_width: float = (max_column - min_column) * style.column_pitch
	for node in plan.nodes:
		nodes[node.id] = node
		neighbours[node.id] = []
		positions[node.id] = Vector2((canvas_size.x - occupied_width) / 2.0 + (node.column - min_column) * style.column_pitch,
			vertical_padding + (int(plan.rows) - 1 - node.layer) * style.row_pitch)
		originals[node.id] = positions[node.id]
		if node.layer == 0: edges.append({"from": START, "to": node.id})
		if node.layer == int(plan.rows) - 1: edges.append({"from": node.id, "to": END})
	positions[START] = Vector2(canvas_size.x / 2.0, canvas_size.y - style.marker_inset)
	positions[END] = Vector2(canvas_size.x / 2.0, style.marker_inset)
	for edge in plan.edges:
		neighbours[edge.from].append(edge.to)
		neighbours[edge.to].append(edge.from)
	var ids: Array = nodes.keys()
	ids.sort()
	var offsets: Dictionary = {}
	var row_rng := _rng(plan.seed, "sway")
	var phase := row_rng.randf_range(0.0, TAU)
	for id in ids:
		neighbours[id].sort()
		var rng := _rng(plan.seed, id)
		offsets[id] = Vector2(sin(float(nodes[id].layer) * style.sway_frequency + phase) * style.row_sway
			+ rng.randf_range(-style.node_jitter.x, style.node_jitter.x), rng.randf_range(-style.node_jitter.y, style.node_jitter.y))
	for pass_index in int(style.layout_passes):
		var order: Array = ids.duplicate()
		if pass_index % 2 == 1: order.reverse()
		for id in order:
			var anchor: Vector2 = originals[id]
			var average := anchor.x
			if not neighbours[id].is_empty():
				average = 0.0
				for neighbour in neighbours[id]: average += positions[neighbour].x
				average /= neighbours[id].size()
			var desired := Vector2(lerpf(anchor.x, average, style.neighbour_pull), anchor.y) + Vector2(offsets[id])
			desired.x = clampf(desired.x, maxf(style.canvas_padding, anchor.x - style.max_shift_x),
				minf(canvas_size.x - style.canvas_padding, anchor.x + style.max_shift_x))
			var previous: Vector2 = positions[id]
			var amount := 1.0
			for _attempt in int(style.layout_backoff_steps):
				positions[id] = previous.lerp(desired, amount)
				if _safe_move(id, nodes, positions, edges, style): break
				positions[id] = previous
				amount *= 0.5
	var paths: Array = []
	for edge in edges:
		paths.append({"from": edge.from, "to": edge.to, "points": PackedVector2Array([positions[edge.from], positions[edge.to]])})
	for index in paths.size():
		var path: Dictionary = paths[index]
		var rng := _rng(plan.seed, path.from + ":" + path.to)
		var bend := rng.randf_range(-style.curve_bend, style.curve_bend)
		for _attempt in int(style.layout_backoff_steps):
			var points := _curve(positions[path.from], positions[path.to], bend, style.curve_segments)
			if _safe_curve(points, path, index, paths, positions, style):
				path.points = points
				break
			bend *= 0.5
	var start: Vector2 = positions[START]
	var end: Vector2 = positions[END]
	positions.erase(START)
	positions.erase(END)
	return {"positions": positions, "paths": paths, "start": start, "end": end}

func _rng(seed_text: String, domain: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = (VERSION + ":" + seed_text + ":" + domain).hash()
	return rng

func _safe_move(id: String, nodes: Dictionary, positions: Dictionary, edges: Array, style: Resource) -> bool:
	var point: Vector2 = positions[id]
	for other in nodes:
		if other == id: continue
		var delta: Vector2 = positions[other] - point
		if absf(delta.x) < style.label_spacing.x and absf(delta.y) < style.label_spacing.y: return false
		if nodes[id].layer == nodes[other].layer:
			if (point.x - positions[other].x) * (nodes[id].column - nodes[other].column) <= 0: return false
	var incident: Array = []
	for edge in edges:
		if id in [edge.from, edge.to]: incident.append(edge)
		elif _distance(point, positions[edge.from], positions[edge.to]) < style.node_radius + style.path_clearance: return false
	for edge in incident:
		var a: Vector2 = positions[edge.from]
		var b: Vector2 = positions[edge.to]
		if a.y - b.y < style.minimum_edge_rise: return false
		for other in nodes:
			if other not in [edge.from, edge.to] and _distance(positions[other], a, b) < style.node_radius + style.path_clearance: return false
		for other in edges:
			if edge.from in [other.from, other.to] or edge.to in [other.from, other.to]: continue
			var c: Vector2 = positions[other.from]
			var d: Vector2 = positions[other.to]
			if not Rect2(a, Vector2.ZERO).expand(b).intersects(Rect2(c, Vector2.ZERO).expand(d), true): continue
			if Geometry2D.segment_intersects_segment(a, b, c, d) != null: return false
	return true

func _curve(a: Vector2, b: Vector2, bend: float, segments: int) -> PackedVector2Array:
	var delta := b - a
	var normal := delta.orthogonal().normalized() * bend
	var c1 := a + delta / 3.0 + normal
	var c2 := a + delta * (2.0 / 3.0) + normal
	var points := PackedVector2Array()
	for i in range(segments + 1):
		points.append(a.bezier_interpolate(c1, c2, b, float(i) / segments))
	return points

func _safe_curve(points: PackedVector2Array, path: Dictionary, index: int, paths: Array, positions: Dictionary, style: Resource) -> bool:
	for i in range(points.size() - 1):
		if points[i].y <= points[i + 1].y: return false
		for id in positions:
			if id in [path.from, path.to, START, END]: continue
			if _distance(positions[id], points[i], points[i + 1]) < style.node_radius + style.path_clearance: return false
	var bounds := _bounds(points)
	for other_index in paths.size():
		if other_index == index: continue
		var other: Dictionary = paths[other_index]
		if not bounds.intersects(_bounds(other.points), true): continue
		for i in range(points.size() - 1):
			for j in range(other.points.size() - 1):
				var intersection: Variant = Geometry2D.segment_intersects_segment(points[i], points[i + 1], other.points[j], other.points[j + 1])
				if intersection == null: continue
				var hidden_by_shared_icon := false
				for id in [path.from, path.to]:
					var radius: float = style.marker_radius if id in [START, END] else style.node_radius
					if id in [other.from, other.to] and Vector2(intersection).distance_to(positions[id]) <= radius:
						hidden_by_shared_icon = true
				if not hidden_by_shared_icon: return false
	return true

func _bounds(points: PackedVector2Array) -> Rect2:
	var rect := Rect2(points[0], Vector2.ZERO)
	for point in points: rect = rect.expand(point)
	return rect

func _distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b))
