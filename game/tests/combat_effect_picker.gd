extends SceneTree
## Real training composition: switching VFX must preserve combat and consume GUI input.
var output := "E:/ShopGame/source_assets/vfx/elemental_slashes_v001/"
const STEP := 1.0 / 60.0
var failures: Array[String] = []
var verified_options: Array[String] = []
var arena

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-root="):
			output = argument.trim_prefix("--output-root=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(output + "reports")
	DirAccess.make_dir_recursive_absolute(output + "previews")
	root.size = Vector2i(1280, 800)
	arena = load("res://rogue/scenes/training_arena.tscn").instantiate()
	arena.build_choices_enabled = false
	root.add_child(arena)
	current_scene = arena
	# Drive combat explicitly; enemy AI and wall-clock timing must not alter assertions.
	arena.set_physics_process(false)
	await settle_layout()
	var picker = arena.hud.effect_picker
	for id in [&"golden", &"element_fire", &"element_lightning", &"element_thunder", &"element_frost", &"fire_slash_v002"]:
		check(picker.buttons.has(id), "approved default and new elemental effect are selectable: " + str(id))
	check(arena.EffectPalette.options.size() == picker.buttons.size(), "palette and UI contain the same effects")
	check_selection(arena.selected_effect_id)
	arena.player.runner.start(arena.player.attacks[0], Vector3.FORWARD)
	arena.player.runner.tick(arena.player.attacks[0].windup + arena.player.attacks[0].active * 0.4)
	arena.views[0].refresh(STEP)
	var before := combat_snapshot()
	for option in arena.EffectPalette.options:
		picker.buttons[option.id].pressed.emit()
		check_selection(option.id)
		var effect: Node3D = arena.views[0].weapon_effect
		check(effect.scene_file_path == option.scene.resource_path, "button installs actual scene: " + str(option.id))
		check(effect.get_script() != null, "selected effect has executable adapter: " + str(option.id))
		check(effect.get_parent() == arena.views[0].blade, "selected effect follows the sword: " + str(option.id))
		check(combat_snapshot() == before, "switch preserves cast, time, health and attack definition: " + str(option.id))
		verified_options.append(str(option.id))
		await process_frame
	check(is_equal_approx(rad_to_deg(arena.player.runner.ability.angle), 160.0), "effect switching preserves the 160 degree rule sector")
	await check_paused_switches()
	await check_mouse_input()
	await check_localized_layout()
	var report := {"failures": failures, "verified_options": verified_options, "viewport": [root.size.x, root.size.y], "renderer": RenderingServer.get_current_rendering_method()}
	var file := FileAccess.open(output + "reports/picker_validation.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("COMBAT_EFFECT_PICKER ", JSON.stringify(report))
	arena.free()
	quit(0 if failures.is_empty() else 1)

func combat_snapshot() -> Dictionary:
	var player = arena.player
	var health: Array[float] = []
	for actor in arena.actors: health.append(actor.health.current)
	return {"cast": player.runner.cast_id, "elapsed": player.runner.elapsed, "cooldown": player.runner.cooldown, "hp": health, "ability": player.runner.ability, "damage": player.runner.ability.damage, "angle": player.runner.ability.angle, "radius": player.runner.ability.radius, "combo": player.combo_index, "charges": player.charges}

func check_selection(id: StringName) -> void:
	var picker = arena.hud.effect_picker
	check(arena.selected_effect_id == id and picker.selected_id == id, "app and picker agree on selection: " + str(id))
	var pressed_count := 0
	for candidate in picker.buttons:
		var button: Button = picker.buttons[candidate]
		if button.button_pressed: pressed_count += 1
		check(button.button_pressed == (candidate == id), "button selection matches current effect: " + str(candidate))
	check(pressed_count == 1, "exactly one effect is selected")

func check_paused_switches() -> void:
	arena.paused = true
	arena.views[0].refresh(0.0)
	var before := combat_snapshot()
	for option in arena.EffectPalette.options:
		arena.hud.effect_picker.buttons[option.id].pressed.emit()
		check_selection(option.id)
		var effect: Node3D = arena.views[0].weapon_effect
		check(effect.scene_file_path == option.scene.resource_path, "paused selection updates actual effect: " + str(option.id))
		for node in effect.find_children("*", "GPUParticles3D", true, false):
			check(node.speed_scale == 0.0, "paused switch freezes new GPU particles: " + str(option.id))
		for node in effect.find_children("*", "CPUParticles3D", true, false):
			check(node.speed_scale == 0.0, "paused switch freezes new CPU particles: " + str(option.id))
		await process_frame
		check(combat_snapshot() == before, "paused selection preserves authoritative state: " + str(option.id))

func click_at(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)
		await process_frame

func check_mouse_input() -> void:
	arena.paused = false
	arena.player.cancel()
	arena.player.runner.cooldown = 0.0
	await settle_layout()
	var option = arena.EffectPalette.options[0]
	var button: Button = arena.hud.effect_picker.buttons[option.id]
	var cast_before: int = arena.player.runner.cast_id
	await click_at(button.get_global_rect().get_center())
	check_selection(option.id)
	check(not arena.player._attack_queued, "real mouse click on effect button does not request attack")
	arena.player.step(0.0)
	check(arena.player.runner.cast_id == cast_before, "button click does not start a cast")
	# The padded corner is inside the panel but outside buttons: it must consume clicks too.
	var blank: Vector2 = arena.hud.effect_picker.get_global_rect().position + Vector2(3.0, 3.0)
	await click_at(blank)
	check(not arena.player._attack_queued, "panel background consumes click instead of attacking")
	arena.player.step(0.0)
	check(arena.player.runner.cast_id == cast_before, "panel background does not start a cast")
	# Positive control: the same physical event still attacks through unobstructed arena space.
	await click_at(root.get_visible_rect().get_center())
	check(arena.player._attack_queued, "unobstructed arena click still requests attack")
	arena.player.step(0.0)
	check(arena.player.runner.cast_id == cast_before + 1, "unobstructed arena click starts a cast")
	arena.player.cancel()

func check_localized_layout() -> void:
	arena.paused = false
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		arena.hud.refresh_text()
		arena.hud.update_state(arena.player, arena.encounter, arena.catalog.waves().size(), arena.state, arena.paused)
		await settle_layout()
		var viewport: Rect2 = root.get_visible_rect()
		var panel: Rect2 = arena.hud.effect_picker.get_global_rect()
		check(viewport.encloses(panel), "effect panel fits viewport: " + locale)
		for control in arena.hud.find_children("*", "Control", true, false):
			if not control.is_visible_in_tree(): continue
			if control is Button or control is Label:
				check(viewport.encloses(control.get_global_rect()), "visible HUD control stays on screen: " + locale + " / " + control.name)
		for button in arena.hud.effect_picker.buttons.values():
			check(panel.encloses(button.get_global_rect()), "effect button fits panel: " + locale + " / " + button.text)
			check(not button.text.begins_with("combat."), "effect button translation resolves: " + locale)
		var header: Rect2 = arena.hud._top.get_global_rect()
		check(header.end.x <= panel.position.x, "combat heading does not overlap picker: " + locale)
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(image.save_png(output + "previews/picker_" + locale + ".png") == OK, "screenshot saved: " + locale)

func settle_layout() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
