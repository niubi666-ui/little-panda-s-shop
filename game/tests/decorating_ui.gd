extends SceneTree
## Dedicated graphical acceptance: launch once per requested window resolution.
## Exercises the real shop UI through window input. Never starts another engine.
const OUTPUT_DIRECTORY := "E:/ShopGame/docs/previews"
const FURNITURE_IDS := ["barrel", "scroll_bin", "supply_crate", "chest"]
const THUMBNAILS := {"barrel":"barrel.png", "scroll_bin":"scroll_bin.png", "supply_crate":"supply_crate.png", "chest":"storage_chest.png"}
var failures: Array[String] = []
var captures: Array[String] = []
var main: Node
var decorating: Node
var panel: Control
var camera: Camera3D
var placed: Dictionary = {}
var finished := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures.append(label)
		push_error(label)
	return ok

func require(ok: bool, label: String) -> bool:
	if check(ok, label): return true
	root.get_texture().get_image().save_png("E:/ShopGame/builds/decoration_ui_failure.png")
	print("UI_DIAGNOSTIC hover=", root.gui_get_hovered_control(), " mouse=", root.get_mouse_position(), " pending=", decorating._pending if is_instance_valid(decorating) else {})
	finish()
	return false

func finish() -> void:
	if finished: return
	finished = true
	print("DECORATING_UI ", JSON.stringify({"window":str(DisplayServer.window_get_size()), "failures":failures, "screenshots":captures}))
	quit(0 if failures.is_empty() else 1)

func settle() -> void:
	await create_timer(0.16).timeout

func key(action: StringName) -> void:
	var bound := InputMap.action_get_events(action)
	if not require(not bound.is_empty(), "input action is configured: " + str(action)): return
	for pressed: bool in [true, false]:
		var event: InputEventKey = bound[0].duplicate()
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func point_mouse(canvas_position: Vector2) -> void:
	# parse_input_event takes window pixels, while camera/Control use canvas pixels.
	# Viewport.get_mouse_position reads the physical cursor for 3D ray projection.
	root.warp_mouse(canvas_position)
	var point := root.get_final_transform() * canvas_position
	var motion := InputEventMouseMotion.new()
	motion.device = InputMap.action_get_events(&"camera_zoom_in")[0].device
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	await process_frame

func click_point(canvas_position: Vector2) -> void:
	await point_mouse(canvas_position)
	var point := root.get_final_transform() * canvas_position
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.device = InputMap.action_get_events(&"camera_zoom_in")[0].device
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func control(node_name: String) -> Control:
	return panel.find_child(node_name, true, false) as Control

func click_named(node_name: String) -> void:
	var target := control(node_name)
	if not require(is_instance_valid(target), "control exists: " + node_name): return
	if not require(target.is_visible_in_tree(), "control visible: " + node_name): return
	await click_point(target.get_global_rect().get_center())

func scene_point_available(point: Vector2) -> bool:
	if not root.get_visible_rect().grow(-12.0).has_point(point): return false
	for node_name in ["CatalogPanel", "ActionBar", "ModeBanner"]:
		var blocker := control(node_name)
		if is_instance_valid(blocker) and blocker.is_visible_in_tree() and blocker.get_global_rect().grow(8.0).has_point(point): return false
	return true

func visible_position(definition_id: String, turn: int, moving_id: String = "", old_cell: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var definition = decorating._catalog.furniture(definition_id)
	var candidates: Array[Dictionary] = []
	var viewport_center := root.get_visible_rect().get_center()
	for y in decorating._geometry.board_size.y:
		for x in decorating._geometry.board_size.x:
			var cell := Vector2i(x, y)
			if cell == old_cell: continue
			var world: Vector3 = decorating._geometry.cell_center(cell)
			if camera.is_position_behind(world): continue
			var point := camera.unproject_position(world)
			if not scene_point_available(point): continue
			var candidate := {"instance_id":decorating._session.next_id() if moving_id.is_empty() else moving_id, "definition_id":definition_id, "cell":cell, "quarter_turn":turn, "footprint":definition.footprint}
			var center: Vector3 = decorating._geometry.placement_center(candidate) + Vector3.UP * 0.35
			if not scene_point_available(camera.unproject_position(center)): continue
			candidates.append({"request":candidate, "score":point.distance_squared_to(viewport_center)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score < b.score)
	for candidate in candidates:
		var request: Dictionary = candidate.request
		if not decorating._session.preview(request, not moving_id.is_empty()).ok: continue
		# Keep the model visible for later real ray-picking, not behind the fixed island.
		var center: Vector3 = decorating._geometry.placement_center(request) + Vector3.UP * 0.35
		var point := camera.unproject_position(center)
		var ray := PhysicsRayQueryParameters3D.create(camera.project_ray_origin(point), center)
		if camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return request
	return {}

func floor_point(request: Dictionary) -> Vector2:
	return camera.unproject_position(decorating._geometry.cell_center(request.cell))

func furniture_pick_point(instance_id: String) -> Variant:
	var node: Node3D = decorating._live_nodes[instance_id]
	for collider in node.find_children("*", "CollisionShape3D", true, false):
		if collider.disabled: continue
		var point := camera.unproject_position(collider.global_position)
		if not scene_point_available(point): continue
		var start := camera.project_ray_origin(point)
		var query := PhysicsRayQueryParameters3D.create(start, start + camera.project_ray_normal(point) * camera.far)
		var hit := node.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and node.is_ancestor_of(hit.collider): return point
	return null

func check_selection(selected_id: String) -> void:
	for id in FURNITURE_IDS:
		var card := control("CatalogCard_" + id) as Button
		check(is_instance_valid(card) and card.button_pressed == (id == selected_id), "exclusive card highlight: " + id + " selected=" + selected_id)
	if selected_id.is_empty(): return
	var definition = decorating._catalog.furniture(selected_id)
	var name_label := control("DetailName") as Label
	check(name_label.text == str(TranslationServer.translate(definition.name_key)), "details receive current furniture ID: " + selected_id)
	for node_name in ["DetailFootprint", "DetailDescription"]:
		var detail := control(node_name) as Label
		check(not detail.text.is_empty() and not detail.text.begins_with("decor."), "detail resolves: " + node_name)

func check_layout() -> void:
	for node_name in ["CatalogPanel", "ActionBar", "ModeBanner", "DetailName", "DetailFootprint", "DetailDescription", "StatusLabel", "RotateButton", "RemoveButton", "CancelButton", "DoneButton"]:
		var node := control(node_name)
		check(is_instance_valid(node) and root.get_visible_rect().grow(1.0).encloses(node.get_global_rect()), "control fits viewport: " + node_name)
	for id in FURNITURE_IDS:
		var card := control("CatalogCard_" + id)
		check(card.is_visible_in_tree() and root.get_visible_rect().grow(1.0).encloses(card.get_global_rect()), "all four furniture cards fit: " + id)
	check((control("CatalogGrid") as GridContainer).columns == 2, "catalog uses two columns")
	for node in panel.find_children("*", "TextureRect", true, false):
		check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "decorative texture does not eat scene/card input: " + str(node.name))

func capture(locale: String) -> void:
	TranslationServer.set_locale(locale)
	await settle()
	check_selection("chest")
	check_layout()
	check(not decorating._panel._status.text.begins_with("decor."), "status translated: " + locale)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var size := DisplayServer.window_get_size()
	var path := OUTPUT_DIRECTORY + "/decoration_v001_%s_%dx%d.png" % [locale, size.x, size.y]
	var error := image.save_png(path)
	check(error == OK, "screenshot saved: " + path)
	if error == OK: captures.append(path)

func run() -> void:
	create_timer(120.0).timeout.connect(func():
		if not finished:
			check(false, "acceptance watchdog exceeded 120 seconds")
			finish())
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIRECTORY)
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(1.0).timeout
	decorating = main.get_node_or_null("ShopDecoration")
	if not require(is_instance_valid(decorating), "real shop decoration application exists"): return
	camera = main.get_node("World/ShopInterior/ShopCamera")
	await key(&"ui_decoration")
	if not require(decorating._active and is_instance_valid(decorating._grid), "R opens validated real decorating module"): return
	panel = decorating._panel
	await create_timer(0.8).timeout
	if not require(decorating._catalog.entries().size() == FURNITURE_IDS.size(), "only four supported definitions, no placeholder art definitions"): return
	for node_name in ["CatalogGrid", "Category_furniture", "Category_ornaments", "Category_lights", "EmptyState", "CatalogPanel", "ActionBar", "ModeBanner", "RotateButton", "CancelButton", "RemoveButton", "DoneButton", "DetailName", "DetailFootprint", "DetailDescription", "StatusLabel"]:
		if not require(is_instance_valid(control(node_name)), "named acceptance control exists: " + node_name): return
	for id in FURNITURE_IDS:
		var card := control("CatalogCard_" + id) as Button
		if not require(is_instance_valid(card), "real furniture card: " + id): return
		var mapped_texture := false
		for texture_node in card.find_children("*", "TextureRect", true, false):
			if texture_node.texture != null and texture_node.texture.resource_path.get_file() == THUMBNAILS[id]: mapped_texture = true
		check(mapped_texture, "correct thumbnail mapping: " + id)
	check_selection("")
	for category in ["ornaments", "lights"]:
		await click_named("Category_" + category)
		check(control("EmptyState").is_visible_in_tree(), "unused category has explicit empty state: " + category)
		check(not control("CatalogGrid").is_visible_in_tree(), "unused category exposes no unavailable furniture: " + category)
		check(decorating._session.snapshot().is_empty(), "category clicks do not place furniture")
	await click_named("Category_furniture")
	check(not control("EmptyState").is_visible_in_tree(), "furniture category restores catalog")
	for id in FURNITURE_IDS:
		var before_count: int = decorating._session.snapshot().size()
		await click_named("CatalogCard_" + id)
		if not require(not decorating._pending.is_empty() and decorating._pending.definition_id == id, "mouse card starts preview: " + id): return
		check_selection(id)
		check(decorating._session.snapshot().size() == before_count, "card click does not pass through and place: " + id)
		var turn := 0
		if id == "chest":
			await click_named("RotateButton")
			turn = 1
			check(decorating._pending.quarter_turn == turn, "real rotate button requests 90 degrees")
			check(decorating._session.snapshot().size() == before_count, "rotate UI does not pass through")
		var request := visible_position(id, turn)
		if not require(not request.is_empty(), "visible legal placement exists: " + id): return
		await point_mouse(floor_point(request))
		if decorating._pending.cell != request.cell:
			print("PLACEMENT_PROJECTION expected=", request.cell, " point=", floor_point(request), " actual=", decorating._pending.cell)
		if not require(decorating._pending.cell == request.cell and decorating._last_result.ok, "transparent scene area permits preview tracking: " + id): return
		await click_point(floor_point(request))
		if not require(decorating._session.snapshot().size() == before_count + 1, "real floor click commits furniture: " + id): return
		check(decorating._pending.is_empty(), "successful placement clears preview")
		check_selection("")
		placed[id] = request.instance_id
		var committed: Dictionary = decorating._session.find(request.instance_id)
		check(committed.quarter_turn == turn and committed.cell == request.cell, "grid position and rotation survive commit: " + id)
	# Capture both locales with a selected card and the genuine shop behind the layered UI.
	await click_named("CatalogCard_chest")
	var screenshot_position := visible_position("chest", 0)
	if not require(not screenshot_position.is_empty(), "fifth preview has a visible legal screenshot position"): return
	await point_mouse(floor_point(screenshot_position))
	await capture("zh_CN")
	await capture("en")
	var revision: int = decorating._session.revision()
	await click_named("CancelButton")
	check(decorating._pending.is_empty() and decorating._session.revision() == revision, "cancel preview is not undo and does not mutate layout")
	check_selection("")
	# Pick through actual physics and GUI input, then prove cancel preserves the old model.
	await physics_frame
	var barrel_id: String = placed.barrel
	var pick = furniture_pick_point(barrel_id)
	if not require(pick != null, "placed barrel is visibly pickable without UI overlap"): return
	await click_point(pick)
	if not require(decorating._moving and decorating._pending.instance_id == barrel_id, "real scene click enters move mode"): return
	check_selection("barrel")
	var original: Dictionary = decorating._session.find(barrel_id)
	var original_transform: Transform3D = decorating._live_nodes[barrel_id].transform
	await click_named("RotateButton")
	await click_named("CancelButton")
	check(decorating._session.find(barrel_id) == original and decorating._live_nodes[barrel_id].transform == original_transform, "cancel move retains authoritative layout and model")
	check_selection("")
	pick = furniture_pick_point(barrel_id)
	if not require(pick != null, "barrel stays pickable after cancel"): return
	await click_point(pick)
	if not require(decorating._moving, "second real pick starts movement"): return
	var move_request := visible_position("barrel", int(original.quarter_turn), barrel_id, original.cell)
	if not require(not move_request.is_empty(), "another legal grid position for move"): return
	await click_point(floor_point(move_request))
	check(decorating._session.find(barrel_id).cell == move_request.cell and decorating._session.snapshot().size() == FURNITURE_IDS.size(), "real mouse move commits without creating an extra item")
	await physics_frame
	pick = furniture_pick_point(barrel_id)
	if not require(pick != null, "moved furniture remains pickable"): return
	await click_point(pick)
	if not require(decorating._moving, "pick moved furniture for removal"): return
	check_selection("barrel")
	await click_named("RemoveButton")
	check(decorating._session.find(barrel_id).is_empty() and not decorating._live_nodes.has(barrel_id), "real remove button removes model and state")
	check_selection("")
	await click_named("DoneButton")
	check(not decorating._active and main.get_node("UIRoot/FoliageUI").visible, "Done leaves decorating and restores shop UI")
	finish()
