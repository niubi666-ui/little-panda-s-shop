extends Node
## Ephemeral training controls. Commands are injected; no save or reward ownership.
const ToolsPanel = preload("res://presentation/combat/training_tools_panel.gd")
const Planner = preload("res://rogue/encounters/encounter_planner.gd")
var panel
var player_invincible := false
var enemies_invincible := false
var extra_wave_count := 0
var _player
var _actors: Callable
var _allowed: Callable
var _panels: Dictionary
var _visibility: Dictionary = {}
var _hud_visibility: Callable
var _catalog
var _seed: String
var _depth: int
var _anchors: Array[Vector3]
var _spawn_clear: Callable
var _append_wave: Callable

func configure(player, actors: Callable, allowed: Callable, ui: Node, theme: Theme, panels: Dictionary, hud_visibility: Callable) -> void:
	_player = player
	_actors = actors
	_allowed = allowed
	_panels = panels
	_hud_visibility = hud_visibility
	panel = ToolsPanel.new()
	ui.add_child(panel)
	panel.configure(theme)
	for id in panels:
		_visibility[id] = panels[id].visible
		panel.register_panel(id, panels[id].visible)
	panel.register_panel("hud")
	panel.player_invincibility_changed.connect(set_player_invincible)
	panel.enemy_invincibility_changed.connect(set_enemies_invincible)
	panel.add_wave_requested.connect(add_wave)
	panel.heal_requested.connect(heal_player)
	panel.visibility_requested.connect(set_menu_visible)
	refresh()

func configure_reinforcements(catalog, seed_value: String, depth: int, anchors: Array[Vector3], spawn_clear: Callable, append_wave: Callable) -> void:
	_catalog = catalog
	_seed = seed_value
	_depth = depth
	_anchors = anchors.duplicate()
	_spawn_clear = spawn_clear
	_append_wave = append_wave

func prepare_actor(actor) -> void:
	actor.set_damage_immunity(player_invincible if actor.team == _player.team else enemies_invincible)

func set_player_invincible(enabled: bool) -> void:
	if not _allowed.call():
		panel.set_invincibility(player_invincible, enemies_invincible)
		return
	player_invincible = enabled
	_player.set_damage_immunity(enabled)
	panel.set_invincibility(player_invincible, enemies_invincible)

func set_enemies_invincible(enabled: bool) -> void:
	if not _allowed.call():
		panel.set_invincibility(player_invincible, enemies_invincible)
		return
	enemies_invincible = enabled
	for actor in _actors.call():
		if is_instance_valid(actor) and actor.team != _player.team: actor.set_damage_immunity(enabled)
	panel.set_invincibility(player_invincible, enemies_invincible)

func heal_player() -> void:
	if not _allowed.call(): return
	if _player.health.restore(): panel.set_notice("training.tools.healed")

func add_wave() -> bool:
	if not _allowed.call() or _catalog == null:
		panel.set_notice("training.tools.unavailable")
		return false
	# A failed placement does not advance this independent sequence or any gameplay RNG.
	var candidate := Planner.new().generate(_seed + ":training_extra:" + str(extra_wave_count), _depth, _anchors.size(), _catalog)
	if candidate.is_empty(): return false
	var wave: Dictionary = candidate.waves[0]
	var alive := 0
	for actor in _actors.call():
		if is_instance_valid(actor) and actor.team != _player.team and actor.health.alive(): alive += 1
	var rules: Dictionary = _catalog.encounters.training_tools
	if alive + wave.enemy_ids.size() > int(rules.max_alive_enemies):
		panel.set_notice("training.tools.limit", {"max": int(rules.max_alive_enemies)})
		return false
	var placements: Array = []
	var offsets: Array[Vector3] = []
	var steps := int(floor(float(rules.spawn_search_radius_m) / float(rules.spawn_step_m)))
	for x in range(-steps, steps + 1):
		for z in range(-steps, steps + 1):
			var offset := Vector3(x, 0.0, z) * float(rules.spawn_step_m)
			if offset.length() <= float(rules.spawn_search_radius_m): offsets.append(offset)
	offsets.sort_custom(func(a, b):
		if a.length_squared() != b.length_squared(): return a.length_squared() < b.length_squared()
		return a.x < b.x if a.x != b.x else a.z < b.z)
	for slot in wave.enemy_ids.size():
		var found := false
		for offset in offsets:
			for index in _anchors.size():
				var point := _anchors[(slot + index) % _anchors.size()] + offset
				if _spawn_clear.call(point, wave.enemy_ids[slot], placements):
					placements.append({"point": point, "actor_id": wave.enemy_ids[slot]})
					found = true
					break
			if found: break
		if not found:
			panel.set_notice("training.tools.no_space")
			return false
	_append_wave.call(wave.enemy_ids, placements)
	extra_wave_count += 1
	panel.set_notice("training.tools.added", {"count": wave.enemy_ids.size()})
	return true

func set_menu_visible(id: String, shown: bool) -> void:
	if id == "hud": _hud_visibility.call(shown)
	elif _panels.has(id):
		_visibility[id] = shown
		_panels[id].visible = shown
	else: return
	panel.set_menu_visibility(id, shown)

func refresh() -> void:
	panel.set_available(_allowed.call())
	# Training display preferences outlive victory cleanup, without reopening choices.
	for id in _panels: _panels[id].visible = _visibility[id]

func refresh_text() -> void: panel.refresh_text()
