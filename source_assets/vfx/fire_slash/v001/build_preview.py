"""Assemble a procedural fire preview; does not generate or edit bitmap art."""
from pathlib import Path
root = Path(__file__).resolve().parents[4]
fx = root / 'game/presentation/combat/fx/fire_slash_v001'
demo = root / 'game/presentation/combat/demos/fire_slash_v001'
shader = (root / 'game/addons/gputrail_preview/shaders/trail_draw_pass.gdshader').read_text(encoding='utf-8')
shader = shader[:shader.index('void fragment(){')]
shader += '''
uniform vec4 core_color : source_color;
uniform vec4 fire_color : source_color;
uniform vec4 edge_color : source_color;
uniform float energy;
uniform float core_width;
uniform float flame_speed;
uniform vec2 flame_frequency;
uniform float effect_opacity;
uniform float flame_time;
float hash_fire(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise_fire(vec2 p) {
    vec2 cell=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash_fire(cell),hash_fire(cell+vec2(1,0)),f.x),mix(hash_fire(cell+vec2(0,1)),hash_fire(cell+vec2(1,1)),f.x),f.y);
}
void fragment() {
    vec2 uv=UV;
    float n=noise_fire(vec2(uv.x*flame_frequency.x-flame_time*flame_speed,uv.y*flame_frequency.y));
    float n2=noise_fire(vec2(uv.x*flame_frequency.x*2.0+flame_time,uv.y*flame_frequency.y*2.0));
    float outer=0.86+0.14*n;
    float body=smoothstep(0.08,0.35,uv.y)*(1.0-smoothstep(outer-0.08,outer,uv.y));
    float ribs=smoothstep(0.22,0.72,n*0.75+n2*0.25);
    float core=exp(-pow((uv.y-0.82)/core_width,2.0));
    float along=smoothstep(0.0,0.18,uv.x)*smoothstep(1.0,0.90,uv.x);
    vec3 fire=mix(edge_color.rgb,fire_color.rgb,ribs);
    fire=mix(fire,core_color.rgb,clamp(core+pow(ribs,4.0)*0.28,0.0,1.0));
    ALBEDO=fire;
    EMISSION=fire*energy;
    ALPHA=clamp(body*(0.2+0.55*ribs)+core*0.8,0.0,0.92)*along*effect_opacity;
}
'''
(fx/'flame.gdshader').write_text(shader,encoding='utf-8')
scene = (root/'game/presentation/combat/fx/slash_candidates_v001/b_weight.tscn').read_text(encoding='utf-8')
scene=scene.replace('res://presentation/combat/fx/slash_candidates_v001/ribbon_effect.gd','res://presentation/combat/fx/fire_slash_v001/fire_effect.gd').replace('res://presentation/combat/fx/slash_candidates_v001/b_weight.tres','res://presentation/combat/fx/fire_slash_v001/flame.tres')
scene=scene.replace('ribbon_material =','material =').replace('blade_span = 1.45','blade_span = 1.6').replace('tail_lifetime_sec = 0.22\nsample_distance = 0.01\nfade_power = 1.1','history_sec = 0.20\nfade_out_sec = 0.18\nsample_fps = 60')
scene=scene.replace('Color(1, 0.96, 0.87, 1)','Color(1, 0.35, 0.035, 1)').replace('amount = 24','amount = 20').replace('radius = 0.018','radius = 0.009').replace('height = 0.036','height = 0.018').replace('emission_sphere_radius = 0.025','emission_sphere_radius = 0.10').replace('lifetime = 0.22','lifetime = 0.30').replace('initial_velocity_max = 0.8','initial_velocity_max = 1.2')
scene=scene.replace('emitting = false','position = Vector3(0, 0, -0.5)\nemitting = false')
(fx/'fire_slash.tscn').write_text(scene,encoding='utf-8')
showcase=(root/'game/presentation/combat/demos/slash_showcase_v001/showcase.gd').read_text(encoding='utf-8')
showcase=showcase.replace('res://presentation/combat/demos/slash_showcase_v001/settings.tres','res://presentation/combat/demos/fire_slash_v001/settings.tres').replace('source_assets/vfx/basic_slash/v001/previews','source_assets/vfx/fire_slash/v001/previews')
showcase=showcase.replace('KEY_1, KEY_2, KEY_3:', 'KEY_1:').replace('1 / 2 / 3 · Space · Tab · P · Esc','Space · Tab · P · Esc')
showcase=showcase.replace('String.chr(65 + _variant)', '"FIRE"')
(demo/'showcase.gd').write_text(showcase,encoding='utf-8')
(demo/'showcase.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://presentation/combat/demos/fire_slash_v001/showcase.gd" id="1"]\n[node name="FireSlashPreview" type="Node"]\nscript = ExtResource("1")\n',encoding='utf-8')
(demo/'settings.tres').write_text('''[gd_resource type="Resource" load_steps=3 format=3]
[ext_resource type="Script" path="res://presentation/combat/demos/slash_showcase_v001/settings.gd" id="1"]
[ext_resource type="PackedScene" path="res://presentation/combat/fx/fire_slash_v001/fire_slash.tscn" id="2"]
[resource]
script = ExtResource("1")
effects = Array[PackedScene]([ExtResource("2")])
camera_size = 12.0
close_camera_size = 5.0
repeat_interval_sec = 1.1
variant_duration_sec = 8.5
slow_scale = 0.35
slow_start_sec = 3.5
capture_length_sec = 8.0
capture_progress = 0.95
overlay_margin = 24.0
overlay_font_size = 36
''',encoding='utf-8')
encode=(root/'source_assets/vfx/basic_slash/v001/encode_preview.py').read_text(encoding='utf-8').replace('slash_compare','fire_slash')
(Path(__file__).parent/'encode_preview.py').write_text(encode,encoding='utf-8')
