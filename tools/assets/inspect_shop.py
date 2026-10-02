import bpy, json
from pathlib import Path
from mathutils import Vector
s=bpy.context.scene
out=Path('E:/ShopGame/builds/inspection');out.mkdir(parents=True,exist_ok=True)
data={'version':bpy.app.version_string,'scene':s.name,'objects':[],'materials':[]}
for o in s.objects:
    bb=[o.matrix_world@Vector(v) for v in o.bound_box] if o.type in {'MESH','CURVE'} else []
    data['objects'].append({'name':o.name,'type':o.type,'collections':[c.name for c in o.users_collection],'location':list(o.location),'dimensions':list(o.dimensions),'matrix':[list(r) for r in o.matrix_world],'bounds':[[min(v[i] for v in bb) for i in range(3)],[max(v[i] for v in bb) for i in range(3)]] if bb else [],'materials':[m.name for m in o.data.materials if m] if o.type in {'MESH','CURVE'} else [],'hidden':o.hide_render})
for m in bpy.data.materials:
    if not m.use_nodes:continue
    nodes=[]
    for n in m.node_tree.nodes:
        vals={}
        for x in n.inputs:
            if hasattr(x,'default_value'):
                v=x.default_value
                try: v=list(v)
                except TypeError: pass
                if isinstance(v,(str,int,float,list,bool)):vals[x.name]=v
        nodes.append({'type':n.type,'values':vals,'image':n.image.name if n.type=='TEX_IMAGE' and n.image else None})
    data['materials'].append({'name':m.name,'nodes':nodes})
(out/'shop.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print('INSPECT',len(s.objects),len(data['materials']))
