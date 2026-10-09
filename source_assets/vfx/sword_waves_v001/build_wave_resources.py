"""Initial authoring generator; runtime art Resources are authoritative after tuning."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game/presentation/combat/fx/sword_waves_v001'
BASE = 'res://presentation/combat/fx/sword_waves_v001'
MODELS = 'res://assets/vfx/sword_waves_v001/models'
ERUPTION = 'res://presentation/combat/fx/elemental_eruptions_v001'

def write(name, body):
    (OUT / name).write_text(body.strip() + '\n', encoding='utf-8')

def material(name, shader, values):
    write(name, f'''[gd_resource type="ShaderMaterial" load_steps=2 format=3]
[ext_resource type="Shader" path="{shader}" id="shader"]
[resource]
shader = ExtResource("shader")
''' + '\n'.join(f'shader_parameter/{k} = {v}' for k, v in values.items()))

for kind in ('normal', 'frost'):
    ice = kind == 'frost'
    color = 'Color(0.22, 0.72, 1.0, 1)' if ice else 'Color(1.0, 0.87, 0.57, 1)'
    material(f'{kind}_blade.tres', f'{BASE}/blade.gdshader', {
        'body_color': 'Color(0.055, 0.3, 0.52, 1)' if ice else 'Color(0.46, 0.54, 0.51, 1)',
        'edge_color': 'Color(0.62, 0.92, 1.0, 1)' if ice else 'Color(1.0, 0.97, 0.84, 1)',
        'vein_color': color, 'roughness_value': '0.16' if ice else '0.24',
        'crystal': '1.0' if ice else '0.0', 'emission_strength':'1.2' if ice else '1.7', 'visual_time':'0.0', 'exit_progress':'0.0'})
    material(f'{kind}_halo.tres', f'{BASE}/aura.gdshader', {
        'tint': color, 'emission_strength':'2.1', 'opacity':'0.34', 'visual_time':'0.0', 'exit_progress':'0.0'})
    material(f'{kind}_ribbon.tres', f'{BASE}/ribbon.gdshader', {
        'tint': color, 'energy':'2.0', 'visual_time':'0.0', 'opacity':'0.53' if ice else '0.38', 'wave_amount':'0.12', 'exit_progress':'0.0'})
    material(f'{kind}_mist.tres', f'{ERUPTION}/mist.gdshader', {
        'tint':'Color(0.12, 0.29, 0.44, 1)' if ice else 'Color(0.2, 0.24, 0.24, 1)',
        'highlight':'Color(0.48, 0.81, 0.95, 1)' if ice else 'Color(0.65, 0.68, 0.58, 1)',
        'opacity':'0.48' if ice else '0.18', 'progress':'0.0', 'particle_seed':'0.0', 'luminous':'0.4' if ice else '0.1'})
    material(f'{kind}_ring.tres', f'{ERUPTION}/ring.gdshader', {
        'tint': color, 'energy':'2.2', 'progress':'0.0', 'brokenness':'0.55'})
    material(f'{kind}_flash.tres', f'{BASE}/flash.gdshader', {
        'tint':color, 'progress':'0.0', 'energy':'4.0'})
    write(f'{kind}_shard.tres', f'''[gd_resource type="StandardMaterial3D" format=3]
[resource]
albedo_color = {'Color(0.23, 0.66, 0.9, 1)' if ice else 'Color(0.9, 0.88, 0.66, 1)'}
roughness = {'0.18' if ice else '0.4'}
metallic = 0.14
emission_enabled = true
emission = {color}
emission_energy_multiplier = {'0.25' if ice else '1.6'}
''')
    values = {
        'blade_scale':'Vector3(1.95, 1.5, 1.85)' if ice else 'Vector3(1.8, 1.2, 1.7)',
        'blade_tilt_deg':0.0,
        # Adapter supplies (2r,1.6r,4.4r); normalize the solid core to local width 1.
        'projectile_unit_scale':'Vector3(0.25641026, 1.0, 0.255)' if ice else 'Vector3(0.27777778, 1.0, 0.28)',
        'halo_scale':'Vector3(1.075, 1.8, 1.10)',
        'embedded_shard_count':9 if ice else 0,'embedded_shard_size':'Vector2(0.19, 0.42)',
        'echo_offsets':'PackedVector3Array(0, 0.02, 0.22, 0, -0.05, 0.52, 0, 0.07, 0.86)',
        'echo_scales':'PackedVector3Array(0.97, 1, 1, 0.86, 1, 0.95, 0.7, 1, 0.9)',
        'echo_opacity':'PackedFloat32Array(0.27, 0.16, 0.08)',
        'ribbon_count':8 if ice else 6,'ribbon_segments':28,'ribbon_length':3.6 if ice else 3.2,
        'ribbon_width':0.22 if ice else 0.15,'ribbon_spread':1.45,'ribbon_wave':0.12,
        'visual_seed':6721 if ice else 8913,
        'trail_count':104 if ice else 68,'trail_lifetime':'Vector2(0.4, 0.7)',
        'trail_size':'Vector2(0.13, 0.37)' if ice else 'Vector2(0.07, 0.22)',
        'trail_spread':1.6 if ice else 1.4,'trail_speed':4.8,'trail_gravity':0.3 if ice else 0.0,
        'mist_count':18 if ice else 8,'mist_size':'Vector2(0.7, 1.4)' if ice else 'Vector2(0.5, 1.0)',
        'mist_opacity':0.38 if ice else 0.12,'light_color':color,'light_energy':1.1 if ice else 0.7,'light_range':3.4,
        'burst_count':88 if ice else 90,'burst_size':'Vector2(0.13, 0.45)' if ice else 'Vector2(0.08, 0.3)',
        'burst_speed':'Vector2(3.0, 8.0)','burst_gravity':4.0 if ice else 1.2,
        'burst_duration':1.08 if ice else 0.78,'burst_mist_count':18 if ice else 10,
        'burst_mist_size':'Vector2(0.9, 1.7)' if ice else 'Vector2(0.55, 1.2)',
        'burst_mist_spread':1.7 if ice else 1.4,
        'impact_ring_radius':2.8 if ice else 2.3,'impact_flash_size':4.6,'impact_flash_duration':0.22,
        'charge_sec':0.18,'flight_sec':0.82,'flight_distance':10.0,'flight_height':1.0,'duration_sec':3.0,'trail_exit_sec':0.42 if ice else 0.3,
    }
    ext=[f'[ext_resource type="Script" path="{BASE}/wave_profile.gd" id="profile"]',
         f'[ext_resource type="ArrayMesh" path="{MODELS}/{kind}_crescent.obj" id="blade_mesh"]',
         f'[ext_resource type="ArrayMesh" path="{MODELS}/frost_shard.obj" id="shard_mesh"]']
    for suffix in ('blade','halo','ribbon','shard','mist','ring','flash'):
        ext.append(f'[ext_resource type="Material" path="{BASE}/{kind}_{suffix}.tres" id="{suffix}"]')
    write(f'{kind}_profile.tres','[gd_resource type="Resource" load_steps=13 format=3]\n'+'\n'.join(ext)+'''
[sub_resource type="Curve" id="growth"]
max_value = 1.15
_data = [Vector2(0, 0), 0.0, 0.0, 0, 0, Vector2(0.72, 1.08), 0.0, 0.0, 0, 0, Vector2(1, 1), 0.0, 0.0, 0, 0]
point_count = 3
[sub_resource type="Curve" id="fade"]
_data = [Vector2(0, 0.3), 0.0, 0.0, 0, 0, Vector2(0.13, 1), 0.0, 0.0, 0, 0, Vector2(0.65, 1), 0.0, 0.0, 0, 0, Vector2(1, 0), 0.0, 0.0, 0, 0]
point_count = 4
[resource]
script = ExtResource("profile")
blade_mesh = ExtResource("blade_mesh")
shard_mesh = ExtResource("shard_mesh")
blade_material = ExtResource("blade")
halo_material = ExtResource("halo")
ribbon_material = ExtResource("ribbon")
shard_material = ExtResource("shard")
mist_material = ExtResource("mist")
ring_material = ExtResource("ring")
flash_material = ExtResource("flash")
growth_curve = SubResource("growth")
fade_curve = SubResource("fade")
'''+ '\n'.join(f'{k} = {v}' for k,v in values.items()))
    for role in ('wave','impact'):
        write(f'{kind}_{role}.tscn',f'''[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="{BASE}/{'wave_effect' if role == 'wave' else 'wave_impact'}.gd" id="script"]
[ext_resource type="Resource" path="{BASE}/{kind}_profile.tres" id="profile"]
[node name="{kind.title()}{role.title()}" type="Node3D"]
script = ExtResource("script")
profile = ExtResource("profile")''')
    write(f'{kind}_demo.tscn', f'''[gd_scene load_steps=5 format=3]
[ext_resource type="Script" path="{BASE}/wave_demo.gd" id="script"]
[ext_resource type="Resource" path="{BASE}/{kind}_profile.tres" id="profile"]
[ext_resource type="PackedScene" path="{BASE}/{kind}_wave.tscn" id="wave"]
[ext_resource type="PackedScene" path="{BASE}/{kind}_impact.tscn" id="impact"]
[node name="{kind.title()}WaveDemo" type="Node3D"]
script = ExtResource("script")
profile = ExtResource("profile")
wave_scene = ExtResource("wave")
impact_scene = ExtResource("impact")''')
print('Authored normal/frost wave, impact, demo scenes:', OUT)
