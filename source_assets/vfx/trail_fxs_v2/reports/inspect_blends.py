import bpy,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
reports=[]
for path in sorted((root/'original').rglob('*.blend')):
    bpy.ops.wm.open_mainfile(filepath=str(path),load_ui=False,use_scripts=False)
    reports.append({'file':path.relative_to(root).as_posix(),'objects':len(bpy.data.objects),'materials':len(bpy.data.materials),'node_groups':len(bpy.data.node_groups),'asset_objects':[o.name for o in bpy.data.objects if o.asset_data],'asset_materials':[m.name for m in bpy.data.materials if m.asset_data],'asset_node_groups':[n.name for n in bpy.data.node_groups if n.asset_data],'frames':[bpy.context.scene.frame_start,bpy.context.scene.frame_end]})
(root/'reports/blend_inventory.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
print('BLEND_INVENTORY',json.dumps(reports,ensure_ascii=False))
