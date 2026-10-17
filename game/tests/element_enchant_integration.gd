extends SceneTree
const OUT := "E:/ShopGame/builds/element_enchant_review/"
var arena
var player
var view
var facts: Array[Dictionary] = []
var failures: Array[String] = []
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func step(delta: float = 1.0/60.0) -> void:
	if delta > 0.0:
		player.step(delta)
		arena.resolver.resolve(player, arena.actors)
		arena.builds.step(delta)
	view.refresh(delta)
	arena.builds.refresh(delta)

func run() -> void:
	create_timer(240.0).timeout.connect(func(): push_error("ELEMENT_ENCHANT TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	arena = load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	arena.set_physics_process(false)
	arena.encounter.cancel()
	arena.input_adapter.actor = null
	arena.get_node("UIRoot").hide()
	player = arena.player
	view = arena.views[0]
	player.collision_mask = 0
	player.position = Vector3(0, player.position.y, 1.5)
	player.facing = Vector3.FORWARD
	for other in arena.actors:
		if other != player: other.position = Vector3(60,0,60)
	arena.builds.runtime.action_presented.connect(func(fact):
		if fact.event == "element_hit": facts.append(fact))
	var camera: Camera3D = arena.get_node("Camera")
	camera.global_position = player.position + Vector3(4,4,6)
	camera.look_at(player.position + Vector3.UP)
	root.scaling_3d_scale = 1.0
	root.use_taa = false
	check(not is_instance_valid(view.weapon_enchant), "initial plain weapon")
	for pair in [["elem_ice_mastery", "ice"], ["elem_superconduct", "thunder"]]:
		check(arena.builds.apply_test_preset(pair[0]).ok, "apply " + pair[0])
		var element: String = pair[1]
		check(is_instance_valid(view.weapon_enchant) and view._enchant_element == element, "weapon element " + element)
		check(view.visual.weapon_fx_surface().material_overlay == view.weapon_enchant._overlay, "overlay attached to sword only")
		for i in 40:
			step()
			await process_frame
		await shot(element + "_idle")
		var target = arena.actors[1]
		target.health.current = target.health.maximum
		target.position = player.position + Vector3.FORWARD * 1.4
		player.request_action("primary")
		var previous := facts.size()
		for i in 60:
			step()
			if facts.size() > previous: break
			await process_frame
		check(facts.size() > previous and facts[-1].element == element, "real melee hit emits " + element)
		var impacts: Array = arena.builds.effects._events.filter(func(e): return e.fact.event == "element_hit")
		check(not impacts.is_empty(), "impact instantiated " + element)
		for i in 4:
			step()
			await process_frame
		await shot(element + "_hit")
		var fx = impacts[-1].node if not impacts.is_empty() else null
		var age: float = view.weapon_enchant._t
		var impact_age: float = fx._age if fx != null else 0.0
		for i in 12:
			step(0.0)
			await process_frame
		check(is_equal_approx(age, view.weapon_enchant._t), "pause freezes enchant")
		if fx != null:
			check(is_equal_approx(impact_age, fx._age), "pause freezes impact layers")
			for p in fx._particles: check(p.speed_scale == 0.0, "pause freezes GPU particle")
		check(view.weapon_enchant._overlay.get_shader_parameter("effect_time") == age, "pause freezes overlay shader")
		target.position = Vector3(60,0,60)
		for i in 330: step()
		check(arena.builds.effects._events.is_empty(), "impact expires after lifetime")
	# A second action's ice hit must use ice even when the persistent weapon is thunder.
	var target = arena.actors[1]
	target.health.current = target.health.maximum
	target.position = player.position + Vector3.FORWARD * 3.5
	var previous := facts.size()
	player.request_action("skill")
	for i in 150:
		step()
		if facts.size() > previous: break
	check(facts.size() > previous and facts[-1].element == "ice", "mixed build ice projectile uses its committed element")
	check(view._enchant_element == "thunder", "second element does not replace permanent enchant")
	target.position = Vector3(60,0,60)
	for i in 120: step()
	check(arena.builds.grant_training_upgrade("ice_core", "special").ok, "ice heavy selection applies")
	target.health.current = target.health.maximum
	target.position = player.position + Vector3.FORWARD * 1.4
	previous = facts.size()
	player.request_action("special")
	for i in 120:
		step()
		if facts.size() > previous: break
	check(facts.size() > previous and facts[-1].element == "ice", "heavy hit uses ice even during elemental reaction")
	target.position = Vector3(60,0,60)
	for i in 120: step()
	player.charges = player.dodge.charges
	player.movement = Vector3.FORWARD
	player.request_dodge()
	step()
	player.movement = Vector3.ZERO
	player.request_action("primary")
	previous = facts.size()
	for i in 100:
		target.position = player.position + Vector3.FORWARD * 1.4
		step()
		if facts.size() > previous: break
	check(facts.size() > previous and facts[-1].element == "thunder" and facts[-1].ability_id == "roll_slash", "roll slash inherits primary thunder impact")
	target.position = Vector3(60,0,60)
	for i in 120: step()
	target.health.current = 1.0
	target.position = player.position + Vector3.FORWARD * 1.4
	previous = facts.size()
	player.request_action("primary")
	for i in 100:
		step()
		if facts.size() > previous: break
	check(facts.size() > previous and not target.health.alive(), "lethal direct hit retains elemental impact")
	# Removal restores material overlay and frees the old world-space emitters.
	var old = weakref(view.weapon_enchant)
	view.set_weapon_enchant("")
	await process_frame
	check(old.get_ref() == null, "old enchant freed")
	check(view.visual.weapon_fx_surface().material_overlay == null, "overlay restored after removal")
	check(arena.builds.apply_test_preset("elem_fire_build").ok, "fire preset still applies")
	check(view._enchant_element == "fire" and is_instance_valid(view.weapon_enchant), "fire integration preserved")
	print("ELEMENT_ENCHANT checks=", checks, " failures=", failures)
	arena.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")
