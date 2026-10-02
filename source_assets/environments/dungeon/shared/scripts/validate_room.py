"""Read-only validation of a saved Blender room. Does not save or alter it."""
import bpy,json,math
from pathlib import Path
s=bpy.context.scene;base=Path(bpy.data.filepath).parent.parent
failures=[]
if not s.camera:failures.append('missing camera')
if abs(s.unit_settings.scale_length-1)>1e-6:failures.append('unexpected metre scale')
missing_images=[]
for image in bpy.data.images:
    if image.source=='FILE' and not image.packed_file and not Path(bpy.path.abspath(image.filepath)).is_file():missing_images.append(image.name)
if missing_images:failures.append('unresolved images')
invalid_geometry=[]
for obj in s.objects:
    if obj.type=='MESH':
        if any(not all(math.isfinite(c) for c in v.co) for v in obj.data.vertices):invalid_geometry.append(obj.name)
if invalid_geometry:failures.append('nonfinite geometry')
dg=bpy.context.evaluated_depsgraph_get();triangles=0
for obj in s.objects:
    if obj.type in ['MESH','CURVE']:
        ev=obj.evaluated_get(dg);mesh=ev.to_mesh();triangles+=sum(max(0,len(p.vertices)-2) for p in mesh.polygons);ev.to_mesh_clear()
anchors=[o.name for o in s.objects if o.name.startswith('REPLACE_ANCHOR_')]
if not anchors:failures.append('missing replacement anchor')
report={'scene':s.name,'file':bpy.data.filepath,'file_reopened_successfully':True,'failures':failures,'invalid_geometry':invalid_geometry,'missing_images':missing_images,'packed_images':[im.name for im in bpy.data.images if im.packed_file],'linked_libraries':[lib.filepath for lib in bpy.data.libraries],'object_count':len(s.objects),'evaluated_triangles':triangles,'replacement_anchors':anchors,'runtime_godot_validated':False,'blender_version':bpy.app.version_string,'color_transform':s.view_settings.view_transform,'color_look':s.view_settings.look,'exposure':s.view_settings.exposure}
(base/'reports'/'validation_v001.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('VALIDATION_COMPLETE',json.dumps(report,ensure_ascii=False),flush=True)
if failures:raise RuntimeError(failures)
