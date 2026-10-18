extends Resource
## Paths keep unrelated masks out of memory. The visible card owns the loaded resource.
@export var profile_paths: Dictionary[String, String]
@export var static_ids: PackedStringArray
func profile_for(id: String):
	assert(profile_paths.has(id) or static_ids.has(id), "Missing card motion policy: " + id)
	if static_ids.has(id):
		assert(not profile_paths.has(id), "Conflicting card motion policy: " + id)
		return null
	var profile = load(profile_paths[id])
	assert(profile != null, "Missing declared card motion resource: " + id)
	profile.validate()
	return profile
