extends SceneTree
## Graphical inventory acceptance. Run this script once per requested resolution.
## Exercises the composed shop through real mapped input without launching an editor.
const OUTPUT_DIRECTORY := "E:/ShopGame/docs/previews"
const ITEM_IDS := ["potion", "sword", "herb", "crystal", "scroll", "bag"]
var failures: Array[String] = []
var captures: Array[String] = []
var main: Node
var ui: Control
var finished := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error(message)
	return ok


func require(ok: bool, message: String) -> bool:
	if check(ok, message): return true
	finish()
	return false


func finish() -> void:
	if finished: return
	finished = true
	print("INVENTORY_UI ", JSON.stringify({"window":str(DisplayServer.window_get_size()), "failures":failures, "screenshots":captures}))
	quit(0 if failures.is_empty() else 1)


func settle() -> void:
	await create_timer(0.18).timeout


func key(action: StringName) -> void:
	var binding: InputEventKey
	for candidate in InputMap.action_get_events(action):
		if candidate is InputEventKey:
			binding = candidate
			break
	if not require(binding != null, "keyboard binding exists: " + str(action)): return
	for pressed: bool in [true, false]:
		var event: InputEventKey = binding.duplicate()
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()


func point_mouse(canvas_position: Vector2) -> void:
	root.warp_mouse(canvas_position)
	var point := root.get_final_transform() * canvas_position
	var motion := InputEventMouseMotion.new()
	motion.device = InputMap.action_get_events(&"camera_zoom_in")[0].device
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	await process_frame


func click_named(node_name: String) -> void:
	var target := control(node_name)
	if not require(is_instance_valid(target), "control exists: " + node_name): return
	if not require(target.is_visible_in_tree(), "control is visible: " + node_name): return
	var canvas_position := target.get_global_rect().get_center()
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


func wheel_at(canvas_position: Vector2) -> void:
	await point_mouse(canvas_position)
	var point := root.get_final_transform() * canvas_position
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputMap.action_get_events(&"camera_zoom_in")[0].duplicate()
		event.position = point
		event.global_position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()


func control(node_name: String) -> Control:
	return ui.find_child(node_name, true, false) as Control


func visible_cards() -> Array[Button]:
	var result: Array[Button] = []
	var grid := control("InventoryGrid")
	if not is_instance_valid(grid): return result
	for child in grid.get_children():
		if child is Button and child.has_meta("entry_id") and child.is_visible_in_tree():
			result.append(child)
	return result


func check_selection(id: String) -> void:
	check(ui._selected == id, "Foliage retains selected stable item ID: " + id)
	for card in visible_cards():
		check(card.button_pressed == (str(card.get_meta("entry_id")) == id), "exclusive item highlight: " + str(card.get_meta("entry_id")))
	var name_label := control("InventoryName") as Label
	var description := control("InventoryDescription") as Label
	for entry: Dictionary in ui._catalog.entries("inventory"):
		if str(entry.id) != id: continue
		check(name_label != null and name_label.text == str(TranslationServer.translate(entry.name_key)), "detail title follows translated selected item")
		check(description != null and description.text == str(TranslationServer.translate(entry.description_key)), "detail description follows translated selected item")
		return
	check(false, "selected ID belongs to the sample catalog")


func check_all_grid() -> void:
	var grid := control("InventoryGrid") as GridContainer
	if not require(grid != null, "inventory exposes its visual grid"): return
	check(grid.columns == 5, "sample grid has five columns")
	check(grid.get_child_count() == 15, "sample grid has three rows of visual placeholders")
	check(visible_cards().size() == ITEM_IDS.size(), "all view shows the six existing sample items")
	var empty_count := 0
	for cell in grid.get_children():
		if not cell.has_meta("entry_id"):
			empty_count += 1
			check(cell is BaseButton and cell.disabled, "empty placeholder cannot be activated")
	check(empty_count == 9, "all view has exactly nine empty placeholders, not a capacity claim")
	for id in ITEM_IDS:
		var card := control("Item_" + id)
		check(is_instance_valid(card) and card.is_visible_in_tree(), "sample item remains available: " + id)


func check_layout() -> void:
	var frame := control("InventoryFrame")
	if not require(is_instance_valid(frame), "inventory has a bounded frame"): return
	var viewport := root.get_visible_rect().grow(1.0)
	check(viewport.encloses(frame.get_global_rect()), "entire inventory frame fits the viewport")
	for node_name in ["InventoryGrid", "InventoryDetails", "InventoryTitle", "InventoryName", "InventoryDescription", "InventoryNotice", "InventorySort", "InventoryClose", "InventoryUse", "InventoryStore", "Category_all", "Category_equipment", "Category_potions", "Category_materials"]:
		var node := control(node_name)
		if not check(is_instance_valid(node), "layout control exists: " + node_name): continue
		check(node.is_visible_in_tree(), "layout control remains visible: " + node_name)
		check(viewport.encloses(node.get_global_rect()), "control fits viewport: " + node_name)
		check(frame.get_global_rect().grow(1.0).encloses(node.get_global_rect()), "control fits inventory frame: " + node_name)
	for card in visible_cards():
		check(frame.get_global_rect().grow(1.0).encloses(card.get_global_rect()), "item fits inventory frame: " + str(card.name))
	var details := control("InventoryDetails")
	for node_name in ["InventoryName", "InventoryDescription", "InventoryUse", "InventoryStore"]:
		var node := control(node_name)
		if is_instance_valid(node) and is_instance_valid(details):
			check(details.get_global_rect().grow(1.0).encloses(node.get_global_rect()), "detail content stays on parchment: " + node_name)
	for node in control("InventoryPanel").find_children("*", "TextureRect", true, false):
		check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "decorative texture allows control input: " + str(node.name))


func check_unavailable_actions() -> void:
	for action_name in ["InventoryUse", "InventoryStore"]:
		var button := control(action_name) as Button
		check(button != null and button.disabled, "sample action remains disabled: " + action_name)
		check(button != null and button.tooltip_text == str(TranslationServer.translate("ui.unavailable")), "disabled action explains unavailable state: " + action_name)
	var notice := control("InventoryNotice") as Label
	check(notice != null and notice.text == str(TranslationServer.translate("ui.sample_note")), "explicit sample notice has no invented item ownership")


func check_sorted() -> void:
	var cards := visible_cards()
	for index in range(1, cards.size()):
		check(cards[index - 1].tooltip_text.naturalnocasecmp_to(cards[index].tooltip_text) <= 0, "sort orders visible translated names")


func capture(locale: String) -> void:
	check(TranslationServer.get_locale().begins_with(locale), "screenshot uses requested locale: " + locale)
	check_selection("crystal")
	check_layout()
	check_unavailable_actions()
	await point_mouse(Vector2(4.0, 4.0))
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var size := DisplayServer.window_get_size()
	var path := OUTPUT_DIRECTORY + "/inventory_v001_%s_%dx%d.png" % [locale, size.x, size.y]
	var error := screenshot.save_png(path)
	check(error == OK, "screenshot saved: " + path)
	if error == OK: captures.append(path)


func run() -> void:
	create_timer(120.0).timeout.connect(func():
		if not finished:
			check(false, "inventory acceptance watchdog exceeded 120 seconds")
			finish())
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIRECTORY)
	TranslationServer.set_locale("zh_CN")
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(1.0).timeout
	ui = main.get_node("UIRoot/FoliageUI")
	var catalog_before: String = JSON.stringify(ui._catalog.entries("inventory"))
	var decorating: Node = main.get_node("ShopDecoration")
	var layout_before: Array = decorating._session.snapshot().duplicate(true)
	var revision_before: int = decorating._session.revision()
	await key(&"ui_inventory")
	if not require(ui.current_page() == "inventory" and is_instance_valid(ui._inventory_panel), "mapped B opens the inventory presentation module"): return
	for node_name in ["InventoryPanel", "InventoryFrame", "InventoryGrid", "InventoryDetails", "InventoryTitle", "InventoryName", "InventoryDescription", "InventoryNotice", "InventorySort", "InventoryClose", "InventoryUse", "InventoryStore", "Category_all", "Category_equipment", "Category_potions", "Category_materials"]:
		if not require(is_instance_valid(control(node_name)), "named inventory control exists: " + node_name): return
	check_all_grid()
	check_unavailable_actions()
	check(ui._catalog.entries("inventory").is_read_only(), "sample collection remains read-only")
	for entry: Dictionary in ui._catalog.entries("inventory"):
		check(entry.is_read_only(), "sample entry remains read-only: " + str(entry.id))
	var player: CharacterBody3D = main.get_node("World/Player")
	var player_before := player.position
	Input.action_press(&"move_right")
	await settle()
	Input.action_release(&"move_right")
	check(player.position.distance_to(player_before) < 0.03, "inventory modal locks player movement")
	var camera: Camera3D = main.get_node("World/ShopInterior/ShopCamera")
	var camera_size := camera.size
	await wheel_at(control("InventoryGrid").get_global_rect().get_center())
	await wheel_at(Vector2(4.0, 4.0))
	check(is_equal_approx(camera.size, camera_size), "modal consumes wheel over panel and dimmed shop")
	for category in ["equipment", "potions", "materials"]:
		await click_named("Category_" + category)
		check(ui._category == category, "mouse requests category: " + category)
		var expected_count := 0
		for entry: Dictionary in ui._catalog.entries("inventory"):
			if str(entry.category) == category: expected_count += 1
		check(visible_cards().size() == expected_count, "filter contains only matching samples: " + category)
		for card in visible_cards():
			for entry: Dictionary in ui._catalog.entries("inventory"):
				if str(entry.id) == str(card.get_meta("entry_id")):
					check(str(entry.category) == category, "filtered card belongs to selected category")
	await click_named("Item_crystal")
	check_selection("crystal")
	await key(&"toggle_language")
	check(TranslationServer.get_locale().begins_with("en"), "mapped L updates the open inventory language")
	check(ui._category == "materials", "language change preserves selected category")
	check_selection("crystal")
	await click_named("Category_all")
	await click_named("Item_crystal")
	await click_named("InventorySort")
	check_all_grid()
	check_sorted()
	check_selection("crystal")
	await click_named("InventoryUse")
	await click_named("InventoryStore")
	check_selection("crystal")
	await capture("en")
	await key(&"toggle_language")
	check(ui._category == "all", "second language change preserves all category")
	check_selection("crystal")
	await click_named("InventorySort")
	check_sorted()
	await capture("zh_CN")
	check(JSON.stringify(ui._catalog.entries("inventory")) == catalog_before, "UI filtering, sorting and disabled actions do not mutate catalog data")
	check(decorating._session.snapshot() == layout_before and decorating._session.revision() == revision_before, "inventory interactions never change furniture state")
	await key(&"ui_inventory")
	check(ui.current_page().is_empty() and not ui.is_modal_open(), "mapped B closes the open inventory")
	await key(&"ui_inventory")
	await click_named("InventoryClose")
	check(ui.current_page().is_empty() and not ui.is_modal_open(), "close button releases inventory modal")
	await key(&"ui_inventory")
	await key(&"ui_cancel")
	check(ui.current_page().is_empty() and not ui.is_modal_open(), "mapped Escape closes inventory without opening settings")
	finish()
