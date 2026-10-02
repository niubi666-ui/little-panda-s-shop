import bpy,bmesh,json
from pathlib import Path
from mathutils import Vector
B=Path('E:/ShopGame/source_assets/characters/elf_archer/head_bake_v001')
bpy.ops.wm.open_mainfile(filepath=str(B/'blender/elf_head_bake_comparison_v001.blend'),load_ui=False,use_scripts=False)
o=bpy.data.objects['04_Head_Low_Baked'];bm=bmesh.new();bm.from_mesh(o.data)
seen=set();groups=[]
for e in bm.edges:
 if not e.is_boundary or e in seen:continue
 todo=[e];seen.add(e);g=[]
 while todo:
  p=todo.pop();g.append(p)
  for v in p.verts:
   for n in v.link_edges:
    if n.is_boundary and n not in seen:seen.add(n);todo.append(n)
 verts=set(v for e in g for v in e.verts);c=sum((v.co for v in verts),Vector())/len(verts)
 groups.append({'edges':len(g),'center':list(c),'closed':all(sum(e.is_boundary for e in v.link_edges)==2 for v in verts),'diameter':max((v.co-c).length for v in verts)*2})
print(json.dumps(sorted(groups,key=lambda g:-g['edges']),indent=1),flush=True)
(B/'reports/holes.json').write_text(json.dumps(groups,indent=2),encoding='utf-8')
