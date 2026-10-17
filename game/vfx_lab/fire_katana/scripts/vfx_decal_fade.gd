extends Decal
## 刀痕焦印：先亮（余火）→ 冷却变暗 → 停留 → 淡出。

@export var glow_peak := 6.0
@export var glow_time := 1.4
@export var hold_time := 3.0
@export var fade_time := 1.2

var _t := -1.0


func _ready() -> void:
	visible = false


func play() -> void:
	_t = 0.0
	visible = true


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	emission_energy = glow_peak * pow(maxf(0.0, 1.0 - _t / glow_time), 2.2)
	var fade_k := clampf((_t - glow_time - hold_time) / fade_time, 0.0, 1.0)
	modulate.a = 1.0 - fade_k
	if fade_k >= 1.0:
		_t = -1.0
		visible = false
