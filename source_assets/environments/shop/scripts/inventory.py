import bpy,math,json
from mathutils import Vector
from pathlib import Path
B=Path('E:/ShopGame/source_assets/environments/shop')
s=bpy.context.scene
obs=[o for o in s.objects if o.type=='MESH']
inventory=[]
for i,o in enumerate(obs):
 inventory.append({'index':i,'name':o.name,'verts':len(o.data.vertices),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons)})
 o.location=((i%6)*2.2,(2-i//6)*2.8,0);o.rotation_euler=(0,0,-math.pi/2)
 o.scale=(1.6,1.6,1.6)
 cu=bpy.data.curves.new('label','FONT');cu.body=str(i)+'  '+o.name[:8];cu.size=.20
 tx=bpy.data.objects.new('Label',cu);s.collection.objects.link(tx);tx.location=(o.location.x-.7,o.location.y-.9,.02)
 tx.rotation_euler=(math.radians(50),0,0)
for o in list(s.objects):
 if o.type=='LIGHT':bpy.data.objects.remove(o,do_unlink=True)
cam=s.camera;cam.location=(5,-12,16);cam.rotation_euler=(Vector((5,2.8,.3))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=15
for loc,power,size in [((0,-4,10),2200,8),((8,5,10),1700,7)]:
 d=bpy.data.lights.new('soft','AREA');d.energy=power;d.shape='DISK';d.size=size;o=bpy.data.objects.new('soft',d);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((5,3,0))-o.location).to_track_quat('-Z','Y').to_euler()
s.world.color=(.3,.3,.3)
s.render.engine='CYCLES';s.cycles.samples=16;s.cycles.use_denoising=True
s.render.resolution_x=1600;s.render.resolution_y=1050;s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.render.filepath=str(B/'previews/asset_inventory.png')
(B/'reports/item1_inventory.json').write_text(json.dumps(inventory,indent=2))
bpy.ops.render.render(write_still=True)
