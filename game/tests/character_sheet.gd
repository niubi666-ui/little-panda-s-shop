extends SceneTree
## Real training scene + input routing; graphical runs also capture both locales.
var failures: Array[String] = []
var checks := 0
var arena
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)
func key(code: Key) -> void:
	var event:=InputEventKey.new(); event.keycode=code; event.physical_keycode=code;event.pressed=true
	root.push_input(event)
	event=InputEventKey.new(); event.keycode=code;event.physical_keycode=code;event.pressed=false
	root.push_input(event)
func run() -> void:
	arena=load("res://app/combat_training.tscn").instantiate()
	arena.build_choices_enabled=false; arena.enable_mechanism_presets=true
	root.add_child(arena);current_scene=arena
	for i in 8: await process_frame
	check(arena.catalog!=null and arena.character_sheet!=null,"training boots with sheet")
	if arena.catalog==null or arena.character_sheet==null: finish();return
	arena.player.set_damage_immunity(true)
	var player=arena.player
	var cards: Array=[{"upgrade_id":"power","action_id":"global","rank":1},{"upgrade_id":"ice_core","action_id":"skill","rank":1},{"upgrade_id":"charged_wave","action_id":"skill","rank":1}]
	check(arena.builds.session.restore_selections(cards).ok,"real session restores build")
	arena.builds._apply_program()
	player.health.current=73.0
	player.request_action("skill");player.step(0.001)
	player.runner.tick(player.runner.ability.windup)
	arena.builds.runtime.tick(0.001)
	var cast: int=player.runner.cast_id
	var elapsed: float=player.runner.elapsed
	var rng_state: int=player._critical_rng.state
	key(KEY_C)
	check(arena.character_sheet.opened and paused,"C opens and pauses")
	check(player.runner.busy() and player.runner.cast_id==cast,"opening preserves committed attack")
	var state: Dictionary=arena.character_sheet.snapshot()
	var projectiles: Array=arena.builds.runtime.projectiles()
	check(not projectiles.is_empty(),"pause fixture includes flying wave")
	check(is_equal_approx(state.skills[0].amount,19.2),"sheet uses real formula and weapon bonus")
	check(state.skills.any(func(s):return s.id=="charged_wave" and is_equal_approx(s.amount,86.4)),"charged preview matches build formula")
	for i in 12: await process_frame
	check(player.runner.elapsed==elapsed and player.health.current==73.0,"combat clock and HP frozen while reading")
	check(projectiles==arena.builds.runtime.projectiles(),"projectiles do not move or age while C page is open")
	check(player._critical_rng.state==rng_state,"sheet does not consume combat RNG")
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_RIGHT;click.pressed=true;root.push_input(click)
	click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_RIGHT;click.pressed=false;root.push_input(click)
	check(not player.charging_skill and player._queued_action.is_empty(),"paused click cannot buffer a skill")
	for locale in ["zh_CN","en"]:
		TranslationServer.set_locale(locale);arena.character_sheet.refresh()
		for i in 3: await process_frame
		check(arena.character_sheet.panel.heading.text==TranslationServer.translate("stats.title"),"localized heading "+locale)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var path: String=ProjectSettings.globalize_path("res://../builds/character_sheet_"+locale+".png")
			check(root.get_texture().get_image().save_png(path)==OK,"capture "+locale)
	key(KEY_ESCAPE)
	check(not arena.character_sheet.opened and not paused and not arena.pause_menu._opened,"Escape closes only C page")
	check(player._queued_action.is_empty() and not player.charging_skill,"no input leak after close")
	arena.pause_menu.open();key(KEY_C)
	check(not arena.character_sheet.opened and paused,"C cannot steal settings pause")
	arena.pause_menu.close()
	# Cross-room restore uses a real adventure room with the same chosen build and HP.
	var saved_hp: float=player.health.current
	arena.free();arena=null
	var adventure=load("res://app/forest_run.tscn").instantiate()
	adventure.initial_run_state={"seed":20261018,"area":0,"node":"boss","visited":[],"room":"boss","hp":saved_hp,"selections":cards,"gold":0,"awakenings":1}
	root.add_child(adventure);current_scene=adventure
	for i in 5:await process_frame
	check(is_equal_approx(adventure.player.health.current,saved_hp),"room reconstruction preserves absolute HP")
	check(adventure.character_sheet.open(),"C page is available in formal combat")
	check(is_equal_approx(adventure.character_sheet.snapshot().skills[0].amount,19.2),"cross-room build and preview restored")
	adventure.character_sheet.close();adventure.free()
	var shop=load("res://app/main.tscn").instantiate();root.add_child(shop);current_scene=shop
	for i in 5: await process_frame
	key(KEY_C)
	check(shop.character_sheet.opened and shop.character_sheet.snapshot().preview,"shop exposes explicit base preview")
	check(shop.character_sheet.snapshot().stats.attack_power==20.0,"shop does not inherit run buffs")
	shop.character_sheet.close();shop.free()
	finish()
func finish() -> void:
	print("CHARACTER_SHEET ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
