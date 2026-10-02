extends SceneTree
## Shop-only engine acceptance. Use a dedicated process/log; never stop another task's engine.
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)
func press_bound_key(action: StringName) -> void:
	var event: InputEventKey = InputMap.action_get_events(action)[0].duplicate()
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
func free_position(decorating, definition_id: String, turn: int, ignore_id: String = "") -> Dictionary:
	var definition = decorating._catalog.furniture(definition_id)
	for y in decorating._geometry.board_size.y:
		for x in decorating._geometry.board_size.x:
			var request := {"instance_id":decorating._session.next_id() if ignore_id.is_empty() else ignore_id, "definition_id":definition_id, "cell":Vector2i(x,y), "quarter_turn":turn, "footprint":definition.footprint}
			if decorating._session.preview(request, not ignore_id.is_empty()).ok: return request
	return {}
func run() -> void:
	var main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(.5).timeout
	var decorating = main.get_node("ShopDecoration")
	var ui = main.get_node("UIRoot/FoliageUI")
	var player: CharacterBody3D = main.get_node("World/Player")
	await press_bound_key(&"ui_decoration")
	check(decorating._active and is_instance_valid(decorating._grid), "R hook opens real grid")
	if not decorating._active or not is_instance_valid(decorating._grid):
		print("SHOP_DECORATING ", JSON.stringify({"failures":failures}))
		quit(1)
		return
	check(ui.is_modal_open() and not ui.visible, "exclusive decorating input context")
	var before := player.position
	Input.action_press("move_right")
	await create_timer(.2).timeout
	Input.action_release("move_right")
	check(player.position.distance_to(before) < .03, "decorating locks player")
	decorating._begin_add("barrel")
	check(decorating._session.snapshot().is_empty(), "preview is non-authoritative")
	decorating._rotate()
	check(decorating._pending.quarter_turn == 1, "rotate changes quarter turn")
	decorating._cancel_preview()
	check(decorating._session.snapshot().is_empty(), "cancel leaves layout unchanged")
	var candidate := free_position(decorating, "chest", 1)
	check(not candidate.is_empty(), "rotated chest has legal location")
	if not candidate.is_empty():
		var result: Dictionary = decorating._session.apply(candidate, false, decorating._session.revision())
		check(result.ok, "chest placement commits")
		decorating._sync_views()
		var node: Node3D = decorating._live_nodes[candidate.instance_id]
		check(node.rotation.y > 0.0, "real node rotates")
		var markers: Array[Node3D] = decorating._factory.targets(node)
		check(markers.size() == 1 and markers[0].get_meta("instance_id") == candidate.instance_id, "fresh chest interaction identity")
		check(main.controller._targets.has(markers[0]), "chest interaction registered")
		var original: Transform3D = node.transform
		decorating._begin_move(candidate.instance_id)
		decorating._rotate()
		decorating._cancel_preview()
		check(node.transform == original, "cancel move leaves original model intact")
		decorating._begin_move(candidate.instance_id)
		decorating._remove()
		check(decorating._session.snapshot().is_empty() and decorating._live_nodes.is_empty(), "remove synchronizes model and state")
	# Every catalog item must instantiate a tangible complete furniture root.
	for furniture in decorating._catalog.entries():
		var request := free_position(decorating, furniture.id, 0)
		check(not request.is_empty(), "legal location for " + furniture.id)
		if request.is_empty(): continue
		var result: Dictionary = decorating._session.apply(request, false, decorating._session.revision())
		check(result.ok, "commit " + furniture.id)
		decorating._sync_views()
		var furniture_node: Node3D = decorating._live_nodes[request.instance_id]
		check(not furniture_node.find_children("*", "MeshInstance3D", true, false).is_empty(), "visible model for " + furniture.id)
		check(not furniture_node.find_children("*", "CollisionShape3D", true, false).is_empty(), "collision for " + furniture.id)
		decorating._session.remove(request.instance_id, decorating._session.revision())
		decorating._sync_views()
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		await process_frame
		check(not decorating._panel._status.text.begins_with("decor."), "decoration locale resolves")
	await press_bound_key(&"ui_decoration")
	check(ui.visible and not ui.is_modal_open(), "close restores shop UI")
	print("SHOP_DECORATING ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
