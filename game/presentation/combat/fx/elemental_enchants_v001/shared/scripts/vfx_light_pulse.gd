extends OmniLight3D
## 一闪即逝的火光：play() 后亮度按曲线走一遍，带一点闪烁。

@export var peak_energy := 6.0
@export var duration := 0.4
@export var curve: Curve
@export var flicker := 0.25

var _t := -1.0


func _ready() -> void:
	light_energy = 0.0


func play() -> void:
	_t = 0.0


func tick(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	var k := clampf(_t / duration, 0.0, 1.0)
	var shape := curve.sample(k) if curve else 1.0 - k
	light_energy = peak_energy * shape * (1.0 - flicker + flicker * randf())
	if k >= 1.0:
		_t = -1.0
		light_energy = 0.0
