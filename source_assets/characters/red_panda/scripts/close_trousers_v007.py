import bpy,bmesh
from mathutils import Vector
for s in [s for s in bpy.data.scenes if s.name.startswith('KneePose_')]:
 bpy.context.window.scene=s;ob=next(o for o in s.objects if o.type=='MESH');bm=bmesh.new();bm.from_mesh(ob.data)
 flag=bm.faces.layers.int.get('pants_v007');uv=bm.loops.layers.uv.active;deform=bm.verts.layers.deform.verify();seen=set();rings=[]
 for e in list(bm.edges):
  if e in seen or not e.is_boundary or not e.link_faces[0][flag]:continue
  es=set();vs=set();todo=[e]
  while todo:
   q=todo.pop()
   if q in seen:continue
   seen.add(q);es.add(q);vs.update(q.verts);todo.extend(a for v in q.verts for a in v.link_edges if a.is_boundary and a not in seen and a.link_faces[0][flag])
  if min(v.co.z for v in vs)<.22:continue
  start=next(iter(vs));ring=[start];prev=None;cur=start
  while True:
   nxt=next(v for edge in cur.link_edges if edge in es for v in edge.verts if v!=cur and v!=prev)
   if nxt==start:break
   ring.append(nxt);prev,cur=cur,nxt
  rings.append(ring)
 for ring in rings:
  center=sum((v.co for v in ring),Vector())/len(ring);side='L' if center.y>0 else 'R';group=ob.vertex_groups[side+'_ThighTwist01'].index
  tex=[]
  for v in ring:
   loops=[l for l in v.link_loops if l.face[flag]];tex.append(sum((l[uv].uv for l in loops),Vector((0,0)))/len(loops))
  def face(verts,coords):
   f=bm.faces.new(verts);f[flag]=1;f.smooth=True
   for l,t in zip(f.loops,coords):l[uv].uv=t
  old=ring
  for scale,height in [(.85,.025),(.55,.055),(.15,.070)]:
   new=[]
   for v in ring:
    co=center+(v.co-center)*scale;co.z=center.z+height;nv=bm.verts.new(co);nv[deform][group]=1.;new.append(nv)
   for i in range(len(ring)):
    j=(i+1)%len(ring);face([old[i],old[j],new[j],new[i]],[tex[i],tex[j],tex[j],tex[i]])
   old=new
  face(old,tex)
 bmesh.ops.recalc_face_normals(bm,faces=[f for f in bm.faces if f[flag]])
 bm.to_mesh(ob.data);bm.free();ob.data.update()
print('Closed each upper trouser leg with a rounded, thigh-weighted extension')
