"""Editable shop art scene. Run with Blender 5.2 and item1.blend loaded.
Geometry/light values are art authoring parameters; no gameplay definitions.
"""
import bpy, math, random, json, sys
from pathlib import Path
from mathutils import Vector
B=Path('E:/ShopGame/source_assets/environments/shop')
R=random.Random(240925)
s=bpy.context.scene
sources=[o for o in s.objects if o.type=='MESH']
assert len(sources)==18
for o in list(s.objects):s.collection.objects.unlink(o) if o.name in s.collection.objects else None
for col in list(s.collection.children):s.collection.children.unlink(col)
s.name='Shop_Interior_Art_v001'
collections={}
for n in ['Architecture','Floor','Furniture','Merchandise','Plants','Details','Lighting','Cameras','Presentation_Only']:
 c=bpy.data.collections.new(n);s.collection.children.link(c);collections[n]=c
active='Architecture'
def link(o,group=None):
 for c in list(o.users_collection):c.objects.unlink(o)
 collections[group or active].objects.link(o);return o

def mat(name,color,rough=.5,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True
 p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 return m

def texturemat(name,c1,c2,scale,rough=.6,bump=.1,stretch=None):
 m=mat(name,c1,rough);n=m.node_tree.nodes;l=m.node_tree.links;p=next(n for n in n if n.type=='BSDF_PRINCIPLED')
 tc=n.new('ShaderNodeTexCoord');noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=scale;noise.inputs['Detail'].default_value=3
 if stretch:
  vec=n.new('ShaderNodeVectorMath');vec.operation='MULTIPLY';vec.inputs[1].default_value=stretch;l.new(tc.outputs['Generated'],vec.inputs[0]);l.new(vec.outputs[0],noise.inputs['Vector'])
 else:l.new(tc.outputs['Generated'],noise.inputs['Vector'])
 ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.2;ramp.color_ramp.elements[0].color=(*c1,1);ramp.color_ramp.elements[1].position=.8;ramp.color_ramp.elements[1].color=(*c2,1)
 l.new(noise.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
 b=n.new('ShaderNodeBump');b.inputs['Strength'].default_value=bump;b.inputs['Distance'].default_value=.055;l.new(noise.outputs['Fac'],b.inputs['Height']);l.new(b.outputs[0],p.inputs['Normal'])
 return m
wood=texturemat('Oak | grain',(.055,.023,.009),(.22,.105,.038),4,.43,.22,(2,24,3))
wooddark=texturemat('Aged oak beams',(.025,.012,.008),(.095,.042,.015),5,.58,.24,(2,20,3))
plaster=texturemat('Warm lime plaster',(.25,.20,.14),(.57,.46,.30),8,.88,.18)
stone=texturemat('Limestone cut edge',(.17,.17,.145),(.36,.33,.27),10,.7,.2)
iron=mat('Forged dark iron',(.035,.028,.021),.36,.72)
brass=mat('Antique brass',(.43,.22,.055),.28,.75)
cloth=texturemat('Forest green woven banner',(.017,.055,.039),(.045,.12,.081),65,.92,.11)
redcloth=mat('Burgundy fabric',(.23,.033,.026),.88)
gold=mat('Embroidered ochre thread',(.55,.31,.072),.67,.12)
leafm=[mat('Ivy leaf '+str(i),c,.7) for i,c in enumerate([(.045,.11,.022),(.085,.18,.035),(.15,.22,.047),(.20,.27,.06)])]

def box(name,loc,dim,material,bevel=.025,group=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=dim;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if material:o.data.materials.append(material)
 if bevel:
  mod=o.modifiers.new('Soft worn edges','BEVEL');mod.width=bevel;mod.segments=2
 return link(o,group)
def cylinder(name,loc,radius,depth,material,vertices=12):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc);o=bpy.context.object;o.name=name;o.data.materials.append(material);return link(o)
def curve(name,pts,radius,material,group='Details'):
 d=bpy.data.curves.new(name,'CURVE');d.dimensions='3D';d.resolution_u=1;d.bevel_depth=radius;d.bevel_resolution=1
 sp=d.splines.new('POLY');sp.points.add(len(pts)-1)
 for v,p in zip(sp.points,pts):v.co=(*p,1)
 o=bpy.data.objects.new(name,d);collections[group].objects.link(o);d.materials.append(material);return o

def prop(i,name,loc,width=None,height=None,depth=None,angle=-90,group='Furniture'):
 src=sources[i];o=src.copy();o.data=src.data;collections[group].objects.link(o);o.name=name
 ds=src.dimensions.copy();o.rotation_euler=(0,0,math.radians(angle));factor=width/ds.y if width else height/ds.z
 o.scale=(factor,factor,factor)
 if height:o.scale.z=height/ds.z
 if depth:o.scale.x=depth/ds.x
 o.location=loc;o['source_file']='item1.blend';o['source_object']=src.name;o['asset_role']=group
 return o

# Counter is the only very dense source. Simplify a private copy once and share it.
counter=sources[3];counter.data=counter.data.copy();collections['Presentation_Only'].objects.link(counter)
bpy.context.view_layer.objects.active=counter;counter.select_set(True)
d=counter.modifiers.new('Counter source reduction','DECIMATE');d.decimate_type='COLLAPSE';d.ratio=.05
bpy.ops.object.modifier_apply(modifier=d.name)
collections['Presentation_Only'].objects.unlink(counter)

# Materials on generated assets retain packed base colors, with modest surface roughness.
for src in sources:
 for m in src.data.materials:
  if m and m.use_nodes:
   p=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
   if p:p.inputs['Roughness'].default_value=.48

# Floor: real gaps, restrained reflection and per-slab color variation.
active='Floor'
box('Foundation',(0,0,-.25),(10.6,9.6,.5),wooddark,.05)
box('Mortar bed',(0,0,-.018),(10.1,9.1,.10),mat('Grout',(.08,.067,.047),.95),0)
floormats=[]
for i in range(9):
 v=R.uniform(.8,1.15);floormats.append(texturemat('Stone floor variation %02d'%i,(.13*v,.135*v,.14*v),(.28*v,.26*v,.225*v),7,.31+R.random()*.13,.16))
for ix in range(15):
 for iy in range(14):
  o=box('Floor slab %02d_%02d'%(ix,iy),(-4.667+ix*.667,-4.179+iy*.643,-.002+R.uniform(-.004,.004)),(.65,.627,.09),R.choice(floormats),.018)
  o.rotation_euler.z=R.uniform(-.006,.006)

active='Architecture'
# Back wall y=4.5. Left wall has two real window openings and a door bay.
box('Back plaster wall',(0,4.60,1.86),(10.4,.32,3.72),plaster,.02)
# Windows centered y=-.5 and 2.4, width 1.75, sill z=1.38, head=3.2.
openings=[(-.5,1.75),(2.4,1.75)]
segments=[(-4.5,-1.375),(.375,1.525),(3.275,4.5)]
for j,(a,b) in enumerate(segments):box('Left plaster pier '+str(j),(-5.10,(a+b)/2,1.86),(.32,b-a,3.72),plaster)
for j,(yc,w) in enumerate(openings):
 box('Window lower wall '+str(j),(-5.1,yc,.69),(.32,w,1.38),plaster)
 box('Window lintel wall '+str(j),(-5.1,yc,3.5),(.32,w,.6),plaster)
# Low cutaway front and right walls leave the interior visible.
box('Front cutaway wall',(0,-4.61,.32),(10.5,.32,.64),stone)
box('Right cutaway wall',(5.1,0,.32),(.32,9.4,.64),stone)
# Lower wainscot bands, square posts and capstones.
for z in [.22,.94]:
 box('Back oak rail',(0,4.39,z),(10.1,.17,.14),wooddark)
 box('Left oak rail',(-4.89,0,z),(.17,9,.14),wooddark)
for x in [-5,-2.65,-.6,1.9,4.95]:
 box('Back timber upright',(x,4.36,1.85),(.24,.26,3.7),wooddark)
 for z in [.25,3.3]:box('Post iron strap',(x,4.20,z),(.29,.055,.16),iron,.01)
for y in [-4.4,-1.48,.49,1.42,3.38,4.42]:box('Left timber upright',(-4.87,y,1.85),(.26,.24,3.7),wooddark)
for z in [1.14,3.48]:
 box('Back horizontal beam',(0,4.28,z),(10.5,.3,.22),wooddark)
 box('Left horizontal beam',(-4.84,0,z),(.3,9.3,.22),wooddark)
for x in [-4.7+i*.67 for i in range(15)]:
 box('Back upper coping',(x,4.55,3.81),(.645,.65,.25),stone,.035)
 box('Front coping',(x,-4.6,.70),(.645,.50,.15),stone,.025)
for y in [-4.22+i*.65 for i in range(14)]:
 box('Left upper coping',(-5.05,y,3.81),(.65,.63,.25),stone,.035)
 box('Right coping',(5.1,y,.70),(.5,.63,.15),stone,.025)
# Slim decorative rafter ends around the cutaway roof perimeter.
for x in [-4.8,-2.8,-.7,1.5,3.6,4.9]:box('Back roof joist',(x,4.39,3.94),(.18,1.02,.18),wooddark)

# Window woodwork with diamonds: clear openings transmit the actual directional light.
for j,(yc,w) in enumerate(openings):
 for y in [yc-w/2,yc+w/2]:box('Window jamb',(-4.87,y,2.28),(.28,.12,1.94),wood)
 for z in [1.38,3.20]:box('Window cross frame',(-4.86,yc,z),(.3,w+.24,.15),wood)
 box('Deep window sill',(-4.68,yc,1.34),(.65,w+.38,.14),stone)
 box('Window middle bar',(-4.86,yc,2.28),(.12,.065,1.78),wooddark,.01)
 # Clip diagonal lattice lines into the opening rectangle.
 for slope in [-1,1]:
  for off in [i*.40 for i in range(-5,6)]:
   pts=[]
   for u in [-w/2,w/2]:
    zz=slope*u+off
    if -.84<=zz<=.84:pts.append((-4.88,yc+u,2.28+zz))
   for zz in [-.84,.84]:
    u=(zz-off)/slope
    if -w/2<=u<=w/2:pts.append((-4.88,yc+u,2.28+zz))
   if len(pts)>=2:curve('Diamond window lattice',pts[:2],.018,wooddark,'Architecture')
 for k,dy in enumerate([-.48,.46]):prop(17 if k else 15,'Window herb pot',(-4.51,yc+dy,1.43),height=.49,angle=0,group='Plants')

# Furniture composition mirrors the supplied concept.
prop(4,'Entrance door',(-4.86,-3.08,.045),width=1.75,height=2.65,depth=.27,angle=0)
prop(2,'Apothecary cabinet',(-3.47,4.0,.045),height=3.22,width=2.08,depth=.63)
prop(3,'Main sales counter',(.45,2.72,.045),width=5.65,height=1.48,depth=1.20)
prop(7,'Order notice board',(1.5,4.22,1.80),width=2.15,height=1.64,depth=.20)
prop(8,'Sword display',(3.68,4.10,1.15),width=1.5,height=2.03,depth=.35)
prop(2,'Curiosity cabinet',(4.55,2.47,.045),width=1.63,height=2.76,depth=.60,angle=180)
prop(2,'Right provisions cabinet',(4.57,-1.77,.045),width=1.95,height=2.57,depth=.64,angle=180)
prop(2,'Window low cabinet',(-4.50,.06,.045),width=1.70,height=1.28,depth=.65,angle=0)
prop(1,'Central merchandise island',(-.10,-.44,.085),width=2.82,height=1.44,depth=1.62)
prop(11,'Main woven rug',(.15,-.85,.052),width=4.78,height=.027,depth=3.52)
prop(11,'Entrance mat',(-3.92,-3.16,.05),width=1.9,height=.02,depth=1.28,angle=0)
prop(11,'Cabinet runner',(4.04,-2.02,.05),width=2.8,height=.02,depth=1.15,angle=180)
prop(0,'Front herb bench',(-1.92,-3.63,.05),width=2.75,height=1.08,depth=.90)
prop(13,'Stock barrel',(-2.96,3.48,.05),height=1.03,group='Merchandise')
prop(13,'Scroll barrel',(.24,-3.76,.05),height=.76,group='Merchandise')
prop(12,'Right treasure chest',(4.03,-3.46,.05),width=.91,height=.67,angle=180,group='Merchandise')
prop(14,'Goods crate',(-3.92,1.58,.05),height=.68,angle=20,group='Merchandise')
prop(14,'Delivery crate',(-3.12,-3.60,.05),height=.64,angle=-82,group='Merchandise')
prop(17,'Entrance greenery',(-4.16,-4.08,.06),height=.81,group='Plants')
prop(15,'Counter side herbs',(3.58,2.61,.055),height=.83,group='Plants')
prop(16,'Hanging plant top',(-3.8,4.1,3.27),height=.59,group='Plants')
prop(16,'Cabinet ivy crown',(4.55,2.64,2.79),height=.60,angle=180,group='Plants')
prop(10,'Potion banner',(-4.84,.93,2.0),width=.62,height=.99,depth=.12,angle=0,group='Details')

# Large botanical banner behind the till; ornament contains no baked language.
active='Details'
box('Botanical banner backing',(-.89,4.16,2.48),(1.06,.045,1.75),cloth,.01)
for x in [-1.385,-.395]:box('Banner gold vertical',(x,4.13,2.48),(.018,.008,1.67),gold,.003)
for z in [1.655,3.3]:box('Banner gold hem',(-.89,4.13,z),(1.00,.008,.023),gold,.003)
curve('Embroidered botanical stem',[(-.89,4.10,1.92),(-.84,4.10,2.32),(-.95,4.10,2.86)],.013,gold)
for k in range(5):
 z=2.02+k*.16
 for sign in [-1,1]:
  x=-.88+sign*.20
  curve('Botanical branch',[(-.88,4.10,z),(x,4.10,z+.16)],.010,gold)
  verts=[(x,4.09,z+.11),(x+sign*.10,4.09,z+.21),(x+sign*.09,4.09,z+.32),(x-sign*.025,4.09,z+.25)]
  me=bpy.data.meshes.new('leaf embroidery');me.from_pydata(verts,[],[(0,1,2,3)]);o=bpy.data.objects.new('Gold embroidered leaf',me);collections['Details'].objects.link(o);me.materials.append(gold)
rod=cylinder('Banner pole',(-.89,4.15,3.42),.032,1.3,brass);rod.rotation_euler.y=math.pi/2

# Extra shelf below notice board, with books and small jars.
box('Order shelf',(1.52,4.0,1.63),(2.25,.50,.12),wood)
for i in range(7):
 o=box('Ledger spine',(R.uniform(.6,1.15),3.92,1.74+i*.038),(.34,.25,.032),redcloth if i%2 else cloth,.008)
 o.rotation_euler.z=R.uniform(-.1,.1)

# Vines: individual modeled leaves hanging from beams, shared small meshes.
for anchor in [(-4.68,3.70,3.48),(-2.38,4.10,3.48),(.08,4.11,3.48),(2.66,4.1,3.46),(4.69,3.63,3.36)]:
 for strand in range(3):
  ax,ay,az=anchor;ax+=R.uniform(-.22,.22);ay+=R.uniform(-.12,.12);length=R.uniform(.65,1.35)
  pts=[(ax+math.sin(t*5+strand)*.08,ay-.035*t,az-length*t) for t in [i/12 for i in range(13)]]
  curve('Trailing ivy stem',pts,.009,leafm[0],'Plants')
  for k in range(11):
   p=Vector(pts[k+1]);side=(-1)**k;size=R.uniform(.055,.105);p.x+=side*.07
   verts=[p+Vector((0,0,-size)),p+Vector((side*size,.015,0)),p+Vector((side*.4*size,-.025,size*.7)),p+Vector((-side*.55*size,0,size*.25))]
   me=bpy.data.meshes.new('ivy leaf');me.from_pydata(verts,[],[(0,1,2),(0,2,3)]);ob=bpy.data.objects.new('Ivy leaf',me);collections['Plants'].objects.link(ob);me.materials.append(R.choice(leafm))

# Wall lamps and real light emitters.
active='Lighting'
def light(name,kind,loc,color,power,size=1,target=None):
 d=bpy.data.lights.new(name,kind);d.energy=power;d.color=color
 if kind=='AREA':d.shape='DISK';d.size=size
 elif kind=='POINT':d.shadow_soft_size=size
 o=bpy.data.objects.new(name,d);collections['Lighting'].objects.link(o);o.location=loc
 if target:o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
 return o
emit=mat('Lantern amber glow',(1,.37,.04),.3)
p=next(n for n in emit.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Emission Color'].default_value=(1,.37,.055,1);p.inputs['Emission Strength'].default_value=5
for x,y,z,angle in [(-4.67,-4.08,2.05,0),(-4.67,.93,2.05,0),(-2.25,4.02,2.38,-90),(.04,4.02,2.42,-90),(2.72,4.02,2.38,-90),(4.56,-.03,2.08,180)]:
 o=prop(9,'Wall lantern',(x,y,z),height=.76,angle=angle,group='Details')
 direction=Vector((math.cos(math.radians(angle)),math.sin(math.radians(angle)),0));pos=Vector((x,y,z+.24))+direction*.19
 box('Lantern luminous core',pos,(.12,.12,.23),emit,.015,'Lighting')
 light('Lantern warm pool','POINT',pos+direction*.15,(1,.48,.14),48,.12)
# Window light enters from the left and rakes across stone toward the camera.
for yc,w in openings:
 light('Afternoon window key','AREA',(-5.55,yc+1.0,3.55),(1,.76,.46),1050,1.0,(-1.4,yc-1.4,.1))
light('Soft interior sky bounce','AREA',(0,-.3,3.56),(.59,.70,1),260,7,(0,0,0))
light('Counter warm bounce','AREA',(.5,2.7,3.3),(1,.62,.30),95,3,(.5,2.4,0))
sun=light('Late afternoon sun','SUN',(-8,1,8),(1,.78,.52),2.4,target=(0,-3,0));sun.data.angle=.07
# Ceiling invisible to the presentation camera, but blocks overhead sun like a real roof.
roof=box('Roof light blocker',(0,0,4.06),(10.5,9.5,.16),wooddark,0,'Presentation_Only');roof.visible_camera=False
# Scene-local fine haze, kept separate from future runtime geometry.
vol=bpy.data.materials.new('Interior airborne dust');vol.use_nodes=True;n=vol.node_tree.nodes;n.clear();out=n.new('ShaderNodeOutputMaterial');v=n.new('ShaderNodeVolumePrincipled');v.inputs['Density'].default_value=.012;v.inputs['Anisotropy'].default_value=.25;vol.node_tree.links.new(v.outputs['Volume'],out.inputs['Volume'])
box('Atmosphere volume',(0,0,1.95),(10.1,9.1,3.9),vol,0,'Presentation_Only')

# Presentation camera and background.
s.world=bpy.data.worlds.new('Cool evening surround');s.world.use_nodes=True
bg=next(n for n in s.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.055,.085,.12,1);bg.inputs['Strength'].default_value=.35
camd=bpy.data.cameras.new('Shop isometric camera');cam=bpy.data.objects.new('Shop isometric camera',camd);collections['Cameras'].objects.link(cam)
cam.location=(12,-17,15.0);target=Vector((0,.2,1.0));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();camd.type='ORTHO';camd.ortho_scale=16.4;camd.lens=50;s.camera=cam
s.unit_settings.system='METRIC';s.unit_settings.scale_length=1
s.render.engine='CYCLES';s.cycles.samples=64;s.cycles.use_denoising=True;s.cycles.max_bounces=8
p=bpy.context.preferences.addons['cycles'].preferences;p.compute_device_type='OPTIX';p.refresh_devices()
for d in p.devices:d.use=d.type=='OPTIX'
s.cycles.device='GPU'
s.render.resolution_x=1600;s.render.resolution_y=1000;s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.render.filepath=str(B/'previews/shop_interior_v001.png')
s.view_settings.exposure=.6
# Clean opening view.
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.overlay.show_overlays=False
   area.spaces.active.shading.type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT')
s['asset_status']='Blender art prototype; not Godot integrated or performance approved'
s['reference']='reference/shop_interior_target.png';s['layout_units']='meters; room 10 x 9; upper wall 3.72'
bpy.ops.file.pack_all()
report={'objects':len(s.objects),'mesh_objects':sum(o.type=='MESH' for o in s.objects),'base_triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in s.objects if o.type=='MESH'),'counter_triangles_after_reduction':sum(len(p.vertices)-2 for p in counter.data.polygons),'source':'source_assets/characters/red_panda/blender/item1.blend','characters':0}
(B/'reports/shop_scene_build.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(B/'blender/shop_interior_v001.blend'))
print('BUILD_COMPLETE',report,flush=True)
bpy.ops.render.render(write_still=True)
print('RENDER_COMPLETE',flush=True)
