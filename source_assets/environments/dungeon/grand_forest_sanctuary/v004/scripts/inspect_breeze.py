import bpy,json
from pathlib import Path
assert bpy.app.background
r=Path(__file__).resolve().parents[1]
examples=[]
seen=set()
for o in bpy.context.scene.objects:
 if o.type!='MESH':continue
 if not (o.name.startswith(('Fern_clump_','White_meadow_flower_spray_','Hero_Sacred_Oak')) or o.get('asset_role') in ['white_flower','purple_flower']):continue
 if o.data.name in seen:continue
 seen.add(o.data.name)
 examples.append({'object':o.name,'mesh':o.data.name,'location':list(o.location),'scale':list(o.scale),'bbox':[[min(v.co[k] for v in o.data.vertices),max(v.co[k] for v in o.data.vertices)] for k in range(3)],'attrs':[(a.name,a.data_type,a.domain) for a in o.data.attributes],'materials':[{'name':m.name,'images':[(n.image.name,n.image.size[:],n.image.filepath) for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image],'nodes':[n.type for n in m.node_tree.nodes]} for m in o.data.materials if m]})
(r/'reports/breeze_source_inspection.json').write_text(json.dumps(examples,indent=2),encoding='utf-8')
print('BREEZE_SOURCES',[(x['object'],x['mesh'],x['bbox']) for x in examples],flush=True)
