import bpy,json
from pathlib import Path
p=Path('E:/ShopGame/source_assets/environments/dungeon/grand_forest_sanctuary/v002/reports/source_inventory.json')
r={'objects':[{'name':o.name,'dims':list(o.dimensions),'tri':sum(len(p.vertices)-2 for p in o.data.polygons)} for o in bpy.context.scene.objects if o.type=='MESH']}
p.write_text(json.dumps(r,indent=2),encoding='utf-8')
print(json.dumps(r))
