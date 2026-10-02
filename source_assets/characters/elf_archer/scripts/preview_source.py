import bpy, math
from mathutils import Vector
from pathlib import Path
bpy.ops.wm.open_mainfile(filepath='E:/ShopGame/source_assets/characters/red_panda/blender/jingling.blend',load_ui=False,use_scripts=False)
scene=bpy.context.scene
try: scene.render.engine='BLENDER_EEVEE'
except TypeError: pass
scene.render.resolution_x=1300;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.world.color=(.15,.15,.15)
scene.world.use_nodes=True
next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND').inputs[0].default_value=(.16,.19,.23,1)
next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND').inputs[1].default_value=.5
for o in list(bpy.data.objects):
    if o.type=='LIGHT':bpy.data.objects.remove(o,do_unlink=True)
target=Vector((0,.72,.5))
for name,pos,power,size in [('Key',(3,-3,4),450,4),('Fill',(-3,1,3),400,3),('Rim',(0,4,4),500,3)]:
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
camera=scene.camera or next(o for o in bpy.data.objects if o.type=='CAMERA');scene.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=2.3
out=Path('E:/ShopGame/source_assets/characters/elf_archer/previews');out.mkdir(parents=True,exist_ok=True)
for name,position in [('source_x_plus',(4,.1,1.5)),('source_x_minus',(-4,.1,1.5))]:
    camera.location=position;camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
