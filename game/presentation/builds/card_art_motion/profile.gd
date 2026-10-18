extends Resource
## All positions use the original illustration UV, before KEEP_ASPECT_COVERED.
@export_enum("fire", "ice", "thunder", "energy", "earth", "composite") var kind: String
@export var layers: Array[Resource]
@export var enabled: bool
@export var shader: Shader
@export var mask: Texture2D
@export var seed: int
@export var instance_seed_stride: int
@export var phase_span: float
@export var intensity: float
@export var hover_gain: float
@export var flow_period_sec: float
@export var flow_px: float
@export var flow_direction: Vector2
@export var flow_speed_px: float
@export var flow_emission: float
@export var glow_variation: float
@export var noise_scale: Vector2
@export var noise_speed: float
@export var tint: Color
@export var mist_opacity: float
@export var mist_speed_px: float
@export var mist_noise: Texture2D
@export_range(0, 12) var mist_puff_count: int
@export var mist_emission_path: PackedVector2Array
@export var mist_lifetime: float
@export var mist_velocity: Vector2
@export var mist_radius_start: Vector2
@export var mist_radius_end: Vector2
@export var mist_sway_px: float
@export var mist_sway_hz: float
@export var mist_color: Color
@export var mist_max_alpha: float
@export_range(0, 24) var particle_count: int
@export var emission_path: PackedVector2Array
@export var particle_life: Vector2
@export var particle_drift: Vector2
@export var particle_drift_spread: Vector2
@export var particle_sway: Vector2
@export var particle_sway_hz: float
@export var particle_tail_sec: float
@export var particle_radius: Vector2
@export var particle_opacity: float
@export var particle_core: Color
@export var particle_glow_scale: float
@export var particle_glow_opacity: float
@export var sparkle_points: PackedVector2Array
@export var sparkle_count: int
@export var sparkle_duration: float
@export var sparkle_period: float
@export var sparkle_stagger: float
@export var sparkle_size: float
@export var sparkle_width: float
@export var arc_paths: Array[PackedVector2Array]
@export var arc_branches: Array[PackedVector2Array]
@export var branch_parents: PackedInt32Array
@export var arc_interval: Vector2
@export var arc_duration: Vector2
@export var arc_widths: Vector3
@export var arc_opacities: Vector3
@export var arc_jitter_px: float
@export var arc_flutter_hz: float
@export var arc_reveal_sec: float
@export var arc_schedule_count: int
@export var stream_paths: Array[PackedVector2Array]
@export_range(0, 12) var stream_count: int
@export var stream_period: float
@export var stream_tail_fraction: float
@export var stream_width: float
@export var stream_opacity: float

func validate() -> void:
	if kind == "composite":
		assert(layers.size() == 2, "A reaction illustration combines exactly two authored effect layers")
		for layer in layers:
			assert(layer.kind != "composite", "Nested effects are not supported")
			layer.validate()
		return
	assert(kind in ["fire","ice","thunder","energy","earth"] and shader != null and mask != null)
	assert(instance_seed_stride > 0 and phase_span > 0.0 and flow_period_sec > 0.0)
	assert(intensity >= 0.0 and particle_count >= 0 and particle_count <= 24)
	if kind == "fire": assert(flow_direction.length_squared() > 0.0 and flow_speed_px > 0.0 and flow_emission >= 0.0)
	if particle_count > 0:
		assert(emission_path.size() >= 2 and particle_life.x > 0.0 and particle_life.y >= particle_life.x)
		assert(particle_drift_spread.x > 0.0 and particle_drift_spread.y >= particle_drift_spread.x)
		assert(particle_tail_sec >= 0.0 and particle_sway_hz >= 0.0)
	if stream_count > 0:
		assert(stream_count <= 12 and not stream_paths.is_empty())
		assert(stream_period > 0.0 and stream_tail_fraction > 0.0 and stream_tail_fraction < 1.0)
		assert(stream_width > 0.0 and stream_opacity > 0.0)
		for path in stream_paths: assert(path.size() >= 2)
	if kind == "ice":
		assert(sparkle_count > 0 and sparkle_points.size() >= sparkle_count and particle_count + sparkle_count + mist_puff_count <= 24)
		assert(sparkle_period > 0.0 and sparkle_duration > 0.0 and sparkle_stagger >= 0.0)
		assert(sparkle_duration + (sparkle_count-1)*sparkle_stagger <= sparkle_period)
		assert(mist_noise != null and mist_puff_count > 0 and mist_puff_count <= 12 and mist_emission_path.size() >= 2)
		assert(mist_lifetime > 0.0 and mist_radius_start.x > 0.0 and mist_radius_start.y > 0.0)
		assert(mist_radius_end.x >= mist_radius_start.x and mist_radius_end.y >= mist_radius_start.y)
		assert(mist_opacity > 0.0 and mist_max_alpha > 0.0 and mist_max_alpha <= 1.0)
	if kind == "thunder":
		assert(not arc_paths.is_empty() and arc_schedule_count > 0 and arc_interval.x > 0.0)
		assert(arc_duration.x > 0.0 and arc_duration.y >= arc_duration.x and arc_interval.y >= arc_interval.x)
		assert(arc_duration.y <= arc_interval.x * 3.0, "At most three overlapping main arcs per card")
		assert(arc_flutter_hz > 0.0 and arc_reveal_sec > 0.0 and arc_reveal_sec < arc_duration.x)
		assert(arc_branches.size() == branch_parents.size())
		for path in arc_paths + arc_branches: assert(path.size() >= 2)
		for parent in branch_parents: assert(parent >= 0 and parent < arc_paths.size())
		for i in arc_paths.size(): assert(Array(branch_parents).count(i) <= 2)
