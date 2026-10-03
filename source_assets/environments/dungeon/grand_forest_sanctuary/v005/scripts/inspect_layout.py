import bpy,json
from pathlib import Path
from mathutils import Vector
assert bpy.app.background
R=Path(__file__).resolve().parents[1]
scene=bpy.context.scene
records=[]
for o in scene.objects:
 if not (o.name.startswith(('Hero_Sacred','Boundary_','West_','East_gateway','North_','Robed','Shrine_','Gateway_','Bronze_votive','Votive_warm','Camera_','WIND_SOURCE')) or o.name=='BREEZE_controls'):continue
 if 'BakedCrown' in o.name:continue
 box=[o.matrix_world@Vector(c) for c in o.bound_box] if o.type=='MESH' else []
 records.append({'name':o.name,'type':o.type,'loc':list(o.matrix_world.translation),'rotation':list(o.rotation_euler),'scale':list(o.scale),'dimensions':list(o.dimensions),'mesh':o.data.name if o.type=='MESH' else None,'bbox':[[min(c[k] for c in box),max(c[k] for c in box)] for k in range(3)] if box else None,'role':o.get('asset_role'),'parent':o.parent.name if o.parent else None,'hidden':o.hide_render})
(R/'reports/layout_source.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print(json.dumps([r for r in records if r['name'].startswith(('Hero','East_gateway_tall','North_Guardian','Robed','Shrine_approach','Camera_Panorama'))],indent=2),flush=True)
