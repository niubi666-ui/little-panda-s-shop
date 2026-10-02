class_name ShopPreviewDefinition
extends RefCounted
## Validated, read-only-by-interface preview tuning. Constructed only by the loader.

var _id: StringName
var _speed_mps: float
var _turn_speed_radps: float
var _gravity_mps2: float
var _interaction_distance_m: float
var _default_locale: String
var _decorating_file: String


func _init(validated_data: Dictionary) -> void:
	_id = StringName(validated_data["id"])
	_speed_mps = float(validated_data["movement"]["speed_mps"])
	_turn_speed_radps = float(validated_data["movement"]["turn_speed_radps"])
	_gravity_mps2 = float(validated_data["movement"]["gravity_mps2"])
	_interaction_distance_m = float(validated_data["interaction"]["distance_m"])
	_default_locale = validated_data["localization"]["default_locale"]
	_decorating_file = validated_data["decorating_file"]


func get_id() -> StringName:
	return _id


func get_speed_mps() -> float:
	return _speed_mps


func get_turn_speed_radps() -> float:
	return _turn_speed_radps


func get_gravity_mps2() -> float:
	return _gravity_mps2


func get_interaction_distance_m() -> float:
	return _interaction_distance_m


func get_default_locale() -> String:
	return _default_locale

func get_decorating_file() -> String:
	return _decorating_file
