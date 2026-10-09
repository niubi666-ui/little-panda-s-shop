"""Isolated Blender CLI export of the approved v003 character; source stays intact."""
import bpy, json, hashlib
from pathlib import Path
from mathutils import Matrix

ROOT = Path('E:/ShopGame/source_assets/characters/jackal_scout')
SOURCE = ROOT / 'blender/jackal_scout_animation_review_v003.blend'
DEST = Path('E:/ShopGame/game/assets/characters/jackal_scout/melee_scout_v001')
DEST.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
rig = bpy.data.objects['Jackal_Scout_Rig']
body = bpy.data.objects['Jackal_Scout_Body']
weapon = bpy.data.objects['Jackal_Scout_Saber']
scene = bpy.data.scenes.new('JackalScoutRuntime')
bpy.context.window.scene = scene
for obj in (rig,body,weapon):
    scene.collection.objects.link(obj)
    obj.hide_set(False)
    obj.hide_render = False
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
scene.render.fps = 30
scene.use_preview_range = False
for track in list(rig.animation_data.nla_tracks):
    rig.animation_data.nla_tracks.remove(track)
rig.animation_data.action = None
for bone in rig.pose.bones: bone.matrix_basis = Matrix.Identity(4)
names = ['scout_idle','scout_walk','scout_run','scout_attack_slash','scout_attack_diagonal','scout_hit_react','scout_death']
assert set(a.name for a in bpy.data.actions) == set(names)
report = {'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'clips':{},'meshes':{},'bones':len(rig.data.bones)}
for name in names:
    action = bpy.data.actions[name]
    rig.animation_data.action = action
    if action.slots: rig.animation_data.action_slot = action.slots[0]
    first,last = map(int,action.frame_range)
    report['clips'][name] = {'frame_start':first,'frame_end':last,'duration_sec':(last-first)/30}
    scene.frame_set(first)
    bpy.context.view_layer.update()
    if name == 'scout_idle':
        deps = bpy.context.evaluated_depsgraph_get()
        ob = body.evaluated_get(deps)
        mesh = ob.to_mesh()
        verts = [ob.matrix_world @ v.co for v in mesh.vertices]
        report['idle_body_bounds_blender'] = {'min':[min(v[i] for v in verts) for i in range(3)],'max':[max(v[i] for v in verts) for i in range(3)]}
        ob.to_mesh_clear()
        report['idle_bones_world'] = {suffix:list(rig.matrix_world @ rig.pose.bones['mixamorig:'+suffix].head) for suffix in ['Head','LeftShoulder','RightShoulder','LeftToeBase','LeftFoot']}
for obj in (body,weapon):
    obj.data.calc_loop_triangles()
    report['meshes'][obj.name] = {'triangles':len(obj.data.loop_triangles),'materials':[m.name for m in obj.data.materials]}
rig.animation_data.action = bpy.data.actions['scout_idle']
if rig.animation_data.action.slots: rig.animation_data.action_slot = rig.animation_data.action.slots[0]
scene.frame_start = 1
scene.frame_end = 74
scene.frame_set(1)
# Validate exporter enum values against this installed Blender version.
rna = bpy.ops.export_scene.gltf.get_rna_type()
for key,value in {'export_format':'GLB','export_animation_mode':'ACTIONS','export_materials':'EXPORT'}.items():
    items = [v.identifier for v in rna.properties[key].enum_items]
    # Dynamic exporter choices can be empty in RNA; installed addon defines GLB.
    if items: assert value in items, (key,value)
runtime = ROOT / 'blender/jackal_scout_runtime_v001.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(runtime))
bpy.ops.export_scene.gltf(filepath=str(DEST / 'jackal_scout.glb'),export_format='GLB',use_selection=True,use_active_scene=True,
    export_animations=True,export_animation_mode='ACTIONS',export_anim_slide_to_zero=True,
    export_force_sampling=True,export_apply=False,export_materials='EXPORT')
report['glb'] = str(DEST / 'jackal_scout.glb')
(ROOT / 'reports/runtime_export_v001.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('SCOUT_EXPORT',json.dumps(report),flush=True)
