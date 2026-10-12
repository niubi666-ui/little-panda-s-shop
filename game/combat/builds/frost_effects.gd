extends RefCounted
## Finite trail and protection runtime. No rendering, global services or content reads.
var paths: Array[Dictionary] = []
var shield_cooldown := 0.0

static func params(plan: Dictionary, kind: String) -> Dictionary:
	for effect in plan.effects:
		if effect.type == kind: return effect.params
	return {}

static func own_earlier(status: Dictionary, context: Dictionary, runtime_id: int) -> bool:
	if status.is_empty(): return false
	var source: Dictionary = status.source
	return source.get("runtime_id", -1) == runtime_id and source.get("room_generation", -1) == context.room_generation and source.get("source_handle", -1) == context.source_handle and source.get("root_id", context.id) < context.id

func froze(context: Dictionary, player) -> void:
	var p := params(context.program, "freeze_shield")
	if p.is_empty() or shield_cooldown > 0.0: return
	shield_cooldown = p.trigger_cooldown_sec
	player.grant_protection(p.shield_amount, p.duration_sec)

func sample_path(context: Dictionary, projectile: Dictionary, start: Vector3, finish: Vector3) -> void:
	var p := params(context.program, "projectile_path")
	if p.is_empty() or int(projectile.generation) != 0: return
	var length := start.distance_to(finish)
	if length <= 0.0: return
	var offset: float = float(p.spacing_m) - float(projectile.get("path_distance", 0.0))
	while offset <= length and context.budget > 0 and paths.size() < int(p.max_targets):
		paths.append({"root_id": context.id, "position": start.lerp(finish, offset / length), "remaining": p.lifetime_sec, "params": p})
		context.budget -= 1
		offset += float(p.spacing_m)
	projectile.path_distance = fmod(float(projectile.get("path_distance", 0.0)) + length, float(p.spacing_m))

func tick(delta: float, runtime) -> void:
	shield_cooldown = maxf(0.0, shield_cooldown - delta)
	for i in range(paths.size() - 1, -1, -1):
		var path := paths[i]
		path.remaining -= delta
		if path.remaining <= 0.0 or not runtime._roots.has(path.root_id): paths.remove_at(i); continue
		var context: Dictionary = runtime._roots[path.root_id]
		for target in runtime._valid_targets(context):
			var offset: Vector3 = target.global_position - path.position; offset.y = 0.0
			if offset.length_squared() <= float(path.params.radius_m) * float(path.params.radius_m):
				runtime._apply_status(context, target, path.params.status_id, path.params.duration_sec)

func clear(player) -> void:
	paths.clear()
	shield_cooldown = 0.0
	if is_instance_valid(player): player.clear_protection()
