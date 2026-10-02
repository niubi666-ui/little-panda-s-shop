extends SceneTree
## Headless integration checks for the real sword adapter and golden trail scene.
const Loader = preload("res://content/combat/combat_loader.gd")
const Catalog = preload("res://content/combat/combat_catalog.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const View = preload("res://presentation/combat/actor_view.gd")
const Style = preload("res://presentation/combat/training_style.tres")
const STEP := 1.0 / 60.0
const POSITION_EPSILON := 0.0001
const TIME_EPSILON := 0.000001
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var catalog := Loader.new().load_catalog()
	check(catalog != null, "catalog loads")
	if catalog == null:
		finish()
		return
	var fixture := make_fixture(catalog, 1)
	check_complete_sweep(fixture, catalog.ability("slash.1"), true)
	check_complete_sweep(fixture, catalog.ability("slash.2"), false)
	check_forward_thrust(fixture, catalog.ability("slash.3"))
	check_pause_and_decay(fixture)
	check_cancel_and_separate_strokes(fixture, catalog.ability("slash.1"))
	check_material_isolation(catalog, fixture)
	fixture.actor.free()
	finish()

func finish() -> void:
	print("GOLDEN_SWORD_TRAIL ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)

func make_fixture(catalog, handle: int) -> Dictionary:
	var actor := Actor.new()
	var abilities: Array[Catalog.Ability] = []
	for ability_id in catalog.player().attacks:
		abilities.append(catalog.ability(ability_id))
	actor.configure(catalog.player(), abilities, catalog.dodge(), handle, 0)
	root.add_child(actor)
	actor.position = Vector3(2.0, 0.0, 3.0)
	actor.facing = Vector3.FORWARD.rotated(Vector3.UP, 0.37)
	var view := View.new()
	actor.add_child(view)
	view.configure(actor, Style, SystemFont.new())
	# Clock the effect explicitly so assertions do not depend on renderer timing.
	view.weapon_effect.set_process(false)
	return {"actor": actor, "view": view, "effect": view.weapon_effect}

func begin_sweep(fixture: Dictionary, ability: Catalog.Ability, clear: bool = true) -> void:
	fixture.actor.runner.cancel()
	fixture.actor.runner.cooldown = 0.0
	if clear: fixture.effect.clear_tail()
	fixture.view.refresh(STEP)
	check(fixture.actor.runner.start(ability, fixture.actor.facing), ability.id + " starts")
	fixture.view.refresh(STEP)
	# Sample the completed anticipation before VFX starts at the active boundary.
	fixture.actor.runner.tick(ability.windup - TIME_EPSILON)
	fixture.view.refresh(STEP)
	fixture.actor.runner.tick(TIME_EPSILON)
	fixture.view.refresh(STEP)

func check_complete_sweep(fixture: Dictionary, ability: Catalog.Ability, left_to_right: bool) -> void:
	check(ability.hit_shape == "sector", ability.id + " keeps sector damage")
	check(is_equal_approx(rad_to_deg(ability.angle), 160.0), ability.id + " displays the requested 160 degree sweep")
	begin_sweep(fixture, ability)
	var origin: Vector3 = fixture.actor.global_position
	var facing: Vector3 = fixture.actor.runner.direction
	var right := facing.cross(Vector3.UP)
	var visual_radius: float = Style.weapon_tip_radius_by_ability[ability.id]
	var start_yaw := ability.angle / 2.0 if left_to_right else -ability.angle / 2.0
	var end_yaw := -start_yaw
	var expected_end := origin + facing.rotated(Vector3.UP, end_yaw) * visual_radius
	expected_end.y = Style.blade_offset.y
	check(not fixture.effect._tips.is_empty(), ability.id + " samples the first active pose")
	if fixture.effect._tips.is_empty(): return
	var start_offset := sword_tip(fixture) - origin
	start_offset.y = 0.0
	check(start_offset.dot(right) < 0.0 if left_to_right else start_offset.dot(right) > 0.0, ability.id + " starts on the requested local side")
	check(absf(facing.signed_angle_to(start_offset.normalized(), Vector3.UP) - start_yaw) < POSITION_EPSILON, ability.id + " starts at its independently expected 80 degree side")
	check(fixture.effect._tips.front().distance_to(sword_tip(fixture)) < POSITION_EPSILON, ability.id + " trail starts on the anticipated sword pose")
	advance_active(fixture, ability)
	var end_offset := sword_tip(fixture) - origin
	check(end_offset.dot(right) > 0.0 if left_to_right else end_offset.dot(right) < 0.0, ability.id + " finishes on the opposite local side")
	check(fixture.actor.runner.phase() == "recovery", ability.id + " reaches recovery")
	check(fixture.effect._tips.back().distance_to(expected_end) < POSITION_EPSILON, ability.id + " trail reaches the opposite 80 degree end pose")
	check(sword_tip(fixture).distance_to(expected_end) < POSITION_EPSILON, ability.id + " sword ends on its authored presentation radius")
	var radius_matches := true
	var largest_radius := 0.0
	var angles_inside := true
	for tip in fixture.effect._tips:
		var offset: Vector3 = tip - origin
		offset.y = 0.0
		largest_radius = maxf(largest_radius, offset.length())
		radius_matches = radius_matches and offset.length() <= visual_radius + POSITION_EPSILON
		angles_inside = angles_inside and absf(facing.signed_angle_to(offset.normalized(), Vector3.UP)) <= ability.angle / 2.0 + POSITION_EPSILON
	check(radius_matches and absf(largest_radius - visual_radius) < POSITION_EPSILON, ability.id + " pullback and sweep preserve the authored maximum tip radius")
	print("TRAIL_GEOMETRY ", JSON.stringify({"ability": ability.id, "rule_radius_m": ability.radius, "visual_radius_m": visual_radius, "left_to_right": left_to_right, "sweep_deg": rad_to_deg(ability.angle), "largest_tip_radius_m": largest_radius}))
	check(angles_inside, ability.id + " trail stays within the full 160 degree sector")
	check(not fixture.effect._active and not fixture.effect.get_node("Particles").emitting, ability.id + " recovery stops new trail and spark emission")
	check(fixture.effect._mesh.get_surface_count() == 1, ability.id + " builds a renderable ribbon")

func advance_active(fixture: Dictionary, ability: Catalog.Ability) -> void:
	var remaining := ability.active - TIME_EPSILON
	while remaining > 0.0:
		var delta := minf(STEP, remaining)
		remaining = maxf(0.0, remaining - delta)
		fixture.actor.runner.tick(delta)
		fixture.view.refresh(delta)
		fixture.effect._process(delta)
	# Record the real last active pose, then close its trail before recovery moves it.
	fixture.actor.runner.tick(TIME_EPSILON * 2.0)
	fixture.view.refresh(TIME_EPSILON * 2.0)
	fixture.effect._process(TIME_EPSILON * 2.0)

func check_forward_thrust(fixture: Dictionary, ability: Catalog.Ability) -> void:
	check(ability.hit_shape == "thrust" and is_zero_approx(ability.angle), "third attack uses thrust rather than sector damage")
	check(is_equal_approx(ability.thrust_width, 1.0), "third attack has its configured narrow width")
	begin_sweep(fixture, ability)
	var origin: Vector3 = fixture.actor.global_position
	var forward: Vector3 = fixture.actor.runner.direction
	var right := forward.cross(Vector3.UP)
	var first_tip := sword_tip(fixture)
	var first_projection := (first_tip - origin).dot(forward)
	advance_active(fixture, ability)
	var last_projection := (sword_tip(fixture) - origin).dot(forward)
	check(last_projection > first_projection, "third sword extends forward during its active phase")
	check(is_equal_approx(last_projection, Style.weapon_tip_radius_by_ability[ability.id]), "third sword reaches its independent 2.2 metre tip bound")
	var previous_projection := first_projection
	var previous_root_projection := -INF
	var forward_only := true
	var follows_blade := true
	for index in fixture.effect._tips.size():
		var tip: Vector3 = fixture.effect._tips[index]
		var projection := (tip - origin).dot(forward)
		forward_only = forward_only and projection >= previous_projection - POSITION_EPSILON
		forward_only = forward_only and absf((tip - origin).dot(right)) < POSITION_EPSILON
		forward_only = forward_only and projection <= Style.weapon_tip_radius_by_ability[ability.id] + POSITION_EPSILON
		var ribbon_root: Vector3 = fixture.effect._roots[index]
		var root_projection := (ribbon_root - origin).dot(forward)
		follows_blade = follows_blade and absf((ribbon_root - origin).dot(right)) < POSITION_EPSILON
		follows_blade = follows_blade and root_projection >= previous_root_projection - POSITION_EPSILON
		follows_blade = follows_blade and projection >= root_projection
		previous_projection = projection
		previous_root_projection = root_projection
	check(forward_only, "third trail extends along the locked facing line without a sideways sweep")
	check(follows_blade and not fixture.effect._tips.is_empty(), "third ribbon root and tip both follow the translating sword")
	check(fixture.effect._tips.back().distance_to(sword_tip(fixture)) < POSITION_EPSILON, "third trail closes at the extended sword")
	check(not fixture.effect._active and not fixture.effect.get_node("Particles").emitting, "third recovery stops emission")
	check(fixture.effect._mesh.get_surface_count() == 1, "third thrust retains its swappable ribbon geometry")

func sword_tip(fixture: Dictionary) -> Vector3:
	return fixture.view.blade.to_global(Vector3.FORWARD * Style.blade_size.z / 2.0)

func check_pause_and_decay(fixture: Dictionary) -> void:
	fixture.view.refresh(0.0)
	var tips: Array = fixture.effect._tips.duplicate()
	var ages: Array = fixture.effect._ages.duplicate()
	var clock: float = fixture.effect._visual_clock
	var phase: float = fixture.effect.ribbon_material.get_shader_parameter("frame_phase")
	fixture.effect._process(1.0)
	fixture.view.refresh(0.0)
	check(fixture.effect._tips == tips and fixture.effect._ages == ages, "paused trail geometry and fade ages remain unchanged")
	check(fixture.effect._visual_clock == clock and fixture.effect.ribbon_material.get_shader_parameter("frame_phase") == phase, "pause freezes material animation")
	check(fixture.effect.get_node("Particles").speed_scale == 0.0, "pause freezes sparks")
	fixture.view.refresh(STEP)
	fixture.effect._process(fixture.effect.tail_lifetime_sec * 2.0)
	check(fixture.effect._tips.is_empty() and fixture.effect._mesh.get_surface_count() == 0, "finished trail disappears after configured lifetime")

func check_cancel_and_separate_strokes(fixture: Dictionary, ability: Catalog.Ability) -> void:
	begin_sweep(fixture, ability)
	fixture.actor.runner.tick(ability.active * 0.7)
	fixture.view.refresh(STEP)
	var last_tip: Vector3 = fixture.effect._tips.back()
	var count: int = fixture.effect._tips.size()
	fixture.actor.runner.cancel()
	fixture.view.refresh(STEP)
	fixture.effect._process(STEP)
	check(fixture.effect._tips.back().distance_to(last_tip) < POSITION_EPSILON, "cancellation ends at the last sword pose, not the idle pose")
	check(fixture.effect._tips.size() <= count + 1, "cancellation does not generate a returning arc")
	check(not fixture.effect._active and not fixture.effect._end_pending, "cancelled stroke is closed immediately")
	var previous_tips: Array = fixture.effect._tips.duplicate()
	var previous_stroke: int = fixture.effect._stroke
	fixture.actor.position += Vector3(5.0, 0.0, 0.0)
	fixture.actor.facing = Vector3.RIGHT
	begin_sweep(fixture, ability, false)
	fixture.actor.runner.tick(ability.active * 0.5)
	fixture.view.refresh(STEP)
	check(fixture.effect._stroke == previous_stroke + 1, "next swing has a separate stroke identity")
	var preserved := true
	for index in previous_tips.size():
		preserved = preserved and fixture.effect._tips[index].distance_to(previous_tips[index]) < POSITION_EPSILON
	check(preserved, "previous tail remains at its original world positions")
	var group_changes := 0
	var expected_segments := 0
	for index in range(1, fixture.effect._strokes.size()):
		if fixture.effect._strokes[index - 1] != fixture.effect._strokes[index]:
			group_changes += 1
		else:
			expected_segments += 1
	check(group_changes == 1, "adjacent swings remain separate ribbon groups")
	var vertices: PackedVector3Array = fixture.effect._mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(vertices.size() == expected_segments * fixture.effect.radial_subdivisions * 6, "rendered mesh contains no triangles bridging two swings")

func check_material_isolation(catalog, fixture: Dictionary) -> void:
	var other := make_fixture(catalog, 2)
	var first_material: ShaderMaterial = fixture.effect.ribbon_material
	var second_material: ShaderMaterial = other.effect.ribbon_material
	check(first_material != second_material, "each trail has an independent shader material")
	other.effect.set_time_running(false)
	var phase_before: float = second_material.get_shader_parameter("frame_phase")
	fixture.effect.set_time_running(true)
	fixture.effect._process(0.03)
	check(second_material.get_shader_parameter("frame_phase") == phase_before, "one trail clock cannot change another trail material")
	other.actor.free()
