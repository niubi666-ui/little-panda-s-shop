import bpy,bmesh,math,json
from pathlib import Path
from mathutils import Matrix,Quaternion,Vector
BASE=Path('E:/ShopGame/source_assets/characters/red_panda')
reports=[]
for src in list(bpy.data.scenes):
 if not src.name.startswith('RunPose_'):continue
 label=src.name.removeprefix('RunPose_');s=bpy.data.scenes.new('RepairPose_'+label);bpy.context.window.scene=s
 oldrig=next(o for o in src.objects if o.type=='ARMATURE');oldmesh=next(o for o in src.objects if o.type=='MESH')
 rig=oldrig.copy();rig.data=oldrig.data.copy();rig.name='RepairRig_'+label;s.collection.objects.link(rig)
 ob=oldmesh.copy();ob.data=oldmesh.data.copy();ob.name='RepairMesh_'+label;s.collection.objects.link(ob)
 for m in ob.modifiers:
  if m.type=='ARMATURE':m.object=rig
 for side in ('L','R'):
  rig.pose.bones[side+'_Hand'].matrix_basis=Matrix.Identity(4)
  rig.pose.bones[side+'_ToeBase'].matrix_basis=Matrix.Identity(4)
 bpy.context.view_layer.update()
 # Fully specify the shoe orientation; no residual twist from shortest-arc aiming.
 for side in ('L','R'):
  pb=rig.pose.bones[side+'_Foot'];loc=pb.matrix.translation.copy();mat=rig.data.bones[side+'_Foot'].matrix_local.copy();mat.translation=loc;pb.matrix=mat
 bpy.context.view_layer.update()
 edited=0
 for v in ob.data.vertices:
  x,y,z=v.co;weights=None
  if z<.12:weights={('L' if y>0 else 'R')+'_Foot':1.}
  elif abs(y)>.405 and .48<z<.65:weights={('L' if y>0 else 'R')+'_Hand':1.}
  if weights:
   for g in list(v.groups):ob.vertex_groups[g.group].remove([v.index])
   for n,w in weights.items():ob.vertex_groups[n].add([v.index],w,'REPLACE')
   edited+=1
 # Dark inner material for deliberately added hidden closures.
 mat=bpy.data.materials.get('RP_InnerLining_v005') or bpy.data.materials.new('RP_InnerLining_v005');mat.use_nodes=True
 node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');node.inputs['Base Color'].default_value=(.085,.048,.023,1);node.inputs['Roughness'].default_value=.9
 ob.data.materials.append(mat);idx=len(ob.data.materials)-1
 bm=bmesh.new();bm.from_mesh(ob.data);seen=set();caps=0
 for e in list(bm.edges):
  if not e.is_boundary or e in seen:continue
  todo=[e];es=set();vs=set()
  while todo:
   q=todo.pop()
   if q in seen:continue
   seen.add(q);es.add(q);vs.update(q.verts);todo.extend(a for v in q.verts for a in v.link_edges if a.is_boundary and a not in seen)
  zmin=min(v.co.z for v in vs);zmax=max(v.co.z for v in vs)
  simple=all(sum(a in es for a in v.link_edges)==2 for v in vs)
  targeted=(.10<zmin and zmax<.15) or (.51<zmin and zmax<.64 and len(es)>=16) or (.37<zmin and zmax<.43 and len(es)>=20)
  if simple and targeted:
   new=bmesh.ops.holes_fill(bm,edges=list(es),sides=0)['faces']
   for f in new:f.material_index=idx
   caps+=len(new)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free();ob.data.update()
 # Closed inner waist volume bridges the separate belt and clothing shells.
 bm=bmesh.new();bmesh.ops.create_uvsphere(bm,u_segments=24,v_segments=12,radius=1)
 for v in bm.verts:v.co=Vector((.135+v.co.x*.118,.0+v.co.y*.122,.401+v.co.z*.083))
 me=bpy.data.meshes.new('InnerWaistMesh_'+label);bm.to_mesh(me);bm.free()
 inner=bpy.data.objects.new('InnerWaist_'+label,me);s.collection.objects.link(inner);me.materials.append(mat)
 for f in me.polygons:f.use_smooth=True
 vg=inner.vertex_groups.new(name='Waist');vg.add(list(range(len(me.vertices))),1.,'REPLACE');mod=inner.modifiers.new('FollowWaist','ARMATURE');mod.object=rig
 s.render.resolution_x=900;s.render.resolution_y=900;s.render.resolution_percentage=100
 reports.append({'scene':s.name,'rigid_paw_boot_vertices':edited,'closure_faces':caps,'new_animation':False})
(BASE/'reports/repair_v005.json').write_text(json.dumps(reports,indent=2),encoding='utf-8');print(reports)
