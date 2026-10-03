extends Node
## Persistent in-memory composition root. Each entered node owns a fresh disposable room.
const CombatLoader = preload("res://content/combat/combat_loader.gd")
const EnemyLoader = preload("res://content/enemies/enemy_loader.gd")
const BuildLoader = preload("res://content/builds/build_loader.gd")
const RouteLoader = preload("res://content/run/run_loader.gd")
const Planner = preload("res://rogue/run/run_planner.gd")
const Session = preload("res://app/session/run_session.gd")
const Starter = preload("res://app/session/training_build_session.gd")
const Room = preload("res://app/run_room.gd")
const MapView = preload("res://presentation/run/run_map_view.gd")
const RoomHUD = preload("res://presentation/run/room_progress_hud.gd")
const ThemeFactory = preload("res://presentation/foliage/foliage_theme_factory.gd")
@export var templates: Resource = preload("res://app/run_templates.tres")
var session
var room
var map_view
var room_hud
var combat
var enemy_catalog
var build_catalog
var route: Dictionary
var planner := Planner.new()
var busy := false
var _generation := 0
var _theme: Theme
var _slot: Node3D
var _pause
var _starter_state: Dictionary
var _starter_program: Dictionary
var _committed: Dictionary = {}
var _hud_state: Dictionary = {}
func _ready() -> void:
	for locale in ["zh_CN", "en"]: TranslationServer.add_translation(load("res://generated/locales/%s.po" % locale))
	_theme = ThemeFactory.create()
	var combat_loader := CombatLoader.new()
	combat = combat_loader.load_catalog()
	if combat == null: push_error(str(combat_loader.errors)); return
	var enemy_loader := EnemyLoader.new()
	enemy_catalog = enemy_loader.load_catalog(combat)
	if enemy_catalog == null: push_error(str(enemy_loader.errors)); return
	var build_loader := BuildLoader.new()
	build_catalog = build_loader.load_catalog()
	if build_catalog == null: push_error(str(build_loader.errors)); return
	var capacities := {}
	for id in templates.rooms:
		var presentation: Resource = templates.rooms[id]
		if presentation == null or presentation.scene == null: push_error("Missing run template: " + id); return
		var geometry: Node = presentation.scene.instantiate()
		if not geometry.has_method("spawn_capacity") or not geometry.has_method("player_spawn") or not geometry.has_method("enemy_spawns"):
			geometry.free()
			push_error("Run template lacks spawn protocol: " + id)
			return
		capacities[id] = geometry.spawn_capacity()
		geometry.free()
	var route_loader := RouteLoader.new()
	route = route_loader.load_route(build_catalog, enemy_catalog, templates.rooms.keys())
	if route.is_empty(): push_error(str(route_loader.errors)); return
	planner.configure(enemy_catalog, capacities)
	var starter := Starter.new()
	starter.configure(build_catalog, 0, func(_candidate): return OK)
	var result: Dictionary = starter.apply_test_preset(route.starter_build_preset)
	if not result.ok: push_error(result.error_key); return
	_starter_state = starter.snapshot()
	_starter_program = starter.program()
	_slot = Node3D.new()
	_slot.name = "RoomSlot"
	add_child(_slot)
	var ui := CanvasLayer.new()
	add_child(ui)
	map_view = MapView.new()
	ui.add_child(map_view)
	map_view.configure(_theme)
	map_view.node_requested.connect(_enter_node)
	map_view.restart_requested.connect(restart)
	room_hud = RoomHUD.new()
	ui.add_child(room_hud)
	room_hud.configure(_theme)
	room_hud.map_requested.connect(return_to_map)
	room_hud.restart_requested.connect(restart)
	_pause = preload("res://app/pause_menu.gd").new()
	add_child(_pause)
	_pause.configure(_theme)
	_pause.open_requested.connect(func():
		if busy: return
		if is_instance_valid(room): room.pause_visuals()
		_pause.open())
	_pause.closed.connect(refresh_text)
	restart()
func _commit(candidate: Dictionary) -> Error:
	_committed = candidate.duplicate(true)
	return OK
func restart() -> void:
	if busy: return
	_generation += 1
	_dispose_room()
	session = Session.new()
	var seed := Time.get_ticks_usec()
	if not session.configure(route, seed, combat.player().health, _starter_state, _starter_program, planner.plan, _commit):
		map_view.set_notice("run.error.invalid_config")
		return
	room_hud.hide()
	map_view.show()
	map_view.set_notice("")
	map_view.set_busy(false)
	map_view.show_route(session.map_snapshot())
func _enter_node(id: String) -> void:
	if busy or get_tree().paused or session == null: return
	var prepared: Dictionary = session.prepare_enter(id)
	if not prepared.ok:
		map_view.set_notice(prepared.error_key)
		return
	busy = true
	map_view.set_busy(true)
	var generation := _generation
	var ticket: Dictionary = prepared.ticket
	var candidate := Room.new()
	_slot.add_child(candidate)
	var snapshot: Dictionary = session.snapshot()
	var valid := candidate.setup(ticket, snapshot.hp, snapshot.build_program, combat, enemy_catalog, build_catalog, templates.rooms[ticket.plan.template_id], _theme)
	await get_tree().physics_frame
	await get_tree().process_frame
	if generation != _generation:
		candidate.shutdown()
		candidate.queue_free()
		return
	if valid: valid = candidate.validate_spawns()
	var committed: Dictionary = session.commit_enter(ticket.id) if valid else {"ok": false, "error_key": "run.error.load_failed"}
	if not committed.ok:
		session.cancel_enter(ticket.id)
		candidate.shutdown()
		_slot.remove_child(candidate)
		candidate.queue_free()
		busy = false
		map_view.set_busy(false)
		map_view.set_notice(committed.error_key)
		return
	room = candidate
	room.cleared.connect(_room_cleared)
	room.defeated.connect(_room_defeated)
	map_view.hide()
	room_hud.show()
	busy = false
	room.activate()
	_refresh_hud()
func _room_cleared(entry: String, hp: float) -> void:
	var result: Dictionary = session.complete_room(entry, hp)
	if not result.ok: push_error(result.error_key)
	_refresh_hud()
func _room_defeated(entry: String) -> void:
	var result: Dictionary = session.defeat(entry)
	if not result.ok: push_error(result.error_key)
	_refresh_hud()
func return_to_map() -> void:
	if busy or session == null: return
	var snapshot: Dictionary = session.snapshot()
	var result: Dictionary = session.return_to_map(snapshot.active_entry_id)
	if not result.ok: return
	_dispose_room()
	room_hud.hide()
	map_view.show()
	map_view.set_busy(false)
	map_view.set_notice("")
	map_view.show_route(session.map_snapshot())
func _dispose_room() -> void:
	if not is_instance_valid(room): return
	room.shutdown()
	_slot.remove_child(room)
	room.queue_free()
	room = null
func _process(_delta: float) -> void:
	if is_instance_valid(room): _refresh_hud(false)
func _refresh_hud(refresh_state: bool = true) -> void:
	if session == null or not is_instance_valid(room): return
	if refresh_state: _hud_state = session.snapshot()
	room_hud.display(_hud_state.room_count, _hud_state.active_room_plan.kind, room.player.health.current, room.player.health.maximum, _hud_state.phase)
func refresh_text() -> void:
	if map_view == null: return
	map_view.refresh_text()
	room_hud.refresh_text()
	_refresh_hud()
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_language") and not event.is_echo():
		TranslationServer.set_locale("en" if TranslationServer.get_locale().begins_with("zh") else "zh_CN")
		refresh_text()
		get_viewport().set_input_as_handled()
func _exit_tree() -> void:
	_generation += 1
	_dispose_room()
