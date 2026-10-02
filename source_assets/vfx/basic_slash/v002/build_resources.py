"""Reuse v001 generated textures, build full blade sweep presentation resources."""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[4]
SOURCE = Path(__file__).resolve().parent
FX = ROOT / 'game/presentation/combat/fx/slash_candidates_v002'
DEMO = ROOT / 'game/presentation/combat/demos/slash_showcase_v002'
OLD_DEMO = ROOT / 'game/presentation/combat/demos/slash_showcase_v001'
regions = {x['key']: x['shader_uv_region'] for x in json.loads((SOURCE.parent / 'v001/asset_validation.json').read_text(encoding='utf-8'))}
variants = [
    dict(key='a_clean', inset=.06, extension=.15, life=.32, fade=.65, bright=1.3, opacity=.96, edge=.055, body=.50, front=.25, grain=0, amount=12, particle=.014),
    dict(key='b_weight', inset=.02, extension=.24, life=.38, fade=.50, bright=1.55, opacity=.98, edge=.078, body=.65, front=.40, grain=0, amount=16, particle=.018),
    dict(key='c_streak', inset=.06, extension=.16, life=.26, fade=.85, bright=1.4, opacity=.94, edge=.05, body=.35, front=.25, grain=.36, amount=18, particle=.012),
]
for v in variants:
    region = ', '.join(f'{n:.9f}' for n in regions[v['key']])
    material = f'''[gd_resource type="ShaderMaterial" load_steps=3 format=3]
[ext_resource type="Shader" path="res://presentation/combat/fx/slash_candidates_v002/ribbon.gdshader" id="shader"]
[ext_resource type="Texture2D" path="res://assets/vfx/basic_slash_v001/{v['key']}.png" id="texture"]
[resource]
shader = ExtResource("shader")
shader_parameter/ribbon_texture = ExtResource("texture")
shader_parameter/texture_region = Vector4({region})
shader_parameter/edge_tint = Color(1, 0.97, 0.86, 1)
shader_parameter/body_tint = Color(0.85, 0.63, 0.30, 1)
shader_parameter/brightness = {v['bright']}
shader_parameter/opacity = {v['opacity']}
shader_parameter/edge_position = 0.93
shader_parameter/edge_width = {v['edge']}
shader_parameter/body_region = Vector2(0.12, 0.72)
shader_parameter/body_strength = {v['body']}
shader_parameter/front_strength = {v['front']}
shader_parameter/texture_strength = 0.08
shader_parameter/streak_amount = {v['grain']}
shader_parameter/streak_frequency = Vector2(54, 12)
'''
    (FX / (v['key'] + '.tres')).write_text(material, encoding='utf-8')
    scene = f'''[gd_scene load_steps=6 format=3]
[ext_resource type="Script" path="res://presentation/combat/fx/slash_candidates_v002/ribbon_effect.gd" id="script"]
[ext_resource type="Material" path="res://presentation/combat/fx/slash_candidates_v002/{v['key']}.tres" id="ribbon"]
[sub_resource type="StandardMaterial3D" id="spark_mat"]
shading_mode = 0
transparency = 1
blend_mode = 1
vertex_color_use_as_albedo = true
albedo_color = Color(1, 0.94, 0.76, 1)
emission_enabled = true
emission = Color(1, 0.94, 0.76, 1)
emission_energy_multiplier = 1.8
[sub_resource type="SphereMesh" id="spark"]
material = SubResource("spark_mat")
radius = {v['particle']}
height = {v['particle'] * 2}
radial_segments = 8
rings = 4
[sub_resource type="Gradient" id="gradient"]
colors = PackedColorArray(1, 1, 1, 1, 1, 1, 1, 0)
[node name="FullBladeSlash" type="Node3D"]
script = ExtResource("script")
ribbon_material = ExtResource("ribbon")
root_inset_ratio = {v['inset']}
tip_extension_ratio = {v['extension']}
tail_lifetime_sec = {v['life']}
sample_distance = 0.01
max_segment_angle_deg = 5.0
fade_power = {v['fade']}
[node name="Particles" type="CPUParticles3D" parent="."]
emitting = false
amount = {v['amount']}
lifetime = 0.22
local_coords = false
emission_shape = 1
emission_sphere_radius = 0.018
direction = Vector3(0, 1, 0)
spread = 180.0
initial_velocity_min = 0.05
initial_velocity_max = 0.35
gravity = Vector3(0, 0, 0)
scale_min = 0.65
scale_max = 1.1
color_ramp = SubResource("gradient")
mesh = SubResource("spark")
cast_shadow = 0
'''
    (FX / (v['key'] + '.tscn')).write_text(scene, encoding='utf-8')

for name in ['settings.gd', 'settings.tres', 'showcase.gd', 'showcase.tscn']:
    content = (OLD_DEMO / name).read_text(encoding='utf-8')
    content = content.replace('slash_candidates_v001', 'slash_candidates_v002').replace('slash_showcase_v001', 'slash_showcase_v002').replace('basic_slash/v001/previews', 'basic_slash/v002/previews')
    (DEMO / name).write_text(content, encoding='utf-8')

default = '''[gd_scene load_steps=2 format=3]
[ext_resource type="PackedScene" path="res://presentation/combat/fx/slash_candidates_v002/a_clean.tscn" id="slash"]
[node name="SwordLight" instance=ExtResource("slash")]
'''
(ROOT / 'game/presentation/combat/fx/slash_default.tscn').write_text(default, encoding='utf-8')
(SOURCE / 'resource_manifest.json').write_text(json.dumps({'texture_source': '../v001/textures', 'variants': variants}, ensure_ascii=False, indent=2), encoding='utf-8')
print('Built 3 full blade sweep candidates and v002 demo; updated training default')
