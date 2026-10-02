"""Decoration-only revision of approved v004. Does not change lighting/camera/world."""
import bpy,math,json,random
from pathlib import Path
from mathutils import Vector,Matrix
B=Path('E:/ShopGame/source_assets/environments/shop');s=bpy.context.scene
SOURCE='E:/ShopGame/source_assets/characters/red_panda/blender/item2.blend'
# Serialize appearance settings before changes so accidental edits fail explicitly.
def appearance():
 def value(v):
  if isinstance(v,(str,int,float,bool)):return v
  try:return list(v)
  except:return str(v)
 def nodes(tree):
  return [{'name':n.name,'type':n.bl_idname,'inputs':{v.name:value(v.default_value) for v in n.inputs if hasattr(v,'default_value')}} for n in tree.nodes]
 return {'lights':{o.name:{'matrix':[list(r) for r in o.matrix_world],'type':o.data.type,'energy':o.data.energy,'color':list(o.data.color),'size':getattr(o.data,'size',None),'angle':getattr(o.data,'angle',None),'radius':getattr(o.data,'shadow_soft_size',None)} for o in s.objects if o.type=='LIGHT'},'camera':{'matrix':[list(r) for r in s.camera.matrix_world],'ortho':s.camera.data.ortho_scale,'lens':s.camera.data.lens},'world':nodes(s.world.node_tree),'view':{'transform':s.view_settings.view_transform,'look':s.view_settings.look,'exposure':s.view_settings.exposure,'gamma':s.view_settings.gamma},'volume':nodes(bpy.data.materials['Interior airborne dust'].node_tree)}
before=appearance()
(B/'reports/v005_appearance_baseline.json').write_text(json.dumps(before,indent=2))
with bpy.data.libraries.load(SOURCE,link=False) as (src,dst):dst.objects=[n for n in src.objects if n!='Camera']
assets={o.name:o for o in dst.objects if o and o.type=='MESH'}
COL={c.name:c for c in s.collection.children}
added=[];replaced=[]
def prop(key,name,loc,height,width=None,depth=None,angle=-90,group='Merchandise',top_anchor=False):
 src=next(o for n,o in assets.items() if n.startswith(key));ob=src.copy();ob.data=src.data;ob.name=name;COL[group].objects.link(ob)
 co=[Vector(v) for v in ob.bound_box];lo=Vector([min(v[i] for v in co) for i in range(3)]);hi=Vector([max(v[i] for v in co) for i in range(3)]);ds=hi-lo
 ob.rotation_euler=(0,0,math.radians(angle));factor=height/ds.z;ob.scale=(factor,factor,factor)
 if width:ob.scale.y=width/ds.y
 if depth:ob.scale.x=depth/ds.x
 ob.location=loc
 if top_anchor:ob.location.z-=height
 ob['source_file']='item2.blend';ob['source_object']=src.name;ob['asset_role']=group;ob['revision']='shop_v005'
 added.append(ob);return ob
# The new table has diagonal geometry in local space; align its long edge to the old table.
src=assets['ab3fc008-5db2-47ea-ac80-156062d75d5e'];ob=src.copy();ob.data=src.data.copy();ob.name='Central merchandise island HD';COL['Furniture'].objects.link(ob)
ob.data.transform(Matrix.Rotation(math.radians(-45),4,'Z'))
lo=Vector([min(v.co[i] for v in ob.data.vertices) for i in range(3)]);hi=Vector([max(v.co[i] for v in ob.data.vertices) for i in range(3)])
ob.data.transform(Matrix.Translation(Vector((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z))))
ds=hi-lo;ob.rotation_euler=(0,0,0);factor=2.82/ds.x;ob.scale=(factor,factor,factor);ob.location=(-.10,-.44,.085)
ob['source_file']='item2.blend';ob['source_object']=src.name;ob['revision']='shop_v005';ob['asset_role']='Furniture';added.append(ob)
old=bpy.data.objects['Central merchandise island'];replaced.append(old.name);bpy.data.objects.remove(old,do_unlink=True)
print('NEW_TABLE',list(ds*factor),flush=True)
# Curio cabinet contains books, a skull and an armillary; complements the potion cabinet.
old=bpy.data.objects['Curiosity cabinet'];replaced.append(old.name);bpy.data.objects.remove(old,do_unlink=True)
prop('47d8e2a6','Corner relics bookcase',(4.03,3.72,.045),2.76,1.63,.60,group='Furniture')
prop('3249f317','Right herbal supplies bookcase',(4.14,.81,.045),2.22,1.35,.56,-100,'Furniture')
# A low stock shelf below the rear window enriches the left edge without covering the glass.
prop('7b0b1420','Low window provisions',(-4.55,2.30,.045),1.16,1.66,.60,0,'Furniture')
# Existing stocks move into a deliberate delivery cluster along the front edge.
bpy.data.objects['Right stock barrel'].location=(.52,-3.92,.045)
bpy.data.objects['Right stock crate'].location=(2.43,-3.85,.045)
# Modest display bench for small curios along the foreground perimeter.
wood=bpy.data.materials['Oak | grain'];dark=bpy.data.materials['Aged oak beams'];iron=bpy.data.materials['Forged dark iron']
def box(name,loc,dim,mat,bevel=.02,group='Details'):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=dim;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for c in list(o.users_collection):c.objects.unlink(o)
 COL[group].objects.link(o);o.data.materials.append(mat)
 if bevel:m=o.modifiers.new('Rounded timber edge','BEVEL');m.width=bevel;m.segments=2
 o['revision']='shop_v005';return o
for x in [1.17,1.90]:box('Curio bench leg',(x,-3.96,.40),(.12,.49,.71),dark,group='Furniture')
box('Curio bench plank',(1.54,-3.96,.79),(1.02,.61,.12),wood,group='Furniture')
box('Curio bench lower brace',(1.54,-3.96,.21),(.88,.32,.11),dark,group='Furniture')
prop('5baf7703','Ornate hourglass',(1.31,-3.96,.853),.46,angle=-85)
prop('11c98630','Crystal specimen',(1.79,-3.96,.853),.38,angle=-75)
prop('ee374f2e','Dried flowers on right cabinet',(4.14,.83,2.265),.42,angle=-100,group='Plants')
# Incense on the notice-board ledge, relocating two small jars to the new bench shelf.
for name in ['Apothecary stock jar.005','Apothecary stock jar.006']:
 o=bpy.data.objects.get(name)
 # These are world-coordinate meshes. Move matching jar assemblies below by shared proximity.
# Shift the last three jar assemblies (body, lid and label) along the ledge to make a clear spot.
for o in s.objects:
 if o.name.startswith(('Apothecary stock jar','Jar stopper','Blank jar label')):
  if o.type=='MESH':
   center=o.matrix_world @ (sum((Vector(v) for v in o.bound_box),Vector())/8)
   if 2.08<center.x<2.75 and 3.65<center.y<4.12 and 1.69<center.z<2.08:
    o.location.x-=.18
prop('0edfae4f','Bronze incense vessel',(2.56,3.94,1.70),.25,angle=-100)
# Existing tiny procedural ivy stays; new broad and fern leaves give larger silhouettes.
# Each is anchored at the top, compressed in depth to hug the furniture/wall.
for key,name,loc,h,w,d,ang in [
 ('11314429','Fern above apothecary',(-3.73,3.73,3.43),1.05,.76,.24,-92),
 ('86149529','Apothecary right trailing leaves',(-2.45,3.81,3.43),1.18,.73,.25,-100),
 ('c06bb2b5','Left beam broad ivy',(-4.70,1.31,3.43),1.28,.55,.24,0),
 ('86149529','Entrance beam hanging leaves',(-4.70,-1.61,3.43),.96,.62,.20,0),
 ('11314429','Relics cabinet fern',(4.03,3.45,3.18),.78,.75,.23,-86),
 ('c06bb2b5','Relics side broad leaves',(4.72,3.54,3.17),1.24,.45,.20,-105),
 ('86149529','Notice board right greenery',(2.72,4.02,3.47),.68,.45,.18,-98),
 ('11314429','Right herbal cabinet fern',(4.04,.62,2.48),.86,.62,.25,-100),
 ('c06bb2b5','Front cabinet hanging ivy',(4.48,-1.52,2.38),.96,.42,.19,-108),
 ('86149529','Front bench trailing greenery',(-2.97,-3.77,1.16),.61,.45,.19,-84),
]:prop(key,name,loc,h,w,d,ang,'Plants',True)
# Give the top foliage on the corner cabinet a small shelf rather than leaving it unsupported.
box('Relics crown shelf',(4.03,3.72,2.81),(1.63,.65,.09),wood,group='Furniture')
# Source images already packed; maintain the source materials unchanged.
bpy.context.view_layer.update()
after=appearance();assert before==after,'Appearance configuration changed unexpectedly'
# Source meshes are held only by their placed instances; no extra library objects in scene.
manifest=[]
for o in added:
 manifest.append({'name':o.name,'source_object':o['source_object'],'location':list(o.location),'rotation_radians':list(o.rotation_euler),'scale':list(o.scale),'dimensions_m':list(o.dimensions),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons)})
report={'source':SOURCE,'base':'shop_interior_v004.blend','appearance_unchanged':before==after,'replaced':replaced,'new_item2_instances':manifest,'new_table_triangles':sum(len(p.vertices)-2 for p in ob.data.polygons),'godot_validated':False}
(B/'reports/shop_v005_changes.json').write_text(json.dumps(report,indent=2))
s.name='Shop_Interior_Decor_v005'
p=bpy.context.preferences.addons['cycles'].preferences;p.compute_device_type='OPTIX';p.refresh_devices()
for d in p.devices:d.use=d.type=='OPTIX'
s.cycles.device='GPU';s.render.filepath=str(B/'previews/shop_interior_v005.png')
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(B/'blender/shop_interior_v005.blend'))
# Preview sampling only; stored quality remains the approved 128 samples /1920x1200.
s.cycles.samples=48;s.render.resolution_percentage=83
print('SAVED_V005',len(added),flush=True)
bpy.ops.render.render(write_still=True)
