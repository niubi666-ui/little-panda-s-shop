"""Read-only checks of Blender source, baked texture delivery and animation."""
import bpy,json,hashlib,math
from pathlib import Path
BASE=Path(__file__).resolve().parents[1];ROOT=BASE.parents[2];GAME=ROOT/'game/assets/vfx/fire_slash_v002'
report={'blender':bpy.app.version_string,'failures':[],'textures':[],'animation':[]}
manifest=json.loads((BASE/'reports/art_bake_manifest.json').read_text(encoding='utf-8'))
for rec in manifest['frames']:
    src=BASE/'bakes'/rec['file'];dest=GAME/rec['file']
    if hashlib.sha256(src.read_bytes()).hexdigest()!=rec['sha256']:report['failures'].append('Source bake hash mismatch: '+rec['file'])
    if src.read_bytes()!=dest.read_bytes():report['failures'].append('Runtime bake mismatch: '+rec['file'])
    image=bpy.data.images.load(str(dest),check_existing=False)
    if list(image.size)!=[2048,512]:report['failures'].append('Size mismatch: '+rec['file'])
    report['textures'].append({'file':rec['file'],'size':list(image.size)});bpy.data.images.remove(image)
atlas=bpy.data.images.load(str(GAME/'flame_atlas.png'),check_existing=False)
if list(atlas.size)!=[1024,1024]:report['failures'].append('Atlas dimensions')
report['atlas']={'size':list(atlas.size),'channels':atlas.channels,'alpha_mode':atlas.alpha_mode}
bpy.ops.wm.open_mainfile(filepath=str(BASE/'blender/fire_slash_v002.blend'),load_ui=False,use_scripts=False)
scene=bpy.context.scene;arc=bpy.data.objects['FIRE_Main_Arc'];sword=bpy.data.objects['Sword_Swing_Control']
for f in [1,10,18,28,47,66,90,96]:
    scene.frame_set(f)
    report['animation'].append({'frame':f,'sword_angle_deg':math.degrees(sword.rotation_euler.z),'arc_hidden':arc.hide_render,'active_shape_keys':[(k.name,round(k.value,3)) for k in arc.data.shape_keys.key_blocks if k.value>0]})
report['source']={'shader_nodes':len(arc.data.materials[0].node_tree.nodes),'shape_keys':len(arc.data.shape_keys.key_blocks),'frame_range':[scene.frame_start,scene.frame_end]}
bpy.ops.wm.open_mainfile(filepath=str(BASE/'blender/flame_atlas_source.blend'),load_ui=False,use_scripts=False)
report['atlas_source']={'mesh_objects':len([o for o in bpy.data.objects if o.type=='MESH']),'film_transparent':bpy.context.scene.render.film_transparent}
if report['atlas_source']['mesh_objects']!=4:report['failures'].append('Atlas source should have 4 flame lobes')
(BASE/'reports/art_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report))
if report['failures']:raise RuntimeError('Art validation failed')
