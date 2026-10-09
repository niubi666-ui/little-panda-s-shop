extends Resource
## All art values live in the .tres. Zero is only an unconfigured Resource field.
@export var arrow_scene: PackedScene
@export var ribbon: ShaderMaterial
@export var flight_core: ShaderMaterial
@export var flight_halo: ShaderMaterial
@export var ui_scene: PackedScene
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
@export var elf_scene: PackedScene
@export var target_scene: PackedScene
@export var elf_scale: float
@export var target_scale: float
@export var muzzle_offset: Vector3
@export var draw_fraction: float
@export var release_sec: float
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
@export var damage_flash_sec: float
@export var label_height_m: float
@export var slow_time_scale: float
@export var arrow_label_color: Color
@export var scar_label_color: Color
@export var dodge_label_color: Color
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
@export var camera_offset: Vector3
@export var camera_target: Vector3
@export var camera_size: float
@export var visual_seed: int

func validate() -> void:
	for key in ["arrow_scene","ribbon","flight_core","flight_halo","ui_scene","ground","sigil","flare","mote","body","warning_material","charge_sound","fire_sound","pulse_sound","elf_scene","target_scene"]:
		assert(get(key) != null, "Missing art resource: " + key)
	for key in ["elf_scale","target_scale","draw_fraction","release_sec","charge_radius_m","charge_turns","charge_orbits","charge_speed","charge_width_m","charge_particle_count","charge_particle_size_m","arrow_length_m","arrow_width_m","flight_tail_m","flight_width_m","flight_echo_sec","flight_helix_radius_m","flight_helix_turns","trail_height_m","trail_fade_sec","trail_particle_count","trail_particle_size_m","trail_particle_height_m","launch_ring_radius_m","launch_ring_count","launch_sec","charge_light_energy","shot_light_energy","light_range_m","flare_size_m","camera_size"]:
		assert(get(key) > 0, "Unconfigured art resource: " + key)
	assert(draw_fraction < 1.0 and muzzle_offset.y > 0.0)
	for key in ["rift_wall","rift_lip","rift_void","rift_source","rift_curtain"]: assert(get(key)!=null)
	for key in ["rift_station_count","rift_curtain_count","rift_frequency","rift_center_ratio","rift_opening_ratio","rift_jagged_ratio","rift_depth_m","rift_source_depth_m","rift_lip_width_m","rift_lip_height_m","rift_beam_drift_m","rift_rise_sec"]: assert(get(key)>0)
	assert(rift_height_m.x>0.0 and rift_height_m.y>=rift_height_m.x)
	assert(rift_center_ratio+rift_jagged_ratio+rift_opening_ratio<=1.0,"Rift must fit rule hazard")
	assert(rift_vertical_segments>1 and rift_forks.size()>0)
	for key in ["flight_height_m","launch_blend_m","damage_flash_sec","label_height_m","slow_time_scale","flight_halo_ratio","impact_size_m","impact_sec"]:
		assert(get(key) > 0)
