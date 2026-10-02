"""Blender art masters: four reference-directed, editable assemblies.
Run in an isolated background Blender. Never writes item2 or the Godot project.
Art construction values only; these are not gameplay definitions.
"""
import bpy, bmesh, math, random, sys, json, hashlib
from pathlib import Path
from mathutils import Vector, Matrix, noise
from mathutils.bvhtree import BVHTree

ROOT=Path('E:/ShopGame')
BASE=ROOT/'source_assets/environments/dungeon/room_compositions/v004'
SOURCE=ROOT/'source_assets/characters/red_panda/blender/item2.blend'
sys.path.insert(0,str(ROOT/'source_assets/environments/dungeon/shared/scripts'))
from room_kit import Kit, enum
from room_foliage import _Geometry, _leaf, _tube, _frame, fern
assert bpy.app.background
source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
kit=Kit('room_compositions/v004',27974);kit.dir=BASE
rng=random.Random(27974)
for folder in ['blender','previews','reports']: (BASE/folder).mkdir(parents=True,exist_ok=True)

def pbs(mat):return next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')

original_geometry_mesh=_Geometry.mesh
def botanical_mesh(self,*args,**kwargs):
 ob=original_geometry_mesh(self,*args,**kwargs)
 if ob and hasattr(self,'leaf_uvs'):
  uv=ob.data.uv_layers.new(name='LeafUV')
  for loop in ob.data.loops:uv.data[loop.index].uv=self.leaf_uvs[loop.vertex_index]
 return ob
_Geometry.mesh=botanical_mesh

def _leaf(geo,base,direction,normal,length,width,material=0,heart=False):
 # Smoothly curved botanical surfaces instead of eight hard triangular facets.
 length*=.77;width*=.77
 base,axis,n=Vector(base),Vector(direction).normalized(),Vector(normal).normalized()
 side=axis.cross(n)
 if side.length<.02:side,n=_frame(axis)
 else:side.normalize();n=side.cross(axis).normalized()
 verts=[];faces=[];steps=12
 for row in range(steps+1):
  t=row/steps;w=max(.005,math.sin(math.pi*t)**.72)
  if heart:w*=1.0+.24*math.sin(t*math.pi*3)
  for col in range(5):
   across=(col-2)/2
   rib=length*(.055*(1-across*across)*math.sin(math.pi*t)-.14*t*t+.04*across*across*t)
   verts.append(base+axis*length*t+side*width*.5*w*across+n*rib)
 for row in range(steps):
  for col in range(4):
   a=row*5+col;faces.append((a,a+1,a+6,a+5))
 if not hasattr(geo,'leaf_uvs'):geo.leaf_uvs=[]
 geo.leaf_uvs.extend((row/steps,col/4) for row in range(steps+1) for col in range(5))
 geo.add(verts,faces,material)

# Warm limestone with subdued grain. Avoid a noisy brown stone texture swallowing the form.
for i in range(7):
 v=.90+i*.032
 kit.mats['limestone'+str(i)]=kit.textured('Weathered limestone '+str(i),(.30*v,.282*v,.215*v),(.56*v,.525*v,.411*v),4.8,.81,.18,.025)
 mat=kit.mats['limestone'+str(i)];n=mat.node_tree.nodes;l=mat.node_tree.links;p=pbs(mat)
 tex=n.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'source_assets/environments/dungeon/shared/textures/worn_rock_natural_01/worn_rock_natural_01_diff_2k.jpg'),check_existing=True);enum(tex,'projection','BOX');tex.projection_blend=.22
 coord=n.new('ShaderNodeTexCoord');l.new(coord.outputs['Object'],tex.inputs['Vector'])
 blend=n.new('ShaderNodeMixRGB');enum(blend,'blend_type','MULTIPLY');blend.inputs[0].default_value=.62;l.new(p.inputs['Base Color'].links[0].from_socket,blend.inputs[1]);l.new(tex.outputs['Color'],blend.inputs[2]);l.new(blend.outputs[0],p.inputs['Base Color'])
 grain=n.new('ShaderNodeBump');grain.inputs['Strength'].default_value=.38;grain.inputs['Distance'].default_value=.022;l.new(tex.outputs['Color'],grain.inputs['Height']);l.new(p.inputs['Normal'].links[0].from_socket,grain.inputs['Normal']);l.new(grain.outputs['Normal'],p.inputs['Normal'])
for i,c in enumerate([(.025,.052,.008),(.055,.093,.013),(.092,.13,.021),(.037,.078,.016),(.14,.18,.036)]):
 kit.mats['leaf_'+str(i)]=kit.textured('Botanical olive leaf '+str(i),tuple(v*.65 for v in c),c,28,.72,.08,.002)
 mat=kit.mats['leaf_'+str(i)];p=pbs(mat);p.inputs['Subsurface Weight'].default_value=.04;n=mat.node_tree.nodes;l=mat.node_tree.links
 uv=n.new('ShaderNodeTexCoord');sep=n.new('ShaderNodeSeparateXYZ');l.new(uv.outputs['UV'],sep.inputs[0])
 def mathnode(op,a,b=None):
  node=n.new('ShaderNodeMath');enum(node,'operation',op)
  if isinstance(a,(float,int)):node.inputs[0].default_value=a
  else:l.new(a,node.inputs[0])
  if b is not None:
   if isinstance(b,(float,int)):node.inputs[1].default_value=b
   else:l.new(b,node.inputs[1])
  return node.outputs[0]
 across=mathnode('ABSOLUTE',mathnode('SUBTRACT',sep.outputs['Y'],.5))
 midrib=mathnode('LESS_THAN',across,.014)
 ribs=mathnode('LESS_THAN',mathnode('ABSOLUTE',mathnode('SINE',mathnode('SUBTRACT',mathnode('MULTIPLY',sep.outputs['X'],65),mathnode('MULTIPLY',across,23)))),.095)
 vein=mathnode('MAXIMUM',midrib,mathnode('MULTIPLY',ribs,.50))
 mix=n.new('ShaderNodeMixRGB');enum(mix,'blend_type','MIX');l.new(mathnode('MULTIPLY',vein,.40),mix.inputs[0]);l.new(p.inputs['Base Color'].links[0].from_socket,mix.inputs[1]);mix.inputs[2].default_value=tuple(min(1,v*1.8+.01) for v in c)+(1,);l.new(mix.outputs[0],p.inputs['Base Color'])
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.28;bump.inputs['Distance'].default_value=.0015;l.new(vein,bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
 out=next(x for x in n if x.type=='OUTPUT_MATERIAL');trans=n.new('ShaderNodeBsdfTranslucent');l.new(mix.outputs[0],trans.inputs[0]);blend=n.new('ShaderNodeMixShader');blend.inputs[0].default_value=.13;l.new(p.outputs[0],blend.inputs[1]);l.new(trans.outputs[0],blend.inputs[2]);l.new(blend.outputs[0],out.inputs['Surface'])
kit.mats['chips']=kit.mats['limestone2']
kit.mats['pottery']=kit.textured('Old olive glazed pottery',(.095,.119,.059),(.25,.29,.17),8,.53,.19,.012)
kit.mats['moss']=kit.textured('Velvet olive moss',(.028,.047,.007),(.13,.17,.025),45,.97,.45,.018)
kit.mats['stem']=kit.plain('Thin olive stems',(.068,.105,.025),.88)
kit.mats['petal_ivory']=kit.plain('Sunlit ivory petals',(.86,.85,.73),.58)
kit.mats['petal_white']=kit.plain('Fresh white petals',(.94,.94,.85),.56)
kit.mats['petal_lilac']=kit.plain('Pale violet florets',(.47,.30,.58),.67)
kit.mats['pollen']=kit.plain('Ochre flower hearts',(.54,.31,.045),.77)

# Pack copies of supplied textured objects, independent from their scene transforms.
IDS={'barrel':'木桶3d模型','crate':'板条箱','chest':'chest1','column':'65fbc458-0833-44c7-b125-2885ac8efc5e','moss_patch':'35ad7ced-c425-407b-be98-e37dc3bd5d60','wall':'71d0d5a4-fa8e-4375-bb31-dc33549b281e','broken_wall':'ba956f36-4051-4087-a2ba-15b622e9bb75','pier':'6d00c541-9c1e-42f5-bdd1-3475b0d613d0'}
with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):
 assert all(v in src.objects for v in IDS.values())
 dst.objects=list(IDS.values())
loaded={o.name:o for o in dst.objects};prototypes={};sizes={}
for key,name in IDS.items():
 ob=loaded[name];mesh=ob.data.copy();mesh.transform(Matrix.Rotation(-math.pi/2,4,'Z'))
 if key=='column':mesh.transform(Matrix.Rotation(math.pi/2,4,'Y'))
 lo=Vector([min(v.co[a] for v in mesh.vertices) for a in range(3)]);hi=Vector([max(v.co[a] for v in mesh.vertices) for a in range(3)])
 mesh.transform(Matrix.Translation(-Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))))
 sizes[key]=hi-lo;prototypes[key]=mesh
 # Local material copies add fine surface grain while retaining the user's UV textures.
 for i,old in enumerate(list(mesh.materials)):
  if not old:continue
  mat=old.copy();mesh.materials[i]=mat;p=pbs(mat);n=mat.node_tree.nodes;l=mat.node_tree.links
  p.inputs['Roughness'].default_value=.72
  if key in ['barrel','crate','chest','moss_patch'] and p.inputs['Base Color'].is_linked:
   hsv=n.new('ShaderNodeHueSaturation');hsv.inputs['Saturation'].default_value=.68;hsv.inputs['Value'].default_value=.73
   l.new(p.inputs['Base Color'].links[0].from_socket,hsv.inputs['Color']);l.new(hsv.outputs['Color'],p.inputs['Base Color'])
  coord=n.new('ShaderNodeTexCoord');grain=n.new('ShaderNodeTexNoise');grain.inputs['Scale'].default_value=110
  l.new(coord.outputs['Generated'],grain.inputs['Vector']);b=n.new('ShaderNodeBump');b.inputs['Strength'].default_value=.14;b.inputs['Distance'].default_value=.005;l.new(grain.outputs['Fac'],b.inputs['Height']);l.new(b.outputs['Normal'],p.inputs['Normal'])
 bpy.data.objects.remove(ob,do_unlink=True)

def supplied(key,name,loc,dim,angle=0):
 ob=bpy.data.objects.new(name,prototypes[key]);kit.collection('Architecture').objects.link(ob);ob.location=loc
 ob.scale=tuple(dim[a]/sizes[key][a] for a in range(3));ob.rotation_euler.z=angle
 ob['source_object']=IDS[key];ob['interaction_part']=key in ['barrel','crate','chest'];return ob

def stone(name,loc,dim,mat=None,rotation=0):
 # Eight-sided footprint with unequal corner chips and irregular upper arris.
 sx,sy,sz=dim;cuts=[rng.uniform(.08,.21)*min(sx,sy) for _ in range(4)]
 outline=[(-sx/2+cuts[0],-sy/2),(sx/2-cuts[1],-sy/2),(sx/2,-sy/2+cuts[1]),(sx/2,sy/2-cuts[2]),(sx/2-cuts[2],sy/2),(-sx/2+cuts[3],sy/2),(-sx/2,sy/2-cuts[3]),(-sx/2,-sy/2+cuts[0])]
 verts=[(x+rng.uniform(-.017,.017),y+rng.uniform(-.015,.015),z+rng.uniform(-.021,.021)) for z in [-sz/2,sz/2] for x,y in outline]
 faces=[tuple(reversed(range(8))),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
 ob=kit.mesh(name,verts,faces,mat or 'limestone'+str(rng.randrange(7)));ob.location=loc;ob.rotation_euler.z=rotation
 kit.bevel(ob,.012,2);return ob

def wall(name,a,b,height=.83,depth=.43,broken=False):
 a,b=Vector((*a,0)),Vector((*b,0));length=(b-a).length;axis=(b-a).normalized();ang=math.atan2(axis.y,axis.x)
 count=max(1,round(length/1.65));span=length/count
 for i in range(count):
  c=a+axis*(i+.5)*span
  supplied('broken_wall' if broken else 'wall',name+'_dressed_ruin_'+str(i),(c.x,c.y,.0),(span+.015,depth,height*rng.uniform(.96,1.03)),ang+(math.pi if broken else 0))
 return

def pier(name,xy,height=1.08,width=.45):
 x,y=xy
 supplied('pier',name+'_weathered_endpost',(x,y,0),(width*1.16,width*1.16,height))
 return

def shrub(name,center,radius=.35,height=.28,count=100):
 geo=_Geometry();stems=_Geometry()
 for i in range(int(count*1.7)):
  a=rng.uniform(0,math.tau);r=radius*math.sqrt(rng.random());base=Vector((center[0]+math.cos(a)*r,center[1]+math.sin(a)*r,center[2]))
  tip=base+Vector((math.cos(a)*.06,math.sin(a)*.06,rng.uniform(.08,height)))
  for k in range(3):
   t=.28+k*.25;angle=a+k*2.3
   _leaf(geo,base.lerp(tip,t),(math.cos(angle),math.sin(angle),rng.uniform(.1,.65)),(0,0,1),rng.uniform(.065,.15),rng.uniform(.035,.07),rng.randrange(5),heart=i%4==0)
  if i%3==0:_tube(stems,[base,tip],[.002,.001],4)
 root=kit.root(name,group='Flora');geo.mesh(kit,name+'_Leaves',root,['leaf_'+str(i) for i in range(5)],True);stems.mesh(kit,name+'_Branches',root,['stem'],True)

def flowers(name,center,extent,count=36,height=(.16,.42),white=.9):
 leaves,stems,blooms=_Geometry(),_Geometry(),_Geometry()
 for i in range(count):
  a=rng.uniform(0,math.tau);r=math.sqrt(rng.random());p=Vector((center[0]+math.cos(a)*r*extent[0]/2,center[1]+math.sin(a)*r*extent[1]/2,center[2]))
  tip=p+Vector((rng.uniform(-.07,.07),rng.uniform(-.07,.07),rng.uniform(*height)))
  _tube(stems,[p,p.lerp(tip,.45)+Vector((.016,0,0)),tip],[.0025,.0018,.001],4)
  for k in range(3):
   angle=a+k*2.4;_leaf(leaves,p.lerp(tip,.15+.2*k),(math.cos(angle),math.sin(angle),.4),(0,0,1),rng.uniform(.05,.095),.024,rng.randrange(5))
  normal=Vector((rng.uniform(-.45,.45),rng.uniform(-.45,.45),1)).normalized();side,front=_frame(normal)
  color=rng.choice([0,0,1]) if rng.random()<white else 2
  petals=8 if color<2 else 5;rad=rng.uniform(.021,.036) if color<2 else rng.uniform(.017,.025)
  for j in range(petals):
   angle=j*math.tau/petals+a;axis=math.cos(angle)*side+math.sin(angle)*front;across=normal.cross(axis)
   verts=[tip+normal*.001,tip+axis*rad*.42-across*rad*.25,tip+axis*rad*.92-across*rad*.27+normal*.008,tip+axis*rad*1.05+normal*.010,tip+axis*rad*.92+across*rad*.27+normal*.008,tip+axis*rad*.42+across*rad*.25,tip+axis*rad*.55+normal*.003]
   blooms.add(verts,[(6,j,(j+1)%6) for j in range(6)],color)
  center_points=[tip+normal*.008]+[tip+normal*.004+rad*.19*(math.cos(j*math.tau/8)*side+math.sin(j*math.tau/8)*front) for j in range(8)]
  blooms.add(center_points,[(0,j+1,(j+1)%8+1) for j in range(8)],3)
 root=kit.root(name,group='Flora');leaves.mesh(kit,name+'_Leaves',root,['leaf_'+str(i) for i in range(5)],True);stems.mesh(kit,name+'_Stems',root,['stem'],True);blooms.mesh(kit,name+'_Petals',root,['petal_ivory','petal_white','petal_lilac','pollen'],True)

def vine(name,points,spread=.15,density=75):
 points=[Vector(p) for p in points];fol=_Geometry();stems=_Geometry()
 bpy.context.view_layer.update()
 vertices=[];faces=[]
 for ob in kit.collection('Architecture').objects:
  if ob.type!='MESH':continue
  if ob.get('source_object') not in [IDS['wall'],IDS['broken_wall'],IDS['pier'],IDS['column']] and not ob.name.startswith('Column_plinth'):continue
  off=len(vertices);vertices.extend(ob.matrix_world@v.co for v in ob.data.vertices);faces.extend(tuple(off+i for i in p.vertices) for p in ob.data.polygons)
 tree=BVHTree.FromPolygons(vertices,faces)
 attached=[]
 for a,b in zip(points[:-1],points[1:]):
  for i in range(12):
   hit,normal,_,distance=tree.find_nearest(a.lerp(b,i/12))
   attached.append(hit+normal*.011)
 _tube(stems,attached,[.0035]*len(attached),5)
 for i in range(int(density*1.65)):
  t=rng.uniform(0,len(points)-1-.0001);index=int(t);center=points[index].lerp(points[index+1],t-index)
  a=rng.uniform(0,math.tau);center+=Vector((rng.uniform(-spread,spread),rng.uniform(-spread,spread),rng.uniform(-spread*.2,spread*.3)))
  hit,normal,_,distance=tree.find_nearest(center)
  if distance>.40:continue
  tangent=Vector((math.cos(a),math.sin(a),rng.uniform(-.7,.7)));tangent-=normal*tangent.dot(normal)
  if tangent.length<.02:tangent=normal.cross(Vector((0,0,1)))
  _leaf(fol,hit+normal*rng.uniform(.012,.028),tangent,normal,rng.uniform(.085,.17),rng.uniform(.06,.12),rng.randrange(5),heart=True)
 root=kit.root(name,group='Flora');fol.mesh(kit,name+'_IvyLeaves',root,['leaf_'+str(i) for i in range(5)],True);stems.mesh(kit,name+'_VineStem',root,['stem'],True)

def bedding(name,sites,flower_density=1.0):
 for i,(x,y,r,h) in enumerate(sites):
  shrub(name+'_understory_'+str(i),(x,y,.013),r,h,int(r*180))
  flowers(name+'_daisies_'+str(i),(x,y,.017),(r*1.8,r*1.5),int(r*92*flower_density),(h*.7,h*1.7))
  if i%3==0:fern(kit,name+'_fern_'+str(i),(x+.1,y-.05,.015),r*.95,187+i)

def rubble(name,sites):
 for i,(x,y,s) in enumerate(sites):
  stone(name+str(i),(x,y,s*.32),(s,s*.73,s*.62),rotation=rng.uniform(-.8,.8))

def rock(name,center,dim):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4,radius=1,location=(0,0,0))
 ob=bpy.context.object
 for col in list(ob.users_collection):col.objects.unlink(ob)
 kit.collection('Architecture').objects.link(ob);ob.name=name
 for v in ob.data.vertices:
  c=v.co.copy();n=noise.noise(c*2.4)+.32*noise.noise(c*6.2)
  c*=1+.15*n;c.z=max(-.57,min(c.z,.75+.14*c.x-.08*c.y));c.x+=.12*c.z
  c.x=max(-.81+.16*c.y,min(c.x,.82+.16*c.z));c.y=max(-.82+.1*c.z,min(c.y,.78-.12*c.x))
  v.co=(c.x*dim[0]/2,c.y*dim[1]/2,(c.z+.57)*dim[2]/1.57)
 for poly in ob.data.polygons:poly.use_smooth=True
 ob.location=center
 ob['moss_support']=True
 mat=kit.textured('Sculpted mossy grey limestone',(.15,.17,.11),(.39,.38,.28),4,.84,.38,.052)
 n=mat.node_tree.nodes;l=mat.node_tree.links;p=pbs(mat)
 coord=n.new('ShaderNodeTexCoord');large=n.new('ShaderNodeTexNoise');large.inputs['Scale'].default_value=3.8;large.inputs['Detail'].default_value=3
 l.new(coord.outputs['Generated'],large.inputs['Vector']);ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.49;ramp.color_ramp.elements[1].position=.55;l.new(large.outputs['Fac'],ramp.inputs[0])
 texture=n.new('ShaderNodeTexImage');texture.image=bpy.data.images.load(str(ROOT/'source_assets/environments/dungeon/shared/textures/worn_rock_natural_01/worn_rock_natural_01_diff_2k.jpg'),check_existing=True);enum(texture,'projection','BOX');texture.projection_blend=.2;l.new(coord.outputs['Generated'],texture.inputs['Vector'])
 mix=n.new('ShaderNodeMixRGB');enum(mix,'blend_type','MIX');l.new(ramp.outputs['Color'],mix.inputs[0]);l.new(texture.outputs['Color'],mix.inputs[1]);mix.inputs[2].default_value=(.055,.095,.012,1);l.new(mix.outputs[0],p.inputs['Base Color'])
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.55;bump.inputs['Distance'].default_value=.023;l.new(texture.outputs['Color'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
 fine=n.new('ShaderNodeTexNoise');fine.inputs['Scale'].default_value=55;fine.inputs['Detail'].default_value=4;l.new(coord.outputs['Generated'],fine.inputs['Vector'])
 moss_color=n.new('ShaderNodeValToRGB');moss_color.color_ramp.elements[0].color=(.018,.033,.006,1);moss_color.color_ramp.elements[1].color=(.14,.18,.031,1);l.new(fine.outputs['Fac'],moss_color.inputs[0]);l.new(moss_color.outputs[0],mix.inputs[2])
 blendmask=n.new('ShaderNodeMath');enum(blendmask,'operation','MULTIPLY');l.new(ramp.outputs[0],blendmask.inputs[0]);l.new(fine.outputs['Fac'],blendmask.inputs[1]);l.new(blendmask.outputs[0],mix.inputs[0])
 micro=n.new('ShaderNodeBump');micro.inputs['Strength'].default_value=.42;micro.inputs['Distance'].default_value=.012;l.new(fine.outputs['Fac'],micro.inputs['Height']);l.new(bump.outputs[0],micro.inputs['Normal']);l.new(micro.outputs[0],p.inputs['Normal'])
 ob.data.materials.clear();ob.data.materials.append(mat)
 # Actual tuft geometry on the crown adds readable grazing silhouettes.
 supplied('moss_patch',name+'_CrownMoss',(center[0]-.1,center[1],center[2]+dim[2]*.79),(.50,.43,.045),.5)
 return ob

# Shared photographic context: open paved ground, soft mottled sun, no display plinth.
stage=bpy.data.collections.new('STAGE__not_part_of_prefabs');bpy.context.scene.collection.children.link(stage)
kit.groups={key:stage for key in ['Architecture','Floor','Decor','Flora','Lighting','Cameras','Atmosphere']}
COURTYARD=ROOT/'source_assets/environments/dungeon/forest_courtyard/v001/blender/forest_courtyard_item2_v001.blend'
with bpy.data.libraries.load(str(COURTYARD),link=False) as (src,dst):dst.objects=['Courtyard_Item2_Paving_0_0']
floor_source=dst.objects[0];floor_mesh=floor_source.data.copy();bpy.data.objects.remove(floor_source,do_unlink=True)
for x in [-6,-2,2,6]:
 for y in [-8,0,8]:
  ob=bpy.data.objects.new('STAGE_supplied_paving',floor_mesh);stage.objects.link(ob);ob.location=(x,y,-.016);ob.scale=(4/.26,8/.74,1);ob.rotation_euler.z=math.pi*((int(x)+int(y))%2)
world=bpy.data.worlds.new('Open woodland sky');world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.43,.52,.62,1);bg.inputs[1].default_value=.18
sun=kit.light('Warm afternoon sun','SUN',(-3,-4,8),(1,.83,.59),3.4,target=(0,0,0));sun.data.angle=.065
kit.light('Soft sky bounce','AREA',(2,1,8),(.72,.82,1),120,7,(0,0,0))
# Geometry outside the camera ray casts soft foliage shadows, just as real overhead branches.
shadow_geo=_Geometry()
for i in range(450):
 a=rng.uniform(0,math.tau);x=rng.uniform(-5,4);y=rng.uniform(-2,5)
 _leaf(shadow_geo,(x,y,3.5),(math.cos(a),math.sin(a),.05),(0,0,1),rng.uniform(.25,.48),rng.uniform(.14,.25),0)
shadow_root=kit.root('Overhead_canopy_shadow',group='Flora');shadow_obj=shadow_geo.mesh(kit,'Overhead_shadow_leaves',shadow_root,['leaf_0']);shadow_obj.visible_camera=False

scenes=[];roots=[];report={}
def begin_scene(id,title,ortho,target):
 s=bpy.data.scenes.new(title);bpy.context.window.scene=s;s.collection.children.link(stage);s.world=world
 enum(s.unit_settings,'system','METRIC');s.unit_settings.scale_length=1
 col=bpy.data.collections.new(id+'__complete_prefab');s.collection.children.link(col)
 kit.scene=s;kit.groups={key:col for key in ['Architecture','Decor','Flora','Replacement_Props']}
 root=kit.root(id);root['prefab_id']=id;root['asset_status']='Blender visual review; not imported to Godot';root['origin']='Ground-centred reusable assembly';roots.append(root)
 data=bpy.data.cameras.new(title+'_Camera');cam=bpy.data.objects.new(title+'_Camera',data);stage.objects.link(cam)
 cam.location=Vector(target)+Vector((-6,-8,7.4));cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();enum(data,'type','ORTHO');data.ortho_scale=ortho;s.camera=cam
 try:s.render.engine='CYCLES'
 except TypeError as err:raise RuntimeError(err)
 s.cycles.samples=128;s.cycles.use_denoising=True;s.cycles.max_bounces=7
 s.render.resolution_x=1600;s.render.resolution_y=1300;s.render.resolution_percentage=100
 enum(s.render.image_settings,'file_format','PNG');enum(s.render.image_settings,'color_mode','RGBA');s.render.film_transparent=False
 s.render.filepath=str(BASE/'previews'/(id+'.png'));s.view_settings.exposure=.3
 try:s.view_settings.look='AgX - Medium High Contrast'
 except TypeError:pass
 pref=bpy.context.preferences.addons['cycles'].preferences
 try:
  if 'OPTIX' in [item[0] for item in pref.get_device_types(bpy.context)]:
   pref.compute_device_type='OPTIX';pref.refresh_devices()
   for dev in pref.devices:dev.use=dev.type=='OPTIX'
   enum(s.cycles,'device','GPU')
 except Exception as err:print('Cycles device fallback',err,flush=True)
 scenes.append(s);return root,col

def finish_scene(root,col):
 # Conform every moss patch to the real wall/column/rock surface, vertex by vertex.
 bpy.context.view_layer.update();verts=[];polys=[]
 for ob in list(col.objects):
  if ob.type!='MESH':continue
  if ob.get('source_object') not in [IDS['wall'],IDS['broken_wall'],IDS['pier'],IDS['column']] and not ob.get('moss_support'):continue
  off=len(verts);verts.extend(ob.matrix_world@v.co for v in ob.data.vertices);polys.extend(tuple(off+i for i in p.vertices) for p in ob.data.polygons)
 tree=BVHTree.FromPolygons(verts,polys)
 for ob in list(col.objects):
  if ob.get('source_object')!=IDS['moss_patch']:continue
  ob.data=ob.data.copy();inverse=ob.matrix_world.inverted()
  original=[ob.matrix_world@v.co for v in ob.data.vertices]
  for vertex in ob.data.vertices:
   point=ob.matrix_world@vertex.co;thickness=max(0,point.z-ob.location.z)
   hit,normal,_,_=tree.find_nearest(point)
   vertex.co=inverse@(hit+normal*(.004+thickness))
  # Nearest-surface projection may jump across a chipped edge. Cut those faces
  # instead of allowing long, stretched moss triangles between different surfaces.
  bm=bmesh.new();bm.from_mesh(ob.data);bm.verts.ensure_lookup_table()
  for face in list(bm.faces):
   invalid=False
   for edge in face.edges:
    a,b=edge.verts
    before=(original[a.index]-original[b.index]).length
    after=(ob.matrix_world@a.co-ob.matrix_world@b.co).length
    if after>max(.024,before*2.5):invalid=True;break
   if invalid:bm.faces.remove(face)
  bm.to_mesh(ob.data);bm.free()
  ob.data.update()
 for ob in list(col.objects):
  if ob!=root and ob.parent is None:ob.parent=root
 root['parts_remain_separate']='Searchable and destructible props are separate child objects; do not join for runtime.'
 col.asset_mark();col.asset_data.description='Reference-directed complete forest ruin composition. Append collection, move root. Excludes staging floor and lighting.'
 report[root.name]={'objects':len(col.objects),'base_triangles':sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in col.objects if ob.type=='MESH')}

root,col=begin_scene('01_long_wall','01 Long wall - barrels and wildflowers',5.35,(0,0,.48))
wall('Low_ruin',(-1.68,0),(1.68,0),.83,.46)
pier('West_end',(-1.91,0),1.10,.44);pier('East_end',(1.91,0),1.14,.46)
supplied('barrel','Barrel_foreground',(-1.67,-.59,.012),(.47,.47,.63),.08)
supplied('barrel','Barrel_behind',(1.43,.49,.012),(.49,.49,.82),-.2)
bedding('Wall_base',[(-2.06,-.28,.33,.22),(-1.03,-.41,.32,.28),(-.36,-.43,.38,.32),(.47,-.40,.33,.24),(1.23,-.37,.30,.28),(2.0,-.29,.32,.25),(-1.05,.40,.32,.22),(.18,.39,.41,.31),(1.03,.4,.24,.24)])
vine('Ivy_across_wall',[(-1.3,-.19,.3),(-.93,-.19,.76),(-.36,-.1,.89),(.45,-.1,.87),(1.12,.03,.87),(1.58,.12,1.13)],.15,200)
vine('Ivy_spilling_front',[(.5,-.20,.91),(.63,-.27,.63),(.49,-.28,.30),(.73,-.38,.13)],.09,90)
flowers('White_walltop',(-.16,.04,.8),(1.25,.30),28,(.10,.29),.97)
rubble('Wall_foot_chips',[(-2.1,-.72,.15),(.1,-.74,.13),(1.94,-.53,.18)])
finish_scene(root,col)

root,col=begin_scene('02_treasure_wall','02 Broken wall - treasure alcove',3.65,(0,-.16,.40))
wall('Broken_back',(-1.07,.28),(.73,.28),.98,.42,True)
supplied('chest','Treasure_chest',(.28,-.36,.012),(.90,.61,.63),-.03)
bedding('Alcove_plants',[(-1.04,.01,.33,.26),(-.57,.06,.29,.33),(-.38,-.30,.23,.24),(.96,-.12,.25,.22),(.41,.61,.31,.28),(-.64,.62,.29,.31)])
vine('Walltop_ivy',[(-.87,.26,.41),(-.59,.27,.74),(-.32,.24,1.03),(.13,.24,1.0)],.12,130)
vine('Left_hanging_ivy',[(-.35,.02,.83),(-.55,-.03,.51),(-.48,-.17,.18)],.08,72)
flowers('Tall_flower_accents',(-.72,-.25,.02),(.60,.32),35,(.24,.52),.89)
rubble('Alcove_stones',[(-1.18,-.29,.21),(-.98,-.47,.14),(.81,-.77,.12)])
finish_scene(root,col)

root,col=begin_scene('03_column_crates','03 Broken column - supply cache',3.65,(.12,0,.72))
stone('Column_plinth_lower',(-.24,.22,.12),(.82,.78,.24))
stone('Column_plinth_block',(-.24,.22,.38),(.66,.65,.31))
stone('Column_plinth_cornice',(-.24,.22,.56),(.76,.72,.13))
supplied('column','Fluted_broken_column',(-.24,.22,.59),(.57,.56,1.31),.05)
supplied('crate','Crate_front',(.56,-.16,.012),(.62,.58,.66),.015)
supplied('crate','Crate_back',(.71,.57,.012),(.82,.57,.62),-.025)
kit.lathe('Ancient_garden_urn',(-.87,-.32,.012),[(.15,0),(.19,.06),(.245,.25),(.19,.43),(.17,.46),(.19,.49),(.165,.49),(.15,.43),(.13,.35)],'pottery',48)
kit.lathe('Urn_rim',(-.87,-.32,.012),[(.19,.435),(.205,.46),(.20,.48),(.18,.49)],'limestone2',48)
flowers('Urn_daisies',(-.87,-.32,.44),(.49,.45),68,(.18,.46),.94)
shrub('Urn_foliage',(-.87,-.32,.44),.21,.27,100)
bedding('Column_garden',[(-.89,.15,.28,.24),(-.51,-.28,.24,.24),(-.13,-.48,.25,.2),(.15,.74,.25,.26),(.85,-.57,.23,.18)])
vine('Column_climber',[(-.56,.13,.18),(-.58,.22,.54),(-.46,.13,.94),(-.32,.14,1.28)],.08,85)
vine('Plinth_ivy',[(-.45,-.06,.61),(-.49,-.15,.38),(-.27,-.2,.17)],.1,70)
supplied('moss_patch','Column_top_moss',(-.24,.21,1.84),(.37,.34,.035),.2)
rubble('Column_debris',[(-.4,-.68,.25),(-.74,-.68,.17),(-.07,-.60,.19),(.03,.9,.19)])
finish_scene(root,col)

root,col=begin_scene('04_rock_corner','04 L wall - mossy boulder',3.7,(0,0,.45))
wall('Corner_back',(-1.1,.58),(1.00,.58),.92,.40)
wall('Corner_return',(1.00,.42),(1.00,-.84),.76,.42)
rock('Mossy_boulder',(-.09,-.08,-.02),(1.12,.91,.82))
bedding('Corner_garden',[(-1.03,.27,.30,.23),(-.72,-.42,.31,.26),(-.32,-.68,.27,.18),(.72,-.8,.23,.17),(1.19,-.10,.25,.21),(.10,.8,.25,.25),(-.79,.77,.29,.22)],.3)
vine('Corner_creeper',[(-.99,.39,.27),(-.80,.38,.66),(-.34,.44,.94),(.26,.45,.95),(.59,.43,.81)],.09,140)
supplied('moss_patch','Walltop_moss_a',(.94,.05,.75),(.56,.34,.042),math.pi/2)
supplied('moss_patch','Walltop_moss_b',(.13,.54,.93),(.55,.32,.035),.12)
rubble('Corner_debris',[(-1.28,.15,.20),(.64,-1.1,.14),(-.75,-.71,.16)])
finish_scene(root,col)

# Keep only useful scenes and make the first composition the default on opening.
for s in list(bpy.data.scenes):
 if s not in scenes:bpy.data.scenes.remove(s)
bpy.context.window.scene=scenes[0]
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   enum(area.spaces.active.region_3d,'view_perspective','CAMERA')
   enum(area.spaces.active.shading,'type','MATERIAL');area.spaces.active.overlay.show_overlays=False
bpy.ops.file.pack_all()
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==source_hash
path=BASE/'blender/forest_compositions_art_v004.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(path))
report.update(source_sha256=source_hash,source=str(SOURCE),blender_file=str(path),scenes=[s.name for s in scenes],packed_images=len([i for i in bpy.data.images if i.packed_file]),godot_imported=False)
(BASE/'reports/build_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('COMPOSITIONS_SAVED',str(path),flush=True)
selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
for s in scenes:
 if selected and s.name[:2] not in selected:continue
 bpy.context.window.scene=s
 print('RENDER_START',s.name,flush=True);bpy.ops.render.render(write_still=True);print('RENDER_DONE',s.name,flush=True)
