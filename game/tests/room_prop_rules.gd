extends SceneTree
const Loader = preload("res://content/rooms/room_prop_loader.gd")
const Planner = preload("res://rogue/rooms/prop_planner.gd")
const Session = preload("res://app/session/training_loot_session.gd")
const Surface = preload("res://presentation/rooms/forest_courtyard_v001/placement_surface.tres")
const Visuals = preload("res://presentation/rooms/props/forest_props.tres")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var loader := Loader.new()
	var catalog = loader.load_catalog()
	check(catalog != null, "validated catalog")
	if catalog == null:
		print(loader.errors)
		quit(1)
		return
	var reserved: Array[Vector3] = [Vector3(0,0,3), Vector3(-3,0,-3), Vector3(3,0,-3), Vector3(0,0,-5)]
	var planner := Planner.new()
	var variants := {}
	var min_count := 100000
	var max_count := 0
	for seed_value in 40:
		var plan := planner.generate(seed_value, catalog, Surface, Visuals, reserved)
		var repeated := planner.generate(seed_value, catalog, Surface, Visuals, reserved)
		check(plan == repeated, "same seed determinism: %s" % seed_value)
		var restored: Dictionary = JSON.parse_string(JSON.stringify(plan, "", true, true))
		check(restored.seed == plan.seed and restored.placements.size() == plan.placements.size(), "plain-value plan roundtrip")
		for index in plan.placements.size():
			var a: Dictionary = plan.placements[index]
			var b: Dictionary = restored.placements[index]
			check(a.prop_id == b.prop_id and is_equal_approx(a.yaw_radians, b.yaw_radians) and Vector3(a.position[0],a.position[1],a.position[2]).is_equal_approx(Vector3(b.position[0],b.position[1],b.position[2])), "roundtrip transform")
		var grid := Planner.grid_for(plan.placements, Surface, Visuals, catalog.rules)
		check(Planner.connected(grid, reserved, plan.placements, Visuals, catalog.rules), "reachable seed %s" % seed_value)
		check(plan.compositions.size() == 3, "three complete compositions: %s" % seed_value)
		var instance_ids := {}
		for group in plan.compositions:
			variants[group.composition_id] = true
			check(not instance_ids.has(group.id), "unique group identity")
			instance_ids[group.id] = true
			var expected := Planner.members_for(Visuals.composition(group.composition_id), group.id, Vector3(group.position[0],group.position[1],group.position[2]), group.yaw_radians, catalog)
			var actual: Array = plan.placements.filter(func(e): return e.composition_instance_id == group.id)
			check(actual.size() == expected.size(), "whole preset accepted; no lost members")
			for index in actual.size():
				check(actual[index].position == expected[index].position and actual[index].yaw_radians == expected[index].yaw_radians, "authored relative geometry preserved")
		check(plan.placements.any(func(e): return e.prop_id == "chest1"), "treasure wall retained")
		min_count = mini(min_count, plan.placements.size())
		max_count = maxi(max_count, plan.placements.size())
	check(variants.size() == catalog.rules.composition_ids.size(), "all four compositions generated")
	var plan := planner.generate(77, catalog, Surface, Visuals, reserved)
	check(plan != planner.generate(78, catalog, Surface, Visuals, reserved), "different seeds")
	var session := Session.new()
	session.configure(plan, func(candidate):
		candidate.items["injected"] = 999
		return false)
	var before := session.snapshot()
	var chest: Dictionary = plan.placements.filter(func(entry): return entry.kind == "searchable")[0]
	check(not session.search(chest.id) and session.snapshot() == before, "failed commit keeps authority isolated")
	session.configure(plan, func(candidate):
		candidate.items["injected"] = 999
		return true)
	check(session.search(chest.id), "loot succeeds")
	check(not session.snapshot().items.has("injected"), "adapter cannot mutate committed candidate")
	var after := session.snapshot()
	check(not session.search(chest.id) and session.snapshot() == after, "repeat loot idempotent")
	check(not session.search("unknown"), "unknown prop rejected")
	for entry in plan.placements:
		if entry.kind == "obstacle": check(not session.destroy(entry.id), "obstacle not destroyable")
		if entry.kind == "destructible":
			check(catalog.prop(entry.prop_id).health == 1, "one HP destructible")
			check(session.destroy(entry.id) and not session.destroy(entry.id), "destroy idempotent")
	print("ROOM_PROP_RULES ", JSON.stringify({"failures":failures, "seeds":40,"min_props":min_count,"max_props":max_count,"variants":variants.keys()}))
	quit(0 if failures.is_empty() else 1)

