extends RefCounted
## Flat-ground swept circle against actor hurt points. No node or content ownership.

static func contact_distance(from: Vector3, direction: Vector3, length: float, center: Vector3, radius: float) -> float:
	var offset := from - center
	offset.y = 0.0
	var c := offset.length_squared() - radius * radius
	if c <= 0.0: return 0.0
	var b := offset.dot(direction)
	var discriminant := b * b - c
	if discriminant < 0.0: return -1.0
	var distance := -b - sqrt(discriminant)
	return distance if distance >= 0.0 and distance <= length else -1.0

static func planar_direction(direction: Vector3) -> Vector3:
	var result := direction
	result.y = 0.0
	return result.normalized()
