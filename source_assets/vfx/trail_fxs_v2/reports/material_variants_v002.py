import bpy
from pathlib import Path
from mathutils import Vector
BASE=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(BASE/'blender/trail_study_amber_v002.blend'),load_ui=False,use_scripts=False)
s=bpy.context.scene;s.frame_set(99)
s.camera.location=(0,-5,11);s.camera.rotation_euler=(Vector((0,0,1))-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=6
floor=bpy.data.materials['Stage_Charcoal_Slate']
bsdf=next(n for n in floor.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
for l in list(floor.node_tree.links):
 if l.to_socket==bsdf.inputs['Base Color']:floor.node_tree.links.remove(l)
bsdf.inputs['Base Color'].default_value=(.007,.01,.017,1);bsdf.inputs['Roughness'].default_value=.8;bsdf.inputs['Metallic'].default_value=0
for l in bpy.data.lights:l.energy*=.45
asset=next((BASE/'original').rglob('TrailFXs_Blades.blend'))
with bpy.data.libraries.load(str(asset),link=False) as (a,b):b.materials=['Trail_Blade_14','Trail_Blade_15','Trail_Blade_01']
trail=bpy.data.objects['FX_01_Flowing_Blade'];m=trail.modifiers[0]
for mat in b.materials:
 print('MAT',mat.name,'mode',mat.surface_render_method)
 print('NODES',[(n.name,n.type) for n in mat.node_tree.nodes if n.type in ['BSDF_PRINCIPLED','MIX_SHADER','EMISSION','BSDF_TRANSPARENT']])
 m.properties.inputs.Input_9.value=mat;trail.update_tag()
 s.render.resolution_percentage=75
 s.render.filepath=str(BASE/'previews/study_v002'/f'variant_{mat.name}.png')
 bpy.ops.render.render(write_still=True)
