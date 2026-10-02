extends RefCounted
## Independent content boundary; never imports combat or application modules.

const Catalog = preload("res://content/builds/build_catalog.gd")
const SCHEMA_VERSION := 3
const MAX_ENTRIES := 512
const MAX_RANKS := 64
const MAX_STRING_LENGTH := 128
const MAX_TAGS := 64
const MAX_SAFE_INTEGER := 9007199254740991
const EFFECT_FIELDS := {
	"status": ["status_id", "trigger", "allowed_origins", "max_per_parent", "max_per_root"],
	"status_duration": ["status_id", "bonus"],
	"explosion": ["trigger", "allowed_origins", "max_per_parent", "max_per_root", "damage_ratio", "radius_m", "edge_ratio", "max_targets", "include_primary", "occlusion", "sight_height_m"],
	"damage_scale": ["bonus"],
	"move_scale": ["bonus"],
	"projectile": ["damage_ratio", "projectile_id"],
	"chain": ["damage_ratio", "radius_m", "jumps", "falloff"],
	"split": ["count", "spread_deg", "damage_ratio", "max_generation", "trigger", "scope"],
}

var errors: PackedStringArray = []


func load_catalog(manifest_path: String = "res://data/manifest.json") -> Catalog:
	errors.clear()
	var manifest: Variant = _read(manifest_path)
	if not manifest is Dictionary or not manifest.has("build_prototype_file"):
		errors.append(manifest_path + ": missing build_prototype_file")
		return null
	var path: Variant = manifest.build_prototype_file
	if not path is String or not path.begins_with("res://data/builds/") or not path.ends_with(".json") or path.contains(".."):
		errors.append(manifest_path + ": invalid build_prototype_file")
		return null
	var data: Variant = _read(path)
	if not errors.is_empty():
		return null
	var catalog := decode(data)
	if catalog == null: return null
	if not data.status_rules.actor_responses.is_empty():
		if not manifest.has("combat_prototype_file"):
			errors.append("status responses require combat manifest")
			return null
		var combat: Variant = _read(manifest.combat_prototype_file)
		if not combat is Dictionary or not combat.has("actors") or not combat.actors is Array:
			errors.append("invalid combat actor references")
			return null
		var ids: Array = []
		for actor in combat.actors:
			if actor is Dictionary and actor.has("id"): ids.append(actor.id)
		for id in data.status_rules.actor_responses:
			if not ids.has(id): errors.append("unknown status response actor: " + str(id))
	return catalog if errors.is_empty() else null


func decode(data: Variant) -> Catalog:
	errors.clear()
	if not _object(data, ["schema_version", "offer", "limits", "stats", "upgrades", "projectiles", "test_attacks", "statuses", "status_rules"], "build"):
		return null
	if not _integer(data.schema_version, 1, MAX_SAFE_INTEGER, "build.schema_version") or data.schema_version != SCHEMA_VERSION:
		errors.append("build.schema_version: unsupported version")
	_validate_offer(data.offer)
	_validate_limits(data.limits)
	_validate_stats(data.stats)
	if not data.upgrades is Array or data.upgrades.is_empty() or data.upgrades.size() > MAX_ENTRIES:
		errors.append("build.upgrades: expected nonempty bounded array")
		return null
	for index in data.upgrades.size():
		_validate_upgrade(data.upgrades[index], "build.upgrades[%s]" % index)
	if not errors.is_empty():
		return null
	_validate_projectiles(data)
	if not errors.is_empty(): return null
	_validate_statuses(data)
	if not errors.is_empty(): return null
	_validate_references(data)
	if not errors.is_empty():
		return null
	return Catalog.new(data)


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append(path + ": file missing")
		return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append(path + ": " + parser.get_error_message())
		return null
	return parser.data


func _validate_offer(value: Variant) -> void:
	var path := "build.offer"
	if not _object(value, ["count", "pool_ids", "fallback_ids", "initial_offers", "rewards_per_wave", "max_queued_offers"], path):
		return
	_integer(value.count, 1, 8, path + ".count")
	_integer(value.initial_offers, 0, MAX_ENTRIES, path + ".initial_offers")
	_integer(value.rewards_per_wave, 0, MAX_ENTRIES, path + ".rewards_per_wave")
	_integer(value.max_queued_offers, 1, MAX_ENTRIES, path + ".max_queued_offers")
	_strings(value.pool_ids, MAX_ENTRIES, path + ".pool_ids")
	_strings(value.fallback_ids, MAX_ENTRIES, path + ".fallback_ids")
	if errors.is_empty() and (value.initial_offers > value.max_queued_offers or value.rewards_per_wave > value.max_queued_offers):
		errors.append(path + ": initial/reward offers exceed queue limit")


func _validate_limits(value: Variant) -> void:
	var path := "build.limits"
	var integers := ["root_effect_budget", "requests_per_step", "max_queue", "max_projectiles", "max_chain_jumps", "max_split_generation", "max_projectiles_per_root"]
	var fields: Array = integers.duplicate()
	fields.append("projectiles_survive_source_death")
	if not _object(value, fields, path):
		return
	for key in integers:
		var maximum := 32 if key in ["max_chain_jumps", "max_split_generation"] else 65536
		_integer(value[key], 1, maximum, path + "." + key)
	if not value.projectiles_survive_source_death is bool:
		errors.append(path + ".projectiles_survive_source_death: expected boolean")
	if errors.is_empty() and value.max_projectiles_per_root > value.max_projectiles:
		errors.append(path + ": per-root projectiles exceed global limit")


func _validate_stats(value: Variant) -> void:
	var path := "build.stats"
	if not _object(value, ["damage_scale_min", "damage_scale_max", "move_scale_min", "move_scale_max"], path):
		return
	var valid := true
	for key in value:
		valid = _number(value[key], 0.0, 10.0, path + "." + key, true) and valid
	if valid and (value.damage_scale_min > value.damage_scale_max or value.move_scale_min > value.move_scale_max):
		errors.append(path + ": minimum exceeds maximum")
	if valid and (value.damage_scale_min > 1.0 or value.damage_scale_max < 1.0 or value.move_scale_min > 1.0 or value.move_scale_max < 1.0):
		errors.append(path + ": ranges must include the unmodified scale 1")


func _validate_upgrade(value: Variant, path: String) -> void:
	var fields := ["id", "name_key", "description_key", "weight", "max_rank", "requires", "excludes", "required_tags", "granted_tags", "effect_type", "ranks"]
	if not _object(value, fields, path):
		return
	for key in ["id", "name_key", "description_key", "effect_type"]:
		_string(value[key], path + "." + key)
	_number(value.weight, 0.0, 1000000000.0, path + ".weight")
	var rank_valid := _integer(value.max_rank, 1, MAX_RANKS, path + ".max_rank")
	for key in ["requires", "excludes"]:
		_strings(value[key], MAX_ENTRIES, path + "." + key)
	for key in ["required_tags", "granted_tags"]:
		_strings(value[key], MAX_TAGS, path + "." + key)
	if not value.effect_type is String or not EFFECT_FIELDS.has(value.effect_type):
		errors.append(path + ".effect_type: unsupported effect type")
		return
	if not value.ranks is Array or value.ranks.is_empty() or value.ranks.size() > MAX_RANKS:
		errors.append(path + ".ranks: expected nonempty bounded array")
		return
	if rank_valid and value.ranks.size() != value.max_rank:
		errors.append(path + ".ranks: length must equal max_rank")
	for index in value.ranks.size():
		var rank: Variant = value.ranks[index]
		var rank_path := path + ".ranks[%s]" % index
		if not _object(rank, EFFECT_FIELDS[value.effect_type], rank_path):
			continue
		for key in rank:
			match key:
				"allowed_origins":
					if _strings(rank[key], 3, rank_path + ".allowed_origins"):
						if rank[key].is_empty(): errors.append(rank_path + ": empty origins")
						for origin in rank[key]:
							if origin not in ["direct_melee", "direct_projectile", "split_projectile"]: errors.append(rank_path + ": forbidden origin")
				"max_per_parent", "max_per_root": _integer(rank[key], 1, 32, rank_path + "." + key)
				"max_targets": _integer(rank[key], 1, 64, rank_path + "." + key)
				"include_primary":
					if not rank[key] is bool: errors.append(rank_path + ": include_primary must be boolean")
				"occlusion":
					if rank[key] not in ["world_ray", "none"]: errors.append(rank_path + ": unsupported occlusion")
				"sight_height_m": _number(rank[key], 0, 10, rank_path + "." + key, true)

				"projectile_id", "status_id": _string(rank[key], rank_path + "." + key)
				"trigger":
					if rank[key] != "enemy_contact": errors.append(rank_path + ": unsupported trigger")
				"scope":
					if rank[key] != "linear_projectile": errors.append(rank_path + ": unsupported scope")
				"bonus": _number(rank[key], 0, 3 if value.effect_type == "status_duration" else 10, rank_path + ".bonus")
				"count", "jumps", "max_generation":
					_integer(rank[key], 1, 32, rank_path + "." + key)
				"radius_m":
					_number(rank[key], 0.0, 10.0, rank_path + "." + key, true)
				"falloff", "edge_ratio":
					_number(rank[key], 0.0, 1.0, rank_path + "." + key)
				"spread_deg":
					_number(rank[key], 0.0, 360.0, rank_path + "." + key)
				_:
					_number(rank[key], 0.0, 10.0, rank_path + "." + key)


func _validate_references(data: Dictionary) -> void:
	var by_id: Dictionary = {}
	var available_tags: Array = []
	for entry in data.upgrades:
		if by_id.has(entry.id):
			errors.append("build.upgrades: duplicate id " + entry.id)
		by_id[entry.id] = entry
		for tag in entry.granted_tags:
			if not available_tags.has(tag):
				available_tags.append(tag)
	for key in ["pool_ids", "fallback_ids"]:
		for id in data.offer[key]:
			if not by_id.has(id):
				errors.append("build.offer." + key + ": unknown id " + id)
	for entry in data.upgrades:
		for key in ["requires", "excludes"]:
			for id in entry[key]:
				if not by_id.has(id) or id == entry.id:
					errors.append("build.upgrades." + entry.id + "." + key + ": invalid reference " + id)
				elif key == "excludes" and not by_id[id].excludes.has(entry.id):
					errors.append("build.upgrades." + entry.id + ": exclusion must be symmetric with " + id)
		for required in entry.requires:
			if entry.excludes.has(required):
				errors.append("build.upgrades." + entry.id + ": required upgrade is excluded")
		for tag in entry.required_tags:
			if not available_tags.has(tag):
				errors.append("build.upgrades." + entry.id + ": unknown required tag " + tag)
		for rank in entry.ranks:
			for selector in ["allowed_origins", "status_id"]:
				if rank.has(selector) and rank[selector] != entry.ranks[0][selector]: errors.append("effect selectors must remain stable across ranks")
			if entry.effect_type in ["explosion", "status"] and (rank.max_per_parent > rank.max_per_root or rank.max_per_root > data.limits.root_effect_budget): errors.append("explosion trigger limits inconsistent")
			if entry.effect_type == "chain" and rank.jumps > data.limits.max_chain_jumps:
				errors.append("build.upgrades." + entry.id + ": jumps exceed limit")
			if entry.effect_type == "split":
				if rank.max_generation > data.limits.max_split_generation or rank.count > data.limits.max_projectiles_per_root or rank.count > data.limits.max_projectiles:
					errors.append("build.upgrades." + entry.id + ": split exceeds limits")
	var visiting: Dictionary = {}
	var visited: Dictionary = {}
	for id in by_id:
		_visit_prerequisites(id, by_id, visiting, visited)
	if errors.is_empty():
		_validate_reachability(data, by_id)


func _validate_reachability(data: Dictionary, entries: Dictionary) -> void:
	# Only authored obtainable definitions can supply ranks/tags. Positive-weight
	# random entries and explicit fallbacks use the same eligibility as the sampler.
	# Exclusions are intentionally ignored here: this is a necessary reachability
	# check, not a claim that all individually reachable upgrades can coexist.
	var remaining: Array[String] = []
	for id in data.offer.pool_ids:
		if float(entries[id].weight) > 0.0:
			remaining.append(id)
	for id in data.offer.fallback_ids:
		if not remaining.has(id):
			remaining.append(id)
	var reached: Dictionary = {}
	var tags: Dictionary = {}
	var changed := true
	while changed:
		changed = false
		for id in remaining.duplicate():
			var entry: Dictionary = entries[id]
			var eligible := true
			for required in entry.requires:
				if not reached.has(required):
					eligible = false
			for tag in entry.required_tags:
				if not tags.has(tag):
					eligible = false
			if not eligible:
				continue
			reached[id] = true
			for tag in entry.granted_tags:
				tags[tag] = true
			remaining.erase(id)
			changed = true
	for id in remaining:
		errors.append("build.upgrades." + id + ": unreachable prerequisites/tags in configured offer pool")


func _visit_prerequisites(id: String, entries: Dictionary, visiting: Dictionary, visited: Dictionary) -> void:
	if visiting.has(id):
		errors.append("build.upgrades." + id + ": prerequisite cycle")
		return
	if visited.has(id) or not entries.has(id):
		return
	visiting[id] = true
	for required in entries[id].requires:
		_visit_prerequisites(required, entries, visiting, visited)
	visiting.erase(id)
	visited[id] = true


func _object(value: Variant, fields: Array, path: String) -> bool:
	if not value is Dictionary:
		errors.append(path + ": expected object")
		return false
	var valid := true
	for field in fields:
		if not value.has(field):
			errors.append(path + "." + field + ": required")
			valid = false
	for key in value:
		if not key is String or not fields.has(key):
			errors.append(path + "." + str(key) + ": unknown field")
			valid = false
	return valid


func _string(value: Variant, path: String) -> bool:
	if not value is String or value.is_empty() or value.length() > MAX_STRING_LENGTH or value.strip_edges() != value:
		errors.append(path + ": expected nonempty bounded string")
		return false
	return true


func _strings(value: Variant, maximum: int, path: String) -> bool:
	if not value is Array or value.size() > maximum:
		errors.append(path + ": expected bounded array")
		return false
	var valid := true
	var seen: Dictionary = {}
	for index in value.size():
		if not _string(value[index], path + "[%s]" % index):
			valid = false
		elif seen.has(value[index]):
			errors.append(path + ": duplicate value " + value[index])
			valid = false
		else:
			seen[value[index]] = true
	return valid


func _integer(value: Variant, minimum: int, maximum: int, path: String) -> bool:
	if not _number(value, minimum, maximum, path):
		return false
	if value != floor(value):
		errors.append(path + ": expected integer")
		return false
	return true


func _number(value: Variant, minimum: float, maximum: float, path: String, exclusive_minimum: bool = false) -> bool:
	if not (value is float or value is int) or not is_finite(float(value)):
		errors.append(path + ": expected finite number")
		return false
	if value < minimum or value > maximum or (exclusive_minimum and value == minimum):
		errors.append(path + ": out of range")
		return false
	return true

func _validate_projectiles(data: Dictionary) -> void:
	if not data.projectiles is Array or data.projectiles.is_empty() or data.projectiles.size() > MAX_ENTRIES:
		errors.append("build.projectiles: expected bounded nonempty array")
		return
	var definitions: Dictionary = {}
	for value in data.projectiles:
		if not _object(value, ["id", "executor", "child_id", "speed_mps", "radius_m", "height_m", "lifetime_sec"], "projectile"): continue
		if not _string(value.id, "projectile.id"): continue
		if definitions.has(value.id): errors.append("duplicate projectile id")
		definitions[value.id] = value
		if value.executor != "linear_contact": errors.append("unsupported projectile executor")
		if not value.child_id is String: errors.append("child_id must be string; empty disables splitting")
		elif not value.child_id.is_empty(): _string(value.child_id, "projectile.child_id")
		_number(value.speed_mps, 0, 100, "projectile.speed_mps", true)
		_number(value.radius_m, 0, 10, "projectile.radius_m", true)
		_number(value.height_m, 0, 10, "projectile.height_m", true)
		_number(value.lifetime_sec, 0, 30, "projectile.lifetime_sec", true)
	if not errors.is_empty(): return
	for value in definitions.values():
		if not value.child_id.is_empty() and not definitions.has(value.child_id): errors.append("unknown child projectile")
	for entry in data.upgrades:
		if entry.effect_type == "projectile":
			for rank in entry.ranks:
				if not definitions.has(rank.projectile_id): errors.append("unknown upgrade projectile")
	if not data.test_attacks is Array or data.test_attacks.size() > MAX_ENTRIES:
		errors.append("test_attacks: expected bounded array")
		return
	var ids: Dictionary = {}
	for attack in data.test_attacks:
		if not _object(attack, ["id", "projectile_id", "damage", "cooldown_sec"], "test_attack"): continue
		if not _string(attack.id, "test_attack.id"): continue
		_string(attack.projectile_id, "test_attack.projectile_id")
		if ids.has(attack.id): errors.append("duplicate test attack")
		ids[attack.id] = true
		if not definitions.has(attack.projectile_id): errors.append("unknown test attack projectile")
		_number(attack.damage, 0, 10000, "test_attack.damage", true)
		_number(attack.cooldown_sec, 0, 30, "test_attack.cooldown_sec", true)

func _validate_statuses(data: Dictionary) -> void:
	if not data.statuses is Array or data.statuses.is_empty() or data.statuses.size() > 64:
		errors.append("statuses: expected bounded array")
		return
	var definitions: Dictionary = {}
	for status in data.statuses:
		if not _object(status, ["id", "kind", "duration_sec", "max_duration_sec", "move_scale", "refresh"], "status"): continue
		if not _string(status.id, "status.id"): continue
		if definitions.has(status.id): errors.append("duplicate status id")
		definitions[status.id] = status
		if status.kind not in ["slow", "freeze"] or status.refresh != "longest": errors.append("unsupported status kind/refresh")
		var valid := _number(status.duration_sec, 0, 30, "status.duration_sec", true)
		valid = _number(status.max_duration_sec, 0, 30, "status.max_duration_sec", true) and valid
		if valid and status.duration_sec > status.max_duration_sec: errors.append("status duration exceeds cap")
		if _number(status.move_scale, 0, 1, "status.move_scale"):
			if (status.kind == "slow" and status.move_scale <= 0) or (status.kind == "freeze" and status.move_scale != 0): errors.append("invalid status movement scale")
	if not _object(data.status_rules, ["default_response_id", "actor_responses", "responses"], "status_rules"): return
	var rules: Dictionary = data.status_rules
	if not rules.responses is Array or rules.responses.is_empty() or rules.responses.size() > 64:
		errors.append("status responses: expected bounded array")
		return
	var responses: Dictionary = {}
	for response in rules.responses:
		if not _object(response, ["id", "immune_kinds", "slow_duration_scale", "freeze_duration_scale"], "response"): continue
		if not _string(response.id, "response.id"): continue
		if responses.has(response.id): errors.append("duplicate response id")
		responses[response.id] = response
		if _strings(response.immune_kinds, 2, "response.immune_kinds"):
			for kind in response.immune_kinds:
				if kind not in ["slow", "freeze"]: errors.append("unknown immune kind")
		_number(response.slow_duration_scale, 0, 1, "response.slow_duration_scale", true)
		_number(response.freeze_duration_scale, 0, 1, "response.freeze_duration_scale", true)
	if not _string(rules.default_response_id, "default_response_id") or not responses.has(rules.default_response_id): errors.append("missing default response")
	if not rules.actor_responses is Dictionary or rules.actor_responses.size() > MAX_ENTRIES: errors.append("actor_responses must be bounded object")
	else:
		for actor_id in rules.actor_responses:
			_string(actor_id, "actor response key")
			if not _string(rules.actor_responses[actor_id], "actor response id") or not responses.has(rules.actor_responses[actor_id]): errors.append("unknown actor response")
	for entry in data.upgrades:
		if entry.effect_type not in ["status", "status_duration"]: continue
		for rank in entry.ranks:
			if not definitions.has(rank.status_id): errors.append("unknown status reference")
