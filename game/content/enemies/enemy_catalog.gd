extends RefCounted
var _profiles: Dictionary = {}
var _actor_names: Dictionary = {}
var _loot_tables: Dictionary = {}
var _encounters: Dictionary
var _version: String
var _encounter_version: String
var _loot_version: String
var profiles: Dictionary:
	get: return _profiles
var loot_tables: Dictionary:
	get: return _loot_tables
var encounters: Dictionary:
	get: return _encounters
var version: String:
	get: return _version
var encounter_version: String:
	get: return _encounter_version
var loot_version: String:
	get: return _loot_version
static func freeze(value: Variant) -> void:
	if value is Dictionary or value is Array:
		for child in value.values() if value is Dictionary else value: freeze(child)
		value.make_read_only()
func _init(roles: Dictionary, encounter_data: Dictionary, loot: Dictionary, combat) -> void:
	for entry in roles.profiles:
		_profiles[entry.actor_id] = entry.duplicate(true)
		_actor_names[entry.actor_id] = combat.actor(entry.actor_id).name_key
	for entry in loot.tables: _loot_tables[entry.id] = entry.duplicate(true)
	_encounters = encounter_data.duplicate(true)
	_encounter_version = roles.content_version + "/" + encounters.content_version
	_loot_version = loot.content_version
	_version = encounter_version + "/" + loot_version
	freeze(profiles)
	freeze(_actor_names)
	freeze(loot_tables)
	freeze(encounters)
func profile(id: String) -> Dictionary: return profiles[id]
func actor_name_key(id: String) -> String: return _actor_names[id]
