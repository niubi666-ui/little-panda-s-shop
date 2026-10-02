extends RefCounted
## Visual ratios only. Never delays authoritative HP or death.
var current := 1.0
var trailing := 1.0
var _delay_left := 0.0
var _delay: float
var _drain_speed: float
func _init(delay_sec: float, drain_ratio_per_sec: float) -> void:
	_delay = delay_sec
	_drain_speed = drain_ratio_per_sec
func set_health(ratio: float) -> void:
	var next := clampf(ratio, 0.0, 1.0)
	if next < current:
		trailing = maxf(trailing, current)
		_delay_left = _delay
	elif next > current:
		trailing = maxf(trailing, next)
	current = next
func tick(delta: float) -> void:
	var waiting := minf(delta, _delay_left)
	_delay_left -= waiting
	trailing = move_toward(trailing, current, _drain_speed * (delta - waiting))
