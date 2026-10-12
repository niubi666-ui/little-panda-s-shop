extends "res://content/builds/build_loader.gd"
## Independent reward content. Combat legality remains in Resolver.
func load_groups(catalog, manifest_path: String = "res://data/manifest.json") -> Dictionary:
	errors.clear()
	var manifest: Variant = _read(manifest_path)
	if not manifest is Dictionary or not manifest.has("build_reward_groups_file"):
		errors.append("manifest: missing build_reward_groups_file")
		return {}
	var path: Variant = manifest.build_reward_groups_file
	if not path is String or not path.begins_with("res://data/builds/") or not path.ends_with(".json") or path.contains(".."):
		errors.append("manifest: invalid build_reward_groups_file")
		return {}
	var data: Variant = _read(path)
	if not errors.is_empty(): return {}
	return decode_groups(data, catalog)

func decode_groups(data: Variant, catalog) -> Dictionary:
	errors.clear()
	if not _object(data, ["schema_version", "rarities", "upgrade_groups", "reward_profiles"], "reward_groups"): return {}
	if not _integer(data.schema_version, 1, 1, "reward_groups.schema_version"): return {}
	var ids: Array[String] = []
	if not data.rarities is Array or data.rarities.size() != 4: errors.append("exactly four rarities required"); return {}
	for entry in data.rarities:
		if not _object(entry, ["id", "name_key", "order"], "rarity"): continue
		if entry.id not in ["common", "rare", "epic", "legendary"] or ids.has(entry.id): errors.append("invalid or duplicate rarity"); continue
		_string(entry.name_key, "rarity.name_key")
		_integer(entry.order, 0, 3, "rarity.order")
		ids.append(entry.id)
	if not data.upgrade_groups is Dictionary or not data.reward_profiles is Dictionary: errors.append("reward maps required"); return {}
	var expected: Array = catalog.offer_rules().pool_ids.duplicate()
	for id in catalog.offer_rules().fallback_ids:
		if not expected.has(id): expected.append(id)
	for id in expected:
		if not data.upgrade_groups.has(id): errors.append("missing rarity: " + id)
	for id in data.upgrade_groups:
		if not expected.has(id) or not ids.has(data.upgrade_groups[id]): errors.append("invalid upgrade rarity: " + str(id))
	for id in ["normal_room", "elite_room", "boss_room", "training_all"]:
		if not data.reward_profiles.has(id): errors.append("missing reward profile: " + id)
	for id in data.reward_profiles:
		var profile: Variant = data.reward_profiles[id]
		if not _object(profile, ["name_key", "count", "rarity_weights", "shortage"], "reward_profile." + str(id)): continue
		_string(profile.name_key, "reward_profile.name_key")
		_integer(profile.count, 1, 8, "reward_profile.count")
		if profile.shortage != "show_available": errors.append("unsupported shortage policy")
		if not profile.rarity_weights is Dictionary or profile.rarity_weights.is_empty(): errors.append("empty rarity weights"); continue
		for rarity in profile.rarity_weights:
			if not ids.has(rarity): errors.append("unknown rarity in profile")
			_number(profile.rarity_weights[rarity], 0, MAX_SAFE_INTEGER, "rarity weight", true)
	return Catalog.freeze_copy(data) if errors.is_empty() else {}
