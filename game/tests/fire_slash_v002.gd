extends SceneTree
## Lifecycle regression for the layered fire runtime through the real ActorView.
const Loader = preload("res://content/combat/combat_loader.gd")
const Catalog = preload("res://content/combat/combat_catalog.gd")
const Actor = preload("res://combat/actors/combat_actor.gd")
const View = preload("res://presentation/combat/actor_view.gd")
const Style = preload("res://presentation/combat/training_style.tres")
const FIRE_PATH := "res://presentation/combat/fx/fire_slash_v002/fire_slash.tscn"
const GOLDEN_PATH := "res://presentation/combat/fx/slash_default.tscn"
const REPORT := "res://../source_assets/vfx/fire_slash_v002/reports/runtime_validation.json"
const STEP := 1.0 / 60.0
const EPSILON := 0.0001
var failures: Array[String] = []
var checks_run := 0
var observed_layers: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks_run += 1
	if not condition:
		failures.append(description)
		push_error(description)

func run() -> void:
	var catalog := Loader.new().load_catalog()
	check(catalog != null, "Combat catalog must load.")
	check(ResourceLoader.exists(FIRE_PATH), "Layered fire scene must exist.")
	if catalog == null or not ResourceLoader.exists(FIRE_PATH):
		finish()
		return
	var fixture := make_fixture(catalog, 1)
	var ability = catalog.ability("slash.1")
	check_layers(fixture)
	begin(fixture, ability)
	advance_active(fixture, ability.active * 0.65)
	check_pause(fixture)
	check_cancel(fixture)
	await check_natural_decay(fixture)
	check_separate_strokes(fixture, ability)
	check_clear(fixture)
	await check_switching(fixture, ability)
	check_material_isolation(catalog, fixture)
	check_death(fixture, ability)
	check_dead_pause(fixture)
	await check_natural_decay(fixture)
	fixture.actor.free()
	finish()

func make_fixture(catalog, handle: int) -> Dictionary:
	var actor := Actor.new()
	var abilities: Array[Catalog.Ability] = []
	for id in catalog.player().attacks: abilities.append(catalog.ability(id))
	actor.configure(catalog.player(), abilities, catalog.dodge(), handle, 0)
	root.add_child(actor)
	actor.position = Vector3(2, 0, 3)
	actor.facing = Vector3.FORWARD.rotated(Vector3.UP, 0.3)
	var view := View.new()
	actor.add_child(view)
	view.configure(actor, Style, SystemFont.new())
	view.set_weapon_effect(load(FIRE_PATH))
	view.weapon_effect.set_process(false)
	return {"actor": actor, "view": view, "effect": view.weapon_effect}

func particles(effect) -> Array[Node]:
	var result: Array[Node] = []
	for node in effect.find_children("*", "CPUParticles3D", true, false): result.append(node)
	for node in effect.find_children("*", "GPUParticles3D", true, false): result.append(node)
	return result

func check_layers(fixture: Dictionary) -> void:
	var effect = fixture.effect
	var emitters := particles(effect)
	check(emitters.size() > 1, "Layered effect has additional particle emitters.")
	check(effect._core_ribbon.mesh == effect._mesh, "Hot edge shares the exact body ribbon geometry.")
	check(effect.core_material != effect.ribbon_material, "Body and hot edge have independent material layers.")
	check(effect._fire_light != null, "Layered fire has its transient light.")
	for emitter in emitters:
		check(not emitter.local_coords, "Particle layer leaves a world-space tail: " + str(emitter.name))
		check(emitter.lifetime > 0.0, "Particle layer has a bounded positive lifetime: " + str(emitter.name))
		observed_layers.append({"name": str(emitter.name), "type": emitter.get_class(), "amount": emitter.amount, "lifetime_sec": emitter.lifetime, "local_coords": emitter.local_coords})

func begin(fixture: Dictionary, ability, clear: bool = true) -> void:
	fixture.actor.runner.cancel()
	fixture.actor.runner.cooldown = 0.0
	if clear: fixture.effect.clear_tail()
	fixture.view.refresh(STEP)
	check(fixture.actor.runner.start(ability, fixture.actor.facing), "Ability starts through the real runner.")
	fixture.view.refresh(STEP)
	fixture.actor.runner.tick(ability.windup)
	fixture.view.refresh(STEP)
	fixture.effect._process(STEP)

func advance_active(fixture: Dictionary, seconds: float) -> void:
	fixture.actor.runner.tick(seconds)
	fixture.view.refresh(STEP)
	fixture.effect._process(STEP)

func check_pause(fixture: Dictionary) -> void:
	var effect = fixture.effect
	fixture.view.refresh(0.0)
	var tips: Array = effect._tips.duplicate()
	var ages: Array = effect._ages.duplicate()
	var clock: float = effect._visual_clock
	var flash: float = effect._flash_left
	var energy: float = effect._fire_light.light_energy
	var light_position: Vector3 = effect._fire_light.global_position
	var body_phase = effect.ribbon_material.get_shader_parameter("frame_phase")
	var edge_phase = effect.core_material.get_shader_parameter("heat_phase")
	effect._process(0.5)
	effect.sample_current_pose()
	check(effect._tips == tips and effect._ages == ages, "Pause freezes ribbon positions and fade ages.")
	check(effect._visual_clock == clock and effect._flash_left == flash, "Pause freezes visual and light clocks.")
	check(effect._fire_light.light_energy == energy and effect._fire_light.global_position == light_position, "Pause freezes transient light energy and position.")
	check(effect.ribbon_material.get_shader_parameter("frame_phase") == body_phase and effect.core_material.get_shader_parameter("heat_phase") == edge_phase, "Pause freezes both animated shader layers.")
	for emitter in particles(effect): check(emitter.speed_scale == 0.0, "Pause freezes every particle layer: " + str(emitter.name))
	effect.set_playback_speed(0.4)
	for emitter in particles(effect): check(emitter.speed_scale == 0.0, "Playback change while paused does not resume layer: " + str(emitter.name))
	effect.set_time_running(true)
	for emitter in particles(effect): check(is_equal_approx(emitter.speed_scale, 0.4), "Resume applies the requested speed to every layer: " + str(emitter.name))
	effect.set_playback_speed(1.0)

func check_cancel(fixture: Dictionary) -> void:
	var effect = fixture.effect
	var tip: Vector3 = effect._tips.back()
	var count: int = effect._tips.size()
	fixture.actor.cancel()
	fixture.view.refresh(STEP)
	effect._process(STEP)
	check(not effect._active and not effect._end_pending, "Cancellation closes the current stroke.")
	check(effect._tips.back().distance_to(tip) < EPSILON, "Cancellation stops at the final sword pose.")
	check(effect._tips.size() <= count + 1, "Cancellation does not produce a return arc.")
	for emitter in particles(effect): check(not emitter.emitting, "Cancellation stops new particles: " + str(emitter.name))
	check(effect._mesh.get_surface_count() > 0, "Cancellation retains the already emitted tail for natural decay.")

func check_natural_decay(fixture: Dictionary) -> void:
	var effect = fixture.effect
	var duration: float = maxf(effect.tail_lifetime_sec, effect.flash_duration_sec)
	for emitter in particles(effect): duration = maxf(duration, emitter.lifetime)
	var frames := ceili(duration / STEP) + 2
	for frame in frames:
		effect._process(STEP)
		await process_frame
	check(effect._tips.is_empty() and effect._ages.is_empty(), "Tail sample data expires after its configured lifetime.")
	check(effect._mesh.get_surface_count() == 0 and effect._core_ribbon.mesh.get_surface_count() == 0, "Both flame sheet and hot edge disappear naturally.")
	check(is_zero_approx(effect._fire_light.light_energy) and not effect._fire_light.visible, "Transient light decays completely and hides.")
	for emitter in particles(effect): check(not emitter.emitting, "Particle layer stays stopped through its full lifetime: " + str(emitter.name))

func check_separate_strokes(fixture: Dictionary, ability) -> void:
	begin(fixture, ability)
	advance_active(fixture, ability.active * 0.65)
	fixture.actor.cancel()
	fixture.view.refresh(STEP)
	var effect = fixture.effect
	var old_tips: Array = effect._tips.duplicate()
	var old_stroke: int = effect._stroke
	fixture.actor.position += Vector3(5, 0, 0)
	fixture.actor.facing = Vector3.RIGHT
	begin(fixture, ability, false)
	advance_active(fixture, ability.active * 0.5)
	check(effect._stroke == old_stroke + 1, "A new swing receives a new stroke ID.")
	var preserved := true
	for index in old_tips.size(): preserved = preserved and effect._tips[index].distance_to(old_tips[index]) < EPSILON
	check(preserved, "Previous flame tail stays in its original world position.")
	var group_changes := 0
	var segments := 0
	for index in range(1, effect._strokes.size()):
		if effect._strokes[index - 1] == effect._strokes[index]: segments += 1
		else: group_changes += 1
	check(group_changes == 1, "Two attacks remain separate flame groups.")
	var vertices: PackedVector3Array = effect._mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(vertices.size() == segments * effect.radial_subdivisions * 6, "No flame or hot-edge triangles connect two strokes.")

func check_clear(fixture: Dictionary) -> void:
	fixture.effect.clear_tail()
	check(fixture.effect._mesh.get_surface_count() == 0 and fixture.effect._tips.is_empty(), "Explicit cleanup clears both ribbon layers.")
	check(is_zero_approx(fixture.effect._fire_light.light_energy) and not fixture.effect._fire_light.visible, "Explicit cleanup clears the transient light immediately.")
	for emitter in particles(fixture.effect): check(not emitter.emitting, "Explicit cleanup stops emitter: " + str(emitter.name))

func check_switching(fixture: Dictionary, ability) -> void:
	begin(fixture, ability)
	advance_active(fixture, ability.active * 0.4)
	var old_effect = fixture.effect
	var old_light = old_effect._fire_light
	var old_layers := particles(old_effect)
	var old_core = old_effect._core_ribbon
	fixture.view.set_weapon_effect(load(GOLDEN_PATH))
	fixture.effect = fixture.view.weapon_effect
	fixture.effect.set_process(false)
	await process_frame
	check(not is_instance_valid(old_effect) and not is_instance_valid(old_light) and not is_instance_valid(old_core), "Switching removes the old root, top-level light and hot edge.")
	for node in old_layers: check(not is_instance_valid(node), "Switching frees each old particle layer.")
	fixture.view.set_weapon_effect(load(FIRE_PATH))
	fixture.effect = fixture.view.weapon_effect
	fixture.effect.set_process(false)
	fixture.view.refresh(0.0)
	check(fixture.effect._tips.is_empty(), "Switching back while paused does not resurrect an old stroke.")
	for emitter in particles(fixture.effect): check(emitter.speed_scale == 0.0, "Paused switch freezes newly created particle layers.")
	fixture.actor.cancel()
	fixture.view.refresh(STEP)
	fixture.effect.clear_tail()

func check_material_isolation(catalog, fixture: Dictionary) -> void:
	var second := make_fixture(catalog, 2)
	check(second.effect.ribbon_material != fixture.effect.ribbon_material, "Flame bodies have independent shader instances.")
	check(second.effect.core_material != fixture.effect.core_material, "Hot edges have independent shader instances.")
	second.effect.set_time_running(false)
	var phase = second.effect.core_material.get_shader_parameter("heat_phase")
	fixture.effect.set_time_running(true)
	fixture.effect._process(0.2)
	check(second.effect.core_material.get_shader_parameter("heat_phase") == phase, "Advancing one fire effect does not animate another hot edge.")
	second.actor.free()

func check_death(fixture: Dictionary, ability) -> void:
	begin(fixture, ability)
	advance_active(fixture, ability.active * 0.55)
	var tip: Vector3 = fixture.effect._tips.back()
	fixture.actor.receive_hit(fixture.actor.health.maximum)
	fixture.view.refresh(STEP)
	check(not fixture.actor.health.alive() and not fixture.actor.runner.busy(), "Actual health death cancels the ability.")
	check(not fixture.effect._active and not fixture.effect._end_pending, "Death closes the active fire stroke.")
	check(fixture.effect._tips.back().distance_to(tip) < EPSILON, "Death does not pull the last flame tip to idle.")
	for emitter in particles(fixture.effect): check(not emitter.emitting, "Death stops each new particle stream: " + str(emitter.name))

func check_dead_pause(fixture: Dictionary) -> void:
	fixture.view.refresh(0.0)
	var effect = fixture.effect
	var ages: Array = effect._ages.duplicate()
	var clock: float = effect._visual_clock
	var flash: float = effect._flash_left
	var energy: float = effect._fire_light.light_energy
	effect._process(0.5)
	check(effect._ages == ages and effect._visual_clock == clock, "Paused dead actor freezes residual fire ages and material clock.")
	check(effect._flash_left == flash and effect._fire_light.light_energy == energy, "Paused dead actor freezes residual light decay.")
	for emitter in particles(effect): check(emitter.speed_scale == 0.0, "Paused dead actor freezes residual particles: " + str(emitter.name))
	fixture.view.refresh(STEP)
	check(effect._running, "Resuming dead actor resumes residual visual lifetime for cleanup.")
	for emitter in particles(effect): check(is_equal_approx(emitter.speed_scale, 1.0), "Resuming dead actor resumes residual particles: " + str(emitter.name))

func finish() -> void:
	var report := {"effect_scene": FIRE_PATH, "renderer": RenderingServer.get_current_rendering_method(), "checks": checks_run, "particle_layers": observed_layers, "scope": ["all-layer pause", "playback speed", "cancel", "natural decay", "stroke isolation", "clear", "switch", "material isolation", "actual health death"], "failures": failures}
	var path := ProjectSettings.globalize_path(REPORT)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("FIRE_SLASH_V002_RUNTIME ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
