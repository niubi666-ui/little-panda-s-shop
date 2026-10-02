import bpy, json
from mathutils import Vector
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(BASE/'blender/trail_study_amber_v001.blend'),load_ui=False,use_scripts=False)
scene=bpy.context.scene
trail=bpy.data.objects['FX_01_Flowing_Blade'];ref=bpy.data.objects['REFERENCE_Sword_Edge']
modifier=trail.modifiers[0]
print('NODE_OBJECT',[(n.name,n.type,[(s.name,str(s.default_value)) for s in n.inputs if hasattr(s,'default_value') and not s.is_linked]) for n in modifier.node_group.nodes if n.type in ['OBJECT_INFO','INPUT_NAMED_ATTRIBUTE','STORE_NAMED_ATTRIBUTE']])
for f in [20,95,100]:
 scene.frame_set(f)
 dg=bpy.context.evaluated_depsgraph_get();e=trail.evaluated_get(dg)
 points=[e.matrix_world@v.co for v in e.data.vertices]
 tip=ref.matrix_world@Vector((0,0,2.20656))
 print('ALIGN',f,'OBJ_MATRIX',list(trail.location),'TIP',list(tip),'NEAREST',min((p-tip).length for p in points))
 print('ATTRS',[(a.name,a.data_type,a.domain) for a in e.data.attributes])
 if f != 100:
  scene.render.resolution_percentage=75
  scene.render.filepath=str(BASE/'previews/study_v001'/f'pose_{f}.png')
  bpy.ops.render.render(write_still=True)
