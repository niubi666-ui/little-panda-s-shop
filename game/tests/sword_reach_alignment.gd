extends SceneTree
## Reads the real palette, view, sword poses and ribbon geometry. No render wait.
## --require-coverage checks slash ribbon coverage and the separate narrow thrust rules.
const Loader = preload("res://content/combat/combat_loader.gd")
const Catalog = preload("res://content/combat/combat_catalog.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const View = preload("res://presentation/combat/actor_view.gd")
const Resolver = preload("res://combat/effects/melee_resolver.gd")
const Style = preload("res://presentation/combat/training_style.tres")
const Palette = preload("res://presentation/combat/effect_picker/palette.tres")
const STEP := 1.0 / 60.0
const EPSILON := 0.0001
const TIME_EPSILON := 0.000001
const REPORT_ROOT := "E:/ShopGame/source_assets/vfx/elemental_slashes_v001/reports/"
var failures: Array[String] = []
var cases: Array[Dictionary] = []
var require_coverage := false
var output_root := REPORT_ROOT

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	require_coverage = "--require-coverage" in OS.get_cmdline_user_args()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-root="):
			output_root = argument.trim_prefix("--output-root=").trim_suffix("/") + "/"
	var catalog := Loader.new().load_catalog()
	check(catalog != null, "real combat catalog loads")
	if catalog == null:
		finish()
		return
	for option in Palette.options:
		for ability_id in catalog.player().attacks:
			measure_sweep(catalog, option, catalog.ability(ability_id))
	check(cases.size() == Palette.options.size() * catalog.player().attacks.size(), "all palette and combo combinations measured")
	if require_coverage:
		check_preserved_visuals()
		check_enlarged_rule_sectors(catalog)
	finish()

func make_rule_actor(catalog, actor_id: String, handle: int, team: int) -> Actor:
	var actor := Actor.new()
	var abilities: Array[Catalog.Ability] = []
	for ability_id in catalog.actor(actor_id).attacks:
		abilities.append(catalog.ability(ability_id))
	actor.configure(catalog.actor(actor_id), abilities, catalog.dodge() if team == 0 else null, handle, team)
	root.add_child(actor)
	return actor

func check_enlarged_rule_sectors(catalog) -> void:
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT_ROOT + "reach_before.json"))
	var old_radii: Dictionary = {}
	for before in baseline.cases: old_radii[before.ability_id] = before.rule_radius_m
	var current_visual_bounds: Dictionary = {}
	for sample in cases:
		current_visual_bounds[sample.ability_id] = maxf(current_visual_bounds.get(sample.ability_id, 0.0), sample.main_ribbon_bound_m)
	var resolver := Resolver.new()
	for ability_id in catalog.player().attacks:
		var ability: Catalog.Ability = catalog.ability(ability_id)
		check(ability.radius > old_radii[ability_id], ability_id + " enlarged rule radius is applied")
		if ability.hit_shape == "thrust":
			check_thrust_rule_bounds(catalog, ability, resolver)
			continue
		check(ability.hit_shape == "sector", ability_id + " uses slash sector damage")
		check(is_equal_approx(rad_to_deg(ability.angle), 160.0), ability_id + " keeps the 160 degree sector")
		var source := make_rule_actor(catalog, catalog.player().id, 100, 0)
		source.position = Vector3(2.0, 0.0, -3.0)
		var facing := Vector3.FORWARD.rotated(Vector3.UP, 0.37)
		var samples: Array[Dictionary] = [
			{"label": "main ribbon outer edge hits", "distance": current_visual_bounds[ability_id], "angle": 0.0, "hit": true},
			{"label": "between old and new radii hits", "distance": (old_radii[ability_id] + ability.radius) / 2.0, "angle": 0.0, "hit": true},
			{"label": "just inside new radius hits", "distance": ability.radius - 0.01, "angle": 0.0, "hit": true},
			{"label": "outside new radius misses", "distance": ability.radius + 0.01, "angle": 0.0, "hit": false},
			{"label": "minus 79 degrees hits", "distance": ability.radius * 0.75, "angle": -79.0, "hit": true},
			{"label": "plus 79 degrees hits", "distance": ability.radius * 0.75, "angle": 79.0, "hit": true},
			{"label": "minus 81 degrees misses", "distance": ability.radius * 0.75, "angle": -81.0, "hit": false},
			{"label": "plus 81 degrees misses", "distance": ability.radius * 0.75, "angle": 81.0, "hit": false}
		]
		var targets: Array = []
		for sample in samples:
			var target := make_rule_actor(catalog, "brute", 101 + targets.size(), 1)
			target.position = source.position + facing.rotated(Vector3.UP, deg_to_rad(sample.angle)) * sample.distance
			targets.append(target)
		check(source.runner.start(ability, facing), ability_id + " resolver test starts")
		source.runner.tick(ability.windup)
		resolver.resolve(source, targets + targets)
		resolver.resolve(source, targets)
		for index in targets.size():
			var target: Actor = targets[index]
			var expected_damage := ability.damage if samples[index].hit else 0.0
			check(is_equal_approx(target.health.current, target.health.maximum - expected_damage), ability_id + " " + samples[index].label + " with per-swing deduplication")
		for target in targets: target.free()
		source.free()

func check_thrust_rule_bounds(catalog, ability: Catalog.Ability, resolver) -> void:
	check(is_zero_approx(ability.angle), "third attack has no damage sweep angle")
	check(is_equal_approx(ability.radius, 2.8) and is_equal_approx(ability.thrust_width, 1.0), "third attack keeps the authored forward reach and narrow width")
	var source := make_rule_actor(catalog, catalog.player().id, 100, 0)
	source.position = Vector3(2.0, 0.0, -3.0)
	var forward := Vector3.FORWARD.rotated(Vector3.UP, 0.37)
	var right := forward.cross(Vector3.UP)
	var samples: Array[Dictionary] = [
		{"label": "forward sword tip hits", "forward": Style.weapon_tip_radius_by_ability[ability.id], "side": 0.0, "hit": true},
		{"label": "near front edge hits", "forward": ability.radius - 0.01, "side": 0.0, "hit": true},
		{"label": "beyond front edge misses", "forward": ability.radius + 0.01, "side": 0.0, "hit": false},
		{"label": "inside left side hits", "forward": ability.radius / 2.0, "side": -ability.thrust_width / 2.0 + 0.01, "hit": true},
		{"label": "inside right side hits", "forward": ability.radius / 2.0, "side": ability.thrust_width / 2.0 - 0.01, "hit": true},
		{"label": "outside left side misses", "forward": ability.radius / 2.0, "side": -ability.thrust_width / 2.0 - 0.01, "hit": false},
		{"label": "outside right side misses", "forward": ability.radius / 2.0, "side": ability.thrust_width / 2.0 + 0.01, "hit": false},
		{"label": "behind actor misses", "forward": -0.01, "side": 0.0, "hit": false},
		{"label": "old broad side arc misses", "forward": 0.4, "side": 1.6, "hit": false}
	]
	var targets: Array = []
	for sample in samples:
		var target := make_rule_actor(catalog, "brute", 101 + targets.size(), 1)
		target.position = source.position + forward * sample.forward + right * sample.side
		targets.append(target)
	check(source.runner.start(ability, forward), "third thrust boundary test starts")
	source.runner.tick(ability.windup)
	resolver.resolve(source, targets + targets)
	resolver.resolve(source, targets)
	for index in targets.size():
		var target: Actor = targets[index]
		var expected_damage := ability.damage if samples[index].hit else 0.0
		check(is_equal_approx(target.health.current, target.health.maximum - expected_damage), "thrust " + samples[index].label + " with per-cast deduplication")
	for target in targets: target.free()
	source.free()

func check_preserved_visuals() -> void:
	var baseline_path := REPORT_ROOT + "reach_before.json"
	check(FileAccess.file_exists(baseline_path), "visual baseline exists")
	if not FileAccess.file_exists(baseline_path): return
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
	var current_by_id: Dictionary = {}
	for sample in cases: current_by_id[sample.effect_id + "/" + sample.ability_id] = sample
	for before in baseline.cases:
		var key: String = before.effect_id + "/" + before.ability_id
		check(current_by_id.has(key), key + " remains in the palette")
		if not current_by_id.has(key): continue
		var after: Dictionary = current_by_id[key]
		# The third strike deliberately changed from a wide arc to a forward thrust.
		if after.hit_shape == "sector":
			check(absf(after.main_ribbon_bound_m - before.main_ribbon_bound_m) < EPSILON, key + " preserves its previous maximum main ribbon extent")
		check(absf(after.sword_tip_radius_m - before.sword_tip_radius_m) < EPSILON, key + " preserves its previous sword pose radius")

func make_fixture(catalog, scene: PackedScene) -> Dictionary:
	var actor := Actor.new()
	var abilities: Array[Catalog.Ability] = []
	for ability_id in catalog.player().attacks:
		abilities.append(catalog.ability(ability_id))
	actor.configure(catalog.player(), abilities, catalog.dodge(), 1, 0)
	root.add_child(actor)
	actor.position = Vector3(2.0, 0.0, -3.0)
	actor.facing = Vector3.FORWARD.rotated(Vector3.UP, 0.37)
	var view := View.new()
	actor.add_child(view)
	view.configure(actor, Style, SystemFont.new())
	var original_effect: Node3D = view.weapon_effect
	view.set_weapon_effect(scene)
	if is_instance_valid(original_effect): original_effect.free()
	stop_automatic_process(view)
	return {"actor": actor, "view": view, "effect": view.weapon_effect}

func stop_automatic_process(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): stop_automatic_process(child)

func has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if property.name == property_name: return true
	return false

func radius_xz(point: Vector3, origin: Vector3) -> float:
	var offset := point - origin
	return Vector2(offset.x, offset.z).length()

func measure_sweep(catalog, option, ability: Catalog.Ability) -> void:
	var fixture := make_fixture(catalog, option.scene)
	var effect: Node3D = fixture.effect
	var is_cpu := has_property(effect, "_tips") and has_property(effect, "_mesh")
	var sample: Dictionary = {
		"effect_id": String(option.id), "scene": option.scene.resource_path,
		"ability_id": ability.id, "rule_radius_m": ability.radius,
		"hit_shape": ability.hit_shape, "thrust_width_m": ability.thrust_width,
		"angle_deg": rad_to_deg(ability.angle), "blade_length_m": Style.blade_size.z,
		"measurement": "cpu_world_mesh_and_tips" if is_cpu else "gpu_emission_endpoint_conservative_bound",
		"sword_tip_radius_m": 0.0, "sword_lateral_extent_m": 0.0, "mesh_radius_m": 0.0,
		"tips_radius_m": 0.0, "main_ribbon_bound_m": 0.0, "sampled_poses": 0,
		"excludes": "detached decoration particles, screen-space bloom"
	}
	if is_cpu:
		sample["tip_extension_ratio"] = effect.tip_extension_ratio
	else:
		sample["blade_span_m"] = effect.blade_span
		sample["bound_reason"] = "trail particle shader records emission-transform local +/-Y endpoints; draw shader interpolates their convex hull with width curve <= 1, billboard disabled; GPU positions are not read back in headless mode"
		check(not effect._trail.billboard, "GPU bound requires billboard disabled")
	fixture.view.refresh(STEP)
	effect._process(0.0)
	check(fixture.actor.runner.start(ability, fixture.actor.facing), String(option.id) + "/" + ability.id + " starts")
	fixture.view.refresh(STEP)
	effect._process(0.0)
	fixture.actor.runner.tick(ability.windup - TIME_EPSILON)
	fixture.view.refresh(STEP)
	effect._process(0.0)
	fixture.actor.runner.tick(TIME_EPSILON)
	fixture.view.refresh(STEP)
	effect._process(0.0)
	record_pose(fixture, sample, is_cpu)
	var remaining := ability.active - TIME_EPSILON
	while remaining > 0.0:
		var delta := minf(STEP, remaining)
		remaining = maxf(0.0, remaining - delta)
		fixture.actor.runner.tick(delta)
		fixture.view.refresh(delta)
		effect._process(delta)
		record_pose(fixture, sample, is_cpu)
	fixture.actor.runner.tick(TIME_EPSILON * 2.0)
	fixture.view.refresh(TIME_EPSILON * 2.0)
	effect._process(TIME_EPSILON * 2.0)
	record_pose(fixture, sample, is_cpu)
	sample["excess_over_rule_m"] = maxf(0.0, sample.main_ribbon_bound_m - ability.radius)
	check(sample.main_ribbon_bound_m > 0.0, String(option.id) + "/" + ability.id + " has measured main ribbon")
	if require_coverage and ability.hit_shape == "sector":
		check(ability.radius + EPSILON >= sample.main_ribbon_bound_m, String(option.id) + "/" + ability.id + " rule contains main ribbon")
	if ability.hit_shape == "thrust":
		check(sample.sword_lateral_extent_m < EPSILON, String(option.id) + "/" + ability.id + " sword remains on its forward thrust axis")
		check(sample.sword_tip_radius_m <= ability.radius + EPSILON, String(option.id) + "/" + ability.id + " sword tip stays within forward gameplay reach")
	cases.append(sample)
	print("SWORD_REACH_CASE ", JSON.stringify(sample))
	fixture.actor.free()

func record_pose(fixture: Dictionary, sample: Dictionary, is_cpu: bool) -> void:
	var origin: Vector3 = fixture.actor.global_position
	var effect: Node3D = fixture.effect
	var sword_tip: Vector3 = fixture.view.blade.to_global(Vector3.FORWARD * Style.blade_size.z / 2.0)
	sample.sword_tip_radius_m = maxf(sample.sword_tip_radius_m, radius_xz(sword_tip, origin))
	var right: Vector3 = fixture.actor.runner.direction.cross(Vector3.UP)
	sample.sword_lateral_extent_m = maxf(sample.sword_lateral_extent_m, absf((sword_tip - origin).dot(right)))
	sample.sampled_poses += 1
	if is_cpu:
		for tip in effect._tips:
			sample.tips_radius_m = maxf(sample.tips_radius_m, radius_xz(tip, origin))
		for surface in effect._mesh.get_surface_count():
			var vertices: PackedVector3Array = effect._mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var world_vertex: Vector3 = effect._ribbon.to_global(vertex)
				sample.mesh_radius_m = maxf(sample.mesh_radius_m, radius_xz(world_vertex, origin))
		sample.main_ribbon_bound_m = maxf(sample.mesh_radius_m, sample.tips_radius_m)
	else:
		var trail: GPUParticles3D = effect._trail
		for endpoint in [Vector3.UP, Vector3.DOWN]:
			sample.main_ribbon_bound_m = maxf(sample.main_ribbon_bound_m, radius_xz(trail.to_global(endpoint), origin))

func finish() -> void:
	var maxima: Dictionary = {}
	for sample in cases:
		var key: String = sample.ability_id
		maxima[key] = maxf(maxima.get(key, 0.0), sample.main_ribbon_bound_m)
	var report := {
		"mode": "require_coverage" if require_coverage else "measurement_only",
		"step_sec": STEP, "palette_count": Palette.options.size(),
		"main_ribbon_max_by_ability_m": maxima, "cases": cases,
		"notes": ["Static actor, real translated/rotated ActorView and actual palette scene instances.", "CPU mesh bound includes transparent UV padding; no CPU shader vertex displacement.", "GPU fire is an analytical endpoint bound, not rendered GPU readback.", "Detached particles and bloom are excluded; visual histories while moving do not imply persistent damage.", "The first two slashes retain their maximum ribbon extents. Third-strike FX width is decorative; narrow thrust damage is verified separately at front, side and rear boundaries."]
	}
	DirAccess.make_dir_recursive_absolute(output_root)
	var filename := "reach_after.json" if require_coverage else "reach_before.json"
	if not require_coverage and FileAccess.file_exists(output_root + filename): filename = "reach_current.json"
	var file := FileAccess.open(output_root + filename, FileAccess.WRITE)
	check(file != null, "measurement report can be saved")
	if file != null: file.store_string(JSON.stringify(report, "\t") + "\n")
	print("SWORD_REACH_ALIGNMENT ", JSON.stringify({"failures": failures, "maxima": maxima, "report": output_root + filename}))
	quit(0 if failures.is_empty() else 1)
