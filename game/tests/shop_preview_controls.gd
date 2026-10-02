extends SceneTree
## Independent headless checks; does not load/import shop art or the root scene.
## godot --headless --path game --script res://tests/shop_preview_controls.gd

const Loader = preload("res://content/shop_preview/shop_preview_loader.gd")
const Controller = preload("res://presentation/shop_preview/shop_preview_controller.gd")
const Selection = preload("res://presentation/shop_preview/shop_interaction_selection.gd")
const STYLE = preload("res://presentation/shop_preview/shop_preview_style.tres")

var _failed: int = 0
var _checks: int = 0
var _opened_events: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var loader := Loader.new()
	var registry := loader.load_registry("res://data/manifest.json")
	_check(registry != null, "manifest publishes validated registry: " + str(loader.get_errors()))
	if registry == null:
		quit(1)
		return
	var definition = registry.get_shop_preview()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/shop_preview.json"))
	var invalid := data.duplicate(true)
	invalid["movement"]["speeed_mps"] = invalid["movement"]["speed_mps"]
	_check(loader.decode(invalid, "fixture/unknown.json") == null and "unknown field" in str(loader.get_errors()), "unknown fields rejected with diagnostics")
	invalid = data.duplicate(true)
	invalid["movement"].erase("speed_mps")
	_check(loader.decode(invalid, "fixture/missing.json") == null and "speed_mps" in str(loader.get_errors()), "missing gameplay value cannot silently default")
	invalid = data.duplicate(true)
	invalid["interaction"]["distance_m"] = 0
	_check(loader.decode(invalid, "fixture/range.json") == null, "nonpositive range rejected")
	invalid = data.duplicate(true)
	invalid["movement"]["gravity_mps2"] = true
	_check(loader.decode(invalid, "fixture/type.json") == null, "boolean cannot become gameplay number")
	invalid = data.duplicate(true)
	invalid["schema_version"] = 1.5
	_check(loader.decode(invalid, "fixture/version.json") == null, "fractional schema version rejected")
	_install_fixture_inputs()
	_install_fixture_translations()
	var fixture := Node3D.new()
	root.add_child(fixture)
	var player := CharacterBody3D.new()
	fixture.add_child(player)
	var visual := Node3D.new()
	player.add_child(visual)
	var camera := Camera3D.new()
	fixture.add_child(camera)
	camera.position = Vector3(0.0, 6.0, 6.0)
	camera.look_at(Vector3.ZERO)
	var far_target := _make_target(fixture, "station.far", Vector3(1.3, 0.0, 0.0))
	var near_target := _make_target(fixture, "station.near", Vector3(0.8, 0.0, 0.0))
	var targets: Array[Node3D] = [far_target, near_target]
	var ui := CanvasLayer.new()
	root.add_child(ui)
	var controller := Controller.new()
	fixture.add_child(controller)
	# This fixture has no imported actor or animations; production mapping stays in Resource.
	var fixture_style = STYLE.duplicate(true)
	fixture_style.idle_animation = &""
	fixture_style.move_animation = &""
	var result: Error = controller.configure(player, camera, visual, null, targets, ui, definition, fixture_style)
	_check(result == OK, "controller configures with validated dependencies")
	controller.set_physics_process(false)
	controller.interaction_opened.connect(func(_instance_id: StringName, _definition_id: StringName): _opened_events += 1)
	controller.refresh_nearby_target()
	_check(controller.get_nearby_instance_id() == &"station.near", "closest interaction marker wins regardless of array order")
	_check(controller.is_interaction_prompt_visible(), "nearby target shows prompt")
	Input.action_press("move_right")
	controller._physics_process(0.016)
	_check(player.velocity.x > 0.0, "movement follows projected camera right")
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	controller._unhandled_input(interact)
	_check(controller.is_interaction_open(), "interaction input opens placeholder")
	_check(not controller.is_interaction_prompt_visible(), "modal hides proximity prompt")
	controller._physics_process(0.016)
	_check(is_zero_approx(player.velocity.x) and is_zero_approx(player.velocity.z), "modal blocks movement even while movement key is held")
	controller._unhandled_input(interact)
	_check(_opened_events == 1, "repeated interaction cannot reopen modal or emit duplicate requests")
	controller.toggle_language()
	_check(TranslationServer.get_locale().begins_with("en") and TranslationServer.translate("shop.preview.pending") == "Feature awaiting design", "language toggle resolves English placeholder")
	controller.toggle_language()
	_check(TranslationServer.get_locale().begins_with("zh") and TranslationServer.translate("shop.preview.pending") == "功能待设计", "language toggle resolves Chinese placeholder")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	controller._unhandled_input(cancel)
	_check(not controller.is_interaction_open(), "Escape action closes modal")
	Input.action_release("move_right")
	player.position = Vector3(20.0, 0.0, 0.0)
	controller.refresh_nearby_target()
	_check(not controller.is_interaction_prompt_visible() and controller.get_nearby_instance_id().is_empty(), "leaving interaction radius hides prompt and clears target")
	_check(not controller.try_interact(), "out of range interaction is rejected")
	var dynamic_target := _make_target(fixture, "station.dynamic", player.position)
	_check(controller.register_target(dynamic_target) == OK and controller.get_nearby_instance_id() == &"station.dynamic", "explicit registration enables a new furniture interaction")
	var duplicate_target := _make_target(fixture, "station.dynamic", player.position)
	_check(controller.register_target(duplicate_target) == ERR_ALREADY_EXISTS, "duplicate furniture instance ID is rejected")
	var missing_metadata := Node3D.new()
	fixture.add_child(missing_metadata)
	_check(controller.register_target(missing_metadata) == ERR_INVALID_DATA, "dynamic registration validates the same required metadata")
	_check(controller.try_interact(), "newly registered furniture opens a placeholder")
	controller.unregister_target(dynamic_target)
	_check(not controller.is_interaction_open(), "removing the open interaction target closes its modal")
	_check(controller.get_nearby_instance_id().is_empty() and not controller.is_interaction_prompt_visible(), "removed target is no longer selected or prompted")
	_check(not controller.try_interact(), "removed and rejected targets cannot be interacted with")
	_check(controller.register_target(dynamic_target) == OK, "removed furniture instance ID can be registered again")
	controller.unregister_target(dynamic_target)
	near_target.position = Vector3.ZERO
	far_target.position = Vector3.ZERO
	_check(Selection.find_nearest(Vector3.ZERO, targets, definition.get_interaction_distance_m()) == far_target, "distance ties resolve by stable furniture instance ID")
	var exact_range := definition.get_interaction_distance_m()
	var single_target: Array[Node3D] = [near_target]
	_check(Selection.find_nearest(Vector3(exact_range, 0.0, 0.0), single_target, exact_range) == near_target, "range boundary is included")
	var rear_anchor := Marker3D.new()
	near_target.add_child(rear_anchor)
	rear_anchor.position = Vector3(0,0,-5)
	_check(Selection.find_nearest(Vector3(0,0,-5), single_target, exact_range) == near_target, "rear anchor resolves to the same furniture identity")
	near_target.position.x = 10
	_check(Selection.find_nearest(Vector3(0,0,-5), single_target, exact_range) == null, "moving furniture also moves rear interaction reach")
	fixture.queue_free()
	ui.queue_free()
	await process_frame
	print("SHOP_PREVIEW_CONTROLS: %s checks, %s failures" % [_checks, _failed])
	quit(0 if _failed == 0 else 1)


func _make_target(parent: Node3D, instance_id: String, position: Vector3) -> Node3D:
	var target := Node3D.new()
	parent.add_child(target)
	target.position = position
	target.set_meta("instance_id", instance_id)
	target.set_meta("definition_id", "furniture.sales_counter")
	target.set_meta("name_key", "shop.station.counter.name")
	target.set_meta("action_key", "shop.station.counter.action")
	return target


func _install_fixture_inputs() -> void:
	var mapping := {"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S, "interact": KEY_F, "toggle_language": KEY_L, "ui_cancel": KEY_ESCAPE}
	for action: String in mapping:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var key := InputEventKey.new()
		key.physical_keycode = mapping[action]
		InputMap.action_add_event(action, key)


func _install_fixture_translations() -> void:
	# Unit fixture deliberately avoids PO imports; the build tool separately checks PO parity.
	for locale: String in ["zh_CN", "en"]:
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/locales/" + locale + ".json"))
		var translation := Translation.new()
		translation.locale = locale
		for key: String in source["messages"]:
			translation.add_message(key, source["messages"][key])
		TranslationServer.add_translation(translation)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failed += 1
		push_error("FAILED: " + description)
	else:
		print("PASS: " + description)
