import bpy,bmesh,json
from pathlib import Path
BASE=Path('E:/ShopGame/source_assets/characters/red_panda')
cs=json.loads((BASE/'reports/v007_lower_regions.json').read_text())
exclude={1129,1131,1138,1142,3188,1690}
pantsfaces={i for c in cs if (c['min'][2]<.20 or c['seed'] in {3922,3923}) and c['seed'] not in exclude for i in c['faces']}
report=[]
for src in list(bpy.data.scenes):
 if not src.name.startswith('ConnectedPose_'):continue
 label=src.name.removeprefix('ConnectedPose_');s=bpy.data.scenes.get('KneePose_'+label) or bpy.data.scenes.new('KneePose_'+label);bpy.context.window.scene=s
 
 for stale in list(s.objects):bpy.data.objects.remove(stale,do_unlink=True)
 oldrig=next(o for o in src.objects if o.type=='ARMATURE');oldob=next(o for o in src.objects if o.type=='MESH')
 rig=oldrig.copy();rig.data=oldrig.data.copy();rig.name='KneeRig_'+label;s.collection.objects.link(rig)
 ob=oldob.copy();ob.data=oldob.data.copy();ob.name='KneeMesh_'+label;s.collection.objects.link(ob)
 for m in ob.modifiers:
  if m.type=='ARMATURE':m.object=rig
 bm=bmesh.new();bm.from_mesh(ob.data);bm.faces.ensure_lookup_table();flag=bm.faces.layers.int.new('pants_v007')
 for f in bm.faces:f[flag]=int(f.index in pantsfaces)
 seams=[e for e in bm.edges if any(f[flag] for f in e.link_faces) and any(not f[flag] for f in e.link_faces)]
 bmesh.ops.split_edges(bm,edges=seams)
 edges=[e for e in bm.edges if e.link_faces and all(f[flag] for f in e.link_faces)]
 bmesh.ops.subdivide_edges(bm,edges=edges,cuts=2,use_grid_fill=True)
 bm.verts.index_update();bm.faces.index_update();ids={v.index for f in bm.faces if f[flag] for v in f.verts}
 bm.to_mesh(ob.data);bm.free();ob.data.update()
 for i in ids:
  v=ob.data.vertices[i];side='L' if v.co.y>-.007 else 'R';knee=rig.data.bones[side+'_Calf'].head_local.z
  t=max(0.,min(1.,(v.co.z-(knee-.035))/.085));t=t*t*(3-2*t)
  for g in list(v.groups):ob.vertex_groups[g.group].remove([i])
  for n,w in [(side+'_CalfTwist01',1-t),(side+'_ThighTwist01',t)]:
   if w>1e-7:ob.vertex_groups[n].add([i],w,'REPLACE')
 s.render.resolution_x=1000;s.render.resolution_y=1000;s.render.resolution_percentage=100
 report.append({'scene':s.name,'pants_vertices':len(ids),'split_edges':len(seams),'vertices':len(ob.data.vertices)})
(BASE/'reports/knee_v007_changes.json').write_text(json.dumps(report,indent=2));print(report)

