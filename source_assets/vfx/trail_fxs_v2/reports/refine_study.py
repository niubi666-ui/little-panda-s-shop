import bpy, json
from pathlib import Path
from mathutils import Vector
BASE=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(BASE/'blender/trail_study_amber_v001.blend'),load_ui=False,use_scripts=False)
scene=bpy.context.scene
scene.frame_set(100)
report={}
for o in scene.objects:
    if o.name.startswith('Weapon_') or o.name.startswith('REFERENCE'):
        report[o.name]={'location':list(o.location),'scale':list(o.scale),'dimensions':list(o.dimensions),
                        'local_z': [min(v.co.z for v in o.data.vertices),max(v.co.z for v in o.data.vertices)],
                        'world_bounds': [list(o.matrix_world@Vector(v)) for v in o.bound_box]}
print('GEOMETRY_REPORT',json.dumps(report))
(BASE/'reports/study_geometry.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
asset=next((BASE/'original').rglob('TrailFXs_Blades.blend'))
with bpy.data.libraries.load(str(asset),link=False) as (a,b):b.materials=['Trail_Blade_06','Trail_Blade_15','Trail_Blade_18']
trail=bpy.data.objects['FX_01_Flowing_Blade']
modifier=trail.modifiers[0]
for mat in b.materials:
    modifier.properties.inputs.Input_9.value=mat
    trail.update_tag()
    scene.render.resolution_percentage=75
    scene.render.filepath=str(BASE/'previews/study_v001'/f'variant_{mat.name}.png')
    bpy.ops.render.render(write_still=True)
print('VARIANTS_DONE')
