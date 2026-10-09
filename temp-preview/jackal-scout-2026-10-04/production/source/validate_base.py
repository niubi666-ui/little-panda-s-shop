"""Read-only round-trip validation of the frozen base's GLB skin/material structure."""
import bpy, json, struct, math
from pathlib import Path
from mathutils import Quaternion, Vector
ROOT=Path(__file__).resolve().parent
raw=(ROOT/'jackal_scout_base.glb').read_bytes(); length,kind=struct.unpack_from('<II',raw,12)
gltf=json.loads(raw[20:20+length].decode('utf8'))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'jackal_scout_base.glb'))
rigs=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
# Blender's importer creates an Icosphere bone-display helper; it is not a glTF mesh.
ms=[o for o in bpy.context.scene.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers)]
assert len(rigs)==1,('armatures',len(rigs));rig=rigs[0]
expected=json.loads((ROOT/'model_counts.json').read_text())
assert len(rig.data.bones)==56
assert set(b.name for b in rig.data.bones)==set(expected['bone_names'])
assert len(ms)==2,('meshes',len(ms))
weapon=next(o for o in ms if 'Machete' in o.name);body=next(o for o in ms if o!=weapon)
for o in ms:
    assert any(m.type=='ARMATURE' and m.object==rig for m in o.modifiers),(o.name,'skin missing')
    for v in o.data.vertices:
        s=sum(g.weight for g in v.groups);assert abs(s-1)<.001,(o.name,v.index,s)
wg={weapon.vertex_groups[g.group].name for v in weapon.data.vertices for g in v.groups if g.weight>.0001}
assert wg=={'Hand.R'},wg
assert not gltf.get('animations'), 'Base is explicitly pre-animation'
assert all('JOINTS_0' in p['attributes'] and 'WEIGHTS_0' in p['attributes'] and 'TEXCOORD_0' in p['attributes'] for m in gltf['meshes'] for p in m['primitives'])
assert not any('camera' in n for n in gltf['nodes'])
assert all('bufferView' in im for im in gltf['images']), 'Texture must be embedded'
def snapshot(o):
    deps=bpy.context.evaluated_depsgraph_get();e=o.evaluated_get(deps);me=e.to_mesh()
    a=[o.matrix_world@v.co for v in me.vertices];e.to_mesh_clear();return a
before_body=snapshot(body);before_wp=snapshot(weapon)
rig.pose.bones['UpperLeg.L'].rotation_mode='QUATERNION';rig.pose.bones['UpperLeg.L'].rotation_quaternion=Quaternion((1,0,0),.33)
rig.pose.bones['Hand.R'].rotation_mode='QUATERNION';rig.pose.bones['Hand.R'].rotation_quaternion=Quaternion((0,0,1),.50)
bpy.context.view_layer.update()
after_body=snapshot(body);after_wp=snapshot(weapon)
bdelta=max((a-b).length for a,b in zip(before_body,after_body));wdelta=max((a-b).length for a,b in zip(before_wp,after_wp))
assert bdelta>.10,(bdelta,'actual limb deformation absent');assert wdelta>.05,(wdelta,'weapon motion absent')
report={'status':'passed','imported_armatures':len(rigs),'imported_meshes':len(ms),'imported_bones':len(rig.data.bones),'skin_joint_counts':[len(s['joints']) for s in gltf['skins']],'materials':len(gltf['materials']),'embedded_images':len(gltf['images']),'exported_primitives':sum(len(m['primitives']) for m in gltf['meshes']),'triangles':sum(gltf['accessors'][p['indices']]['count']//3 for m in gltf['meshes'] for p in m['primitives']),'weapon_weighted_bones':sorted(wg),'weight_normalization':'all vertices sum to one within 0.001','body_deformation_max_m':round(bdelta,6),'weapon_deformation_max_m':round(wdelta,6),'animation_clips':[],'note':'Pre-animation base only. Final animated GLB is validated by the root/animation stages.'}
(ROOT/'base_roundtrip_validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2),flush=True)
