extends RefCounted
signal damaged(amount: float)
signal died
var maximum: float
var current: float
func _init(hp: float) -> void:
	maximum = hp
	current = hp
func apply(amount: float, invulnerable: bool) -> float:
	if current <= 0.0 or invulnerable or amount <= 0.0: return 0.0
	var effective := minf(current, amount)
	current -= effective
	damaged.emit(effective)
	if current <= 0.0: died.emit()
	return effective
func alive() -> bool: return current > 0.0
