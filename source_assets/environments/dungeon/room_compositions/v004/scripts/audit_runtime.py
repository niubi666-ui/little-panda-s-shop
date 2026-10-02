import bpy,json
from pathlib import Path
out=[]
for s in bpy.data.scenes:
 col=next(c for c in s.collection.children if c.name.endswith('__complete_prefab'))
 out.append({'scene':s.name,'objects':[{'name':o.name,'type':o.type,'source':o.get('source_object'),'interactive':o.get('interaction_part',False),'location':list(o.location),'dims':list(o.dimensions),'uv':[(uv.name,uv.active_render) for uv in o.data.uv_layers] if o.type=='MESH' else [],'mats':[m.name for m in o.data.materials if m] if o.type=='MESH' else []} for o in col.objects if o.type in {'MESH','CURVE'}]})
Path('E:/ShopGame/builds/compositions_audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
