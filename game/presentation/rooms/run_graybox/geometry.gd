extends Node3D
## Replace this scene using the same spawn protocol; route logic never reads geometry names.
func player_spawn() -> Vector3: return $PlayerSpawn.global_position
func enemy_spawns() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for marker in $EnemySpawns.get_children(): result.append(marker.global_position)
	return result
func spawn_capacity() -> int: return $EnemySpawns.get_child_count()
