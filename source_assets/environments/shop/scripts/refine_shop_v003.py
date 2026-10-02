import bpy,math,json,random
from pathlib import Path
from mathutils import Vector
B=Path('E:/ShopGame/source_assets/environments/shop');s=bpy.context.scene
collections={c.name:c for c in s.collection.children};active='Details'
def link(o,group=None):
 for c in list(o.users_collection):c.objects.unlink(o)
 collections[group or active].objects.link(o);return o
code=(B/'scripts/build_shop_v001.py').read_text(encoding='utf-8-sig');exec(code[code.index('def box('):code.index('def prop(')])
dark=bpy.data.materials['Aged oak beams'];iron=bpy.data.materials['Forged dark iron']
for o in list(s.objects):
 if o.name.startswith('Left horizontal beam') and o.location.z<2:bpy.data.objects.remove(o,do_unlink=True)
for a,b in [(-4.5,-4.01),(-2.14,4.5)]:box('Door clearance lower beam',(-4.84,(a+b)/2,1.14),(.3,b-a,.22),dark,.025,'Architecture')
box('Right lamp support',(4.91,-.03,1.48),(.23,.25,2.96),dark,.025,'Architecture')
for z in [.3,2.7]:box('Right post iron collar',(4.91,-.03,z),(.27,.29,.10),iron,.015,'Architecture')
# Use GPU in this background process as preferences are not part of a blend file.
p=bpy.context.preferences.addons['cycles'].preferences;p.compute_device_type='OPTIX';p.refresh_devices()
for d in p.devices:d.use=d.type=='OPTIX'
s.cycles.device='GPU';s.cycles.samples=48
s.render.resolution_x=1600;s.render.resolution_y=1000
s.render.filepath=str(B/'previews/shop_interior_v003_check.png');s.name='Shop_Interior_Art_v003'
bpy.ops.wm.save_as_mainfile(filepath=str(B/'blender/shop_interior_v003.blend'))
print('READY_FOR_GPU_RENDER',flush=True)
bpy.ops.render.render(write_still=True)
