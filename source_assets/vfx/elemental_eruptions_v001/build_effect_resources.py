"""Rebuild art Resources for two Godot eruption studies. Run with bundled Python."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game/presentation/combat/fx/elemental_eruptions_v001'
BASE = 'res://presentation/combat/fx/elemental_eruptions_v001'
MODELS = 'res://assets/vfx/elemental_eruptions_v001/models'

def write(name, text):
    (OUT / name).write_text(text.strip() + '\n', encoding='utf-8')

def shader_mat(name, shader, values):
    write(name, f'''[gd_resource type="ShaderMaterial" load_steps=2 format=3]
[ext_resource type="Shader" path="{BASE}/{shader}.gdshader" id="shader"]
[resource]
shader = ExtResource("shader")
''' + '\n'.join(f'shader_parameter/{key} = {value}' for key, value in values.items()))

for kind in ('ice', 'rock'):
    ice = kind == 'ice'
    shader_mat(f'{kind}_spire.tres', 'spire', {
        'base_color': 'Color(0.025, 0.15, 0.31, 1)' if ice else 'Color(0.20, 0.16, 0.115, 1)',
        'tip_color': 'Color(0.5, 0.83, 0.92, 1)' if ice else 'Color(0.58, 0.47, 0.31, 1)',
        'glow_color': 'Color(0.12, 0.66, 1.0, 1)' if ice else 'Color(1.0, 0.38, 0.045, 1)',
        'roughness_value': '0.19' if ice else '0.76', 'metallic_value': '0.14' if ice else '0.04',
        'crystal_mode': '1.0' if ice else '0.0', 'vein_scale': '9.0' if ice else '7.0',
        'emission_strength': '1.8' if ice else '1.0', 'rim_strength': '0.5' if ice else '0.018',
        'visual_time': '0.0', 'reveal': '0.0'})
    shader_mat(f'{kind}_ground.tres', 'ground', {
        'crack_color': 'Color(0.13, 0.37, 0.44, 1)' if ice else 'Color(0.011, 0.009, 0.006, 1)',
        'glow_color': 'Color(0.14, 0.76, 1.0, 1)' if ice else 'Color(1.0, 0.32, 0.025, 1)',
        'visual_time':'0.0', 'anticipation':'0.22', 'travel':'0.72', 'duration':'4.6',
        'ice_mode':'1.0' if ice else '0.0', 'opacity':'0.95', 'glow_strength':'2.2' if ice else '1.5', 'pattern_seed':'31.0' if ice else '71.0'})
    shader_mat(f'{kind}_ring.tres','ring',{
        'tint':'Color(0.12, 0.64, 1.0, 0.9)' if ice else 'Color(1.0, 0.49, 0.12, 0.75)',
        'energy':'2.4' if ice else '1.5','progress':'0.0','brokenness':'0.65'})
    shader_mat(f'{kind}_mist.tres','mist',{
        'tint':'Color(0.16, 0.33, 0.44, 1)' if ice else 'Color(0.14, 0.08, 0.035, 1)',
        'highlight':'Color(0.44, 0.8, 0.88, 1)' if ice else 'Color(0.56, 0.36, 0.16, 1)',
        'opacity':'0.46' if ice else '0.58','progress':'0.0','particle_seed':'0.0','luminous':'0.3' if ice else '0.03'})
    color = 'Color(0.22, 0.59, 0.78, 1)' if ice else 'Color(0.3, 0.21, 0.105, 1)'
    write(f'{kind}_chip.tres',f'''[gd_resource type="StandardMaterial3D" format=3]
[resource]
albedo_color = {color}
vertex_color_use_as_albedo = true
roughness = {'0.25' if ice else '0.8'}
metallic = {'0.15' if ice else '0.0'}
emission_enabled = {'true' if ice else 'false'}
emission = Color(0.06, 0.25, 0.4, 1)
emission_energy_multiplier = 0.4
''')
    write(f'{kind}_spark.tres',f'''[gd_resource type="StandardMaterial3D" format=3]
[resource]
shading_mode = 0
vertex_color_use_as_albedo = true
albedo_color = {'Color(0.25, 0.7, 1.0, 1)' if ice else 'Color(1.0, 0.45, 0.09, 1)'}
emission_enabled = true
emission = {'Color(0.2, 0.7, 1.0, 1)' if ice else 'Color(1.0, 0.35, 0.015, 1)'}
emission_energy_multiplier = {'3.2' if ice else '2.5'}
''')
    values = {
        'visual_seed':1201 if ice else 5207, 'duration_sec':4.6 if ice else 4.8,
        'anticipation_sec':0.22 if ice else 0.28, 'travel_sec':0.64 if ice else 0.78,
        'rise_sec':0.28 if ice else 0.34, 'hold_sec':1.9 if ice else 2.0,'sink_sec':0.7,
        'length_m':9.0,'station_count':7 if ice else 6,
        'height_range':'Vector2(1.4, 3.5)' if ice else 'Vector2(1.1, 2.9)',
        'width_range':'Vector2(1.35, 1.85)' if ice else 'Vector2(2.2, 2.9)',
        'lateral_spread':0.35 if ice else 0.45,'satellite_scale':'Vector2(0.38, 0.61)',
        'lean_deg':'Vector2(8, 20)' if ice else 'Vector2(10, 28)',
        'crown_count':5, 'crown_radius':1.1 if ice else 1.2,
        'crown_height_scale':'Vector2(0.58, 0.84)', 'crown_width_scale':0.7,
        'crown_stagger_sec':0.018, 'crown_chip_count':36 if ice else 44,
        'crown_spark_count':50 if ice else 35, 'crown_burst_speed_scale':1.2,
        'ground_width':5.6,'ground_height':0.025,'ring_radius':2.6,'ring_duration':0.65,
        'chip_count':128 if ice else 112,'chip_size':'Vector2(0.1, 0.33)' if ice else 'Vector2(0.14, 0.45)',
        'chip_speed':'Vector2(0.9, 3.0)','chip_up_speed':'Vector2(3.0, 6.5)',
        'chip_gravity':16.0,'chip_lifetime':'Vector2(1.7, 2.9)', 'chip_bounce':0.24,'chip_drag':0.22,
        'mist_count':28 if ice else 32,'mist_size':'Vector2(1.3, 2.2)' if ice else 'Vector2(1.5, 2.6)',
        'mist_lifetime':'Vector2(1.7, 2.6)','mist_spread':0.8 if ice else 1.0,'mist_rise':0.6 if ice else 0.9,
        'spark_count':110 if ice else 75,'spark_size':'Vector2(0.07, 0.22)','spark_speed':'Vector2(1.6, 4.2)',
        'spark_lifetime':'Vector2(0.6, 1.5)','spark_gravity':3.0 if ice else 6.0,
        'light_color':'Color(0.12, 0.58, 1.0, 1)' if ice else 'Color(1.0, 0.43, 0.085, 1)',
        'light_energy':2.0 if ice else 2.4,'light_radius':3.5,'light_height':0.7,'light_pulse_sec':0.32,
    }
    ext = [f'[ext_resource type="Script" path="{BASE}/eruption_profile.gd" id="profile"]']
    ext += [f'[ext_resource type="ArrayMesh" path="{MODELS}/{kind}_spire_0{i}.obj" id="mesh{i}"]' for i in range(1,4)]
    ext += [f'[ext_resource type="ArrayMesh" path="{MODELS}/{kind}_chip.obj" id="chip_mesh"]']
    ext += [f'[ext_resource type="Material" path="{BASE}/{kind}_{suffix}.tres" id="{suffix}"]' for suffix in ('spire','chip','ground','ring','mist','spark')]
    curves='''
[sub_resource type="Curve" id="rise"]
max_value = 1.25
_data = [Vector2(0, 0), 0.0, 0.0, 0, 0, Vector2(0.4, 1.15), 0.0, 0.0, 0, 0, Vector2(0.68, 0.98), 0.0, 0.0, 0, 0, Vector2(0.83, 1.025), 0.0, 0.0, 0, 0, Vector2(1, 1), 0.0, 0.0, 0, 0]
point_count = 5
[sub_resource type="Curve" id="vanish"]
max_value = 1.2
_data = [Vector2(0, 1), 0.0, 0.0, 0, 0, Vector2(0.2, 1.04), 0.0, 0.0, 0, 0, Vector2(1, 0), 0.0, 0.0, 0, 0]
point_count = 3
[sub_resource type="Curve" id="shrink"]
_data = [Vector2(0, 1), 0.0, 0.0, 0, 0, Vector2(0.65, 1), 0.0, 0.0, 0, 0, Vector2(1, 0), 0.0, 0.0, 0, 0]
point_count = 3
'''
    write(f'{kind}_profile.tres','[gd_resource type="Resource" load_steps=15 format=3]\n'+'\n'.join(ext)+curves+'''
[resource]
script = ExtResource("profile")
spire_meshes = Array[Mesh]([ExtResource("mesh1"), ExtResource("mesh2"), ExtResource("mesh3")])
chip_mesh = ExtResource("chip_mesh")
spire_material = ExtResource("spire")
chip_material = ExtResource("chip")
ground_material = ExtResource("ground")
ring_material = ExtResource("ring")
mist_material = ExtResource("mist")
spark_material = ExtResource("spark")
rise_curve = SubResource("rise")
vanish_curve = SubResource("vanish")
chip_scale_curve = SubResource("shrink")
'''+'\n'.join(f'{key} = {value}' for key,value in values.items()))
    write(f'{kind}_eruption.tscn',f'''[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="{BASE}/eruption_effect.gd" id="script"]
[ext_resource type="Resource" path="{BASE}/{kind}_profile.tres" id="profile"]
[node name="{'GlacialCascade' if ice else 'AncientEarthshatter'}" type="Node3D"]
script = ExtResource("script")
profile = ExtResource("profile")
''')
print('Built 2 eruption scenes and all explicit art resources:', OUT)
