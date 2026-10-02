import bpy,json,sys
from pathlib import Path
from mathutils import Vector,Matrix
B=Path('E:/ShopGame/source_assets/characters/elf_archer/head_bake_v001')
bpy.ops.wm.open_mainfile(filepath=str(B/'blender/elf_head_bake_comparison_v001.blend'),load_ui=False,use_scripts=False)
sources=[bpy.data.objects[n] for n in ['elf character 3d model','elf character 3d model_Clone1','04_Head_Low_Baked']]
scene=bpy.data.scenes.new('Head_QA');bpy.context.window.scene=scene;scene.render.engine='CYCLES';scene.cycles.samples=32
try:
 p=bpy.context.preferences.addons['cycles'].preferences;p.compute_device_type='OPTIX';p.get_devices()
 for d in p.devices:d.use=d.type=='OPTIX'
 scene.cycles.device='GPU'
except Exception:scene.cycles.device='CPU'
scene.cycles.use_denoising=True
scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
world=bpy.data.worlds.new('Head_QA_World');scene.world=world;world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.065,.085,.105,1);bg.inputs['Strength'].default_value=.5
target=Vector((0,0,.50))
camd=bpy.data.cameras.new('Head_QA_Camera');cam=bpy.data.objects.new('Head_QA_Camera',camd);scene.collection.objects.link(cam);scene.camera=cam;camd.type='ORTHO';camd.ortho_scale=1.12
for name,pos,power,size in [('Key',(2,-1.5,2),110,1.5),('Fill',(1,2,1),45,2),('Rim',(-1,0,2),90,1.3)]:
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
for mode,angle in [('color',(3,0,.6)),('clay',(3,-1.5,.8))]:
 cam.location=angle;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
 for index,src in enumerate(sources):
  if '--quick' in sys.argv and index!=2:continue
  ob=src.copy();ob.data=src.data.copy();ob.matrix_world=Matrix.Identity(4);scene.collection.objects.link(ob)
  if mode=='clay':
   mat=src.data.materials[0].copy();ob.data.materials.clear();ob.data.materials.append(mat);bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
   for socket in ['Base Color','Roughness','Metallic']:
    for link in list(bs.inputs[socket].links):mat.node_tree.links.remove(link)
   bs.inputs['Base Color'].default_value=(.32,.32,.32,1);bs.inputs['Roughness'].default_value=.48;bs.inputs['Metallic'].default_value=0
  scene.render.filepath=str(B/'previews'/f'{mode}_{index}.png');print('RENDER',mode,index,flush=True);bpy.ops.render.render(write_still=True);bpy.data.objects.remove(ob,do_unlink=True)
cam.location=(-3,0,.75);cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
ob=sources[2].copy();scene.collection.objects.link(ob);ob.matrix_world=Matrix.Identity(4);scene.render.filepath=str(B/'previews/baked_back.png');bpy.ops.render.render(write_still=True)
print('QA_RENDERS_DONE',flush=True)
