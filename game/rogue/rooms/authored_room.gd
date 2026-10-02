extends Node3D
func runtime_prop_container() -> Node3D:
	return $ReservedRuntimeProps
## Authored room contract; no combat logic, random draws or session mutations.
func player_spawn() -> Vector3:
	return $PlayerSpawn.global_position
func enemy_spawns() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for marker in $EnemySpawns.get_children(): result.append(marker.global_position)
	return result
