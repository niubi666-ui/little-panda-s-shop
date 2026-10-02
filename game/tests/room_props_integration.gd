extends SceneTree
const HOST = preload("res://app/combat_training.tscn")
const Planner = preload("res://rogue/rooms/prop_planner.gd")
const Loader = preload("res://content/rooms/room_prop_loader.gd")
const Surface = preload("res://presentation/rooms/forest_courtyard_v001/placement_surface.tres")
const Visuals = preload("res://presentation/rooms/props/forest_props.tres")
var failures: Array[String] = []
var arena
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func accessible_position(prop) -> Vector3:
	var module = arena.room_props
	var best := INF
	var result := Vector3.ZERO
	for x in module._grid.region.size.x:
		for y in module._grid.region.size.y:
			var cell := Vector2i(x, y)
			if module._grid.is_point_solid(cell): continue
			var p: Vector2 = module._grid.get_point_position(cell)
			var world: Vector3 = module.room.to_global(Vector3(p.x, .04, p.y))
			arena.player.global_position = world
			var distance: float = world.distance_to(prop.global_position)
			if prop.definition.kind == "searchable" and module.nearest_searchable() != prop: continue
			if distance < best and module.has_clear_path(arena.player, prop):
				result = world
				best = distance
	return result
func run() -> void:
	create_timer(90.0).timeout.connect(func(): push_error("Room integration timeout"); quit(1))
	arena = HOST.instantiate()
	arena.build_choices_enabled = false
	var reserved: Array[Vector3] = [Vector3(0,0,3),Vector3(-3,0,-3),Vector3(3,0,-3),Vector3(0,0,-5)]
	arena.initial_room_plan = Planner.new().generate(270927, Loader.new().load_catalog(), Surface, Visuals, reserved)
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	await physics_frame
	await physics_frame
	var module = arena.room_props
	check(module != null and module.props.size() >= 10, "props instantiated in authored room")
	var initial := JSON.stringify(module.plan)
	for point in reserved:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = arena.player.get_child(0).shape
		query.transform.origin = point + Vector3.UP * .525
		query.collision_mask = 1
		check(arena.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "physical spawn clear")
	var chests: Array = module.props.filter(func(prop): return prop.definition.kind == "searchable")
	for container in chests:
		check(accessible_position(container) != Vector3.ZERO, "every composition chest has real physics interaction access")
	var chest = chests[0]
	arena.player.position = Vector3(0,.04,30)
	check(not module.search_nearest(), "distant F cannot loot")
	arena.player.global_position = accessible_position(chest)
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	arena._unhandled_input(interact)
	check(chest.searched and module.session.snapshot().searched.has(chest.entry.id), "F interaction commits loot")
	var loot: Dictionary = module.session.snapshot()
	arena._unhandled_input(interact)
	check(module.session.snapshot() == loot, "repeated F cannot duplicate loot")
	for language in ["zh_CN", "en"]:
		TranslationServer.set_locale(language)
		module.refresh(true)
		check(not module.hud.get_node("Panel/Rows/Prompt").text.contains("room."), "translated loot prompt")
	# Real melee runner and hit resolver, not directly setting HP.
	var crate = module.destructibles[0]
	arena.player.global_position = accessible_position(crate)
	arena.player.facing = (crate.global_position - arena.player.global_position).normalized()
	arena.player.facing.y = 0.0
	arena.player.request_attack()
	arena.player.step(.01)
	arena.player.runner.tick(arena.player.runner.ability.windup)
	module.resolve_attack()
	check(crate.health.current == 0 and crate.collision_layer == 0, "one melee hit destroys and unblocks crate")
	check(module.session.snapshot().destroyed.has(crate.entry.id), "destroy state committed")
	var wall
	for prop in module.props:
		if prop.definition.kind == "obstacle": wall = prop; break
	check(wall.receive_hit(9999) == 0 and wall.collision_layer == 1, "stone obstacle indestructible")
	# Real character movement must get around a solid wall to reach the player.
	var enemy = arena.actors[1]
	arena.player.global_position = accessible_position(wall)
	var found_blocked_route := false
	for x in module._grid.region.size.x:
		for y in module._grid.region.size.y:
			var cell := Vector2i(x,y)
			if module._grid.is_point_solid(cell): continue
			var p: Vector2 = module._grid.get_point_position(cell)
			var world: Vector3 = module.room.to_global(Vector3(p.x,0.04,p.y))
			if world.distance_to(arena.player.global_position) > 5.0: continue
			enemy.global_position = world
			if not module.has_clear_path(enemy, arena.player):
				found_blocked_route = true
				break
		if found_blocked_route: break
	check(found_blocked_route, "reachable cells on opposite sides of composition")
	check(not module.has_clear_path(enemy, arena.player), "wall blocks attack sightline")
	print("NAV_START ", enemy.position, " target=", arena.player.position, " wall=", wall.position)
	for frame in 420:
		await physics_frame
		enemy.movement = module.movement_towards(enemy, arena.player)
		enemy.step(1.0 / 60.0)
		if enemy.global_position.distance_to(arena.player.global_position) < 1.0: break
	check(enemy.global_position.distance_to(arena.player.global_position) < 1.0, "enemy physically navigates around random wall")
	print("NAV_END ", enemy.position, " target=", arena.player.position)
	# Capture real engine view, if this is a graphical invocation.
	arena.player.position = Vector3(0,.04,3)
	arena.player.cancel()
	arena._follow_camera()
	module.refresh(true)
	TranslationServer.set_locale("zh_CN")
	module.refresh(true)
	if DisplayServer.get_name() != "headless":
		await create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("E:/ShopGame/docs/previews/room_presets_runtime.png")
	arena._finish("victory")
	if chests.size() > 1:
		var second_chest = chests[1]
		arena.player.global_position = accessible_position(second_chest)
		arena._unhandled_input(interact)
		check(second_chest.searched, "cleared room still allows searching")
	else:
		arena.player.global_position = accessible_position(chest)
		arena._unhandled_input(interact)
		check(module.session.snapshot().items == loot.items, "cleared room does not duplicate searched loot")
	arena.player.position = Vector3(0,.04,3)
	var before_move: Vector3 = arena.player.position
	Input.action_press("move_forward")
	arena._physics_process(.1)
	Input.action_release("move_forward")
	check(arena.player.position.distance_to(before_move) > 0.0, "cleared room still allows movement")
	arena._retry()
	await arena._transition.completed
	arena = current_scene
	arena.set_physics_process(false)
	check(JSON.stringify(arena.room_props.plan) == initial, "retry keeps exact plan and loot roll")
	check(arena.room_props.session.snapshot().items.is_empty(), "retry clears ephemeral loot")
	arena._new_layout()
	await arena._transition.completed
	arena = current_scene
	arena.set_physics_process(false)
	check(JSON.stringify(arena.room_props.plan) != initial, "new layout produces new plan")
	print("ROOM_PROPS_INTEGRATION ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)


