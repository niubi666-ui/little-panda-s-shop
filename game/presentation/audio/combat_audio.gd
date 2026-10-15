extends Node3D
## 战斗音效：只消费已经发生的战斗事实（出手、命中、受击、冻结、击杀……），不改任何规则。
## 删掉本节点或换掉 wav 都不影响判定。配置在 combat_audio_style.tres。
const Style = preload("res://presentation/audio/combat_audio_style.gd")

var style: Style
var _players: Array[AudioStreamPlayer3D] = []
var _next_voice := 0
var _last_played: Dictionary = {}
var _clock := 0.0
var _rng := RandomNumberGenerator.new()     # 只用于音高/选曲，不碰玩法随机流
var _player
var _was_dodging := false
var _brain_states: Dictionary = {}

func configure(settings: Style) -> void:
	assert(settings != null and settings.voices > 0, "combat audio style missing")
	for key in settings.cues:
		var cue = settings.cues[key]
		assert(cue != null and not cue.streams.is_empty() and cue.pitch_min > 0.0 and cue.pitch_max >= cue.pitch_min, "audio cue invalid: " + String(key))
	for key in [settings.default_swing_cue, settings.default_hit_cue, settings.armor_hit_cue, settings.guard_break_cue]:
		assert(settings.cues.has(key), "audio cue missing: " + String(key))
	style = settings
	_rng.randomize()
	for index in style.voices:
		var voice := AudioStreamPlayer3D.new()
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		voice.panning_strength = style.panning_strength
		voice.bus = style.bus
		add_child(voice)
		_players.append(voice)

## 播放一个事件；at 为世界坐标。返回是否真的播放了（被最短间隔挡掉时为 false）。
func play(cue_id: StringName, at: Vector3) -> bool:
	if style == null or not style.cues.has(cue_id): return false
	var cue = style.cues[cue_id]
	if _last_played.has(cue_id) and _clock - float(_last_played[cue_id]) < cue.min_interval_sec: return false
	_last_played[cue_id] = _clock
	var voice := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	voice.stream = cue.streams[_rng.randi_range(0, cue.streams.size() - 1)]
	voice.volume_db = cue.volume_db
	voice.pitch_scale = _rng.randf_range(cue.pitch_min, cue.pitch_max)
	voice.global_position = at
	voice.play()
	return true

# ---------------- 事实入口（由战斗场景连接） ----------------
func bind_player(actor) -> void:
	_player = actor
	actor.runner.cue_reached.connect(func(_cast, ability_id): swing(actor, ability_id))

## 敌人近战（斥候、重装）：起手提示 + 出手挥砍
func bind_enemy(actor) -> void:
	actor.runner.committed.connect(func(_cast, _ability_id): windup(actor))
	actor.runner.cue_reached.connect(func(_cast, ability_id): swing(actor, ability_id))

func swing(actor, ability_id: String) -> void:
	if not is_instance_valid(actor): return
	play(style.swing_cues.get(ability_id, style.default_swing_cue), actor.global_position)

func windup(actor) -> void:
	if is_instance_valid(actor) and style.windup_cues.has(actor.definition.id):
		play(style.windup_cues[actor.definition.id], actor.global_position)

func player_hit(ability_id: String, target) -> void:
	if not is_instance_valid(target): return
	if target.armored():
		play(style.armor_hit_cue, target.global_position)
	else:
		play(style.hit_cues.get(ability_id, style.default_hit_cue), target.global_position)

## BuildRuntime.element_presented
func element_fact(fact: Dictionary) -> void:
	match String(fact.event):
		"applied": if style.element_cues.has(fact.element): play(style.element_cues[fact.element], fact.position)
		"discharge": play(style.discharge_cue, fact.position)
		"reaction": if style.reaction_cues.has(fact.reaction_id): play(style.reaction_cues[fact.reaction_id], fact.position)

func guard_broken(actor) -> void:
	if is_instance_valid(actor): play(style.guard_break_cue, actor.global_position)

func player_hurt() -> void:
	if is_instance_valid(_player): play(&"player_hurt", _player.global_position)

func enemy_killed(actor) -> void:
	if is_instance_valid(actor): play(&"kill", actor.global_position)

## real_delta 为真实时间；暂停时传 0，此时不检测新事件。
func refresh(real_delta: float, brains: Array) -> void:
	_clock += real_delta
	if real_delta <= 0.0 or not is_instance_valid(_player): return
	var dodging: bool = _player.dodge_left > 0.0
	if dodging and not _was_dodging: play(&"dodge", _player.global_position)
	_was_dodging = dodging
	# 远程、冲锋、游侠等按 AI 状态出招的敌人：进入前摇时提示
	var seen: Dictionary = {}
	for brain in brains:
		if brain == null or not ("state" in brain) or not is_instance_valid(brain.actor): continue
		var handle: int = brain.actor.handle
		seen[handle] = true
		var before: String = _brain_states.get(handle, "")
		if brain.state == "windup" and before != "windup" and not brain.actor.runner.busy():
			windup(brain.actor)
		_brain_states[handle] = brain.state
	for handle in _brain_states.keys():
		if not seen.has(handle): _brain_states.erase(handle)
