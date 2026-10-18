extends SceneTree
## Real BuildCardView/panel lifecycle and reward input; graphical mode writes review PNGs.
const Loader = preload("res://content/builds/build_loader.gd")
const Rewards = preload("res://content/builds/reward_groups_loader.gd")
const Session = preload("res://app/session/training_build_session.gd")
const ChoicePanel = preload("res://presentation/builds/build_choice_panel.gd")
const Art = preload("res://presentation/builds/build_card_art_library.tres")
const CardSkin = preload("res://presentation/builds/build_card_skin.tres")
const ThemeFactory = preload("res://presentation/foliage/foliage_theme_factory.gd")
const IDS = ["fire_core", "ice_core", "thunder_core"]
const OUT = "res://../source_assets/ui/build_selection/animated_v001/previews/"
var failures: Array[String] = []
var checks := 0
var panel
var catalog
var session
var requests := 0
var commits := 0
var screenshots: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok: failures.append(what)

func _wait(seconds: float) -> void:
	await create_timer(seconds, true).timeout

func _settle() -> void:
	await _wait(CardSkin.deal_delay_sec + CardSkin.deal_stagger_sec * 2.0 + CardSkin.deal_sec + CardSkin.input_lock_sec)
	check(panel.accepting(), "panel accepts input after real entry timeline")
	check(panel.buttons.values().all(func(card): return is_equal_approx(card.appear, 1.0)), "cards complete existing entry motion")

func _sample(ids: Array) -> Dictionary:
	var candidates: Array = []
	for index in ids.size():
		var id: String = ids[index]
		var entry: Dictionary = catalog.upgrade(id)
		var action := "skill"
		if id in ["power", "agility"] or entry.effect_type in ["element_boost", "reaction_boost", "element_mastery"]: action = "global"
		elif id in ["primary_reach", "opening_strike"]: action = "primary"
		elif id in ["special_reach", "shatter_heavy"]: action = "special"
		candidates.append({"choice_id": "preview_%s" % index, "upgrade_id": id,
			"action_id": action, "rank": 1, "operation": "add", "replaced": {},
			"rarity_id": Art.card(id).default_rarity})
	return {"id": "motion_preview", "candidates": candidates, "resolved": false}

func _show(ids: Array) -> void:
	panel.show_offer(_sample(ids), [])
	await _settle()

func _shot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for index in 3: await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUT + label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "save " + label)
	screenshots.append(path)

func _key(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	root.push_input(event)

func _click(point: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	root.push_input(move)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = point
		event.global_position = point
		root.push_input(event)

func _layer_checks(card) -> void:
	var motion = card.art_motion
	check(motion != null, card.art_id + " has authored motion")
	if motion == null: return
	var illustration: TextureRect = card.get_node("Illustration")
	check(illustration.texture.resource_path == card.art_path, "static source art retained " + card.art_id)
	check(illustration.material == null, "base art has no deformation shader " + card.art_id)
	check(motion.overlay != illustration, "motion is a separate overlay " + card.art_id)
	check(motion.overlay.get_parent() != null, "motion belongs to card tree " + card.art_id)
	if motion.profile.kind == "thunder":
		for index in motion._events.size():
			var next_start: float = motion._events[index+1].start if index+1 < motion._events.size() else motion._event_period
			var gap: float = next_start-motion._events[index].start
			check(gap >= motion.profile.arc_interval.x and gap <= motion.profile.arc_interval.y, "thunder interval including loop seam stays configured")
			check(motion._events[index].duration > gap, "thunder has overlapping discharge, including loop seam")
			var next_path: int = motion._events[(index+1)%motion._events.size()].path
			check(motion._events[index].path != next_path, "thunder moves to another surrounding path")
	var controls: Array[Node] = [motion.overlay]
	controls.append_array(motion.overlay.find_children("*", "Control", true, false))
	for control in controls:
		if control is Control:
			check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "effect does not intercept input " + card.art_id + "/" + control.name)
	check(card.get_node("RulesScroll").get_rect().end.y <= card.get_node("ChooseSurface").position.y, "rules stay above choice surface " + card.art_id)
	var static_rects: Dictionary = {}
	for key in card.labels: static_rects[key] = card.labels[key].get_rect()
	card.set_process(false)
	var before: float = motion.clock
	motion.advance(0.4, 0.0)
	check(motion.clock > before, "visible motion advances explicit clock " + card.art_id)
	for key in card.labels:
		check(card.labels[key].get_rect() == static_rects[key], "text layout remains stable " + card.art_id + "/" + key)
	card.set_art_motion_paused(true)
	before = motion.clock
	motion.advance(0.4, 1.0)
	check(is_equal_approx(motion.clock, before), "explicit freeze stops clock " + card.art_id)
	card.set_art_motion_paused(false)
	card.set_art_motion_enabled(false)
	before = motion.clock
	motion.advance(0.4, 0.0)
	check(is_equal_approx(motion.clock, before), "static mode stops clock " + card.art_id)
	check(not motion.overlay.is_visible_in_tree(), "static mode removes overlay " + card.art_id)
	check(int(motion.diagnostics().particles) == 0, "static mode leaves no active particles " + card.art_id)
	card.set_art_motion_enabled(true)
	card.set_process(true)

func _instances_and_lifecycle() -> void:
	for id in IDS:
		await _show([id, id, id])
		var cards: Array = panel.buttons.values()
		var phases: Array = []
		var materials: Array = []
		for card in cards:
			if card.art_motion == null:
				check(false, "missing motion " + id)
				continue
			var diagnostic: Dictionary = card.art_motion.diagnostics()
			phases.append(diagnostic.phase)
			materials.append(diagnostic.material_id)
		check(phases.size() == 3 and phases[0] != phases[1] and phases[1] != phases[2] and phases[0] != phases[2], "three " + id + " cards have independent phase")
		check(materials.size() == 3 and materials[0] != materials[1] and materials[1] != materials[2] and materials[0] != materials[2], "three " + id + " cards own independent materials")
		if cards[0].art_motion == null: continue
		var other: float = cards[1].art_motion.intensity
		cards[0].set_art_motion_intensity(0.35)
		check(is_equal_approx(cards[1].art_motion.intensity, other), "intensity mutation isolated " + id)
		var clocks: Array = []
		for card in cards: clocks.append(card.art_motion.clock)
		panel.hide()
		await _wait(0.15)
		for index in cards.size():
			cards[index].art_motion.advance(0.4, 0.0)
			check(is_equal_approx(cards[index].art_motion.clock, clocks[index]), "hidden card clock stops " + id + str(index))
			check(int(cards[index].art_motion.diagnostics().particles) == 0, "hidden card clears active particles " + id + str(index))
		panel.show()
		await _wait(0.1)
		check(cards[0].art_motion.clock > clocks[0], "motion resumes after show " + id)
		var old_card: WeakRef = weakref(cards[0])
		panel.dismiss()
		await _wait(maxf(CardSkin.discard_sec, CardSkin.close_sec) + 0.2)
		check(not panel.visible and panel.buttons.is_empty(), "dismiss clears all cards " + id)
		check(old_card.get_ref() == null, "dismiss releases card instance " + id)

func _layouts() -> void:
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = resolution
		root.content_scale_size = resolution
		for locale in ["zh_CN", "en"]:
			TranslationServer.set_locale(locale)
			await _show(IDS)
			for card in panel.buttons.values():
				var rect: Rect2 = card.get_global_rect()
				check(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(rect), "card inside " + str(resolution) + "/" + locale)
				for key in card.labels:
					var label: Label = card.labels[key]
					check(not label.text.contains("build.") and not label.text.contains("{"), "translated " + card.art_id + "/" + key + "/" + locale)
					if key in ["name", "headline", "rarity", "binding", "next"]:
						var width: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
						check(width <= label.size.x, "single line fits " + card.art_id + "/" + key + "/" + locale)
			await _shot("cards_motion_%sx%s_%s" % [resolution.x, resolution.y, locale])
			for card in panel.buttons.values(): card.set_art_motion_enabled(false)
			await _shot("cards_static_%sx%s_%s" % [resolution.x, resolution.y, locale])

func _reward_input() -> void:
	session = Session.new()
	var groups: Dictionary = Rewards.new().load_groups(catalog)
	session.configure(catalog, 31, func(_state): commits += 1; return OK, groups)
	check(session.open_offer("normal_room", {"mode": "awakening", "count": 3, "guarantee_same": false, "guarantee_new": false}).ok, "real awakening opens")
	var offer: Dictionary = session.snapshot().offer
	panel.show_offer(offer, [], ["build.awakening.title", "build.awakening.subtitle"])
	panel.choice_requested.connect(func(offer_id, choice_id):
		requests += 1
		var result: Dictionary = session.choose(offer_id, choice_id)
		check(result.ok, "real reward validates and commits")
		if result.ok: panel.dismiss()
	)
	var original_commits := commits
	var rng_before: String = session.snapshot().rng_state
	panel.buttons.values()[0].pressed.emit()
	check(requests == 0 and session.snapshot().selections.is_empty(), "entry lock rejects premature click")
	# The reward modal remains animated while world rules are paused.
	paused = true
	await _settle()
	var cards: Array = panel.buttons.values()
	var animated = null
	for card in cards:
		if card.art_motion != null: animated = card; break
	check(animated != null, "real awakening has animated sample")
	if animated != null:
		var clock_before: float = animated.art_motion.clock
		await _wait(0.15)
		check(animated.art_motion.clock > clock_before, "reward UI moves while world is paused")
	check(session.snapshot().rng_state == rng_before, "presentation consumes no reward random state")
	cards[0].grab_focus()
	_key(KEY_TAB)
	_key(KEY_TAB, false)
	await process_frame
	check(root.gui_get_focus_owner() in cards, "keyboard focus stays inside cards")
	var target = animated if animated != null else cards[0]
	var art: Control = target.get_node("Illustration")
	var point: Vector2 = art.get_global_transform_with_canvas() * (art.size * 0.5)
	_click(point)
	_click(point)
	await process_frame
	check(requests == 1, "art-area mouse click submits exactly once despite double click")
	check(commits == original_commits + 1 and session.snapshot().selections.size() == 1, "exactly one real transaction committed")
	await _wait(maxf(CardSkin.pick_sec + CardSkin.close_sec, CardSkin.burst_lifetime) + 0.3)
	check(not panel.visible and panel.buttons.is_empty(), "selection exit releases cards while world paused")
	check(panel.find_children("PickBurst", "", true, false).is_empty(), "selection burst finishes without residual emitter")
	paused = false

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280, 800)
	root.content_scale_size = root.size
	for locale in ["zh_CN", "en"]:
		TranslationServer.add_translation(load("res://generated/locales/%s.po" % locale))
	TranslationServer.set_locale("zh_CN")
	catalog = Loader.new().load_catalog()
	check(catalog != null, "build catalog loads")
	if catalog == null: quit(1); return
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.09, 0.15, 0.12)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = ChoicePanel.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(panel)
	panel.configure(catalog, ThemeFactory.create())
	# This visual fixture must not depend on the player's saved UI preference.
	panel.set_art_motion_enabled(true)
	check(is_equal_approx(CardSkin.screen_height_fraction, 0.69), "existing screen fraction retained")
	# Exercise the real library map for every remaining card, including legacy inactive cards.
	for entry in catalog.entries():
		if entry.id in IDS: continue
		panel.show_offer(_sample([entry.id]), [])
		check(panel.buttons.values()[0].art_motion != null, "catalog card has authored motion " + entry.id)
		await process_frame
	await _show(IDS)
	for card in panel.buttons.values(): _layer_checks(card)
	await _instances_and_lifecycle()
	await _layouts()
	await _reward_input()
	var report := {"checks": checks, "failures": failures, "screenshots": screenshots}
	FileAccess.open(OUT + "validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("CARD_ART_MOTION checks=", checks, " failures=", failures.size(), " details=", failures)
	quit(0 if failures.is_empty() else 1)
