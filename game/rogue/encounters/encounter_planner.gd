extends RefCounted
## Whole authored teams only. No fallback to arbitrary individual monsters.
static func stream(seed_value: String, channel: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = (seed_value + "|" + channel).sha256_text().substr(0, 15).hex_to_int()
	return rng
static func band_for(depth: int, catalog) -> Dictionary:
	assert(depth >= 1)
	var selected: Dictionary = catalog.encounters.depth_bands[0]
	for band in catalog.encounters.depth_bands:
		if band.min_depth <= depth: selected = band
	return selected
static func legal(depth: int, capacity: int, catalog) -> Array:
	var band := band_for(depth, catalog)
	var result: Array = []
	for team in catalog.encounters.combinations:
		var cost := 0
		for id in team.enemy_ids: cost += int(catalog.profile(id).budget_cost)
		if team.enemy_ids.size() <= mini(capacity, int(band.max_enemies)) and cost <= band.budget and cost >= band.budget * catalog.encounters.minimum_budget_fraction:
			result.append(team)
	return result
func validate_plan(plan: Dictionary, capacity: int, catalog) -> bool:
	for key in ["seed", "depth", "budget", "version", "generation_version", "waves"]:
		if not plan.has(key): return false
	if not plan.seed is String or not (plan.depth is float or plan.depth is int): return false
	if not is_finite(float(plan.depth)) or plan.depth < 1 or plan.depth != floor(plan.depth): return false
	if plan.version != catalog.version or plan.generation_version != catalog.encounters.generation_version: return false
	if legal(int(plan.depth), capacity, catalog).is_empty(): return false
	return plan == generate(plan.seed, int(plan.depth), capacity, catalog)
func generate(seed_value: String, depth: int, capacity: int, catalog) -> Dictionary:
	var candidates := legal(depth, capacity, catalog)
	if candidates.is_empty():
		push_error("No legal encounter for depth/capacity: %s/%s" % [depth, capacity])
		return {}
	var band := band_for(depth, catalog)
	var rng := stream(seed_value, catalog.encounter_version + "|encounter")
	var waves: Array = []
	var remaining := candidates.duplicate()
	for wave_index in int(catalog.encounters.wave_count):
		if remaining.is_empty(): remaining = candidates.duplicate()
		var total := 0.0
		for candidate in remaining: total += candidate.weight
		var roll := rng.randf() * total
		var selected: Dictionary = remaining.back()
		for candidate in remaining:
			roll -= candidate.weight
			if roll <= 0.0:
				selected = candidate
				break
		remaining.erase(selected)
		var drops: Array = []
		for slot in selected.enemy_ids.size():
			var loot_rng := stream(seed_value, catalog.loot_version + "|loot|%s|%s" % [wave_index, slot])
			var entries: Array = []
			var profile: Dictionary = catalog.profile(selected.enemy_ids[slot])
			for entry in catalog.loot_tables[profile.loot_table_id].entries:
				if loot_rng.randf() < entry.chance:
					entries.append({"item_id":entry.item_id, "count":loot_rng.randi_range(entry.count_min, entry.count_max)})
			drops.append(entries)
		waves.append({"combination_id":selected.id,"name_key":selected.name_key,"enemy_ids":selected.enemy_ids.duplicate(),"drops":drops})
	return {"seed":seed_value,"depth":depth,"budget":band.budget,"version":catalog.version,"generation_version":catalog.encounters.generation_version,"waves":waves}
