"""Write independent Godot resources for the Blender-authored fire/frost bakes."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[5]
for kind in ['fire','frost']:
    folder=ROOT/'game/presentation/combat/fx/elemental_slashes_v001'/kind
    folder.mkdir(parents=True,exist_ok=True)
    lines=['[gd_resource type="ShaderMaterial" load_steps=10 format=3]',
           '[ext_resource type="Shader" path="res://presentation/combat/fx/trail_presets_01_06_v001/baked_trail.gdshader" id="shader"]']
    for f in range(4):
        for name,ext in [('emission','exr'),('mask','png')]:
            lines.append(f'[ext_resource type="Texture2D" path="res://assets/vfx/elemental_slashes_v001/{kind}/{kind}_{f}_{name}.{ext}" id="{name}_{f}"]')
    lines+=['[resource]','shader = ExtResource("shader")']
    for f in range(4):
        for name in ['emission','mask']:lines.append(f'shader_parameter/{name}_{f} = ExtResource("{name}_{f}")')
    lines+=['shader_parameter/frame_phase = 0.0',f'shader_parameter/energy_scale = {0.75 if kind=="fire" else 0.95}','shader_parameter/opacity = 1.0','']
    (folder/'ribbon.tres').write_text('\n'.join(lines),encoding='utf-8')
    fire=kind=='fire'
    scene=f'''[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://presentation/combat/fx/golden_trail_v001/golden_effect.gd" id="script"]
[ext_resource type="Material" path="res://presentation/combat/fx/elemental_slashes_v001/{kind}/ribbon.tres" id="ribbon"]

[sub_resource type="StandardMaterial3D" id="spark_mat"]
shading_mode = 0
transparency = 1
blend_mode = 1
vertex_color_use_as_albedo = true
albedo_color = Color({"1, 0.62, 0.16, 1" if fire else "0.2, 0.78, 1, 1"})
emission_enabled = true
emission = Color({"1, 0.12, 0.006, 1" if fire else "0.08, 0.46, 1, 1"})
emission_energy_multiplier = {3.0 if fire else 2.3}

'''
    if fire:
        scene+='''[sub_resource type="SphereMesh" id="spark"]
material = SubResource("spark_mat")
radius = 0.012
height = 0.036
radial_segments = 6
rings = 3
'''
    else:
        scene+='''[sub_resource type="CylinderMesh" id="spark"]
material = SubResource("spark_mat")
top_radius = 0.0
bottom_radius = 0.018
height = 0.092
radial_segments = 4
rings = 1
'''
    scene+=f'''
[sub_resource type="Gradient" id="gradient"]
offsets = PackedFloat32Array(0, 0.28, 0.65, 1)
colors = PackedColorArray({"1, 0.91, 0.43, 1, 1, 0.48, 0.05, 1, 0.9, 0.095, 0.008, 0.65, 0.45, 0.016, 0.003, 0" if fire else "0.85, 0.98, 1, 1, 0.4, 0.88, 1, 1, 0.11, 0.49, 1, 0.7, 0.035, 0.12, 0.4, 0"})

[node name="{"RollingFlameSlash" if fire else "CrystalFrostSlash"}" type="Node3D"]
script = ExtResource("script")
ribbon_material = ExtResource("ribbon")
root_inset_ratio = 0.02
tip_extension_ratio = 0.28
tail_lifetime_sec = {0.31 if fire else 0.28}
sample_distance = 0.01
max_segment_angle_deg = 2.0
fade_power = {0.45 if fire else 0.4}
radial_subdivisions = 8
noise_frame_rate = {7.0 if fire else 4.0}
spark_blade_coverage = 0.8
spark_emitter_thickness = {0.035 if fire else 0.025}

[node name="Particles" type="CPUParticles3D" parent="."]
emitting = false
amount = {92 if fire else 52}
lifetime = {0.34 if fire else 0.32}
randomness = 0.65
local_coords = false
emission_shape = 2
emission_box_extents = Vector3(0.025, 0.025, 0.44)
direction = Vector3(0, 1, 0)
spread = 150.0
initial_velocity_min = {0.2 if fire else 0.1}
initial_velocity_max = {1.5 if fire else 1.05}
gravity = Vector3(0, {0.8 if fire else -1.7}, 0)
damping_min = 0.2
damping_max = 1.2
angle_min = -180.0
angle_max = 180.0
angular_velocity_min = -140.0
angular_velocity_max = 140.0
scale_amount_min = {0.45 if fire else 0.4}
scale_amount_max = {1.35 if fire else 1.15}
color_ramp = SubResource("gradient")
mesh = SubResource("spark")
cast_shadow = 0
'''
    (folder/'slash.tscn').write_text(scene,encoding='utf-8')
print('Runtime scene resources written')
