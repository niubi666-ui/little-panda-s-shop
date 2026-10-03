extends RefCounted
## Explicit test binding adapter. Production accepts selections, never global rank maps.
const Resolver = preload("res://combat/builds/build_resolver.gd")
static func state(ranks: Dictionary, action_id: String, revision: int = 1) -> Dictionary:
	var selections: Array = []
	for id in ranks: selections.append({"upgrade_id": id, "action_id": action_id, "rank": ranks[id]})
	return {"selections": selections, "revision": revision}
static func compile(catalog, ranks: Dictionary, action_id: String, revision: int = 1) -> Dictionary:
	var resolver := Resolver.new()
	resolver.configure(catalog)
	return resolver.resolve(state(ranks, action_id, revision))
