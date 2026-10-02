"""Read-only validation of saved Blender source and reusable collection boundaries."""
import bpy, json, hashlib, math
from pathlib import Path
BASE=Path('E:/ShopGame/source_assets/environments/dungeon/room_compositions/v004')
report=json.loads((BASE/'reports/build_report.json').read_text(encoding='utf-8'))
assert hashlib.sha256(Path(report['source']).read_bytes()).hexdigest()==report['source_sha256']
assert len(bpy.data.scenes)==4
result={'scenes':[],'unpacked_images':[],'source_unchanged':True}
for s in bpy.data.scenes:
 assert s.camera is not None
 groups=[c for c in s.collection.children if c.name.endswith('__complete_prefab')]
 assert len(groups)==1
 col=groups[0];assert col.asset_data is not None
 roots=[o for o in col.objects if o.get('prefab_id')]
 assert len(roots)==1
 root=roots[0];triangles=0
 for ob in col.objects:
  assert all(math.isfinite(v) for row in ob.matrix_world for v in row)
  if ob!=root:
   ancestor=ob
   while ancestor.parent:ancestor=ancestor.parent
   assert ancestor==root,ob.name
  if ob.type=='MESH':
   assert len(ob.data.vertices)>0 and len(ob.data.polygons)>0
   triangles+=sum(len(p.vertices)-2 for p in ob.data.polygons)
   assert len(ob.data.materials)>0,ob.name
 result['scenes'].append({'scene':s.name,'collection':col.name,'objects':len(col.objects),'base_triangles':triangles,'root':root.name})
for image in bpy.data.images:
 if image.source=='FILE' and image.users>0:
  assert len(image.pixels)>0,image.name
  if not image.packed_file:result['unpacked_images'].append(image.name)
assert not result['unpacked_images'],result
(BASE/'reports/validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print('BLENDER_COMPOSITIONS_VALID',json.dumps(result,ensure_ascii=False))
