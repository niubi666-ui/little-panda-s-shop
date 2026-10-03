extends Node
## Training-only application coordinator. Persistence can replace the commit adapter.
const Loader = preload("res://content/builds/build_loader.gd")
const Session = preload("res://app/session/training_build_session.gd")
const Runtime = preload("res://combat/builds/build_runtime.gd")
const ChoicePanel = preload("res://presentation/builds/build_choice_panel.gd")
const StatusPanel = preload("res://presentation/builds/build_status_panel.gd")
const EffectsView = preload("res://presentation/builds/build_effects_view.gd")
const MechanismView = preload("res://presentation/builds/mechanism_view.gd")
const MechanismStyle = preload("res://presentation/builds/mechanism_style.tres")
const EffectsStyle = preload("res://presentation/builds/build_effects_style.tres")
signal damage_applied(source, target, amount: float, origin: String)
var catalog
var session := Session.new()
var runtime := Runtime.new()
var choice_panel: ChoicePanel
var status_panel: StatusPanel
var effects: EffectsView
var mechanisms: MechanismView
var _test_attack_ids: Array = []
var _player
var _combat_catalog
var _rules: Dictionary
var _pending := 0
var _auto_rewards := true
var _stopped := false
var _committed_state: Dictionary = {}
var _test_presets_enabled := false

func configure(player, targets: Callable, wall_query: Callable, ui_root: Node, shared_theme: Theme, world: Node, combat_catalog, auto_rewards: bool, test_attack_ids: Array = [], enable_test_presets: bool = false, effects_style: Resource = EffectsStyle, mechanism_style: Resource = MechanismStyle) -> bool:
	var loader := Loader.new()
	catalog = loader.load_catalog()
	if catalog == null:
		for error in loader.errors: push_error(error)
		return false
	# Validate every authored preset using the same detached session/evaluator before UI.
	for preset in catalog.test_presets():
		var probe := Session.new()
		probe.configure(catalog, 0, func(_candidate): return OK)
		var checked: Dictionary = probe.apply_test_preset(preset.id)
		if not checked.ok:
			push_error("Invalid build preset %s: %s" % [preset.id, checked.error_key])
			return false
	_test_attack_ids = test_attack_ids.duplicate()
	_player = player
	_combat_catalog = combat_catalog
	_auto_rewards = auto_rewards
	_test_presets_enabled = enable_test_presets
	_rules = catalog.offer_rules()
	session.configure(catalog, Time.get_ticks_usec(), _commit_training)
	runtime.configure(catalog, player, targets, wall_query, _test_attack_ids)
	player.runner.committed.connect(runtime.on_committed)
	player.runner.cue_reached.connect(runtime.on_cue)
	player.runner.finished.connect(runtime.on_finished)
	runtime.damage_applied.connect(func(source, target, amount, origin): damage_applied.emit(source, target, amount, origin))
	effects = EffectsView.new()
	world.add_child(effects)
	effects.configure(effects_style)
	runtime.chain_emitted.connect(effects.show_chain)
	runtime.projectile_presented.connect(effects.on_projectile_event)
	runtime.action_presented.connect(effects.on_action_event)
	mechanisms = MechanismView.new()
	world.add_child(mechanisms)
	mechanisms.configure(mechanism_style)
	runtime.area_presented.connect(mechanisms.show_area_fact)
	status_panel = StatusPanel.new()
	ui_root.add_child(status_panel)
	status_panel.configure(catalog, shared_theme, enable_test_presets)
	status_panel.test_offer_requested.connect(request_test_offer)
	status_panel.test_preset_requested.connect(apply_test_preset)
	choice_panel = ChoicePanel.new()
	ui_root.add_child(choice_panel)
	choice_panel.configure(catalog, shared_theme)
	choice_panel.choice_requested.connect(_choose)
	_apply_program()
	if _auto_rewards: _queue(int(_rules["initial_offers"]))
	return true

func _commit_training(candidate: Dictionary) -> Error:
	_committed_state = candidate.duplicate(true)
	return OK

func _apply_program() -> void:
	var program: Dictionary = session.program()
	runtime.set_program(program)
	_player.set_action_program(program.actions, _combat_catalog)
	_player.set_build_movement_multiplier(float(program.global.move_scale))
	status_panel.update_state(session.snapshot().selections, program)

func apply_test_preset(id: String) -> Dictionary:
	if not _test_presets_enabled or _stopped or is_choosing() or not _player.health.alive():
		return {"ok": false, "error": "preset_unavailable"}
	var result: Dictionary = session.apply_test_preset(id)
	if not result.ok:
		status_panel.set_notice(result.error_key)
		return result
	_player.clear_intents()
	_player.runner.cancel()
	_pending = 0
	choice_panel.dismiss()
	clear_room()
	_apply_program()
	status_panel.set_notice("build.preset.applied", {"name_key": catalog.test_preset(id).name_key})
	return result

func is_choosing() -> bool:
	return choice_panel != null and choice_panel.visible

func request_test_offer() -> void:
	if _stopped or is_choosing(): return
	_queue(1)
	flush_offers()

func reward_wave(_wave_index: int) -> void:
	if _auto_rewards: _queue(int(_rules["rewards_per_wave"]))

func _queue(count: int) -> void:
	if not _stopped: _pending = mini(_pending + count, int(_rules["max_queued_offers"]))

func flush_offers() -> void:
	if _stopped or is_choosing() or _pending <= 0: return
	var result: Dictionary = session.open_offer()
	if not result["ok"]:
		status_panel.set_notice("build.error")
		return
	var offer: Dictionary = result["offer"]
	if offer["resolved"] or offer["candidates"].is_empty():
		_pending = 0
		status_panel.set_notice("build.no_candidates")
		return
	_player.clear_intents()
	status_panel.set_notice("")
	choice_panel.show_offer(offer, session.snapshot().selections)

func _choose(offer_id: String, choice_id: String) -> void:
	if _stopped: return
	var result: Dictionary = session.choose(offer_id, choice_id)
	if not result["ok"]:
		choice_panel.set_error(result.error_key)
		return
	_apply_program()
	_pending -= 1
	choice_panel.dismiss()
	flush_offers()

func before_motion(delta: float) -> void: runtime.statuses.tick(delta)
func step(delta: float) -> void: runtime.tick(delta)
func refresh(delta: float) -> void:
	effects.sync(runtime.projectiles(), delta)
	mechanisms.sync(runtime.statuses.visuals(), delta)
func refresh_text() -> void:
	choice_panel.refresh_text()
	status_panel.refresh_text()
func clear_room() -> void:
	runtime.clear_room()
	if is_instance_valid(effects): effects.clear()
	if is_instance_valid(mechanisms): mechanisms.clear()
func finish() -> void:
	if _stopped: return
	_stopped = true
	_pending = 0
	if is_instance_valid(choice_panel): choice_panel.dismiss()
	if is_instance_valid(status_panel): status_panel.hide()
	clear_room()

func resume_training() -> void:
	# Extra practice after victory keeps the chosen build, without another reward.
	_stopped = false
	_apply_program()

func handle_test_input(event: InputEvent) -> bool:
	if _test_attack_ids.is_empty() or _stopped or is_choosing(): return false
	if get_viewport().gui_get_focus_owner() is LineEdit: return false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		runtime.fire_attack(_test_attack_ids[0], _player.facing)
		return true
	return false
