extends SceneTree
## Render every authored card and verify static mode avoids loading effect resources.
const Art = preload("res://presentation/builds/build_card_art_library.tres")
const Motion = preload("res://presentation/builds/card_art_motion/library.tres")
const CardSkin = preload("res://presentation/builds/build_card_skin.tres")
const ChoicePanel = preload("res://presentation/builds/build_choice_panel.gd")
const Loader = preload("res://content/builds/build_loader.gd")
const ThemeFactory = preload("res://presentation/foliage/foliage_theme_factory.gd")
const OUT = "res://../source_assets/ui/build_selection/animated_v001/previews/catalog/"
var failures: Array[String] = []
var checks := 0
var review: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _layers(profile) -> Array:
	return Array(profile.layers) if profile.kind == "composite" else [profile]

func _offer(ids: Array) -> Dictionary:
	var candidates: Array = []
	for id in ids:
		candidates.append({"choice_id":id,"upgrade_id":id,"action_id":"skill","rank":1,
			"operation":"add","replaced":{},"rarity_id":Art.card(id).default_rarity})
	return {"id":"art_catalog_review","candidates":candidates,"resolved":false}

func _image() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _difference(first: Image, second: Image, rect: Rect2i) -> float:
	var changed := 0
	var samples := 0
	for y in range(rect.position.y,rect.end.y,3):
		for x in range(rect.position.x,rect.end.x,3):
			var a := first.get_pixel(x,y)
			var b := second.get_pixel(x,y)
			if maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))) > 3.0/255.0: changed += 1
			samples += 1
	return float(changed)/maxi(samples,1)

func run() -> void:
	root.size = Vector2i(1280,800)
	root.content_scale_size = root.size
	for locale in ["zh_CN","en"]: TranslationServer.add_translation(load("res://generated/locales/%s.po" % locale))
	TranslationServer.set_locale("zh_CN")
	check(Motion.profile_paths.size() == Art.cards.size(), "every illustration has a motion path")
	check(Motion.static_ids.is_empty(), "full catalog has no unimplemented static entries")
	for path in Motion.profile_paths.values():
		check(not ResourceLoader.has_cached(path), "path index does not preload " + path)
	var panel := ChoicePanel.new()
	root.add_child(panel)
	panel.configure(Loader.new().load_catalog(),ThemeFactory.create())
	panel.set_art_motion_enabled(false)
	var ids: Array = Art.cards.keys()
	for offset in range(0,ids.size(),3):
		var page := ids.slice(offset,mini(offset+3,ids.size()))
		panel.show_offer(_offer(page),[])
		for card in panel.buttons.values():
			check(card.art_motion == null, "disabled card allocates no effect: " + card.art_id)
			check(not ResourceLoader.has_cached(Motion.profile_paths[card.art_id]), "disabled card does not load its mask/profile: " + card.art_id)
		await process_frame
	panel.set_art_motion_enabled(true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for offset in range(0,ids.size(),3):
		var page := ids.slice(offset,mini(offset+3,ids.size()))
		panel.show_offer(_offer(page),[])
		await create_timer(CardSkin.deal_delay_sec+CardSkin.deal_stagger_sec*2+CardSkin.deal_sec+0.1).timeout
		for card in panel.buttons.values():
			check(card.art_motion != null, "animated catalog entry: " + card.art_id)
			if card.art_motion == null: continue
			for profile in _layers(card.art_motion.profile):
				profile.validate()
				check(profile.mask.get_width() <= 512 and profile.mask.get_height() <= 384,"bounded mask size: " + card.art_id)
				var sparks: int = profile.particle_count+profile.mist_puff_count+profile.sparkle_count+profile.stream_count
				check(sparks <= 36,"bounded visible effect count per layer: " + card.art_id)
			card.set_process(false)
		if DisplayServer.get_name() != "headless":
			var first: Image = await _image()
			for card in panel.buttons.values(): card.art_motion.advance(0.63,0.0)
			var second: Image = await _image()
			for card in panel.buttons.values():
				var art: Control = card.get_node("Illustration")
				var rect := Rect2i(art.get_global_rect()).intersection(Rect2i(Vector2i.ZERO,root.size))
				var changed := _difference(first,second,rect)
				check(changed > 0.003,"visible pixel motion in " + card.art_id)
				review.append({"id":card.art_id,"changed_pixel_fraction":changed})
			second.save_jpg(OUT+"page_%02d.jpg" % (offset/3+1),0.94)
		# Toggle both ways on every entry, including composite reactions.
		panel.set_art_motion_enabled(false)
		await process_frame
		for card in panel.buttons.values(): check(card.art_motion == null,"effect released by toggle: " + card.art_id)
		panel.set_art_motion_enabled(true)
		await process_frame
		for card in panel.buttons.values(): check(card.art_motion != null,"effect recreated by toggle: " + card.art_id)
	panel.queue_free()
	await process_frame
	await process_frame
	for path in Motion.profile_paths.values():
		check(not ResourceLoader.has_cached(path),"effect profile is no longer owned after cards close: " + path)
	var report := {"checks":checks,"failures":failures,"cards":review}
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CARD_ART_CATALOG ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
