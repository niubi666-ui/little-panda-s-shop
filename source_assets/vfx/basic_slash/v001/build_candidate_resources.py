"""Build candidate Godot Resources and inspect source alpha; PNGs are not edited."""
from pathlib import Path
from PIL import Image
import json

ROOT = Path(__file__).resolve().parents[4]
SOURCE = Path(__file__).resolve().parent
FX = ROOT / 'game/presentation/combat/fx/slash_candidates_v001'
DEMO = ROOT / 'game/presentation/combat/demos/slash_showcase_v001'
VARIANTS = [
    dict(key='a_clean', span=.95, life=.16, fade=1.7, brightness=2.0, opacity=.85, grain=0, color='1, 0.99, 0.93', amount=18, particle=.012, core=.04, texture=.18),
    dict(key='b_weight', span=1.45, life=.22, fade=1.1, brightness=2.3, opacity=.9, grain=0, color='1, 0.96, 0.87', amount=24, particle=.018, core=.065, texture=.30),
    dict(key='c_streak', span=1.05, life=.15, fade=1.8, brightness=2.2, opacity=.82, grain=.7, color='0.96, 0.99, 1', amount=32, particle=.01, core=.035, texture=.17),
]
report = []
for v in VARIANTS:
    im = Image.open(SOURCE / 'textures' / (v['key'] + '.png')).convert('RGBA')
    a = im.getchannel('A')
    bbox = a.point(lambda x: 255 if x > 8 else 0).getbbox()
    assert a.getpixel((0, 0)) == 0 and bbox is not None
    x0, y0, x1, y1 = bbox
    region = [(x0 - 2) / im.width, (y0 - 2) / im.height, (x1 - x0 + 4) / im.width, (y1 - y0 + 4) / im.height]
    region_s = ', '.join(f'{x:.9f}' for x in region)
    report.append(dict(key=v['key'], dimensions=list(im.size), alpha_range=a.getextrema(), alpha_bbox=list(bbox), shader_uv_region=region))
    material = f'''[gd_resource type="ShaderMaterial" load_steps=3 format=3]
[ext_resource type="Shader" path="res://presentation/combat/fx/slash_candidates_v001/ribbon.gdshader" id="shader"]
[ext_resource type="Texture2D" path="res://assets/vfx/basic_slash_v001/{v['key']}.png" id="texture"]
[resource]
shader = ExtResource("shader")
shader_parameter/ribbon_texture = ExtResource("texture")
shader_parameter/texture_region = Vector4({region_s})
shader_parameter/tint = Color({v['color']}, 1)
shader_parameter/brightness = {v['brightness']}
shader_parameter/opacity = {v['opacity']}
shader_parameter/streak_amount = {v['grain']}
shader_parameter/streak_frequency = Vector2(54, 17)
shader_parameter/core_width = {v['core']}
shader_parameter/texture_strength = {v['texture']}
'''
    (FX / (v['key'] + '.tres')).write_text(material, encoding='utf-8')
    scene = f'''[gd_scene load_steps=6 format=3]
[ext_resource type="Script" path="res://presentation/combat/fx/slash_candidates_v001/ribbon_effect.gd" id="script"]
[ext_resource type="Material" path="res://presentation/combat/fx/slash_candidates_v001/{v['key']}.tres" id="ribbon"]
[sub_resource type="StandardMaterial3D" id="spark_mat"]
shading_mode = 0
transparency = 1
blend_mode = 1
vertex_color_use_as_albedo = true
albedo_color = Color({v['color']}, 1)
emission_enabled = true
emission = Color({v['color']}, 1)
emission_energy_multiplier = 2.0
[sub_resource type="SphereMesh" id="spark"]
material = SubResource("spark_mat")
radius = {v['particle']}
height = {v['particle'] * 2}
radial_segments = 8
rings = 4
[sub_resource type="Gradient" id="gradient"]
colors = PackedColorArray(1, 1, 1, 1, 1, 1, 1, 0)
[node name="NeutralSlash" type="Node3D"]
script = ExtResource("script")
ribbon_material = ExtResource("ribbon")
blade_span = {v['span']}
tail_lifetime_sec = {v['life']}
sample_distance = 0.01
fade_power = {v['fade']}
[node name="Particles" type="CPUParticles3D" parent="."]
emitting = false
amount = {v['amount']}
lifetime = {v['life']}
local_coords = false
emission_shape = 1
emission_sphere_radius = 0.025
direction = Vector3(0, 1, 0)
spread = 180.0
initial_velocity_min = 0.1
initial_velocity_max = 0.8
gravity = Vector3(0, 0, 0)
scale_min = 0.7
scale_max = 1.2
color_ramp = SubResource("gradient")
mesh = SubResource("spark")
cast_shadow = 0
'''
    (FX / (v['key'] + '.tscn')).write_text(scene, encoding='utf-8')

effects = ', '.join(f'ExtResource("{i}")' for i in range(len(VARIANTS)))
resources = '\n'.join(f'[ext_resource type="PackedScene" path="res://presentation/combat/fx/slash_candidates_v001/{v["key"]}.tscn" id="{i}"]' for i,v in enumerate(VARIANTS))
settings = f'''[gd_resource type="Resource" load_steps=5 format=3]
[ext_resource type="Script" path="res://presentation/combat/demos/slash_showcase_v001/settings.gd" id="script"]
{resources}
[resource]
script = ExtResource("script")
effects = Array[PackedScene]([{effects}])
camera_size = 12.0
close_camera_size = 6.0
repeat_interval_sec = 1.1
variant_duration_sec = 4.5
slow_scale = 0.35
slow_start_sec = 2.2
capture_length_sec = 13.4
capture_progress = 0.72
overlay_margin = 24.0
overlay_font_size = 36
'''
(DEMO / 'settings.tres').write_text(settings, encoding='utf-8')
(SOURCE / 'asset_validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(report, ensure_ascii=False))
