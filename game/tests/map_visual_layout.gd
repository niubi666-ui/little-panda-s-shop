extends SceneTree
const Loader = preload("res://content/run/map_preview_loader.gd")
const Generator = preload("res://rogue/run/map_preview_generator.gd")
const Layout = preload("res://presentation/map_preview/map_visual_layout.gd")
const Style = preload("res://presentation/map_preview/map_preview_style.tres")
var failures: Array[String] = []
var checks := 0
var maximum_ms := 0

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); push_error(label)

func intersections(layout: Dictionary) -> int:
	var positions: Dictionary = layout.positions.duplicate()
	positions[Layout.START] = layout.start
	positions[Layout.END] = layout.end
	var paths: Array = layout.paths
	var hits := 0
	var boxes: Array[Rect2] = []
	for path in paths:
		var box := Rect2(path.points[0], Vector2.ZERO)
		for p in path.points: box = box.expand(p)
		boxes.append(box)
	for i in paths.size():
		for j in range(i + 1, paths.size()):
			if not boxes[i].intersects(boxes[j], true): continue
			for a in range(paths[i].points.size() - 1):
				for b in range(paths[j].points.size() - 1):
					var point: Variant = Geometry2D.segment_intersects_segment(paths[i].points[a], paths[i].points[a + 1], paths[j].points[b], paths[j].points[b + 1])
					if point == null: continue
					var permitted := false
					for id in [paths[i].from, paths[i].to]:
						if id not in [paths[j].from, paths[j].to]: continue
						var radius: float = Style.marker_radius if id in [Layout.START, Layout.END] else Style.node_radius
						if Vector2(point).distance_to(positions[id]) <= radius + 0.01: permitted = true
					if not permitted: hits += 1
	return hits

func verify(plan: Dictionary, width: float) -> void:
	var size := Layout.new().minimum_size(plan, Style)
	size.x = width
	var before := JSON.stringify(plan)
	var start := Time.get_ticks_msec()
	var layout := Layout.new().build(plan, Style, size)
	maximum_ms = maxi(maximum_ms, Time.get_ticks_msec() - start)
	check(JSON.stringify(plan) == before, "layout never mutates gameplay plan")
	check(layout.positions.size() == plan.nodes.size(), "one visual position per real node")
	var shifted := 0
	for node in plan.nodes:
		var p: Vector2 = layout.positions[node.id]
		check(p.x >= Style.canvas_padding - 0.01 and p.x <= width - Style.canvas_padding + 0.01, "node inside canvas margin")
		var padding: float = (size.y - (plan.rows - 1) * Style.row_pitch) / 2.0
		var grid_y: float = padding + (plan.rows - 1 - node.layer) * Style.row_pitch
		if absf(p.y - grid_y) > 1.0: shifted += 1
		for other in plan.nodes:
			if other.id <= node.id: continue
			var d: Vector2 = layout.positions[other.id] - p
			check(absf(d.x) >= Style.label_spacing.x - 0.01 or absf(d.y) >= Style.label_spacing.y - 0.01, "icons/captions do not overlap")
	check(shifted > plan.nodes.size() / 2, "most nodes visibly leave rigid rows")
	var links: Dictionary = {}
	var positions: Dictionary = layout.positions.duplicate()
	positions[Layout.START] = layout.start
	positions[Layout.END] = layout.end
	for path in layout.paths:
		links[path.from + ":" + path.to] = true
		check(path.points[0] == positions[path.from] and path.points[-1] == positions[path.to], "curves terminate at actual hit-test positions")
		var clear := true
		for i in range(path.points.size() - 1):
			check(path.points[i].y > path.points[i + 1].y, "path progresses upwards")
			for id in layout.positions:
				if id in [path.from, path.to]: continue
				var nearest := Geometry2D.get_closest_point_to_segment(positions[id], path.points[i], path.points[i + 1])
				if nearest.distance_to(positions[id]) < Style.node_radius + Style.path_clearance - 0.01:
					clear = false
					push_error("seed=%s width=%s edge=%s>%s near %s distance=%s" % [plan.seed, width, path.from, path.to, id, nearest.distance_to(positions[id])])
		check(clear, "path avoids unrelated icons")
	for edge in plan.edges:
		check(links.erase(edge.from + ":" + edge.to), "original edge is drawn once")
	for key in links: check(key.begins_with(Layout.START + ":") or key.ends_with(":" + Layout.END), "only synthetic endpoint connections added")
	check(intersections(layout) == 0, "no visible path crossings introduced")
	check(layout == Layout.new().build(plan, Style, size), "identical seed and size give identical presentation")

func run() -> void:
	var rules := Loader.new().load_rules("res://data/run/map_preview_manifest.json")
	var generator := Generator.new()
	for index in 40:
		var result := generator.generate(rules, str(index))
		check(result.ok, "fixture generated")
		if not result.ok: continue
		verify(result.plan, (rules.columns - 1) * Style.column_pitch + Style.canvas_padding * 2.0)
		verify(result.plan, 1400.0)
	var sample: Dictionary = generator.generate(rules, "panda-preview").plan
	seed(432)
	var expected := randi()
	seed(432)
	Layout.new().build(sample, Style, Vector2(1000, 1800))
	check(randi() == expected, "presentation never consumes global RNG")
	print("MAP_VISUAL_LAYOUT checks=", checks, " failures=", failures.size(), " seeds=40 widths=2 max_build_ms=", maximum_ms)
	quit(0 if failures.is_empty() else 1)
