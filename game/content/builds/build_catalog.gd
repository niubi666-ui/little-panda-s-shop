extends RefCounted
## Validated definitions only. Recursively immutable and isolated from input.

var _entries: Array[Dictionary] = []
var _by_id: Dictionary = {}
var _offer: Dictionary
var _limits: Dictionary
var _statuses: Dictionary = {}
var _responses: Dictionary = {}
var _status_rules: Dictionary
var _stats: Dictionary
var _projectiles: Dictionary = {}
var _test_attacks: Dictionary = {}
var _control_groups: Dictionary = {}
var _test_presets: Array[Dictionary] = []
var _presets_by_id: Dictionary = {}
var _actions: Array[Dictionary] = []
var _actions_by_id: Dictionary = {}
var _forms: Array[Dictionary] = []
var _forms_by_id: Dictionary = {}


func _init(data: Dictionary) -> void:
	for entry in data.upgrades:
		var copy: Dictionary = freeze_copy(entry)
		_entries.append(copy)
		_by_id[copy.id] = copy
	_entries.make_read_only()
	_by_id.make_read_only()
	for definition in data.actions:
		var copy: Dictionary = freeze_copy(definition)
		_actions.append(copy)
		_actions_by_id[copy.id] = copy
	for definition in data.forms:
		var copy: Dictionary = freeze_copy(definition)
		_forms.append(copy)
		_forms_by_id[copy.id] = copy
	_actions.make_read_only()
	_actions_by_id.make_read_only()
	_forms.make_read_only()
	_forms_by_id.make_read_only()
	_offer = freeze_copy(data.offer)
	_limits = freeze_copy(data.limits)
	_stats = freeze_copy(data.stats)
	for status in data.statuses: _statuses[status.id] = freeze_copy(status)
	for response in data.status_rules.responses: _responses[response.id] = freeze_copy(response)
	_status_rules = freeze_copy(data.status_rules)
	_statuses.make_read_only()
	_responses.make_read_only()
	for definition in data.projectiles: _projectiles[definition.id] = freeze_copy(definition)
	for attack in data.test_attacks: _test_attacks[attack.id] = freeze_copy(attack)
	_projectiles.make_read_only()
	_test_attacks.make_read_only()
	for group in data.status_rules.control_groups: _control_groups[group.id] = freeze_copy(group)
	_control_groups.make_read_only()
	for preset in data.test_presets:
		var copy: Dictionary = freeze_copy(preset)
		_test_presets.append(copy)
		_presets_by_id[copy.id] = copy
	_test_presets.make_read_only()
	_presets_by_id.make_read_only()


func entries() -> Array[Dictionary]:
	return _entries


func upgrade(id: String) -> Dictionary:
	assert(_by_id.has(id), "Unknown build upgrade: " + id)
	return _by_id[id]


func has_upgrade(id: String) -> bool:
	return _by_id.has(id)


func offer_rules() -> Dictionary:
	return _offer


func limits() -> Dictionary:
	return _limits


func stat_limits() -> Dictionary:
	return _stats


static func freeze_copy(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = {}
		for key in value:
			dictionary[key] = freeze_copy(value[key])
		dictionary.make_read_only()
		return dictionary
	if value is Array:
		var array: Array = []
		for item in value:
			array.append(freeze_copy(item))
		array.make_read_only()
		return array
	return value

func projectile(id: String) -> Dictionary:
	return _projectiles[id]

func test_attack(id: String) -> Dictionary:
	return _test_attacks[id]

func status(id: String) -> Dictionary: return _statuses[id]
func control_group(id: String) -> Dictionary: return _control_groups[id]
func test_presets() -> Array[Dictionary]: return _test_presets
func test_preset(id: String) -> Dictionary: return _presets_by_id[id] if _presets_by_id.has(id) else {}
func status_response(actor_id: String) -> Dictionary:
	var id: String = _status_rules.actor_responses[actor_id] if _status_rules.actor_responses.has(actor_id) else _status_rules.default_response_id
	return _responses[id]

func actions() -> Array[Dictionary]: return _actions
func action(id: String) -> Dictionary: return _actions_by_id[id]
func has_action(id: String) -> bool: return _actions_by_id.has(id)
func forms() -> Array[Dictionary]: return _forms
func form(id: String) -> Dictionary: return _forms_by_id[id]
func has_form(id: String) -> bool: return _forms_by_id.has(id)
