from pathlib import Path
import shutil
base=Path(__file__).resolve().parent
root=base.parents[3]
fx=root/'game/presentation/combat/fx/trail_presets_01_06_v001'
demo=root/'game/presentation/combat/demos/trail_presets_01_06_v001'
assets=root/'game/assets/vfx/trail_presets_01_06_v001'
for file in (base/'textures').iterdir():shutil.copy2(file,assets/file.name)
for number in ['01','06']:
    refs=['[ext_resource type="Shader" path="res://presentation/combat/fx/trail_presets_01_06_v001/baked_trail.gdshader" id="shader"]']
    params=[]
    for frame in range(4):
        idx=0 if number=='01' else frame
        for kind,ext in [('emission','exr'),('mask','png')]:
            key=f'{kind}_{frame}'
            refs.append(f'[ext_resource type="Texture2D" path="res://assets/vfx/trail_presets_01_06_v001/blade_{number}_{idx}_{kind}.{ext}" id="{key}"]')
            params.append(f'shader_parameter/{key} = ExtResource("{key}")')
    text='[gd_resource type="ShaderMaterial" load_steps=10 format=3]\n'+'\n'.join(refs)+'\n[resource]\nshader = ExtResource("shader")\n'+'\n'.join(params)+'\nshader_parameter/frame_phase = 0.0\nshader_parameter/energy_scale = 1.0\nshader_parameter/opacity = 1.0\n'
    text=text.replace('shader_parameter/energy_scale = 1.0','shader_parameter/energy_scale = 0.65')
    (fx/f'blade_{number}.tres').write_text(text,encoding='utf-8')
    scene=(root/'game/presentation/combat/fx/slash_candidates_v002/a_clean.tscn').read_text(encoding='utf-8')
    scene=scene.replace('res://presentation/combat/fx/slash_candidates_v002/ribbon_effect.gd','res://presentation/combat/fx/trail_presets_01_06_v001/preset_effect.gd').replace('res://presentation/combat/fx/slash_candidates_v002/a_clean.tres',f'res://presentation/combat/fx/trail_presets_01_06_v001/blade_{number}.tres')
    scene=scene.replace('root_inset_ratio = 0.06','root_inset_ratio = 0.02').replace('tip_extension_ratio = 0.15','tip_extension_ratio = 0.28').replace('fade_power = 0.65','fade_power = 0.25').replace('max_segment_angle_deg = 5.0','max_segment_angle_deg = 2.0')
    scene=scene.replace('[node name="Particles"',f'radial_subdivisions = 8\nnoise_frame_rate = {0.0 if number=="01" else 6.6666667}\n[node name="Particles"').replace('emitting = false','visible = false\nemitting = false')
    (fx/f'blade_{number}.tscn').write_text(scene,encoding='utf-8')
settings=(root/'game/presentation/combat/demos/slash_showcase_v001/settings.gd').read_text(encoding='utf-8')+'\n@export var preset_names: PackedStringArray\n@export var stage_material: Material\n'
(demo/'settings.gd').write_text(settings,encoding='utf-8')
(demo/'settings.tres').write_text('''[gd_resource type="Resource" load_steps=5 format=3]
[ext_resource type="Script" path="res://presentation/combat/demos/trail_presets_01_06_v001/settings.gd" id="1"]
[ext_resource type="PackedScene" path="res://presentation/combat/fx/trail_presets_01_06_v001/blade_01.tscn" id="01"]
[ext_resource type="PackedScene" path="res://presentation/combat/fx/trail_presets_01_06_v001/blade_06.tscn" id="06"]
[ext_resource type="Material" path="res://presentation/combat/demos/trail_presets_01_06_v001/stage.tres" id="stage"]
[resource]
script = ExtResource("1")
stage_material = ExtResource("stage")
effects = Array[PackedScene]([ExtResource("01"),ExtResource("06")])
preset_names = PackedStringArray("M_Trail_Blade_01", "M_Trail_Blade_06")
camera_size = 12.0
close_camera_size = 4.5
repeat_interval_sec = 1.1
variant_duration_sec = 7.0
slow_scale = 0.35
slow_start_sec = 2.5
capture_length_sec = 13.9
capture_progress = 0.9
overlay_margin = 24.0
overlay_font_size = 32
''',encoding='utf-8')
show=(root/'game/presentation/combat/demos/slash_showcase_v002/showcase.gd').read_text(encoding='utf-8')
show=show.replace('res://presentation/combat/demos/slash_showcase_v002/settings.tres','res://presentation/combat/demos/trail_presets_01_06_v001/settings.tres').replace('source_assets/vfx/basic_slash/v002/previews','source_assets/vfx/trail_fxs_v2/selected_01_06_v001/previews')
show=show.replace('String.chr(65 + _variant)','Settings.preset_names[_variant]').replace('button.text = String.chr(65 + index)','button.text = Settings.preset_names[index].right(2)').replace('KEY_1, KEY_2, KEY_3:','KEY_1, KEY_2:').replace('1 / 2 / 3','1 / 2')
show=show.replace('\t_arena.hud.hide()', '\t_arena.hud.hide()\n\t_arena.get_node("Ground").material_override = Settings.stage_material\n\tfor tile in _arena.get_node("Tiles").get_children():\n\t\tif tile is MeshInstance3D: tile.material_override = Settings.stage_material')
(demo/'showcase.gd').write_text(show,encoding='utf-8')
(demo/'showcase.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://presentation/combat/demos/trail_presets_01_06_v001/showcase.gd" id="1"]\n[node name="SelectedPresets" type="Node"]\nscript = ExtResource("1")\n',encoding='utf-8')
encode=(root/'source_assets/vfx/basic_slash/v001/encode_preview.py').read_text(encoding='utf-8').replace('slash_compare','presets_01_06')
(base/'encode_preview.py').write_text(encode,encoding='utf-8')
print('RESOURCES_READY')
