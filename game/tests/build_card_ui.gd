extends SceneTree
## Actual panel, all catalog IDs/ranks/locales, and a real session choice through input.
const Loader = preload("res://content/builds/build_loader.gd")
const Rewards = preload("res://content/builds/reward_groups_loader.gd")
const Session = preload("res://app/session/training_build_session.gd")
const ChoicePanel = preload("res://presentation/builds/build_choice_panel.gd")
const Art = preload("res://presentation/builds/build_card_art_library.tres")
const ThemeFactory = preload("res://presentation/foliage/foliage_theme_factory.gd")
const OUT = "E:/ShopGame/source_assets/ui/build_selection/v005/previews/"
var failures: Array[String] = []
var checks := 0
var panel
var catalog
var session
var chosen := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok: failures.append(what)

func shot(file: String) -> void:
	for i in 3: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUT + file + "_final.png") == OK, "save preview " + file)

func sample(ids: Array, max_rank: bool = false) -> Dictionary:
	var candidates: Array = []
	for id in ids:
		var entry: Dictionary = catalog.upgrade(id)
		var action := "skill"
		if id in ["power", "agility"] or entry.effect_type in ["element_boost", "reaction_boost", "element_mastery"]: action = "global"
		elif id in ["primary_reach", "opening_strike"]: action = "primary"
		elif id in ["special_reach", "shatter_heavy"]: action = "special"
		candidates.append({"choice_id": id, "upgrade_id": id, "action_id": action,
			"rank": entry.max_rank if max_rank else 1, "operation": "rank" if max_rank else "add",
			"replaced": {}, "rarity_id": Art.card(id).default_rarity})
	return {"id": "visual_review", "candidates": candidates, "resolved": false}

func show_sample(ids: Array, max_rank: bool = false, wait: bool = false) -> void:
	panel.show_offer(sample(ids, max_rank), [])
	for i in 2: await process_frame
	if wait: await settle()

## 等弹出动画放完（卡牌落定、防误触锁解除）
func settle() -> void:
	for i in 240:
		if panel.accepting() and panel.buttons.values().all(func(card): return card.appear >= 1.0): break
		await process_frame
	for i in 3: await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1280, 800)
	for locale in ["zh_CN", "en"]:
		TranslationServer.add_translation(load("res://generated/locales/%s.po" % locale))
	catalog = Loader.new().load_catalog()
	check(catalog != null, "catalog loads")
	if catalog == null: quit(1); return
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.09, 0.15, 0.12)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	panel = ChoicePanel.new()
	root.add_child(panel)
	panel.configure(catalog, ThemeFactory.create())
	check(Art.cards.size() == catalog.entries().size(), "every card has an authored image")
	for locale in ["zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		for high_rank in [false, true]:
			for entry in catalog.entries():
				await show_sample([entry.id], high_rank)
				var card = panel.buttons[entry.id]
				check(card.get_node("Illustration").texture != null, locale + " art " + entry.id)
				check(card.get_node("RarityFrame").texture != null, "independent frame " + entry.id)
				check(card.get_node("BotanicalOrnament").texture != null, "independent ornament " + entry.id)
				check(card.get_node("Illustration") != card.get_node("RarityFrame"), "separate art and frame")
				for key in card.labels:
					var text: String = card.labels[key].text
					check(not text.contains("{") and not text.contains("build."), "resolved live text " + entry.id + "/" + key + "/" + locale)
					if key in ["name", "headline", "rarity", "binding", "next"]:
						var label: Label = card.labels[key]
						var width := label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
						check(width <= label.size.x, "unclipped text " + entry.id + "/" + key + "/" + locale)
				check(card.get_node("RulesScroll").get_rect().end.y <= card.get_node("ChooseSurface").position.y, "rules never overlap choose")
		await show_sample(["primary_reach", "frost_path", "opening_strike"], false, true)
		await shot("cards_" + locale)
		# Detailed rules and restrictions remain available on hover.
		var full: String = panel.buttons["opening_strike"].tooltip_text
		check(full.length() > 40, "long rules retained " + locale)
	TranslationServer.set_locale("zh_CN")
	for count in [1, 2, 3]:
		await show_sample(["primary_reach", "frost_path", "opening_strike"].slice(0, count), false, true)
		for card in panel.buttons.values():
			var rect: Rect2 = card.get_global_rect()
			check(rect.position.x >= 0 and rect.end.x <= root.size.x, "card inside width " + str(count))
			check(rect.position.y >= 0 and rect.end.y <= root.size.y, "card inside height " + str(count))
		await shot("candidates_" + str(count))
	# Future legendary frame must be ready without inventing a legendary gameplay card.
	var future := sample(["primary_reach", "frost_path", "opening_strike"])
	future.candidates[2].rarity_id = "legendary"
	panel.show_offer(future, [])
	await settle()
	await shot("legendary_skin_preview")
	# Real sampler and transaction, not synthetic preview offers.
	session = Session.new()
	var reward_loader := Rewards.new()
	var groups: Dictionary = reward_loader.load_groups(catalog)
	session.configure(catalog, 31, func(_candidate): return OK, groups)
	var opened: Dictionary = session.open_offer("normal_room", {"mode": "awakening", "count": 3, "guarantee_same": false, "guarantee_new": false})
	check(opened.ok, "real awakening sampled")
	var offer: Dictionary = session.snapshot().offer
	panel.show_offer(offer, [], ["build.awakening.title", "build.awakening.subtitle"])
	panel.choice_requested.connect(func(offer_id, choice_id):
		var result: Dictionary = session.choose(offer_id, choice_id)
		check(result.ok, "actual card input commits legal choice")
		chosen = result.ok
		if chosen: panel.dismiss()
	)
	var early: Array = panel.buttons.values()
	early[0].pressed.emit()
	check(not chosen and panel.is_open(), "choice ignored while cards are still dealing in (anti-misclick)")
	await settle()
	await shot("awakening")
	var ordered: Array = panel.buttons.values()
	check(ordered.size() == 3, "awakening keeps three candidates")
	var tip = ordered[0]._make_custom_tooltip(ordered[0].tooltip_text)
	check(tip is Control and tip.get_child(0).text == ordered[0].tooltip_text, "styled tooltip carries the full rules")
	tip.free()
	ordered[0].grab_focus()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	Input.parse_input_event(tab)
	await process_frame
	check(root.gui_get_focus_owner() in ordered, "keyboard focus remains in modal")
	var accept := InputEventKey.new()
	accept.keycode = KEY_SPACE
	accept.pressed = true
	Input.parse_input_event(accept)
	await process_frame
	accept.pressed = false
	Input.parse_input_event(accept)
	for i in 3: await process_frame
	check(chosen, "keyboard activates a real reward")
	check(session.snapshot().selections.size() == 1, "one selection exactly")
	check(not panel.is_open(), "successful choice dismisses UI")
	for i in 120:
		if not panel.visible: break
		await process_frame
	check(not panel.visible, "pick animation finishes and hides the panel")
	# Number keys pick directly once the cards have landed.
	session.open_offer("normal_room", {})
	panel.show_offer(session.snapshot().offer, session.snapshot().selections)
	await settle()
	chosen = false
	var two := InputEventKey.new()
	two.physical_keycode = KEY_2
	two.pressed = true
	Input.parse_input_event(two)
	for i in 3: await process_frame
	check(chosen and session.snapshot().selections.size() == 2, "number key 2 chooses the second card")
	# A new offer arriving during the pick animation waits for it, and counts as still choosing.
	session.open_offer("normal_room", {})
	panel.show_offer(session.snapshot().offer, session.snapshot().selections)
	check(panel.is_open() and panel.visible, "queued offer keeps the modal open")
	for i in 120:
		if not panel._closing: break
		await process_frame
	check(panel.visible and panel.buttons.size() > 0 and not panel._closing, "queued offer presented after pick animation")
	var report := {"checks": checks, "failures": failures, "cards": Art.cards.size()}
	FileAccess.open(OUT + "validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("BUILD_CARD_UI checks=", checks, " failures=", failures.size(), " details=", failures.slice(0, 12))
	quit(0 if failures.is_empty() else 1)

