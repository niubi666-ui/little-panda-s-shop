import bpy,bmesh,json,numpy as np
from pathlib import Path
from mathutils.bvhtree import BVHTree
B=Path('E:/ShopGame/source_assets/characters/elf_archer/head_bake_v001')
bpy.ops.wm.open_mainfile(filepath=str(B/'blender/elf_head_bake_comparison_v001.blend'),load_ui=False,use_scripts=False)
h=bpy.data.objects['elf character 3d model'];l=bpy.data.objects['04_Head_Low_Baked']
t=BVHTree.FromPolygons([v.co for v in h.data.vertices],[p.vertices[:] for p in h.data.polygons],all_triangles=True)
for label in ['before','recalculated']:
 if label=='recalculated':
  bm=bmesh.new();bm.from_mesh(l.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(l.data);bm.free();l.data.update()
 dots=[]
 for f in l.data.polygons:
  loc,n,idx,d=t.find_nearest(f.center);dots.append(f.normal.dot(n))
 print(label,'negative',sum(d<0 for d in dots),'quantiles',np.quantile(dots,[0,.01,.05,.5,.95,1]),'customnormals',l.data.has_custom_normals,flush=True)
bm=bmesh.new();bm.from_mesh(l.data);print('boundaries',sum(e.is_boundary for e in bm.edges),'nonmanifold',sum(not e.is_manifold for e in bm.edges));bm.free()
