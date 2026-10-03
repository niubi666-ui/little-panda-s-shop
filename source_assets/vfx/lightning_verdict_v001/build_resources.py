"""Initial art authoring. Runtime .tres Resources remain authoritative after tuning."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/presentation/combat/fx/lightning_verdict_v001'
BASE='res://presentation/combat/fx/lightning_verdict_v001'
ERU='res://presentation/combat/fx/elemental_eruptions_v001'

def write(name,body):
    (OUT/name).write_text(body.strip()+'\n',encoding='utf-8')

def material(name,shader,values):
    write(name,f'''[gd_resource type="ShaderMaterial" load_steps=2 format=3]
[ext_resource type="Shader" path="{shader}" id="shader"]
[resource]
shader = ExtResource("shader")
'''+ '\n'.join(f'shader_parameter/{k} = {v}' for k,v in values.items()))

material('core.tres',f'{BASE}/bolt.gdshader',{'tint':'Color(0.86, 0.93, 1, 1)','energy':'5.0','intensity':'0.0','visual_time':'0.0','softness':'6.0'})
material('corona.tres',f'{BASE}/bolt.gdshader',{'tint':'Color(0.25, 0.36, 1, 1)','energy':'2.7','intensity':'0.0','visual_time':'0.0','softness':'4.8'})
material('sigil.tres',f'{BASE}/sigil.gdshader',{'tint':'Color(0.25, 0.45, 1, 1)','energy':'2.2','opacity':'0.7','visual_time':'0.0','charge_sec':'0.48','duration_sec':'4.2'})
material('ring.tres',f'{ERU}/ring.gdshader',{'tint':'Color(0.3, 0.53, 1, 0.88)','energy':'2.4','progress':'0.0','brokenness':'0.55'})
material('flash.tres','res://presentation/combat/fx/sword_waves_v001/flash.gdshader',{'tint':'Color(0.68, 0.82, 1, 1)','energy':'4.5','progress':'0.0'})
material('smoke.tres',f'{ERU}/mist.gdshader',{'tint':'Color(0.08, 0.13, 0.24, 1)','highlight':'Color(0.34, 0.47, 0.7, 1)','opacity':'0.26','progress':'0.0','particle_seed':'0.0','luminous':'0.15'})
write('spark.tres','''[gd_resource type="StandardMaterial3D" format=3]
[resource]
shading_mode = 0
albedo_color = Color(0.64, 0.81, 1, 1)
emission_enabled = true
emission = Color(0.26, 0.46, 1, 1)
emission_energy_multiplier = 2.4
''')
write('debris.tres','''[gd_resource type="StandardMaterial3D" format=3]
[resource]
albedo_color = Color(0.27, 0.28, 0.3, 1)
roughness = 0.68
metallic = 0.12
''')
ext=[f'[ext_resource type="Script" path="{BASE}/lightning_profile.gd" id="profile"]']
ext += [f'[ext_resource type="Material" path="{BASE}/{key}.tres" id="{key}"]' for key in ('core','corona','sigil','ring','flash','smoke','spark','debris')]
ext += ['[ext_resource type="ArrayMesh" path="res://assets/vfx/elemental_eruptions_v001/models/rock_chip.obj" id="mesh"]']
values={
 'duration_sec':4.2,'charge_sec':0.48,'target':'Vector3(0, 0, -4.8)',
 'strike_offsets':'PackedVector3Array(0, 0, 0, -1.65, 0, 0.7, 1.6, 0, 0.35, 0.45, 0, -1.6)',
 'strike_delays':'PackedFloat32Array(0.48, 0.6, 0.71, 0.82)',
 'strike_heights':'PackedFloat32Array(6.4, 4.6, 5.0, 4.7)',
 'strike_widths':'PackedFloat32Array(1, 0.5, 0.58, 0.52)',
 'pulse_times':'PackedFloat32Array(0, 0.12, 0.26, 0.43)',
 'pulse_weights':'PackedFloat32Array(1, 0.78, 0.62, 0.35)',
 'pulse_decay_sec':0.085,'bolt_duration_sec':0.82,'shape_rate':15.0,'shape_count':4,
 'bolt_segments':24,'bolt_jitter':0.34,'bolt_width':0.115,'branch_count':6,
 'branch_span':'Vector2(0.85, 2.0)','branch_drop':'Vector2(1.0, 2.7)',
 'branch_width_ratio':0.42,'corona_width_ratio':3.5,'visual_seed':31037,
 'ground_radius':3.8,'ground_height':0.035,'ground_arc_count':14,'ground_arc_segments':18,
 'arc_lifetime_sec':2.3,'ring_lifetime_sec':0.86,'ring_radius':3.8,
 'flash_size':3.7,'flash_lifetime_sec':0.2,
 'spark_count':164,'spark_size':'Vector2(0.12, 0.34)','spark_speed':'Vector2(1.6, 4.6)',
 'spark_lifetime':'Vector2(0.55, 1.55)','spark_gravity':3.5,
 'debris_count':92,'debris_size':'Vector2(0.12, 0.36)','debris_speed':'Vector2(1.0, 3.1)',
 'debris_lifetime':'Vector2(1.4, 2.7)','debris_gravity':14.0,'debris_bounce':0.26,'debris_drag':0.23,
 'smoke_count':24,'smoke_size':'Vector2(1.1, 2.0)','smoke_lifetime':'Vector2(1.7, 2.7)',
 'smoke_spread':1.0,'smoke_rise':0.8,'light_color':'Color(0.28, 0.43, 1, 1)',
 'light_energy':4.8,'light_radius':4.3,
}
write('profile.tres','[gd_resource type="Resource" load_steps=12 format=3]\n'+'\n'.join(ext)+'''
[sub_resource type="Curve" id="fade"]
_data = [Vector2(0, 0.55), 0.0, 0.0, 0, 0, Vector2(0.15, 1), 0.0, 0.0, 0, 0, Vector2(0.7, 1), 0.0, 0.0, 0, 0, Vector2(1, 0), 0.0, 0.0, 0, 0]
point_count = 4
[resource]
script = ExtResource("profile")
core_material = ExtResource("core")
corona_material = ExtResource("corona")
sigil_material = ExtResource("sigil")
ring_material = ExtResource("ring")
flash_material = ExtResource("flash")
smoke_material = ExtResource("smoke")
spark_material = ExtResource("spark")
debris_material = ExtResource("debris")
debris_mesh = ExtResource("mesh")
fade_curve = SubResource("fade")
'''+ '\n'.join(f'{k} = {v}' for k,v in values.items()))
write('lightning_verdict.tscn',f'''[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="{BASE}/lightning_effect.gd" id="script"]
[ext_resource type="Resource" path="{BASE}/profile.tres" id="profile"]
[node name="TempestVerdict" type="Node3D"]
script = ExtResource("script")
profile = ExtResource("profile")
''')

# A separate editable preview stage retains all accepted ice/rock scenes.
stage=ROOT/'game/presentation/combat/lightning_showcase'
stage.mkdir(parents=True,exist_ok=True)
original=(ROOT/'game/presentation/combat/eruption_showcase/showcase_style.tres').read_text(encoding='utf-8')
original=original.replace('load_steps=10','load_steps=9')
original=original.replace('res://presentation/combat/fx/elemental_eruptions_v001/ice_eruption.tscn',f'{BASE}/lightning_verdict.tscn')
original='\n'.join(line for line in original.splitlines() if 'id="rock"' not in line)
original=original.replace('Array[PackedScene]([ExtResource("ice"), ExtResource("rock")])','Array[PackedScene]([ExtResource("ice")])')
original=original.replace('PackedStringArray("vfx.showcase.ice", "vfx.showcase.rock")','PackedStringArray("vfx.lightning.name")')
original=original.replace('camera_position = Vector3(13.0, 9.2, 3.8)','camera_position = Vector3(12.8, 9.6, 5.0)')
original=original.replace('camera_target = Vector3(0, 1.2, -4.3)','camera_target = Vector3(0, 2.05, -4.8)')
original=original.replace('camera_fov = 35.0','camera_fov = 38.0')
original=original.replace('ice_color = Color(0.32, 0.82, 1.0, 1)','ice_color = Color(0.56, 0.72, 1.0, 1)')
original=original.replace('loop_interval = 5.9','loop_interval = 4.8')
(stage/'showcase_style.tres').write_text(original+'\n',encoding='utf-8')
(stage/'showcase.tscn').write_text('''[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://presentation/combat/lightning_showcase/showcase.gd" id="script"]
[ext_resource type="Resource" path="res://presentation/combat/lightning_showcase/showcase_style.tres" id="style"]
[node name="LightningShowcase" type="Node3D"]
script = ExtResource("script")
style = ExtResource("style")
''',encoding='utf-8')
print('Authored lightning effect and isolated preview Resources:',OUT)
