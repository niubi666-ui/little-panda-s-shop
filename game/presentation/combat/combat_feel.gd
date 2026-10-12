extends RefCounted
## 打击感（纯表现层，不影响判定和 RNG）：
##  - 顿帧：命中时短暂冻结战斗时间，重击/终结段/击杀更长
##  - 方向性镜头冲击：沿击打方向推一下镜头，叠加小幅高频抖动
##  - 平滑跟随镜头：阻尼跟随 + 朝鼠标方向的前瞻
## 由战斗场景每物理帧调用 consume_delta() 得到“战斗用 delta”，再调用 camera_offset()。

# 顿帧（秒，真实时间）
const HITSTOP_LIGHT := 0.045
const HITSTOP_FINISHER := 0.085
const HITSTOP_HEAVY := 0.11
const HITSTOP_KILL := 0.13
const HITSTOP_PLAYER_HURT := 0.07
const HITSTOP_SLOW := 0.06          # 顿帧期间不是完全静止，保留一点点流动，避免卡顿感

# 镜头冲击
const KICK_LIGHT := 0.14
const KICK_HEAVY := 0.32

const JITTER_FREQ := Vector2(31.0, 37.0)

# 跟随
const FOLLOW_SHARPNESS := 7.5
const LOOK_AHEAD := 2.2            # 朝鼠标方向最多偏移多少米
const LOOK_AHEAD_SHARPNESS := 4.0

var _hitstop_left := 0.0
var _kick := Vector3.ZERO
var _jitter_t := 0.0
var _jitter_amp := 0.0
var _follow := Vector3.ZERO
var _look := Vector3.ZERO
var _follow_ready := false

func hit(ability_id: String, direction: Vector3, killed: bool) -> void:
	var heavy := ability_id in ["heavy_slash", "slash.3"]
	var stop := HITSTOP_HEAVY if ability_id == "heavy_slash" else (HITSTOP_FINISHER if ability_id == "slash.3" else HITSTOP_LIGHT)
	if killed: stop = maxf(stop, HITSTOP_KILL)
	_hitstop_left = maxf(_hitstop_left, stop)
	var d := direction; d.y = 0.0
	if not d.is_zero_approx():
		_kick += d.normalized() * (KICK_HEAVY if heavy or killed else KICK_LIGHT)
		_kick = _kick.limit_length(0.5)
	_jitter_amp = maxf(_jitter_amp, 0.06 if heavy or killed else 0.03)
	_jitter_t = 0.0

func player_hurt(direction: Vector3) -> void:
	_hitstop_left = maxf(_hitstop_left, HITSTOP_PLAYER_HURT)
	var d := direction; d.y = 0.0
	if not d.is_zero_approx(): _kick += d.normalized() * 0.22
	_jitter_amp = maxf(_jitter_amp, 0.08)
	_jitter_t = 0.0

func in_hitstop() -> bool: return _hitstop_left > 0.0

## 返回本帧战斗逻辑应推进的时间
func consume_delta(delta: float) -> float:
	if _hitstop_left <= 0.0: return delta
	var used := minf(_hitstop_left, delta)
	_hitstop_left -= used
	return (delta - used) + used * HITSTOP_SLOW

const KICK_DURATION := 0.15        # 冲击有确定的结束时间，结束后镜头精确回到原位
func tick(delta: float) -> void:
	_jitter_t += delta
	if _jitter_t >= KICK_DURATION: _kick = Vector3.ZERO

## 平滑跟随目标点：target 为镜头注视点（已含边界限制），aim 为玩家朝向
func follow(target: Vector3, aim: Vector3, delta: float) -> Vector3:
	var want_look := Vector3(aim.x, 0.0, aim.z).limit_length() * LOOK_AHEAD
	if not _follow_ready:
		_follow = target; _look = want_look; _follow_ready = true
	if delta <= 0.0: return _follow + _look
	_follow = _follow.lerp(target, 1.0 - exp(-FOLLOW_SHARPNESS * delta))
	_look = _look.lerp(want_look, 1.0 - exp(-LOOK_AHEAD_SHARPNESS * delta))
	return _follow + _look

func reset_follow() -> void: _follow_ready = false

## 世界空间偏移（冲击）+ 屏幕平面抖动（h/v offset）
func world_offset() -> Vector3:
	if _jitter_t >= KICK_DURATION: return Vector3.ZERO
	var k := 1.0 - _jitter_t / KICK_DURATION
	return _kick * k * k
const JITTER_DURATION := 0.12
func screen_jitter() -> Vector2:
	if _jitter_amp < 0.002 or _jitter_t >= JITTER_DURATION: return Vector2.ZERO
	return Vector2(sin(_jitter_t * TAU * JITTER_FREQ.x), sin(_jitter_t * TAU * JITTER_FREQ.y + 1.3)) * _jitter_amp

func clear() -> void:
	_hitstop_left = 0.0; _kick = Vector3.ZERO; _jitter_amp = 0.0; _follow_ready = false
