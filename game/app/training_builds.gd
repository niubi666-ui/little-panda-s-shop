extends Node
## Training-only application coordinator. Persistence can replace the commit adapter.
const Loader = preload("res://content/builds/build_loader.gd")
const RewardLoader = preload("res://content/builds/reward_groups_loader.gd")
const Session = preload("res://app/session/training_build_session.gd")
const Runtime = preload("res://combat/builds/build_runtime.gd")
const ChoicePanel = preload("res://presentation/builds/build_choice_panel.gd")
const StatusPanel = preload("res://presentation/builds/build_status_panel.gd")
const EffectsView = preload("res://presentation/builds/build_effects_view.gd")
const MechanismView = preload("res://presentation/builds/mechanism_view.gd")
const MechanismStyle = preload("res://presentation/builds/mechanism_style.tres")
const EffectsStyle = preload("res://presentation/builds/build_effects_style.tres")
const FrostView = preload("res://presentation/builds/frost_runtime_view.gd")
const ElementView = preload("res://presentation/builds/element_view.gd")
const ElementStyle = preload("res://presentation/builds/element_style.tres")
var frost_view: FrostView
signal damage_applied(source, target, amount: float, origin: String)
var catalog
var reward_groups: Dictionary
var _reward_profile := "training_all"
## 一局冒险里当前这次奖励的过滤条件（见 request_filtered_offer）
var _filter: Dictionary = {}
var _filtered_active := false
## 一次过滤奖励结束（chosen：是否真的选了一张）
signal offer_finished(chosen: bool)
## 构筑生效后（选卡、预设、训练加卡）：表现层据此更新剑上的元素附魔等
signal program_applied(program: Dictionary)
var session := Session.new()
var runtime := Runtime.new()
var choice_panel: ChoicePanel
var status_panel: StatusPanel
var effects: EffectsView
var mechanisms: MechanismView
var elements: ElementView
var _test_attack_ids: Array = []
var _player
var _combat_catalog
var _rules: Dictionary
var _pending := 0
var _auto_rewards := true
var _stopped := false
var _rewards_finished := false
var _committed_state: Dictionary = {}
var _test_presets_enabled := false

func configure(player, targets: Callable, wall_query: Callable, ui_root: Node, shared_theme: Theme, world: Node, combat_catalog, auto_rewards: bool, test_attack_ids: Array = [], enable_test_presets: bool = false, effects_style: Resource = EffectsStyle, mechanism_style: Resource = MechanismStyle) -> bool:
	var loader := Loader.new()
	catalog = loader.load_catalog()
	if catalog == null:
		for error in loader.errors: push_error(error)
		return false
	# Validate every authored preset using the same detached session/evaluator before UI.
	var reward_loader := RewardLoader.new()
	reward_groups = reward_loader.load_groups(catalog)
	if reward_groups.is_empty():
		for error in reward_loader.errors: push_error(error)
		return false
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
	session.configure(catalog, Time.get_ticks_usec(), _commit_training, reward_groups)
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
	frost_view = FrostView.new()
	world.add_child(frost_view)
	runtime.area_presented.connect(mechanisms.show_area_fact)
	runtime.conditional_damage_applied.connect(mechanisms.show_conditional_fact)
	elements = ElementView.new()
	world.add_child(elements)
	elements.configure(ElementStyle, shared_theme.default_font if shared_theme != null else null, catalog)
	runtime.element_presented.connect(elements.on_fact)
	status_panel = StatusPanel.new()
	ui_root.add_child(status_panel)
	status_panel.configure(catalog, shared_theme, enable_test_presets)
	status_panel.test_offer_requested.connect(request_test_offer)
	status_panel.configure_reward_profiles(reward_groups)
	status_panel.reward_profile_requested.connect(request_profile_offer)
	status_panel.test_preset_requested.connect(apply_test_preset)
	status_panel.training_upgrade_requested.connect(grant_training_upgrade)
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
	program_applied.emit(program)
	if _test_presets_enabled:
		status_panel.update_training_options(session.legal_operations().filter(func(op): return op.operation != "replace" and float(catalog.upgrade(op.upgrade_id).weight) > 0.0))

## Explicit training grant, never used by adventure rewards. Re-evaluate the selected identity.
func grant_training_upgrade(upgrade_id: String, action_id: String) -> Dictionary:
	if not _test_presets_enabled or _stopped or is_choosing() or not _player.health.alive():
		return {"ok": false, "error": "training_grant_unavailable"}
	if not catalog.has_upgrade(upgrade_id) or float(catalog.upgrade(upgrade_id).weight) <= 0.0:
		return {"ok": false, "error": "training_grant_unavailable"}
	for op in session.legal_operations(upgrade_id):
		if op.action_id != action_id or op.operation == "replace": continue
		var result: Dictionary = session.submit_operation(op)
		if result.ok:
			_player.clear_intents()
			_player.runner.cancel()
			_apply_program()
			status_panel.set_notice("build.training.granted", {"name_key": catalog.upgrade(upgrade_id).name_key})
		return result
	return {"ok": false, "error": "training_grant_unavailable"}

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
	if _pending <= 0: _queue(1)
	flush_offers()

## 一局冒险的房间奖励：选完或没有可选卡时发出 offer_finished；候选不可暂时关闭。
func request_filtered_offer(profile_id: String, filter: Dictionary) -> void:
	if _stopped or is_choosing() or not reward_groups.reward_profiles.has(profile_id):
		offer_finished.emit(false)
		return
	_reward_profile = profile_id
	_filter = filter
	_filtered_active = true
	_pending = 1
	flush_offers()

func restore_selections(selections: Array) -> bool:
	var result: Dictionary = session.restore_selections(selections)
	if result.ok: _apply_program()
	return result.ok

func request_profile_offer(profile_id: String) -> void:
	if _stopped or is_choosing() or not reward_groups.reward_profiles.has(profile_id): return
	_reward_profile = profile_id
	request_test_offer()

func reward_wave(_wave_index: int) -> void:
	if _auto_rewards and not _rewards_finished: _queue(int(_rules["rewards_per_wave"]))

func _queue(count: int) -> void:
	if not _stopped: _pending = mini(_pending + count, int(_rules["max_queued_offers"]))

func flush_offers() -> void:
	if _stopped or is_choosing() or _pending <= 0: return
	var result: Dictionary = session.open_offer(_reward_profile, _filter)
	if not result["ok"]:
		status_panel.set_notice("build.error")
		_end_filtered(false)
		return
	var offer: Dictionary = result["offer"]
	if offer["resolved"] or offer["candidates"].is_empty():
		_pending = 0
		status_panel.set_notice("build.no_candidates")
		_end_filtered(false)
		return
	_player.clear_intents()
	status_panel.set_notice("")
	var awakening := String(_filter.get("mode", "")) == "awakening"
	choice_panel.show_offer(offer, session.snapshot().selections,
		["build.awakening.title", "build.awakening.subtitle"] if awakening else ["build.title", "build.subtitle"])

func _choose(offer_id: String, choice_id: String) -> void:
	if _stopped: return
	var result: Dictionary = session.choose(offer_id, choice_id)
	if not result["ok"]:
		choice_panel.set_error(result.error_key)
		return
	_apply_program()
	_pending -= 1
	choice_panel.dismiss()
	if _filtered_active:
		_end_filtered(true)
		return
	flush_offers()

func _end_filtered(chosen: bool) -> void:
	if not _filtered_active: return
	_filtered_active = false
	_filter = {}
	_pending = 0
	offer_finished.emit(chosen)

func before_motion(delta: float) -> void: runtime.statuses.tick(delta)
func step(delta: float) -> void: runtime.tick(delta)
func refresh(delta: float) -> void:
	if frost_view != null: frost_view.sync(runtime, _player)
	effects.sync(runtime.projectiles(), delta)
	mechanisms.sync(runtime.statuses.visuals(), delta)
	elements.sync(runtime.elements.snapshot(), delta)
## 敌人身上元素的染色（给 ActorView）：取第一个元素的颜色，层数越多越浓
func element_tint(handle: int) -> Color:
	var stacks: Dictionary = runtime.elements.stacks_on(handle)
	for id in stacks:
		var amount: float = ElementStyle.tint_base + ElementStyle.tint_per_stack * (int(stacks[id]) - 1)
		var color: Color = ElementStyle.element_colors.get(id, Color.WHITE)
		return Color(color, minf(amount, 1.0))
	return Color(1, 1, 1, 0)

func refresh_text() -> void:
	choice_panel.refresh_text()
	status_panel.refresh_text()
func clear_room() -> void:
	runtime.clear_room()
	if is_instance_valid(frost_view): frost_view.clear()
	if is_instance_valid(effects): effects.clear()
	if is_instance_valid(mechanisms): mechanisms.clear()
	if is_instance_valid(elements): elements.clear()
func finish_rewards() -> void:
	# Encounter completion ends automatic offers, not the actor's combat runtime.
	_rewards_finished = true
	_pending = 0
	if is_instance_valid(choice_panel): choice_panel.dismiss()

func finish() -> void:
	if _stopped: return
	_stopped = true
	finish_rewards()
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
