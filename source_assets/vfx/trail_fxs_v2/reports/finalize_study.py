"""Finalize an editable study and render using the user's Trail FXs v2 library."""
import bpy,json,sys
from pathlib import Path
from mathutils import Vector
BASE=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(BASE/'blender/trail_study_amber_v002.blend'),load_ui=False,use_scripts=False)
s=bpy.context.scene
s.name='Sword_Trail_Study'
s.camera.location=(0,-5,11)
s.camera.rotation_euler=(Vector((0,0,1))-s.camera.location).to_track_quat('-Z','Y').to_euler()
s.camera.data.ortho_scale=6.4
s.render.resolution_x=1280;s.render.resolution_y=720;s.render.resolution_percentage=100
s.eevee.taa_render_samples=64
floor=bpy.data.materials['Stage_Charcoal_Slate']
bsdf=next(n for n in floor.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
for l in list(floor.node_tree.links):
 if l.to_socket==bsdf.inputs['Base Color']:floor.node_tree.links.remove(l)
bsdf.inputs['Base Color'].default_value=(.004,.006,.01,1)
bsdf.inputs['Roughness'].default_value=.85;bsdf.inputs['Metallic'].default_value=0
for l in bpy.data.lights:l.energy*=.3
trail=bpy.data.objects['FX_01_Flowing_Blade'];m=trail.modifiers[0]
m.properties.inputs.Input_8.value=8.0
m.properties.inputs.Input_6.value=(1,.48,.055,1)
m.properties.inputs.Input_7.value=(1,.055,.006,1)
trail.update_tag()
asset=next((BASE/'original').rglob('TrailFXs_Blades.blend'))
with bpy.data.libraries.load(str(asset),link=False) as (a,b):b.materials=['Trail_Blade_14']
materials=[m.properties.inputs.Input_9.value,b.materials[0]]
labels=['01_Golden_Filaments','02_Ember_Brush']
for mat,label in zip(materials,labels):
 mat.name=label
 # Preserve the asset's animated procedural texture; add a soft tapered tail.
 nodes=mat.node_tree.nodes;links=mat.node_tree.links
 mix=next(n for n in nodes if n.type=='MIX_SHADER')
 old=next(l.from_socket for l in links if l.to_socket==mix.inputs[0])
 uv=nodes.new('ShaderNodeAttribute');uv.attribute_name='BladeUVs';uv.label='Chronological trail coordinates'
 split=nodes.new('ShaderNodeSeparateXYZ');links.new(uv.outputs['Vector'],split.inputs[0])
 def mathnode(op,a,b=None):
  n=nodes.new('ShaderNodeMath');n.operation=op
  if hasattr(a,'node'):links.new(a,n.inputs[0])
  else:n.inputs[0].default_value=a
  if b is not None:
   if hasattr(b,'node'):links.new(b,n.inputs[1])
   else:n.inputs[1].default_value=b
  return n.outputs[0]
 fade=mathnode('MULTIPLY',split.outputs['X'],2.5)
 fade.node.use_clamp=True
 width=mathnode('ADD',mathnode('MULTIPLY',split.outputs['X'],.9),.1)
 ratio=mathnode('DIVIDE',split.outputs['Y'],width)
 taper=mathnode('SUBTRACT',1,ratio);taper.node.use_clamp=True
 taper=mathnode('POWER',taper,.6)
 alpha=mathnode('MULTIPLY',old,mathnode('MULTIPLY',fade,taper))
 links.new(alpha,mix.inputs[0])
 mat.use_backface_culling=False
for o in bpy.data.objects:
 if o.name.startswith('Weapon_'):
  # The imported conversion reflects Z; correct winding for the metallic sword.
  import bmesh
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(o.data);bm.free()
preview=BASE/'previews/final';preview.mkdir(exist_ok=True,parents=True)
s.frame_set(99)
for mat,label in zip(materials,labels):
 m.properties.inputs.Input_9.value=mat;trail.update_tag()
 s.render.filepath=str(preview/(label+'.png'))
 bpy.ops.render.render(write_still=True)
m.properties.inputs.Input_9.value=materials[0];trail.update_tag()
s['description']='User supplied Trail FXs v2 geometry nodes/materials; new swing, aligned longsword, tapered material fade and studio presentation. Blender art study, not Godot runtime.'
readme=bpy.data.texts.get('READ_ME');readme.clear();readme.write('刀光与火星 Blender 样片\n素材：用户提供的 Trail FXs v2。未安装额外插件。\n1–150 帧，30 fps。10–21 正常挥砍；78–108 放慢的细节挥砍。\n主刀光材质 01_Golden_Filaments；备选 02_Ember_Brush，修改器 Material 中切换。\n仿真已打包；改变动作、参考线或粒子数量后需删除并重新烘焙。\nREAD_ME 文件夹报告记录制作流程。本样片尚未接入 Godot，也尚未匹配小熊猫角色。\n')
for screen in bpy.data.screens:
 for a in screen.areas:
  if a.type=='VIEW_3D':
   a.spaces.active.region_3d.view_perspective='CAMERA'
   a.spaces.active.shading.type='MATERIAL'
   a.spaces.active.overlay.show_overlays=False
bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'blender/sword_trail_study.blend'))
if '--video' in sys.argv:
 s.render.image_settings.media_type='VIDEO'
 s.render.image_settings.file_format='FFMPEG'
 s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.constant_rate_factor='HIGH'
 for mat,label in zip(materials,labels):
  m.properties.inputs.Input_9.value=mat;trail.update_tag()
  s.render.filepath=str(preview/(label+'.mp4'))
  bpy.ops.render.render(animation=True)
print('FINAL_READY',flush=True)
