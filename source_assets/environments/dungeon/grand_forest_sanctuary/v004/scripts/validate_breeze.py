import bpy,json,hashlib,numpy as np
from pathlib import Path
assert bpy.app.background
R=Path(__file__).resolve().parents[1];cfg=json.loads((R/'scripts/breeze_profile.json').read_text())
def mesh_sig(me):
 h=hashlib.sha256()
 for seq,prop,n,dtype in [(me.vertices,'co',3,np.float32),(me.loops,'vertex_index',1,np.int32),(me.polygons,'loop_total',1,np.int32),(me.polygons,'material_index',1,np.int32)]:
  a=np.empty(len(seq)*n,dtype=dtype);seq.foreach_get(prop,a);h.update(a.tobytes())
 for uv in me.uv_layers:
  a=np.empty(len(uv.data)*2,np.float32);uv.data.foreach_get('uv',a);h.update(a.tobytes())
 h.update(str([m.name if m else None for m in me.materials]).encode())
 return h.hexdigest()
bpy.ops.wm.open_mainfile(filepath=cfg['source']);s=bpy.context.scene
source_hash=hashlib.sha256(Path(cfg['source']).read_bytes()).hexdigest()
unique_meshes={o.data.name:o.data for o in s.objects if o.type=='MESH'}
meshes={name:mesh_sig(me) for name,me in unique_meshes.items()}
del unique_meshes
print('BREEZE_BASELINE_HASHED',len(meshes),flush=True)
objects={o.name:tuple(f for row in o.matrix_world for f in row) for o in s.objects}
materials=set(m.name for m in bpy.data.materials)
lights={o.name:(o.data.type,o.data.energy,list(o.data.color)) for o in s.objects if o.type=='LIGHT'}
bpy.ops.wm.open_mainfile(filepath=str(R/'blender/grand_forest_sanctuary_v004_breeze.blend'));s=bpy.context.scene
issues=[]
for name,sig in meshes.items():
 if name not in bpy.data.meshes or mesh_sig(bpy.data.meshes[name])!=sig:issues.append('Original geometry/UV/material changed: '+name)
for name,matrix in objects.items():
 ob=s.objects.get(name)
 if ob is None or any(abs(x-y)>1e-6 for x,y in zip(matrix,(f for row in ob.matrix_world for f in row))):issues.append('Original placement changed: '+name)
for name,params in lights.items():
 o=s.objects[name]
 if (o.data.type,o.data.energy,list(o.data.color))!=params:issues.append('Original light changed: '+name)
assert materials.issubset(set(m.name for m in bpy.data.materials))
nodes=bpy.data.node_groups['BREEZE_weighted_bend_v004'];assert s.objects['BREEZE_controls']['strength']==1
assert not s.objects['LIGHTING_ONLY_overhead_leaf_shadows'].visible_camera
root_weights={}
for name in ['FY_white_flower_shared','FY_purple_flower_shared','Bellflower_stems_mesh']:
 me=bpy.data.meshes[name];w=me.attributes['breeze_weight'];root=[w.data[i].value for i,v in enumerate(me.vertices) if v.co.z<1e-6]
 assert root and max(root)==0, (name,root[:4]);root_weights[name]=len(root)
# Confirm actual evaluated crown geometry changes with the timeline, without
# changing its topology or the shared source data.
o=next(o for o in s.objects if '__BakedCrownCluster_' in o.name)
def evaluated(frame):
 s.frame_set(frame);dg=bpy.context.evaluated_depsgraph_get();me=o.evaluated_get(dg).data
 return np.array([v.co[:] for v in me.vertices]),sum(len(p.vertices)-2 for p in me.polygons)
a,ta=evaluated(1);b,tb=evaluated(49)
delta=float(np.linalg.norm(a-b,axis=1).max());assert delta>.005 and ta==tb==176
report={'passed':not issues,'issues':issues,'source_sha256_unchanged':hashlib.sha256(Path(cfg['source']).read_bytes()).hexdigest()==source_hash,'original_unique_meshes_geometry_uv_materials_checked':len(meshes),'original_objects_placements_checked':len(objects),'lights_checked':len(lights),'root_vertices_with_zero_weight':root_weights,'crown_test':{'object':o.name,'frames':[1,49],'max_local_displacement_m':delta,'triangles_each_frame':ta},'scope':'Source geometry/UV/material slots, transforms, light settings and root anchors verified; actual Cycles preview is separate. No whole-game FPS claim.'}
(R/'reports/breeze_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print('BREEZE_VALIDATED',json.dumps(report),flush=True)
assert report['passed'] and report['source_sha256_unchanged']
