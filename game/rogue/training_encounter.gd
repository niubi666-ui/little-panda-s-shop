extends RefCounted
signal wave_requested(enemy_ids: Array)
signal cleared
signal wave_completed(wave_index: int)
var _waves: Array
var _delay: float
var _waiting := 0.0
var _alive: Dictionary = {}
var _cancelled := false
var _complete := false
var wave_index := -1
func _init(waves: Array, delay: float) -> void:
	_waves = waves
	_delay = delay
func start() -> void: _next()
func register_enemy(handle: int) -> void: _alive[handle] = true
func enemy_killed(handle: int) -> void:
	if _cancelled or _complete or not _alive.has(handle): return
	_alive.erase(handle)
	if _alive.is_empty():
		if wave_index + 1 >= _waves.size():
			_complete = true
			cleared.emit()
		else:
			_waiting = _delay
			wave_completed.emit(wave_index)
func tick(delta: float) -> void:
	if _cancelled or _complete or not _alive.is_empty(): return
	_waiting -= delta
	if _waiting <= 0.0: _next()
func _next() -> void:
	wave_index += 1
	wave_requested.emit(_waves[wave_index])
func cancel() -> void:
	_cancelled = true
	_alive.clear()
func remaining() -> int: return _alive.size()
