"""Create a non-destructive copy, then bind it using Auto-Rig Pro's native bind operator."""
import bpy
import json
import io
import contextlib
from pathlib import Path
from mathutils import Matrix

BASE=Path('E:/ShopGame/source_assets/characters/red_panda')
assert 'bl_ext.user_default.auto_rig_pro_master' in bpy.context.preferences.addons
assert 'RedPanda_ARP_v003' not in bpy.data.scenes
if bpy.context.screen.is_animation_playing:
    bpy.ops.screen.animation_play()
scene=bpy.data.scenes.new('RedPanda_ARP_v003')
bpy.context.window.scene=scene
source_rig=bpy.data.objects['RedPanda_Rig_v002']
source_mesh=bpy.data.objects['RedPanda_Mesh_v002']
rig=source_rig.copy();rig.data=source_rig.data.copy();rig.name='RedPanda_ARP_Rig_v003'
scene.collection.objects.link(rig)
rig.animation_data_clear()
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
mesh=source_mesh.copy();mesh.data=source_mesh.data.copy();mesh.name='RedPanda_ARP_Mesh_v003'
scene.collection.objects.link(mesh)
mesh.parent=rig
mesh.animation_data_clear()
mesh.vertex_groups.clear()
for modifier in list(mesh.modifiers):
    if modifier.type=='ARMATURE':mesh.modifiers.remove(modifier)
# Only bones used for deformation in the imported binding participate in the solve.
deform_names={g.name for g in source_mesh.vertex_groups}
for bone in rig.data.bones:bone.use_deform=bone.name in deform_names
rig.data.pose_position='REST'
for obj in scene.objects:obj.select_set(False)
mesh.select_set(True);rig.select_set(True)
bpy.context.view_layer.objects.active=rig
scene.arp_bind_engine='HEAT_MAP'
scene.arp_bind_split=True
scene.arp_bind_chin=False # This is a custom animation skeleton, not ARP's head_ref template.
scene.arp_bind_improve_twists=False
scene.arp_bind_improve_hips=False
scene.arp_bind_improve_heels=False
scene.arp_bind_scale_fix=False
scene.arp_bind_preserve=False # Linear skinning matches the planned game deformation model.
scene.arp_bind_sel_verts=False
scene.arp_bind_selected_bones=False
scene.arp_debug_bind=False
capture=io.StringIO()
with contextlib.redirect_stdout(capture):
    result=bpy.ops.arp.bind_to_rig()
log=capture.getvalue()
(BASE/'reports/arp_v003_bind_log.txt').write_text(log,encoding='utf-8')
print(log[-7000:])
print(json.dumps({'result':list(result),'groups':len(mesh.vertex_groups),
                  'modifiers':[(m.type,getattr(m,'object',None).name if getattr(m,'object',None) else None) for m in mesh.modifiers],
                  'weighted_vertices':sum(bool(v.groups) for v in mesh.data.vertices)}))
