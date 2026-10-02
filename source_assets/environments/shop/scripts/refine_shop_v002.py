import bpy,math,random,json
from pathlib import Path
from mathutils import Vector
B=Path('E:/ShopGame/source_assets/environments/shop');s=bpy.context.scene;R=random.Random(25)
# Reuse authoring helper functions without rebuilding the scene.
code=(B/'scripts/build_shop_v001.py').read_text(encoding='utf-8-sig')
helpers=code[code.index('def box('):code.index('def prop(')]
collections={n:bpy.data.collections[n] for n in ['Architecture','Floor','Furniture','Merchandise','Plants','Details','Lighting','Cameras','Presentation_Only']};active='Details'
def link(o,group=None):
 for c in list(o.users_collection):c.objects.unlink(o)
 collections[group or active].objects.link(o);return o
exec(helpers)
wood=bpy.data.materials['Oak | grain'];dark=bpy.data.materials['Aged oak beams'];iron=bpy.data.materials['Forged dark iron'];brass=bpy.data.materials['Antique brass']
# Cabinets turn toward the viewing aisle; no backs hiding merchandise.
o=bpy.data.objects['Curiosity cabinet'];o.location=(4.03,3.72,.045);o.rotation_euler.z=math.radians(-90)
o=bpy.data.objects['Sword display'];o.location.x=2.82;o.scale.y*=.82
o=bpy.data.objects['Right provisions cabinet'];o.location=(4.05,-1.4,.045);o.rotation_euler.z=math.radians(-100);o.scale.y*=.78;o.scale.z*=.85
# Move its greenery with the cabinet.
o=bpy.data.objects['Cabinet ivy crown'];o.location=(4.04,3.70,2.79);o.rotation_euler.z=-math.pi/2
# Keep the door opening clear of the continuous wainscot trim.
for o in list(s.objects):
 if o.name.startswith('Left oak rail'):bpy.data.objects.remove(o,do_unlink=True)
for z in [.22,.94]:
 for a,b in [(-4.5,-4.01),(-2.14,4.5)]:box('Left segmented oak rail',(-4.89,(a+b)/2,z),(.17,b-a,.14),dark,group='Architecture')
# Wainscot panels below the shelves add timber texture to the large pale walls.
for x in [-4.8+i*.27 for i in range(36)]:box('Back wainscot board',(x,4.38,.60),(.258,.07,.75),wood,.012,'Architecture')
for y in [-1.94+i*.27 for i in range(24)]:box('Left wainscot board',(-4.91,y,.60),(.07,.258,.75),wood,.012,'Architecture')
# Lower, subtler light cores sit inside the lantern mesh rather than protruding.
lamps=sorted([o for o in s.objects if o.name.startswith('Wall lantern')],key=lambda o:o.name)
cores=sorted([o for o in s.objects if o.name.startswith('Lantern luminous core')],key=lambda o:o.name)
lights=sorted([o for o in s.objects if o.name.startswith('Lantern warm pool')],key=lambda o:o.name)
for lamp,core,lamp_light in zip(lamps,cores,lights):
 direction=Vector((math.cos(lamp.rotation_euler.z),math.sin(lamp.rotation_euler.z),0))
 core.location=lamp.location+direction*.035+Vector((0,0,.22));core.scale=(.5,.5,.6)
 lamp_light.location=core.location+direction*.15;lamp_light.data.energy=65
# Counter and island existing lamps get actual warm illumination.
for name,loc,power in [('Till lantern glow',(-1.92,2.41,1.80),30),('Display lantern glow',(-1.17,-.43,1.52),20)]:
 d=bpy.data.lights.new(name,'POINT');d.energy=power;d.color=(1,.43,.10);d.shadow_soft_size=.085;o=bpy.data.objects.new(name,d);collections['Lighting'].objects.link(o);o.location=loc
# A lower sun angle throws lattice shadows across the room.
o=bpy.data.objects['Late afternoon sun'];o.location=(-10,3,7);o.rotation_euler=(Vector((0,-1,1.5))-o.location).to_track_quat('-Z','Y').to_euler();o.data.energy=3.4;o.data.angle=.045
for o,yc in zip(sorted([o for o in s.objects if o.name.startswith('Afternoon window key')],key=lambda o:o.name),[-.5,2.4]):
 o.location=(-5.55,yc+.35,2.8);o.rotation_euler=(Vector((0,yc-2,.05))-o.location).to_track_quat('-Z','Y').to_euler();o.data.energy=650;o.data.size=.50
bpy.data.objects['Soft interior sky bounce'].data.energy=140
bpy.data.objects['Counter warm bounce'].data.energy=160
for m in bpy.data.materials:
 if m.name.startswith('Stone floor variation'):
  p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Roughness'].default_value=R.uniform(.21,.35)
  ramp=next(n for n in m.node_tree.nodes if n.type=='VALTORGB')
  for e in ramp.color_ramp.elements:e.color=tuple(v*.79 for v in e.color[:3])+(1,)
# Small nail heads on exposed framing.
for x in [-5,-2.65,-.6,1.9,4.95]:
 for z in [.25,3.3]:
  o=cylinder('Forged beam nail',(x,4.158,z),.028,.018,iron,8);o.rotation_euler.x=math.pi/2
# Slight chipped seams on a few walking-area tiles. Fine geometry, not gameplay obstacles.
for j in range(14):
 x=R.uniform(-3.9,3.7);y=R.uniform(-3.8,3.7)
 if -2.3<x<2.6 and -2.7<y<1:continue
 pts=[(x,y,.047),(x+.04,y+.08,.047),(x+.11,y+.12,.047),(x+.14,y+.19,.047)]
 curve('Hairline stone fissure',pts,.0035,iron,'Floor')
# More stock at the right edge, keeping independent objects and shared meshes.
src=bpy.data.objects['Stock barrel'];o=src.copy();o.data=src.data;collections['Merchandise'].objects.link(o);o.name='Right stock barrel';o.location=(4.23,.95,.05);o.scale*=.8
src=bpy.data.objects['Goods crate'];o=src.copy();o.data=src.data;collections['Merchandise'].objects.link(o);o.name='Right stock crate';o.location=(3.83,.18,.05);o.rotation_euler.z=-1.7
# Shift camera framing up and back to include capstones.
s.camera.data.ortho_scale=18.05;s.camera.rotation_euler=(Vector((0,.15,1.25))-s.camera.location).to_track_quat('-Z','Y').to_euler()
s.render.resolution_x=1920;s.render.resolution_y=1200;s.cycles.samples=96
s.render.filepath=str(B/'previews/shop_interior_v002.png')
s.name='Shop_Interior_Art_v002'
bpy.ops.wm.save_as_mainfile(filepath=str(B/'blender/shop_interior_v002.blend'))
print('REFINEMENT_SAVED',flush=True)
bpy.ops.render.render(write_still=True)
