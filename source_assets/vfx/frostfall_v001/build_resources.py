"""Initial art authoring. Runtime .tres Resources are authoritative after tuning."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game/presentation/combat/fx/frostfall_v001'
BASE = 'res://presentation/combat/fx/frostfall_v001'
OUT.mkdir(parents=True, exist_ok=True)

def write(name, body):
    (OUT / name).write_text(body.strip() + '\n', encoding='utf-8')

def replace_field(text, key, value):
    result, count = re.subn(r'^' + re.escape(key) + r' = .+$', f'{key} = {value}', text, flags=re.M)
    assert count == 1, f'Expected one authoring field: {key}'
    return result

write('fall_streak.tres', f'''[gd_resource type="ShaderMaterial" load_steps=2 format=3]
[ext_resource type="Shader" path="{BASE}/fall_streak.gdshader" id="shader"]
[resource]
shader = ExtResource("shader")
shader_parameter/tint = Color(0.32, 0.8, 1, 1)
shader_parameter/energy = 3.3
shader_parameter/intensity = 0.0
shader_parameter/visual_time = 0.0
shader_parameter/filament_density = 65.0
shader_parameter/flow_speed = 30.0
''')
write('impact_flash.tres', '''[gd_resource type="ShaderMaterial" load_steps=2 format=3]
[ext_resource type="Shader" path="res://presentation/combat/fx/sword_waves_v001/flash.gdshader" id="shader"]
[resource]
shader = ExtResource("shader")
shader_parameter/tint = Color(0.4, 0.85, 1, 1)
shader_parameter/energy = 3.8
shader_parameter/progress = 0.0
''')
profile = (ROOT / 'game/presentation/combat/fx/elemental_eruptions_v001/ice_profile.tres').read_text(encoding='utf-8')
profile = profile.replace('load_steps=15', 'load_steps=19')
profile = profile.replace('res://presentation/combat/fx/elemental_eruptions_v001/eruption_profile.gd', f'{BASE}/frostfall_profile.gd')
profile = profile.replace('[sub_resource type="Curve" id="rise"]', f'''[ext_resource type="Material" path="{BASE}/fall_streak.tres" id="trail"]
[ext_resource type="Material" path="{BASE}/impact_flash.tres" id="flash"]
[sub_resource type="Curve" id="rise"]''')
profile = profile.replace('[resource]', '''[sub_resource type="Curve" id="fall"]
_data = [Vector2(0, 0), 0.0, 0.0, 0, 0, Vector2(0.25, 0.0625), 0.5, 0.5, 0, 0, Vector2(0.5, 0.25), 1.0, 1.0, 0, 0, Vector2(0.75, 0.5625), 1.5, 1.5, 0, 0, Vector2(1, 1), 2.0, 2.0, 0, 0]
point_count = 5
[sub_resource type="Curve" id="settle"]
min_value = -0.2
_data = [Vector2(0, 0), 0.0, 0.0, 0, 0, Vector2(0.25, -0.12), 0.0, 0.0, 0, 0, Vector2(0.6, 0.035), 0.0, 0.0, 0, 0, Vector2(1, 0), 0.0, 0.0, 0, 0]
point_count = 4
[resource]''')
for key, value in {
    'visual_seed': 12783, 'duration_sec': 5.1, 'anticipation_sec': 0.2,
    'travel_sec': 1.08, 'hold_sec': 1.65, 'sink_sec': 0.72,
    'height_range': 'Vector2(1.6, 3.7)', 'lean_deg': 'Vector2(5, 16)',
    'crown_stagger_sec': 0.04, 'light_energy': 2.6,
}.items():
    profile = replace_field(profile, key, value)
profile += '''
fall_sec = 0.42
spawn_height_m = 5.8
embed_depth_m = 0.22
satellite_delay_sec = 0.035
settle_sec = 0.18
fall_curve = SubResource("fall")
settle_curve = SubResource("settle")
trail_length_m = 2.4
trail_width_m = 0.9
trail_material = ExtResource("trail")
flash_size_m = 3.2
flash_sec = 0.18
flash_material = ExtResource("flash")
'''
write('profile.tres', profile)
write('frostfall.tscn', f'''[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="{BASE}/frostfall_effect.gd" id="script"]
[ext_resource type="Resource" path="{BASE}/profile.tres" id="profile"]
[node name="FrostCrownDescent" type="Node3D"]
script = ExtResource("script")
profile = ExtResource("profile")
''')

STAGE = ROOT / 'game/presentation/combat/frostfall_showcase'
STAGE.mkdir(parents=True, exist_ok=True)
stage = (ROOT / 'game/presentation/combat/eruption_showcase/showcase_style.tres').read_text(encoding='utf-8')
stage = stage.replace('load_steps=10', 'load_steps=9')
stage = stage.replace('res://presentation/combat/fx/elemental_eruptions_v001/ice_eruption.tscn', f'{BASE}/frostfall.tscn')
stage = '\n'.join(line for line in stage.splitlines() if 'id="rock"' not in line)
for key, value in {
    'effects': 'Array[PackedScene]([ExtResource("ice")])',
    'effect_keys': 'PackedStringArray("vfx.frostfall.name")',
    'camera_position': 'Vector3(15.2, 11.8, 6.0)',
    'camera_target': 'Vector3(0, 2.75, -4.3)',
    'camera_fov': 38.0, 'loop_interval': 5.8, 'capture_frames': 180,
}.items():
    stage = replace_field(stage, key, value)
(STAGE / 'showcase_style.tres').write_text(stage + '\n', encoding='utf-8')
(STAGE / 'showcase.tscn').write_text('''[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://presentation/combat/frostfall_showcase/showcase.gd" id="script"]
[ext_resource type="Resource" path="res://presentation/combat/frostfall_showcase/showcase_style.tres" id="style"]
[node name="FrostfallShowcase" type="Node3D"]
script = ExtResource("script")
style = ExtResource("style")
''', encoding='utf-8')
print('Authored frostfall Resources:', OUT)
