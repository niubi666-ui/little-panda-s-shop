import bpy,json
from pathlib import Path
from mathutils import Vector
BASE=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(BASE/'blender/sword_trail_study.blend'),load_ui=False,use_scripts=False)
s=bpy.context.scene;ref=bpy.data.objects['REFERENCE_Sword_Edge'];trail=bpy.data.objects['FX_01_Flowing_Blade']
report={'blender_version':bpy.app.version_string,'checks':[]}
for f in [15,20,85,95,99,105,135]:
 s.frame_set(f);dg=bpy.context.evaluated_depsgraph_get();e=trail.evaluated_get(dg)
 tip=ref.matrix_world@Vector((0,0,2))
 distance=min(((e.matrix_world@v.co)-tip).length for v in e.data.vertices)
 report['checks'].append({'frame':f,'vertices':len(e.data.vertices),'distance_to_tip':distance})
 if f in [15,20,105,135]:
  s.render.resolution_percentage=50
  s.render.filepath=str(BASE/'previews/final'/f'check_{f}.png');bpy.ops.render.render(write_still=True)
(BASE/'reports/final_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report))
