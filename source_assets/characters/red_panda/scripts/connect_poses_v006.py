import bpy,bmesh,json
from pathlib import Path
BASE=Path('E:/ShopGame/source_assets/characters/red_panda')
original=bpy.data.objects['PoseMesh_01_Contact'];adj=[[] for v in original.data.vertices]
for e in original.data.edges:
 a,b=e.vertices;adj[a].append(b);adj[b].append(a)
def part(seed):
 seen=set();todo=[seed]
 while todo:
  i=todo.pop()
  if i in seen:continue
  seen.add(i);todo.extend(adj[i])
 return seen
pants=part(1);upper=part(32);boots=part(279)|part(2754)
for old in list(bpy.data.scenes):
 if not old.name.startswith('RepairPose_'):continue
 label=old.name.removeprefix('RepairPose_');s=bpy.data.scenes.new('ConnectedPose_'+label);bpy.context.window.scene=s
 rr=next(o for o in old.objects if o.type=='ARMATURE');rig=rr.copy();rig.data=rr.data.copy();rig.name='ConnectedRig_'+label;s.collection.objects.link(rig)
 src=bpy.data.objects['PoseMesh_'+label];ob=src.copy();ob.data=src.data.copy();ob.name='ConnectedMesh_'+label;s.collection.objects.link(ob)
 prior=next(o for o in old.objects if o.name.startswith('RepairMesh_'))
 for mod in ob.modifiers:
  if mod.type=='ARMATURE':mod.object=rig
 def assign(v,w):
  for g in list(v.groups):ob.vertex_groups[g.group].remove([v.index])
  for n,x in w.items():
   if x>1e-8:ob.vertex_groups[n].add([v.index],x,'REPLACE')
 def smooth(x):
  x=max(0.,min(1.,x));return x*x*(3-2*x)
 for v in ob.data.vertices:
  weights={prior.vertex_groups[g.group].name:g.weight for g in prior.data.vertices[v.index].groups}
  side='L' if v.co.y>0 else 'R';z=v.co.z
  if v.index in boots:
   t=smooth((z-.045)/.05);weights={side+'_Foot':1-t,side+'_CalfTwist01':t}
  elif v.index in pants:
   if z<.19:weights={side+'_CalfTwist01':1.}
   elif z<.28:
    t=smooth((z-.19)/.09);weights={side+'_CalfTwist01':1-t,side+'_ThighTwist01':t}
   elif z<.34:
    t=smooth((z-.28)/.06);weights={side+'_ThighTwist01':1-t,'Waist':t}
   else:weights={'Waist':1.}
  elif v.index in upper and z<.49:
   t=smooth((z-.435)/.055);weights={'Waist':1-t,'Spine01':t}
  assign(v,weights)
 # Only close the detached head/neck seam; no flat caps on waist or boots.
 bm=bmesh.new();bm.from_mesh(ob.data);seen=set()
 for e in list(bm.edges):
  if not e.is_boundary or e in seen:continue
  es=set();vs=set();todo=[e]
  while todo:
   q=todo.pop()
   if q in seen:continue
   seen.add(q);es.add(q);vs.update(q.verts);todo.extend(a for v in q.verts for a in v.link_edges if a.is_boundary and a not in seen)
  if len(es)==27 and min(v.co.z for v in vs)>.61 and max(v.co.z for v in vs)<.64:bmesh.ops.holes_fill(bm,edges=list(es),sides=0)
 bm.to_mesh(ob.data);bm.free();ob.data.update()
 s.render.resolution_x=1000;s.render.resolution_y=1000;s.render.resolution_percentage=100
print('Four v006 scenes built, continuous waist/calf weights; no exposed filler objects.')
