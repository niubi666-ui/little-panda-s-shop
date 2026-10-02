extends Node
## Composition/application boundary for temporary shop layouts. No combat dependencies.
const Catalog = preload("res://content/decorating/decorating_catalog.gd")
const Loader = preload("res://content/decorating/decorating_loader.gd")
const Session = preload("res://shop/decorating/decoration_session.gd")
const Rules = preload("res://shop/decorating/layout_rules.gd")
const Geometry = preload("res://presentation/decorating/placement_geometry.gd")
const Factory = preload("res://presentation/decorating/furniture_view_factory.gd")
const DecorationPanel = preload("res://presentation/decorating/decorating_panel.gd")
const Style = preload("res://presentation/decorating/decorating_style.tres")
signal mode_changed(active: bool)
var _catalog: Catalog
var _session: Session
var _geometry := Geometry.new()
var _factory := Factory.new()
var _shop: Node3D
var _player: CharacterBody3D
var _camera: Camera3D
var _shop_controller
var _camera_controller
var _ui_parent: Node
var _theme: Theme
var _targets: Array[Node3D]
var _interaction_distance: float
var _placed_parent: Node3D
var _live_nodes: Dictionary = {}
var _grid: MeshInstance3D
var _ghost: Node3D
var _footprint: MeshInstance3D
var _panel: DecorationPanel
var _pending: Dictionary = {}
var _moving := false
var _expected_revision := 0
var _last_result: Dictionary = {}
var _active := false
var _configured := false
func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)
func configure(shop: Node3D, player: CharacterBody3D, camera: Camera3D, shop_controller, camera_controller, ui_parent: Node, shared_theme: Theme, shop_definition, targets: Array[Node3D]) -> bool:
	var loader := Loader.new()
	_catalog = loader.load_catalog(shop_definition.get_decorating_file())
	if _catalog == null:
		for message in loader.errors: push_error(message)
		return false
	_shop = shop
	_player = player
	_camera = camera
	_shop_controller = shop_controller
	_camera_controller = camera_controller
	_ui_parent = ui_parent
	_theme = shared_theme
	_targets = targets.duplicate()
	_interaction_distance = shop_definition.get_interaction_distance_m()
	_geometry.configure(Style, _catalog.grid_size())
	if not _geometry.errors.is_empty():
		for message in _geometry.errors: push_error(message)
		return false
	if not _factory.configure(shop, Style, _catalog, _geometry):
		for message in _factory.errors: push_error(message)
		return false
	for language in ["zh_CN", "en"]:
		TranslationServer.add_translation(load("res://generated/locales/decorating/%s.po" % language))
	_session = Session.new(_catalog)
	_placed_parent = Node3D.new()
	_placed_parent.name = "PrototypeFurniture"
	_shop.add_child(_placed_parent)
	_configured = true
	return true
func open() -> void:
	if not _configured or _active or _shop_controller.is_interaction_open(): return
	_active = true
	mode_changed.emit(true)
	_panel = DecorationPanel.new()
	_ui_parent.add_child(_panel)
	_panel.configure(_catalog, Style, _theme)
	_panel.furniture_chosen.connect(_begin_add)
	_panel.rotate_requested.connect(_rotate)
	_panel.remove_requested.connect(_remove)
	_panel.cancel_requested.connect(_cancel_preview)
	_panel.done_requested.connect(close)
	_camera_controller.set_decoration_view(true, Style.camera_focus, Style.camera_size)
	var snapshot := _geometry.snapshot(_shop, _player, _targets, _interaction_distance)
	if snapshot.is_empty():
		for message in _geometry.errors: push_error(message)
		_panel.refresh(false, false, "scene_unavailable", _session.snapshot().size())
		set_process_unhandled_input(true)
		return
	var rules := Rules.new()
	rules.configure(_geometry.board_size, snapshot.blocked, snapshot.required, snapshot.origin, snapshot.navigation, snapshot.clearance)
	_session.set_rules(rules)
	_grid = _create_grid()
	_shop.add_child(_grid)
	_panel.refresh(false, false, "idle", _session.snapshot().size())
	set_process(true)
	set_process_unhandled_input(true)
func close() -> void:
	if not _active: return
	_cancel_preview()
	if is_instance_valid(_grid): _grid.queue_free()
	if is_instance_valid(_panel): _panel.queue_free()
	_grid = null
	_panel = null
	_active = false
	set_process(false)
	set_process_unhandled_input(false)
	_camera_controller.set_decoration_view(false, Style.camera_focus, Style.camera_size)
	mode_changed.emit(false)
func _begin_add(id: String) -> void:
	if not is_instance_valid(_grid): return
	_cancel_preview()
	var definition = _catalog.furniture(id)
	_pending = {"instance_id":_session.next_id(), "definition_id":id, "cell":_geometry.world_cell(_player.global_position), "quarter_turn":0, "footprint":definition.footprint}
	_expected_revision = _session.revision()
	_ghost = _factory.create(_pending, true)
	_shop.add_child(_ghost)
	_footprint = MeshInstance3D.new()
	_footprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shop.add_child(_footprint)
	_refresh_preview()
func _begin_move(id: String) -> void:
	if not is_instance_valid(_grid): return
	_cancel_preview()
	_pending = _session.find(id)
	if _pending.is_empty(): return
	_moving = true
	_expected_revision = _session.revision()
	_ghost = _factory.create(_pending, true)
	_shop.add_child(_ghost)
	_footprint = MeshInstance3D.new()
	_footprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shop.add_child(_footprint)
	_refresh_preview()
func _rotate() -> void:
	if _pending.is_empty(): return
	_pending.quarter_turn = (_pending.quarter_turn + 1) % 4
	_refresh_preview()
func _cancel_preview() -> void:
	if is_instance_valid(_ghost): _ghost.queue_free()
	_ghost = null
	if is_instance_valid(_footprint): _footprint.queue_free()
	_footprint = null
	_pending.clear()
	_moving = false
	_last_result.clear()
	if is_instance_valid(_panel):
		_panel.set_selection("")
		_panel.refresh(false, false, "idle", _session.snapshot().size())
func _remove() -> void:
	if not _moving: return
	var result := _session.remove(_pending.instance_id, _expected_revision)
	if result.ok:
		_cancel_preview()
		_sync_views()
	_panel.refresh(not _pending.is_empty(), _moving, result.code, _session.snapshot().size())
func _process(_delta: float) -> void:
	if _pending.is_empty() or _ui_hovered(): return
	var point = _floor_point()
	if point == null: return
	var cell := _geometry.world_cell(point)
	if cell != _pending.cell:
		_pending.cell = cell
		_refresh_preview()
func _refresh_preview() -> void:
	_panel.set_selection(_pending.definition_id)
	_last_result = _session.preview(_pending, _moving)
	var scale := _ghost.scale
	_ghost.transform = Transform3D(Basis(Vector3.UP, _pending.quarter_turn * PI / 2.0) * Basis.from_scale(scale), _geometry.placement_center(_pending))
	_factory.tint_ghost(_ghost, _last_result.ok)
	var extent: Vector2i = _pending.footprint
	if _pending.quarter_turn % 2 != 0: extent = Vector2i(extent.y, extent.x)
	var plane := PlaneMesh.new()
	plane.size = Vector2(extent) * _catalog.grid_size()
	_footprint.mesh = plane
	_footprint.material_override = Style.valid_material if _last_result.ok else Style.invalid_material
	_footprint.position = _geometry.placement_center(_pending)
	_footprint.position.y = Style.footprint_height
	_panel.refresh(true, _moving, _last_result.code, _session.snapshot().size())
func _floor_point() -> Variant:
	var mouse := _camera.get_viewport().get_mouse_position()
	return Plane(Vector3.UP, Style.floor_height).intersects_ray(_camera.project_ray_origin(mouse), _camera.project_ray_normal(mouse))
func _ui_hovered() -> bool:
	return get_viewport().gui_get_hovered_control() != null
func _unhandled_input(event: InputEvent) -> void:
	if not _active or event.is_echo(): return
	if event.is_action_pressed("ui_decoration"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_cancel_or_close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not _ui_hovered():
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_or_close()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if _pending.is_empty():
				var id := _pick_instance()
				if not id.is_empty(): _begin_move(id)
			else:
				var point = _floor_point()
				if point == null: return
				_pending.cell = _geometry.world_cell(point)
				_refresh_preview()
				var result := _session.apply(_pending, _moving, _expected_revision)
				if result.ok:
					_cancel_preview()
					_sync_views()
				_panel.refresh(not _pending.is_empty(), _moving, result.code, _session.snapshot().size())
			get_viewport().set_input_as_handled()
func _cancel_or_close() -> void:
	if _pending.is_empty(): close()
	else: _cancel_preview()
func _pick_instance() -> String:
	var mouse := _camera.get_viewport().get_mouse_position()
	var start := _camera.project_ray_origin(mouse)
	var end := start + _camera.project_ray_normal(mouse) * _camera.far
	var query := PhysicsRayQueryParameters3D.create(start, end)
	var hit := _shop.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return ""
	for id in _live_nodes:
		if _live_nodes[id].is_ancestor_of(hit.collider): return id
	return ""
func _sync_views() -> void:
	# Whole replacement is small and deterministic in this prototype; register only live roots.
	for node in _live_nodes.values():
		for marker in _factory.targets(node): _shop_controller.unregister_target(marker)
		_placed_parent.remove_child(node)
		node.queue_free()
	_live_nodes.clear()
	for entry in _session.snapshot():
		var node := _factory.create(entry, false)
		_placed_parent.add_child(node)
		_live_nodes[entry.instance_id] = node
		for marker in _factory.targets(node):
			var error: Error = _shop_controller.register_target(marker)
			if error != OK: push_error("Prototype furniture interaction failed: " + error_string(error))
	_shop_controller.refresh_nearby_target()
func _create_grid() -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Style.grid_color
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var bounds: Rect2 = Style.floor_bounds
	for x in _geometry.board_size.x + 1:
		var world_x := bounds.position.x + x * _catalog.grid_size()
		mesh.surface_add_vertex(Vector3(world_x, Style.grid_height, bounds.position.y))
		mesh.surface_add_vertex(Vector3(world_x, Style.grid_height, bounds.end.y))
	for y in _geometry.board_size.y + 1:
		var world_z := bounds.position.y + y * _catalog.grid_size()
		mesh.surface_add_vertex(Vector3(bounds.position.x, Style.grid_height, world_z))
		mesh.surface_add_vertex(Vector3(bounds.end.x, Style.grid_height, world_z))
	mesh.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
