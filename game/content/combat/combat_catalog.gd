extends RefCounted
## Values are decoded once; immutable properties expose no mutable JSON collections.
class Ability extends RefCounted:
	var _data: Dictionary
	func _init(data: Dictionary) -> void:
		_data = data.duplicate(true)
		_data.dodge_cancel_phases.make_read_only()
		_data.make_read_only()
	var id: String:
		get: return _data.id
	var windup: float:
		get: return _data.windup_sec
	var active: float:
		get: return _data.active_sec
	var recovery: float:
		get: return _data.recovery_sec
	var cooldown: float:
		get: return _data.cooldown_sec
	var radius: float:
		get: return _data.radius_m
	var hit_shape: String:
		get: return _data.hit_shape
	var thrust_width: float:
		get: return _data.thrust_width_m
	var angle: float:
		get: return deg_to_rad(_data.angle_deg)
	var damage: float:
		get: return _data.damage
	var movement_multiplier: float:
		get: return _data.movement_speed_multiplier
	var knockback_speed: float:
		get: return _data.knockback_speed_mps
	var knockback_duration: float:
		get: return _data.knockback_duration_sec
	var interruptible: bool:
		get: return _data.interruptible
	var buffer_sec: float:
		get: return _data.buffer_sec
	var dodge_cancel_phases: Array:
		get: return _data.dodge_cancel_phases

class Actor extends RefCounted:
	var _data: Dictionary
	func _init(data: Dictionary) -> void:
		_data = data.duplicate(true)
		_data.attack_ids.make_read_only()
		_data.make_read_only()
	var id: String:
		get: return _data.id
	var name_key: String:
		get: return _data.name_key
	var health: float:
		get: return _data.health
	var speed: float:
		get: return _data.move_speed_mps
	var stagger: float:
		get: return _data.stagger_sec
	var attacks: Array:
		get: return _data.attack_ids
	var decision_interval: float:
		get: return _data.decision_interval_sec
	var aggro_range: float:
		get: return _data.aggro_range_m
	var combo_reset: float:
		get: return _data.combo_reset_sec

class Dodge extends RefCounted:
	var _data: Dictionary
	func _init(data: Dictionary) -> void:
		_data = data.duplicate(true)
		_data.make_read_only()
	var charges: int:
		get: return int(_data.charges)
	var duration: float:
		get: return _data.duration_sec
	var invulnerable: float:
		get: return _data.invulnerable_sec
	var recharge: float:
		get: return _data.recharge_sec
	var speed: float:
		get: return _data.speed_mps

var _abilities: Dictionary = {}
var _actors: Dictionary = {}
var _waves: Array
var _player_id: String
var _player_hurt_radius: float
var _delay: float
var _dodge: Dodge
func _init(data: Dictionary) -> void:
	for entry in data.abilities:
		_abilities[entry.id] = Ability.new(entry)
	for entry in data.actors:
		_actors[entry.id] = Actor.new(entry)
	_abilities.make_read_only()
	_actors.make_read_only()
	_waves = data.waves.duplicate(true)
	for wave in _waves:
		wave.make_read_only()
	_waves.make_read_only()
	_player_hurt_radius = data.player_hurt_radius_m
	_player_id = data.player_id
	_delay = data.wave_delay_sec
	_dodge = Dodge.new(data.dodge)
func ability(id: String) -> Ability: return _abilities[id]
func has_ability(id: String) -> bool: return _abilities.has(id)
func actor(id: String) -> Actor: return _actors[id]
func has_actor(id: String) -> bool: return _actors.has(id)
func player() -> Actor: return actor(_player_id)
func dodge() -> Dodge: return _dodge
func waves() -> Array: return _waves
func wave_delay() -> float: return _delay

func player_hurt_radius() -> float: return _player_hurt_radius
