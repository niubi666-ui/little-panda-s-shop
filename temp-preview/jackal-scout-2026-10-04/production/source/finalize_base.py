"""Consolidate assembly to two skinned meshes. Run after build_jackal.py."""
from pathlib import Path
import bpy, json
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'jackal_scout_working.blend'))
scene=bpy.context.scene
col=bpy.data.collections['JACKAL_SCOUT | skinned game character']
rig=next(o for o in col.objects if o.type=='ARMATURE');rig.name='JackalScout_Rig'

def join_meshes(items,name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in items:o.select_set(True)
    bpy.context.view_layer.objects.active=items[0];bpy.ops.object.join();o=items[0];o.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);o.parent=rig
    for m in list(o.modifiers):
        if m.type!='ARMATURE':o.modifiers.remove(m)
    if not any(m.type=='ARMATURE' for m in o.modifiers):
        m=o.modifiers.new('Humanoid skin','ARMATURE');m.object=rig
    for m in o.modifiers:
        if m.type=='ARMATURE':m.object=rig
    return o
items=[o for o in col.objects if o.type=='MESH']
body_parts=[o for o in items if not o.name.startswith('MACHETE')]
weapon_parts=[o for o in items if o.name.startswith('MACHETE')]
body=join_meshes(body_parts,'JackalScout_Character')
weapon=join_meshes(weapon_parts,'JackalScout_Machete_R')
weapon['attachment']='All vertices rigidly weighted to Hand.R; same rig skin. Left hand is empty.'
body['species']='Anthropomorphic black-backed jackal'
body['surface']='Continuous remeshed anatomy, shaped face and ears, solid sculpted tufts, tailored mesh clothing'
rig['revision']='Frozen model base for animation; bones and rest matrices stable'
minz=min((body.matrix_world@v.co).z for v in body.data.vertices)
floor=bpy.data.objects.get('Studio ground')
if floor:floor.location.z=minz-.0007
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
scene.render.filepath=str(ROOT/'previews'/'final_base_threequarter.png')
scene.cycles.use_denoising=False;scene.render.threads_mode='FIXED';scene.render.threads=3;scene.frame_set(1)
readme=bpy.data.texts.get('START HERE | Jackal Scout')
if readme:
    readme.clear();readme.write('JACKAL SCOUT | frozen model base\n\nJackalScout_Rig: 56 humanoid, finger and tail bones.\nJackalScout_Character: one skinned mesh with clothes.\nJackalScout_Machete_R: one rigid Hand.R skin, left hand empty.\n\nFace -Y in Blender; anatomical RIGHT is -X.\nPacked PBR images; no particles or network service.\nStudio presentation collection is excluded from GLB.\n\nRebuild: make_textures.py, build_jackal.py, finalize_base.py.\nAnimation is a separate stage against this frozen skeleton.\n')
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'jackal_scout_base.blend'))
for o in [rig,body,weapon]:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'jackal_scout_base.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=True,export_yup=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_apply=False)
stats={'model_revision':'frozen native Blender prototype base','mesh_objects':2,'vertices':sum(len(o.data.vertices) for o in [body,weapon]),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in [body,weapon]),'bone_count':len(rig.data.bones),'deform_bone_count':sum(b.use_deform for b in rig.data.bones),'materials':len(set(m for o in [body,weapon] for m in o.data.materials)),'packed_texture_images':sum(im.source=='FILE' and bool(im.packed_file) for im in bpy.data.images),'collections':[col.name,'PRESENTATION | camera and lights'],'source_facing':'-Y','source_right_hand':'Hand.R, -X side','foot_sole_z_m':round(minz,6),'rig_object':rig.name,'character_mesh':body.name,'weapon_mesh':weapon.name,'bone_names':[b.name for b in rig.data.bones],'maximum_weights_per_vertex':max(len(v.groups) for o in [body,weapon] for v in o.data.vertices),'pre_animation_export':'jackal_scout_base.glb; animation stage produces final animated GLB'}
(ROOT/'model_counts.json').write_text(json.dumps(stats,indent=2));print('FROZEN BASE',json.dumps(stats),flush=True)
