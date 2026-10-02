from pathlib import Path
R=Path(__file__).resolve().parents[2]/'game/presentation/combat'
for actor,color,weapon_size,weapon_pos in [
 ('crossbow','0.15, 0.42, 0.65','1.0, 0.12, 0.3','0, 0.9, -0.4'),
 ('charger','0.72, 0.48, 0.12','0.09, 0.09, 1.8','0.3, 0.8, -0.7'),
 ('banner','0.65, 0.13, 0.3','0.06, 2.5, 0.06','0.45, 1.25, 0')]:
 text=f'''[gd_scene format=3]
[sub_resource type="StandardMaterial3D" id="body_mat"]
albedo_color = Color({color}, 1)
roughness = 0.7
[sub_resource type="StandardMaterial3D" id="weapon_mat"]
albedo_color = Color(0.3, 0.2, 0.1, 1)
[sub_resource type="CapsuleMesh" id="body"]
material = SubResource("body_mat")
radius = 0.4
height = 1.5
[sub_resource type="BoxMesh" id="weapon"]
material = SubResource("weapon_mat")
size = Vector3({weapon_size})
[sub_resource type="BoxMesh" id="visor"]
size = Vector3(0.55, 0.12, 0.12)
[sub_resource type="BoxMesh" id="flag"]
material = SubResource("body_mat")
size = Vector3(0.8, 0.6, 0.05)
[node name="{actor.title()}Placeholder" type="Node3D"]
[node name="Body" type="MeshInstance3D" parent="."]
position = Vector3(0, 0.75, 0)
mesh = SubResource("body")
[node name="Visor" type="MeshInstance3D" parent="."]
position = Vector3(0, 1.2, -0.4)
mesh = SubResource("visor")
[node name="Weapon" type="MeshInstance3D" parent="."]
position = Vector3({weapon_pos})
mesh = SubResource("weapon")
'''
 if actor=='banner':text+='[node name="Flag" type="MeshInstance3D" parent="."]\nposition = Vector3(0.8, 2.1, 0)\nmesh = SubResource("flag")\n'
 (R/f'{actor}_visual.tscn').write_text(text,encoding='utf-8')
 (R/f'{actor}_presentation.tres').write_text(f'''[gd_resource type="Resource" format=3]
[ext_resource type="Script" path="res://presentation/combat/actor_presentation.gd" id="script"]
[ext_resource type="PackedScene" path="res://presentation/combat/{actor}_visual.tscn" id="visual"]
[sub_resource type="CapsuleShape3D" id="body"]
radius = 0.4
height = 1.5
[resource]
script = ExtResource("script")
visual_scene = ExtResource("visual")
body_shape = SubResource("body")
body_height = 0.75
''',encoding='utf-8')
