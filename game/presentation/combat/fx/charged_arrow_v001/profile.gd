extends Resource
@export var arrow_scene: PackedScene
@export var ribbon: ShaderMaterial
@export var flight_core: ShaderMaterial
@export var flight_halo: ShaderMaterial
@export var rift_wall: ShaderMaterial
@export var rift_lip: ShaderMaterial
@export var rift_void: ShaderMaterial
@export var rift_source: ShaderMaterial
@export var rift_curtain: ShaderMaterial
@export var rift_station_count: int
@export var rift_curtain_count: int
@export var rift_frequency: float
@export var rift_center_ratio: float
@export var rift_opening_ratio: float
@export var rift_jagged_ratio: float
@export var rift_depth_m: float
@export var rift_source_depth_m: float
@export var rift_surface_height_m: float
@export var rift_lip_width_m: float
@export var rift_lip_height_m: float
@export var rift_height_m: Vector2
@export var rift_beam_drift_m: float
@export var rift_rise_sec: float
@export var rift_vertical_segments: int
@export var rift_forks: PackedVector4Array
@export var ground: ShaderMaterial
@export var sigil: ShaderMaterial
@export var flare: ShaderMaterial
@export var mote: ShaderMaterial
@export var body: Material
@export var charge_sound: AudioStream
@export var fire_sound: AudioStream
@export var pulse_sound: AudioStream
@export var draw_fraction: float
@export var charge_radius_m: float
@export var charge_turns: float
@export var charge_orbits: int
@export var charge_speed: float
@export var charge_width_m: float
@export var charge_particle_count: int
@export var charge_particle_size_m: float
@export var arrow_length_m: float
@export var arrow_width_m: float
@export var flight_height_m: float
@export var launch_blend_m: float
@export var warning_material: ShaderMaterial
@export var flight_tail_m: float
@export var flight_width_m: float
@export var flight_halo_ratio: float
@export var impact_size_m: float
@export var impact_sec: float
@export var flight_echo_sec: float
@export var flight_helix_radius_m: float
@export var flight_helix_turns: float
@export var trail_height_m: float
@export var trail_fade_sec: float
@export var trail_particle_count: int
@export var trail_particle_size_m: float
@export var trail_particle_height_m: float
@export var launch_ring_radius_m: float
@export var launch_ring_count: int
@export var launch_sec: float
@export var light_color: Color
@export var charge_light_energy: float
@export var shot_light_energy: float
@export var light_range_m: float
@export var flare_size_m: float
@export var audio_volume_db: float
@export var visual_seed: int

func validate() -> void:
	assert(arrow_scene != null,"Missing charged art: arrow_scene")
	assert(ribbon != null,"Missing charged art: ribbon")
	assert(flight_core != null,"Missing charged art: flight_core")
	assert(flight_halo != null,"Missing charged art: flight_halo")
	assert(rift_wall != null,"Missing charged art: rift_wall")
	assert(rift_lip != null,"Missing charged art: rift_lip")
	assert(rift_void != null,"Missing charged art: rift_void")
	assert(rift_source != null,"Missing charged art: rift_source")
	assert(rift_curtain != null,"Missing charged art: rift_curtain")
	assert(ground != null,"Missing charged art: ground")
	assert(sigil != null,"Missing charged art: sigil")
	assert(flare != null,"Missing charged art: flare")
	assert(mote != null,"Missing charged art: mote")
	assert(body != null,"Missing charged art: body")
	assert(charge_sound != null,"Missing charged art: charge_sound")
	assert(fire_sound != null,"Missing charged art: fire_sound")
	assert(pulse_sound != null,"Missing charged art: pulse_sound")
	assert(warning_material != null,"Missing charged art: warning_material")
	assert(rift_station_count>1 and rift_vertical_segments>1 and rift_height_m.x>0)
