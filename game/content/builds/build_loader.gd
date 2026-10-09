extends RefCounted
## Independent content boundary; never imports combat or application modules.

const Catalog = preload("res://content/builds/build_catalog.gd")
const SCHEMA_VERSION := 6
const MAX_ENTRIES := 512
const MAX_RANKS := 64
const MAX_STRING_LENGTH := 128
const MAX_TAGS := 64
const MAX_SAFE_INTEGER := 9007199254740991
const EFFECT_FIELDS := {
	"form": ["form_id"],
	"pierce": ["trigger", "scope", "max_hits"],
	"area_status": ["source_effect_id", "status_id", "allowed_origins", "include_primary", "max_targets"],
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
	if not manifest.has("combat_prototype_file"):
		errors.append("action forms require combat manifest")
		return null
	var combat: Variant = _read(manifest.combat_prototype_file)
	if not combat is Dictionary or not combat.has("actors") or not combat.actors is Array or not combat.has("abilities") or not combat.abilities is Array:
		errors.append("invalid combat references")
		return null
	var ability_ids: Dictionary = {}
	for ability in combat.abilities:
		if ability is Dictionary and ability.has("id"): ability_ids[ability.id] = true
	for form in data.forms:
		for id in form.ability_ids:
			if not ability_ids.has(id): errors.append("unknown combat ability in form " + str(form.id) + ": " + str(id))
	var actor_ids: Dictionary = {}
	for actor in combat.actors:
		if actor is Dictionary and actor.has("id"): actor_ids[actor.id] = true
	for id in data.status_rules.actor_responses:
		if not actor_ids.has(id): errors.append("unknown status response actor: " + str(id))
	return catalog if errors.is_empty() else null


func decode(data: Variant) -> Catalog:
	errors.clear()
	if not _object(data, ["schema_version", "offer", "limits", "stats", "upgrades", "projectiles", "test_attacks", "statuses", "status_rules", "test_presets", "actions", "forms"], "build"):
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
	_validate_actions(data)
	if not errors.is_empty(): return null
	_validate_references(data)
	if not errors.is_empty(): return null
	_validate_presets(data)
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
	if not _object(value, ["count", "pool_ids", "fallback_ids", "initial_offers", "rewards_per_wave", "max_queued_offers", "target_weighting"], path):
		return
	if value.target_weighting != "uniform": errors.append(path + ": unsupported target weighting")
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
	var integers := ["root_effect_budget", "requests_per_step", "max_queue", "max_projectiles", "max_chain_jumps", "max_split_generation", "max_projectiles_per_root", "max_projectile_hits"]
	var fields: Array = integers.duplicate()
	fields.append("projectiles_survive_source_death")
	if not _object(value, fields, path):
		return
	for key in integers:
		var maximum := 32 if key in ["max_chain_jumps", "max_split_generation", "max_projectile_hits"] else 65536
		_integer(value[key], 1, maximum, path + "." + key)
	if not value.projectiles_survive_source_death is bool:
		errors.append(path + ".projectiles_survive_source_death: expected boolean")
	if errors.is_empty() and value.max_projectiles_per_root > value.max_projectiles:
		errors.append(path + ": per-root projectiles exceed global limit")


func _validate_stats(value: Variant) -> void:
	var path := "build.stats"
	if not _object(value, ["damage_scale_min", "damage_scale_max", "move_scale_min", "move_scale_max", "damage_composition"], path):
		return
	var valid := true
	if value.damage_composition != "additive_then_clamp": errors.append(path + ": unsupported damage composition")
	for key in ["damage_scale_min", "damage_scale_max", "move_scale_min", "move_scale_max"]:
		valid = _number(value[key], 0.0, 10.0, path + "." + key, true) and valid
	if valid and (value.damage_scale_min > value.damage_scale_max or value.move_scale_min > value.move_scale_max):
		errors.append(path + ": minimum exceeds maximum")
	if valid and (value.damage_scale_min > 1.0 or value.damage_scale_max < 1.0 or value.move_scale_min > 1.0 or value.move_scale_max < 1.0):
		errors.append(path + ": ranges must include the unmodified scale 1")


func _validate_upgrade(value: Variant, path: String) -> void:
	var fields := ["id", "name_key", "description_key", "weight", "max_rank", "requires", "excludes", "required_tags", "granted_tags", "effect_type", "ranks", "scope", "layer", "action_ids", "test_only"]
	if not _object(value, fields, path):
		return
	if value.scope not in ["global", "action"]: errors.append(path + ": unsupported scope")
	if value.layer not in ["form", "core", "support", "synergy"]: errors.append(path + ": unsupported layer")
	if not value.test_only is bool: errors.append(path + ": test_only must be boolean")
	_strings(value.action_ids, 16, path + ".action_ids")
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

				"projectile_id", "status_id", "source_effect_id", "form_id": _string(rank[key], rank_path + "." + key)
				"trigger":
					if rank[key] != "enemy_contact": errors.append(rank_path + ": unsupported trigger")
				"scope":
					if rank[key] != "linear_projectile": errors.append(rank_path + ": unsupported scope")
				"bonus": _number(rank[key], 0, 3 if value.effect_type == "status_duration" else 10, rank_path + ".bonus")
				"count", "jumps", "max_generation", "max_hits":
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
	var area_status_sources: Dictionary = {}
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
			for selector in ["allowed_origins", "status_id", "source_effect_id"]:
				if rank.has(selector) and rank[selector] != entry.ranks[0][selector]: errors.append("effect selectors must remain stable across ranks")
			if entry.effect_type in ["explosion", "status"] and (rank.max_per_parent > rank.max_per_root or rank.max_per_root > data.limits.root_effect_budget): errors.append("explosion trigger limits inconsistent")
			if entry.effect_type == "chain" and rank.jumps > data.limits.max_chain_jumps:
				errors.append("build.upgrades." + entry.id + ": jumps exceed limit")
			if entry.effect_type == "split":
				if rank.max_generation > data.limits.max_split_generation or rank.count > data.limits.max_projectiles_per_root or rank.count > data.limits.max_projectiles:
					errors.append("build.upgrades." + entry.id + ": split exceeds limits")
			if entry.effect_type == "pierce" and rank.max_hits > data.limits.max_projectile_hits:
				errors.append("build.upgrades." + entry.id + ": max_hits exceeds projectile hit limit")
		if entry.effect_type == "pierce":
			for other in data.upgrades:
				if other.effect_type == "split" and (not entry.excludes.has(other.id) or not other.excludes.has(entry.id)):
					errors.append("build.upgrades." + entry.id + ": all pierce/split definitions require symmetric exclusion")
		if entry.effect_type == "area_status":
			var source_id: String = entry.ranks[0].source_effect_id
			if not by_id.has(source_id) or by_id[source_id].effect_type != "explosion":
				errors.append("build.upgrades." + entry.id + ": area status requires an explosion source")
			else:
				if not entry.requires.has(source_id): errors.append("area status must require its explosion source")
				var shares_origin := false
				for origin in entry.ranks[0].allowed_origins:
					if by_id[source_id].ranks[0].allowed_origins.has(origin): shares_origin = true
				if not shares_origin: errors.append("area status has no compatible source origin")
			if area_status_sources.has(source_id): errors.append("only one area status definition is supported per explosion source")
			area_status_sources[source_id] = true
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
		if not _object(attack, ["id", "projectile_id", "damage", "cooldown_sec", "action_id"], "test_attack"): continue
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
		if not _object(status, ["id", "kind", "duration_sec", "max_duration_sec", "move_scale", "refresh", "control_group"], "status"): continue
		if not _string(status.id, "status.id"): continue
		if definitions.has(status.id): errors.append("duplicate status id")
		definitions[status.id] = status
		if status.kind not in ["slow", "freeze"]: errors.append("unsupported status kind")
		if status.kind == "slow" and (status.refresh != "longest" or status.control_group != ""):
			errors.append("slow requires longest refresh and no control group")
		if status.kind == "freeze":
			if status.refresh != "reject_active": errors.append("freeze must reject active reapplication")
			_string(status.control_group, "status.control_group")
		var valid := _number(status.duration_sec, 0, 30, "status.duration_sec", true)
		valid = _number(status.max_duration_sec, 0, 30, "status.max_duration_sec", true) and valid
		if valid and status.duration_sec > status.max_duration_sec: errors.append("status duration exceeds cap")
		if _number(status.move_scale, 0, 1, "status.move_scale"):
			if (status.kind == "slow" and status.move_scale <= 0) or (status.kind == "freeze" and status.move_scale != 0): errors.append("invalid status movement scale")
	if not _object(data.status_rules, ["default_response_id", "actor_responses", "responses", "control_groups"], "status_rules"): return
	var rules: Dictionary = data.status_rules
	# This finite slice has one shared freeze group, independent of status/source ID.
	if not rules.control_groups is Array or rules.control_groups.size() != 1:
		errors.append("status_rules.control_groups: exactly one shared freeze group required")
	else:
		var group: Variant = rules.control_groups[0]
		if _object(group, ["id", "kind", "thaw_immunity_sec"], "control_group"):
			_string(group.id, "control_group.id")
			if group.kind != "freeze": errors.append("unsupported control group kind")
			_number(group.thaw_immunity_sec, 0, 30, "control_group.thaw_immunity_sec", true)
			if errors.is_empty():
				for status in definitions.values():
					if status.kind == "freeze" and status.control_group != group.id: errors.append("all freeze statuses must share the validated freeze group")
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
		if entry.effect_type not in ["status", "status_duration", "area_status"]: continue
		for rank in entry.ranks:
			if not definitions.has(rank.status_id): errors.append("unknown status reference")


func _validate_presets(data: Dictionary) -> void:
	if not data.test_presets is Array or data.test_presets.size() > 64:
		errors.append("test_presets: expected bounded array")
		return
	var entries: Dictionary = {}
	for entry in data.upgrades: entries[entry.id] = entry
	var actions: Dictionary = {}
	for action in data.actions: actions[action.id] = action
	var ids: Dictionary = {}
	for preset in data.test_presets:
		if not _object(preset, ["id", "name_key", "selections"], "test_preset"): continue
		if not _string(preset.id, "test_preset.id"): continue
		_string(preset.name_key, "test_preset.name_key")
		if ids.has(preset.id): errors.append("duplicate test preset id")
		ids[preset.id] = true
		if not preset.selections is Array or preset.selections.size() > MAX_ENTRIES:
			errors.append("test_preset.selections: expected bounded sequence")
			continue
		var selected: Dictionary = {}
		var slots: Dictionary = {}
		for selection in preset.selections:
			if not _object(selection, ["upgrade_id", "action_id", "rank"], "test_preset.selection"): continue
			if not _string(selection.upgrade_id, "preset.upgrade_id") or not entries.has(selection.upgrade_id):
				errors.append("test_preset: unknown upgrade")
				continue
			var entry: Dictionary = entries[selection.upgrade_id]
			if not _string(selection.action_id, "preset.action_id"): continue
			if entry.test_only: errors.append("test_preset: debug upgrade forbidden")
			if not _integer(selection.rank, 1, int(entry.max_rank), "preset.rank"): continue
			var target: String = selection.action_id
			if target != "global" and actions.has(target) and actions[target].test_only: errors.append("test_preset: debug action forbidden")
			if (entry.scope == "global" and target != "global") or (entry.scope == "action" and not entry.action_ids.has(target)):
				errors.append("test_preset: wrong action binding")
			var identity := target + ":" + str(selection.upgrade_id)
			if selected.has(identity): errors.append("test_preset: duplicate identity")
			selected[identity] = true
			if entry.layer in ["form", "core"]:
				var slot := target + ":" + str(entry.layer)
				if slots.has(slot): errors.append("test_preset: duplicate slot")
				slots[slot] = true
		for selection in preset.selections:
			if not selection is Dictionary or not selection.has("upgrade_id") or not entries.has(selection.upgrade_id) or not selection.has("action_id"): continue
			var entry: Dictionary = entries[selection.upgrade_id]
			for required in entry.requires:
				if not selected.has(str(selection.action_id) + ":" + str(required)): errors.append("test_preset: missing bound prerequisite")
			for excluded in entry.excludes:
				if selected.has(str(selection.action_id) + ":" + str(excluded)): errors.append("test_preset: excluded bound upgrade")

		if errors.is_empty(): _validate_preset_capabilities(data, preset, entries)

func _validate_preset_capabilities(data: Dictionary, preset: Dictionary, entries: Dictionary) -> void:
	# Static content proof; app still preflights through the combat evaluator.
	var forms: Dictionary = {}
	var projectiles: Dictionary = {}
	for form in data.forms: forms[form.id] = form
	for projectile in data.projectiles: projectiles[projectile.id] = projectile
	for action in data.actions:
		var selected: Array = []
		var form_id: String = action.base_form_id
		var types: Array = []
		var tags: Array = []
		for item in preset.selections:
			if item.action_id != action.id: continue
			var entry: Dictionary = entries[item.upgrade_id]
			var params: Dictionary = entry.ranks[int(item.rank) - 1]
			selected.append({"entry": entry, "params": params})
			types.append(entry.effect_type)
			tags.append_array(entry.granted_tags)
			if entry.effect_type == "form": form_id = params.form_id
		var form: Dictionary = forms[form_id]
		var projectile: Dictionary = projectiles[form.projectile_id] if projectiles.has(form.projectile_id) else {}
		var origins: Array = ["direct_projectile" if not projectile.is_empty() else "direct_melee"]
		if types.has("split"):
			if projectile.is_empty() or str(projectile.child_id).is_empty(): errors.append("preset split needs same-action child-producing carrier")
			origins.append("split_projectile")
			if types.has("pierce") or types.has("area_status"): errors.append("preset unsupported complete contact strategy")
		if types.has("pierce") and projectile.is_empty(): errors.append("preset pierce needs same-action projectile")
		var status_ids: Array = []
		for value in selected:
			var entry: Dictionary = value.entry
			var params: Dictionary = value.params
			for tag in entry.required_tags:
				if not tags.has(tag): errors.append("preset missing same-action tag")
			if entry.effect_type in ["status", "explosion"]:
				var compatible := false
				for origin in origins:
					if params.allowed_origins.has(origin): compatible = true
				if not compatible: errors.append("preset impact has no compatible carrier")
			if entry.effect_type == "status": status_ids.append(params.status_id)
			if entry.effect_type == "area_status":
				var compatible := false
				for source in selected:
					if source.entry.id != params.source_effect_id: continue
					for origin in origins:
						if params.allowed_origins.has(origin) and source.params.allowed_origins.has(origin): compatible = true
				if not compatible: errors.append("preset area status has no same-action source")
				status_ids.append(params.status_id)
		for value in selected:
			if value.entry.effect_type == "status_duration" and not status_ids.has(value.params.status_id): errors.append("preset duration has no same-action status carrier")

func _validate_actions(data: Dictionary) -> void:
	if not data.actions is Array or data.actions.is_empty() or data.actions.size() > 16 or not data.forms is Array or data.forms.is_empty() or data.forms.size() > 64:
		errors.append("build: bounded nonempty actions/forms required")
		return
	var forms: Dictionary = {}
	var actions: Dictionary = {}
	var projectiles: Dictionary = {}
	for definition in data.projectiles: projectiles[definition.id] = true
	for form in data.forms:
		if not _object(form, ["id", "name_key", "executor", "ability_ids", "projectile_id", "presentation_key"], "form"): continue
		for field in ["id", "name_key", "presentation_key"]: _string(form[field], "form." + field)
		if not errors.is_empty(): return
		if forms.has(form.id): errors.append("duplicate form id")
		forms[form.id] = form
		_strings(form.ability_ids, 16, "form.ability_ids")
		if form.executor not in ["melee", "projectile"]: errors.append("unsupported form executor")
		if not form.projectile_id is String: errors.append("form.projectile_id must be string")
		elif form.executor == "projectile" and not projectiles.has(form.projectile_id): errors.append("unknown form projectile")
		elif form.executor == "melee" and (not form.projectile_id.is_empty() or form.ability_ids.is_empty()): errors.append("melee form needs abilities and no projectile")
	for action in data.actions:
		if not _object(action, ["id", "name_key", "base_form_id", "form_ids", "test_only"], "action"): continue
		for field in ["id", "name_key", "base_form_id"]: _string(action[field], "action." + field)
		if not errors.is_empty(): return
		if action.id == "global" or actions.has(action.id): errors.append("duplicate/reserved action id")
		actions[action.id] = action
		if not action.test_only is bool: errors.append("action.test_only must be boolean")
		if not _strings(action.form_ids, 64, "action.form_ids"): continue
		if not action.form_ids.has(action.base_form_id): errors.append("base form must be allowed")
		for id in action.form_ids:
			if not forms.has(id): errors.append("unknown action form")
	if not errors.is_empty(): return
	for attack in data.test_attacks:
		if not attack.action_id is String or not actions.has(attack.action_id) or not actions[attack.action_id].test_only:
			errors.append("test attack requires isolated debug action")
		elif forms[actions[attack.action_id].base_form_id].projectile_id != attack.projectile_id: errors.append("test attack projectile disagrees with debug form")
	for entry in data.upgrades:
		if entry.scope == "global":
			if not entry.action_ids.is_empty() or entry.layer != "support" or entry.effect_type not in ["damage_scale", "move_scale"]:
				errors.append("global supports only unbound numeric actor stats")
		else:
			if entry.action_ids.is_empty() or entry.effect_type == "move_scale": errors.append("action scope needs targets and cannot change actor movement")
			for id in entry.action_ids:
				if not actions.has(id): errors.append("unknown upgrade action")
				elif entry.test_only and not actions[id].test_only: errors.append("debug upgrade cannot target formal action")
		var expected_layer: String = "form" if entry.effect_type == "form" else ("core" if entry.effect_type in ["status", "explosion"] else ("synergy" if entry.effect_type == "area_status" else "support"))
		if entry.layer != expected_layer: errors.append("effect type and layer disagree")
		if entry.effect_type in ["projectile", "chain"] and not entry.test_only: errors.append("legacy projectile/chain restricted to fixture")
		if entry.effect_type == "form":
			for rank in entry.ranks:
				if not forms.has(rank.form_id): errors.append("unknown upgrade form")
				for target in entry.action_ids:
					if actions.has(target) and not actions[target].form_ids.has(rank.form_id): errors.append("form upgrade not allowed by target")
	for id in data.offer.pool_ids + data.offer.fallback_ids:
		for entry in data.upgrades:
			if entry.id == id and entry.test_only: errors.append("debug upgrade in formal offer pool")
