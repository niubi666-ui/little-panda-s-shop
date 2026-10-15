extends RefCounted
## 打击感（纯表现层，不影响判定和 RNG）：
##  - 顿帧：命中时短暂压缩战斗时间，重击/终结段/击杀更长
##  - 方向性镜头冲击：沿击打方向推一下镜头，叠加小幅高频抖动
##  - 平滑跟随镜头：阻尼跟随 + 朝移动方向的前瞻
## 所有数值在 feel/combat_feel_style.tres；由 training_style.tres 的 combat_feel 引用。
## 战斗场景每物理帧调用 consume_delta() 得到“战斗用 delta”。
const Style = preload("res://presentation/combat/feel/combat_feel_style.gd")

var style: Style
var _hitstop_left := 0.0
var _kick := Vector3.ZERO
var _jitter_t := 0.0
var _jitter_amp := 0.0
var _follow := Vector3.ZERO
var _look := Vector3.ZERO
var _follow_ready := false

func configure(settings: Style) -> void:
	assert(settings != null and settings.default_hit != null and settings.kill_hit != null and settings.player_hurt != null, "combat feel style incomplete")
	assert(settings.kick_duration_sec > 0.0 and settings.jitter_duration_sec > 0.0)
	style = settings

func hit(ability_id: String, direction: Vector3, killed: bool) -> void:
	var feel = style.ability_hits.get(ability_id, style.default_hit)
	var stop: float = feel.hitstop_sec
	var kick: float = feel.kick_m
	var jitter: float = feel.jitter_m
	if killed:
		stop = maxf(stop, style.kill_hit.hitstop_sec)
		kick = maxf(kick, style.kill_hit.kick_m)
		jitter = maxf(jitter, style.kill_hit.jitter_m)
	_apply(stop, direction, kick, jitter)

func player_hurt(direction: Vector3) -> void:
	_apply(style.player_hurt.hitstop_sec, direction, style.player_hurt.kick_m, style.player_hurt.jitter_m)

func _apply(stop: float, direction: Vector3, kick: float, jitter: float) -> void:
	_hitstop_left = maxf(_hitstop_left, stop)
	var d := direction; d.y = 0.0
	if not d.is_zero_approx():
		_kick += d.normalized() * kick
		_kick = _kick.limit_length(style.kick_limit_m)
	_jitter_amp = maxf(_jitter_amp, jitter)
	_jitter_t = 0.0

func in_hitstop() -> bool: return _hitstop_left > 0.0

## 返回本帧战斗逻辑应推进的时间
func consume_delta(delta: float) -> float:
	if _hitstop_left <= 0.0: return delta
	var used := minf(_hitstop_left, delta)
	_hitstop_left -= used
	return (delta - used) + used * style.hitstop_time_scale

func tick(delta: float) -> void:
	_jitter_t += delta
	if _jitter_t >= style.kick_duration_sec: _kick = Vector3.ZERO

## 平滑跟随目标点：target 为镜头注视点（已含边界限制），aim 为玩家移动方向
func follow(target: Vector3, aim: Vector3, delta: float) -> Vector3:
	var want_look := Vector3(aim.x, 0.0, aim.z).limit_length() * style.look_ahead_m
	if not _follow_ready:
		_follow = target; _look = want_look; _follow_ready = true
	if delta <= 0.0: return _follow + _look
	_follow = _follow.lerp(target, 1.0 - exp(-style.follow_sharpness * delta))
	_look = _look.lerp(want_look, 1.0 - exp(-style.look_ahead_sharpness * delta))
	return _follow + _look

func reset_follow() -> void: _follow_ready = false

## 世界空间偏移（冲击）+ 屏幕平面抖动（h/v offset）
func world_offset() -> Vector3:
	if _jitter_t >= style.kick_duration_sec: return Vector3.ZERO
	var k := 1.0 - _jitter_t / style.kick_duration_sec
	return _kick * k * k

func screen_jitter() -> Vector2:
	if _jitter_amp <= 0.0 or _jitter_t >= style.jitter_duration_sec: return Vector2.ZERO
	var frequency: Vector2 = style.jitter_frequency_hz
	return Vector2(sin(_jitter_t * TAU * frequency.x), sin(_jitter_t * TAU * frequency.y + 1.3)) * _jitter_amp

func clear() -> void:
	_hitstop_left = 0.0; _kick = Vector3.ZERO; _jitter_amp = 0.0; _follow_ready = false
