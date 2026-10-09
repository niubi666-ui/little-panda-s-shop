"""Rebuild only the standalone art study, never the main Godot project."""
from pathlib import Path
import hashlib
import json
import math
import shutil
import struct
import wave

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DEMO = HERE / "godot_demo"
ASSETS = DEMO / "assets"
ASSETS.mkdir(parents=True, exist_ok=True)

sources = {
    "elf.glb": "game/assets/characters/elf_archer/elite_ranger_v001/elite_ranger.glb",
    "target.glb": "game/assets/characters/red_panda/red_panda_v008.glb",
    "arrow.glb": "game/assets/vfx/elite_ranger_v001/ranger_arrow.glb",
    "forest_courtyard.glb": "game/assets/environments/forest_courtyard_v001/forest_courtyard.glb",
    "NotoSerifSC-VF.ttf": "game/assets/fonts/NotoSerifSC-VF.ttf",
}
report = {"date": "2026-10-07", "scope": "source_assets/vfx/charged_arrow_v001 only", "sources": []}
for name, relative in sources.items():
    src = ROOT / relative
    dst = ASSETS / name
    if not dst.exists() or hashlib.sha256(dst.read_bytes()).digest() != hashlib.sha256(src.read_bytes()).digest():
        shutil.copyfile(src, dst)
    report["sources"].append({"copy": name, "source": relative, "sha256": hashlib.sha256(src.read_bytes()).hexdigest()})

# Copy static art/lighting, replacing its gameplay-derived root with a pure art adapter.
room = (ROOT / "game/presentation/rooms/forest_courtyard_v001/room.tscn").read_text(encoding="utf-8")
room = room.replace("res://presentation/rooms/forest_courtyard_v001/forest_surfaces.gd", "res://courtyard_surfaces.gd")
room = room.replace("res://presentation/rooms/forest_courtyard_v001/wet_paving.tres", "res://fx/wet_paving.tres")
room = room.replace("res://presentation/rooms/forest_courtyard_v001/water.tres", "res://fx/water.tres")
room = room.replace("res://assets/environments/forest_courtyard_v001/forest_courtyard.glb", "res://assets/forest_courtyard.glb")
room = room.replace("glow_intensity = 0.25", "glow_intensity = 0.52")
(DEMO / "courtyard.tscn").write_text(room + "\n", encoding="utf-8")
for name in ["wet_paving.gdshader", "wet_paving.tres", "water.tres"]:
    source = (ROOT / "game/presentation/rooms/forest_courtyard_v001" / name).read_text(encoding="utf-8")
    source = source.replace("res://presentation/rooms/forest_courtyard_v001/", "res://fx/")
    if name == "wet_paving.gdshader":
        source = source.replace("varying vec3 world_position;", '''uniform bool use_texture;
uniform vec4 base_tint : source_color;
#include "res://fx/rift_cut.gdshaderinc"
varying vec3 world_position;''')
        source = source.replace("void fragment() {", '''void fragment() {
 if(inside_rift(world_position))discard;''')
        source = source.replace("texture(surface_color, UV).rgb", "(use_texture ? texture(surface_color, UV).rgb : vec3(1.0))*base_tint.rgb")
    (DEMO / "fx" / name).write_text(source,encoding="utf-8")

def write(name, text):
    (DEMO / name).write_text(text.strip() + "\n", encoding="utf-8")

def material(name, shader, values):
    write("fx/" + name + ".tres", '[gd_resource type="ShaderMaterial" load_steps=2 format=3]\n'
          f'[ext_resource type="Shader" path="res://fx/{shader}.gdshader" id="shader"]\n'
          '[resource]\nshader = ExtResource("shader")\n' +
          "\n".join(f"shader_parameter/{k} = {v}" for k, v in values.items()))

# Layout, fonts and colors are editor-visible Resources, including the test HUD.
styles = {
    "normal": ("Color(0.027,0.065,0.044,0.94)", "Color(0.56,0.42,0.2,1)",10),
    "hover": ("Color(0.075,0.14,0.08,0.94)", "Color(1,0.78,0.31,1)",10),
    "pressed": ("Color(0.12,0.16,0.075,0.94)", "Color(1,0.85,0.4,1)",10),
    "panel": ("Color(0.025,0.05,0.035,0.90)", "Color(0.43,0.33,0.17,1)",14),
    "bar": ("Color(0.025,0.05,0.035,0.90)", "Color(0.43,0.33,0.17,1)",0),
    "gold": ("Color(0.92,0.62,0.13,1)", "Color(1,0.89,0.4,1)",0),
    "red": ("Color(0.53,0.13,0.045,1)", "Color(1,0.45,0.2,1)",0),
}
theme = ['[gd_resource type="Theme" load_steps=9 format=3]',
         '[ext_resource type="FontFile" path="res://assets/NotoSerifSC-VF.ttf" id="font"]']
for name,(bg,edge,margin) in styles.items():
    theme += [f'[sub_resource type="StyleBoxFlat" id="{name}"]',f'bg_color = {bg}',f'border_color = {edge}']
    theme += [f'border_width_{side} = 1' for side in ["left","right","top","bottom"]]
    theme += [f'corner_radius_{side} = 5' for side in ["top_left","top_right","bottom_left","bottom_right"]]
    theme += [f'content_margin_{side} = {float(margin)}' for side in ["left","right","top","bottom"]]
theme += ['[resource]','default_font = ExtResource("font")','default_font_size = 17',
          'Label/colors/font_color = Color(1,0.9,0.68,1)',
          'Label/colors/font_shadow_color = Color(0.015,0.025,0.015,0.9)',
          'Label/constants/shadow_offset_x = 2','Label/constants/shadow_offset_y = 2',
          'TitleLabel/base_type = &"Label"','TitleLabel/font_sizes/font_size = 34',
          'SmallLabel/base_type = &"Label"','SmallLabel/font_sizes/font_size = 15',
          'PhaseLabel/base_type = &"Label"','PhaseLabel/font_sizes/font_size = 20',
          'Button/font_sizes/font_size = 16','Button/colors/font_color = Color(1,0.88,0.65,1)',
          *[f'Button/styles/{key} = SubResource("{key}")' for key in ["normal","hover","pressed"]],
          'PanelContainer/styles/panel = SubResource("panel")',
          'ProgressBar/styles/background = SubResource("bar")','ProgressBar/styles/fill = SubResource("red")',
          'ChargeBar/base_type = &"ProgressBar"','ChargeBar/styles/fill = SubResource("gold")',
          'CheckButton/font_sizes/font_size = 16','CheckButton/colors/font_color = Color(1,0.88,0.65,1)']
write("ui_theme.tres","\n".join(theme))
ui = '''[gd_scene load_steps=2 format=3]
[ext_resource type="Theme" path="res://ui_theme.tres" id="theme"]
[node name="StudyUI" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
theme = ExtResource("theme")
[node name="Heading" type="VBoxContainer" parent="."]
layout_mode = 0
offset_left = 32.0
offset_top = 26.0
offset_right = 620.0
offset_bottom = 142.0
'''
for id_ in ["title","subtitle","speed"]:
    ui += f'''[node name="{id_}" type="Label" parent="Heading"]
layout_mode = 2
theme_type_variation = &"{'TitleLabel' if id_=='title' else 'SmallLabel'}"
'''
ui += '''[node name="Status" type="PanelContainer" parent="."]
layout_mode = 0
anchor_left = 1.0
anchor_right = 1.0
offset_left = -416.0
offset_top = 26.0
offset_right = -26.0
offset_bottom = 211.0
grow_horizontal = 0
[node name="Values" type="VBoxContainer" parent="Status"]
layout_mode = 2
theme_override_constants/separation = 8
[node name="phase" type="Label" parent="Status/Values"]
layout_mode = 2
theme_type_variation = &"PhaseLabel"
autowrap_mode = 2
[node name="Charge" type="ProgressBar" parent="Status/Values"]
custom_minimum_size = Vector2(0, 9)
layout_mode = 2
theme_type_variation = &"ChargeBar"
max_value = 1.0
show_percentage = false
[node name="health" type="Label" parent="Status/Values"]
layout_mode = 2
[node name="Health" type="ProgressBar" parent="Status/Values"]
custom_minimum_size = Vector2(0, 12)
layout_mode = 2
show_percentage = false
[node name="hits" type="Label" parent="Status/Values"]
layout_mode = 2
theme_type_variation = &"SmallLabel"
[node name="Footer" type="PanelContainer" parent="."]
layout_mode = 0
anchor_top = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 24.0
offset_top = -154.0
offset_right = -24.0
offset_bottom = -18.0
grow_horizontal = 2
grow_vertical = 0
[node name="Rows" type="VBoxContainer" parent="Footer"]
layout_mode = 2
theme_override_constants/separation = 7
[node name="note" type="Label" parent="Footer/Rows"]
layout_mode = 2
theme_type_variation = &"SmallLabel"
[node name="Modes" type="HBoxContainer" parent="Footer/Rows"]
layout_mode = 2
theme_override_constants/separation = 8
'''
for id_ in ["stand","walk","dodge","trail","manual","replay","pause","language"]:
    ui += f'''[node name="{id_}" type="Button" parent="Footer/Rows/Modes"]
layout_mode = 2
focus_mode = 0
toggle_mode = {'true' if id_ in ['stand','walk','dodge','trail','manual'] else 'false'}
'''
ui += '''[node name="Hints" type="HBoxContainer" parent="Footer/Rows"]
layout_mode = 2
theme_override_constants/separation = 12
[node name="help" type="Label" parent="Footer/Rows/Hints"]
layout_mode = 2
theme_type_variation = &"SmallLabel"
[node name="Slow" type="CheckButton" parent="Footer/Rows/Hints"]
layout_mode = 2
focus_mode = 0
'''
write("ui.tscn",ui)

material("ribbon", "ribbon", {"tint":"Color(1, 0.77, 0.32, 1)", "energy":3.0, "opacity":0.86,
         "time_value":0.0,"flow_frequency":38.0,"flow_speed":20.0})
material("flight_core", "ribbon", {"tint":"Color(1, 0.93, 0.71, 1)", "energy":6.5,"opacity":0.95,
         "time_value":0.0,"flow_frequency":54.0,"flow_speed":40.0})
material("flight_halo", "ribbon", {"tint":"Color(1, 0.63, 0.20, 1)", "energy":3.0,"opacity":0.20,
         "time_value":0.0,"flow_frequency":28.0,"flow_speed":30.0})
material("ground", "ground", {"gold":"Color(1, 0.71, 0.22, 1)", "ember":"Color(0.25, 0.06, 0.008, 1)",
         "energy":4.7,"time_value":0.0,"life":1.0,"travel":0.0,"tick_sec":0.5,"length_m":1.0,
         "half_width":1.0,"opacity":0.95,"scar_frequency":9.0,"edge_glow":0.9})
material("warning", "ribbon", {"tint":"Color(1, 0.27, 0.04, 1)", "energy":1.3,"opacity":0.45,
         "time_value":0.0,"flow_frequency":68.0,"flow_speed":8.0})
material("sigil", "sigil", {"tint":"Color(1, 0.74, 0.32, 1)", "energy":3.0, "opacity":0.0,
         "time_value":0.0,"spin_speed":-0.7,"rune_count":12.0,"radial_width":180.0})
material("flare", "flare", {"tint":"Color(1, 0.89, 0.61, 1)","energy":6.0,"opacity":0.0})
material("mote", "mote", {"tint":"Color(1, 0.8, 0.38, 1)", "energy":4.0})
for kind in ["wall", "lip", "void"]:
    material("rift_"+kind,"rift_stone",{
        "top_color":"Color(0.12,0.09,0.065,1)" if kind=="wall" else ("Color(0.39,0.34,0.27,1)" if kind=="lip" else "Color(0.01,0.004,0.002,1)"),
        "depth_color":"Color(0.025,0.012,0.006,1)","glow_color":"Color(1,0.51,0.08,1)",
        "glow_energy":0.45 if kind=="wall" else 0.0,"roughness_value":0.87,
        "travel":0.0,"life":0.0,"time_value":0.0,"grain_scale":180.0})
material("rift_source","rift_source",{"tint":"Color(1,0.78,0.3,1)","energy":4.2,
         "travel":0.0,"life":0.0,"time_value":0.0})
material("rift_curtain","rift_curtain",{"base_tint":"Color(1,0.83,0.46,1)",
         "top_tint":"Color(1,0.66,0.23,1)","energy":3.4,"opacity":0.85,
         "life":0.0,"travel":0.0,"rise":0.0,"time_value":0.0,"tick_sec":0.5,
         "plume_scale":18.0,"flow_speed":0.9,"vertical_power":1.1})
write("fx/body.tres", '''[gd_resource type="StandardMaterial3D" format=3]
[resource]
albedo_color = Color(1, 0.82, 0.43, 1)
metallic = 0.45
roughness = 0.22
emission_enabled = true
emission = Color(1, 0.76, 0.23, 1)
emission_energy_multiplier = 3.0
''')
values = {
    "elf_scale":2.4,"target_scale":1.20058629,"muzzle_offset":"Vector3(0, 1.95, 0.825)",
    "draw_fraction":0.3,"release_sec":0.85,"charge_radius_m":1.25,"charge_turns":1.7,
    "charge_orbits":4,"charge_speed":6.0,"charge_width_m":0.045,"charge_particle_count":96,
    "charge_particle_size_m":0.065,"arrow_length_m":2.15,"arrow_width_m":0.072,
    "flight_tail_m":5.2,"flight_width_m":0.30,"flight_echo_sec":0.32,"flight_height_m":0.9,
    "launch_blend_m":2.0,"damage_flash_sec":0.18,"label_height_m":1.8,"slow_time_scale":0.2,
    "flight_halo_ratio":3.0,"impact_size_m":1.6,"impact_sec":0.3,
    "flight_helix_radius_m":0.22,"flight_helix_turns":3.0,"trail_height_m":0.13,
    "trail_fade_sec":0.9,"trail_particle_count":192,"trail_particle_size_m":0.047,
    "trail_particle_height_m":2.2,"launch_ring_radius_m":1.3,"launch_ring_count":3,
    "launch_sec":0.38,"light_color":"Color(1, 0.71, 0.26, 1)","charge_light_energy":3.4,
    "shot_light_energy":5.5,"light_range_m":4.5,"flare_size_m":3.2,"audio_volume_db":-11.0,
    "camera_offset":"Vector3(6, 12, 13)","camera_target":"Vector3(0.1, 0.9, 1.5)",
    "camera_size":15.3,"visual_seed":10072026,
    "arrow_label_color":"Color(1,0.22,0.07,1)","scar_label_color":"Color(1,0.82,0.3,1)",
    "dodge_label_color":"Color(0.5,1,0.8,1)",
    "rift_station_count":160,"rift_curtain_count":2,"rift_frequency":0.85,
    "rift_center_ratio":0.18,"rift_opening_ratio":0.57,"rift_jagged_ratio":0.24,
    "rift_depth_m":1.15,"rift_source_depth_m":0.35,"rift_surface_height_m":0.04,"rift_lip_width_m":0.09,
    "rift_lip_height_m":0.065,"rift_height_m":"Vector2(1.9,3.5)",
    "rift_beam_drift_m":0.45,"rift_rise_sec":0.22,"rift_vertical_segments":12,
    "rift_forks":"PackedVector4Array(1.4,0.85,-1,0.16, 4.05,1.1,1,0.19, 6.8,0.74,-1,0.13, 9.2,1.25,1,0.2)",
}
refs = {
    "script": ("Script", "res://fx/profile.gd"),
    "arrow_scene": ("PackedScene", "res://assets/arrow.glb"),
    "elf_scene": ("PackedScene", "res://assets/elf.glb"),
    "target_scene": ("PackedScene", "res://assets/target.glb"),
    **{x: ("ShaderMaterial", f"res://fx/{x}.tres") for x in ["ribbon","ground","sigil","flare","mote","flight_core","flight_halo"]},
    "warning_material": ("ShaderMaterial", "res://fx/warning.tres"),
    "ui_scene": ("PackedScene", "res://ui.tscn"),
    **{"rift_"+kind: ("ShaderMaterial", f"res://fx/rift_{kind}.tres") for kind in ["wall","lip","void","source","curtain"]},
    "body": ("Material", "res://fx/body.tres"),
    **{x + "_sound": ("AudioStream", f"res://assets/{x}.wav") for x in ["charge","fire","pulse"]},
}
write("fx/profile.tres", f'[gd_resource type="Resource" load_steps={len(refs)+1} format=3]\n' +
      "\n".join(f'[ext_resource type="{typ}" path="{path}" id="{key}"]' for key,(typ,path) in refs.items()) +
      '\n[resource]\n' + "\n".join(f'{key} = ExtResource("{key}")' for key in refs) + '\n' +
      "\n".join(f"{key} = {val}" for key,val in values.items()))
write("demo.tscn", '''[gd_scene load_steps=5 format=3]
[ext_resource type="Script" path="res://demo.gd" id="script"]
[ext_resource type="Resource" path="res://fx/profile.tres" id="art"]
[ext_resource type="PackedScene" path="res://courtyard.tscn" id="room"]
[ext_resource type="FontFile" path="res://assets/NotoSerifSC-VF.ttf" id="font"]
[node name="ChargedArrowStudy" type="Node3D"]
script = ExtResource("script")
art = ExtResource("art")
[node name="Courtyard" parent="." instance=ExtResource("room")]
[node name="Floating" type="Label3D" parent="."]
font = ExtResource("font")
font_size = 60
pixel_size = 0.005
outline_size = 9
outline_modulate = Color(0.08,0.02,0.01,1)
billboard = 1
no_depth_test = true
''')

# Original temporary sound design; reproducible, no external samples.
sr = 48000
def save_sound(name, duration, synth):
    raw = bytearray()
    for i in range(round(duration*sr)):
        t = i/sr
        raw += struct.pack("<h", round(max(-1.0,min(1.0,synth(t,duration)))*32760))
    with wave.open(str(ASSETS / (name + ".wav")),"wb") as f:
        f.setparams((1,2,sr,0,"NONE","not compressed"));f.writeframes(raw)

save_sound("charge",2.4,lambda t,d: (t/d)**1.8*math.sin(math.pi*t/d)**0.3*0.32*(
    math.sin(math.tau*(210*t+170*t*t))+0.28*math.sin(math.tau*(420*t+260*t*t))))
save_sound("fire",0.48,lambda t,d: math.exp(-t*14)*0.52*(math.sin(math.tau*(950*t-650*t*t))+
    math.sin(math.tau*155*t)*0.25+math.sin(math.tau*(5783*t+3117*t*t))*0.18))
save_sound("pulse",0.22,lambda t,d: math.sin(math.pi*t/d)*math.exp(-t*12)*0.35*(
    math.sin(math.tau*880*t)+math.sin(math.tau*1320*t)*0.25))
(HERE / "asset_manifest.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps({"project":str(DEMO),"copied_assets":len(sources)},ensure_ascii=False))
