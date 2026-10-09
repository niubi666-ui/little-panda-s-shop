"""Blender 4.3 native Jackal Scout: reproducible production geometry, rig and GLB.
Run: blender -b -t 3 --python build_jackal.py -- --preview
All art is locally authored; no network service is used.
"""
import bpy, math, sys, json
from mathutils import Vector, Matrix, Quaternion
from mathutils.bvhtree import BVHTree
from pathlib import Path
from math import sin, cos, pi, sqrt
ROOT=Path(__file__).resolve().parent
TEX=ROOT/'textures'
OUT=ROOT
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for d in list(bpy.data.materials): bpy.data.materials.remove(d)
scene=bpy.context.scene
scene.unit_settings.system='METRIC'
scene.render.fps=30
scene.render.engine='CYCLES'; scene.cycles.samples=16; scene.cycles.use_denoising=False
scene.render.threads_mode='FIXED'; scene.render.threads=3
scene.render.resolution_x=768; scene.render.resolution_y=768; scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'; scene.view_settings.look='AgX - Medium High Contrast'
char=bpy.data.collections.new('JACKAL_SCOUT | skinned game character'); scene.collection.children.link(char)
pres=bpy.data.collections.new('PRESENTATION | camera and lights'); scene.collection.children.link(pres)
MAT={}; meshes=[]; bone_specs={}

def move_col(o,col=char):
    for c in list(o.users_collection): c.objects.unlink(o)
    col.objects.link(o)
    return o

def mat(name,col,rough=.75,metal=0,tex=None,norm=None,rmap=None):
    m=bpy.data.materials.new(name); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*col,1)
    p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
    m.diffuse_color=(*col,1); nd=m.node_tree.nodes; links=m.node_tree.links
    if tex:
        im=bpy.data.images.load(str(TEX/(tex+'.png')),check_existing=True); im.pack()
        t=nd.new('ShaderNodeTexImage'); t.image=im; t.label='Game export base color'
        links.new(t.outputs['Color'],p.inputs['Base Color'])
    if norm:
        im=bpy.data.images.load(str(TEX/(norm+'.png')),check_existing=True); im.colorspace_settings.name='Non-Color'; im.pack()
        t=nd.new('ShaderNodeTexImage'); t.image=im
        n=nd.new('ShaderNodeNormalMap'); n.inputs['Strength'].default_value=.32
        links.new(t.outputs['Color'],n.inputs['Color']); links.new(n.outputs['Normal'],p.inputs['Normal'])
    if rmap:
        im=bpy.data.images.load(str(TEX/(rmap+'.png')),check_existing=True); im.colorspace_settings.name='Non-Color'; im.pack()
        t=nd.new('ShaderNodeTexImage'); t.image=im; links.new(t.outputs['Color'],p.inputs['Roughness'])
    MAT[name]=m; return m

mat('01 | rust ochre fur',(.57,.29,.105),tex='fur_ochre_color',norm='fur_normal',rmap='fur_roughness')
mat('02 | warm cream fur',(.77,.64,.43),tex='fur_cream_color',norm='fur_normal',rmap='fur_roughness')
mat('03 | black back saddle',(.12,.105,.09),tex='fur_charcoal_color',norm='fur_normal',rmap='fur_roughness')
mat('04 | worn brown leather',(.25,.125,.065),tex='leather_brown_color',norm='leather_normal',rmap='leather_roughness')
mat('05 | dark leather wraps',(.17,.11,.074),tex='wrap_dark_color',norm='leather_normal',rmap='leather_roughness')
mat('06 | linen knee shorts',(.56,.48,.35),tex='linen_color',norm='cloth_normal',rmap='cloth_roughness')
mat('07 | tucked olive scarf',(.22,.245,.125),tex='scarf_olive_color',norm='cloth_normal',rmap='cloth_roughness')
mat('08 | dark tempered steel',(.34,.37,.38),rough=.42,metal=.85,tex='steel_color',norm='steel_normal',rmap='steel_roughness')
mat('09 | sharpened steel edge',(.60,.64,.66),rough=.27,metal=.91)
mat('10 | warm aged brass',(.46,.30,.105),rough=.48,metal=.7)
mat('11 | leather seam thread',(.37,.25,.13),rough=.9)
mat('12 | ear velvet',(.27,.145,.105),rough=.87,tex='wrap_dark_color',norm='fur_normal')
mat('13 | nose claws and eye line',(.018,.015,.012),rough=.64)
mat('14 | amber eye',(.27,.088,.009),rough=.59,metal=0)
mat('15 | dark pupil',(.003,.002,.001),rough=.64)
mat('17 | painted jackal face',(.46,.285,.14),tex='jackal_face_color',norm='fur_normal',rmap='fur_roughness')
mat('16 | eye glint',(.95,.87,.62),rough=.15)
FUR=MAT['01 | rust ochre fur']; CREAM=MAT['02 | warm cream fur']; SADDLE=MAT['03 | black back saddle']
LEATHER=MAT['04 | worn brown leather']; WRAP=MAT['05 | dark leather wraps']; LINEN=MAT['06 | linen knee shorts']
SCARF=MAT['07 | tucked olive scarf']; STEEL=MAT['08 | dark tempered steel']; EDGE=MAT['09 | sharpened steel edge']
BRASS=MAT['10 | warm aged brass']; THREAD=MAT['11 | leather seam thread']; EAR=MAT['12 | ear velvet']
BLACK=MAT['13 | nose claws and eye line']; AMBER=MAT['14 | amber eye']; PUPIL=MAT['15 | dark pupil']; GLINT=MAT['16 | eye glint']

def mesh(name,vs,fs,material,uv=None):
    me=bpy.data.meshes.new(name+' mesh'); me.from_pydata(vs,[],fs); me.update()
    o=bpy.data.objects.new(name,me); char.objects.link(o)
    if isinstance(material,list):
        for m in material: me.materials.append(m)
    else: me.materials.append(material)
    for p in me.polygons: p.use_smooth=True
    if uv:
        l=me.uv_layers.new(name='UVMap')
        for p in me.polygons:
            for li in p.loop_indices:
                co=list(uv[me.loops[li].vertex_index])
                us=[uv[me.loops[q].vertex_index][0] for q in p.loop_indices]
                if max(us)-min(us)>.5 and co[0]<.1:co[0]+=1
                l.data[li].uv=co
    meshes.append(o); return o

def active(o):
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o

def apply(o,mod):
    active(o); bpy.ops.object.modifier_apply(modifier=mod.name)

def unwrap(o):
    active(o); bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=1.15192,island_margin=.012)
    bpy.ops.object.mode_set(mode='OBJECT')

def finish(o,sub=0,solid=0,bevel=0):
    if sub:
        m=o.modifiers.new('Surface polish','SUBSURF'); m.levels=sub; m.render_levels=sub; apply(o,m)
    if solid:
        m=o.modifiers.new('Tailored fabric thickness','SOLIDIFY'); m.thickness=solid; m.offset=0; apply(o,m)
    if bevel:
        m=o.modifiers.new('Soft crafted edges','BEVEL'); m.width=bevel; m.segments=2; apply(o,m)
    if not o.data.uv_layers: unwrap(o)
    return o

def uv_sphere(name,center,scale,material,seg=24,rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=center)
    o=bpy.context.object; o.name=name; o.scale=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    move_col(o); o.data.materials.append(material)
    for p in o.data.polygons: p.use_smooth=True
    meshes.append(o); return o

def box(name,center,scale,material,bevel=.009):
    bpy.ops.mesh.primitive_cube_add(size=1,location=center); o=bpy.context.object; o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); move_col(o); o.data.materials.append(material); meshes.append(o)
    m=o.modifiers.new('Rounded craft edges','BEVEL'); m.width=bevel; m.segments=3; apply(o,m)
    for p in o.data.polygons: p.use_smooth=True
    m=o.modifiers.new('Weighted surface normals','WEIGHTED_NORMAL'); apply(o,m); unwrap(o)
    return o

def tube(name,path,radius,material,sides=8,cap=True):
    path=[Vector(p) for p in path]; vs=[]; uv=[]
    for i,p in enumerate(path):
        tan=(path[min(i+1,len(path)-1)]-path[max(0,i-1)]).normalized()
        a=tan.cross(Vector((0,1,0)))
        if a.length<.1: a=tan.cross(Vector((1,0,0)))
        a.normalize(); b=tan.cross(a).normalized()
        r=radius[i] if isinstance(radius,(tuple,list)) else radius
        for j in range(sides):
            ang=2*pi*j/sides; vs.append(tuple(p+r*(a*cos(ang)+b*sin(ang)))); uv.append((j/sides,i/max(1,len(path)-1)))
    fs=[]
    for i in range(len(path)-1):
        for j in range(sides): fs.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    if cap: fs.extend([tuple(reversed(range(sides))),tuple((len(path)-1)*sides+j for j in range(sides))])
    return mesh(name,vs,fs,material,uv)

def loft(name,rings,material,sides=32,cap=True,axis='Z',wrinkle=0):
    # rings: center, lateral radius, sagittal radius. Consistent human contours.
    vs=[]; uv=[]
    for i,(cen,rx,ry) in enumerate(rings):
        for j in range(sides):
            a=2*pi*j/sides; w=1+wrinkle*sin(a*5+i*1.31)*sin(i*pi/max(1,len(rings)-1))
            if axis=='Z': p=(cen[0]+cos(a)*rx*w,cen[1]+sin(a)*ry*w,cen[2])
            elif axis=='Y': p=(cen[0]+cos(a)*rx*w,cen[1],cen[2]+sin(a)*ry*w)
            vs.append(p); uv.append((j/sides,i/max(1,len(rings)-1)))
    fs=[]
    for i in range(len(rings)-1):
        for j in range(sides): fs.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    if cap: fs.extend([tuple(reversed(range(sides))),tuple((len(rings)-1)*sides+j for j in range(sides))])
    return mesh(name,vs,fs,material,uv)

def sweep(name,centers,radii,material,sides=20):
    centers=[Vector(c) for c in centers]; vs=[]; uv=[]
    for i,c in enumerate(centers):
        t=(centers[min(i+1,len(centers)-1)]-centers[max(0,i-1)]).normalized()
        a=Vector((0,1,0)); a=(a-t*t.dot(a)).normalized(); b=t.cross(a).normalized()
        r=radii[i]; rx,ry=r if isinstance(r,(tuple,list)) else (r,r)
        for j in range(sides):
            an=2*pi*j/sides; vs.append(tuple(c+a*cos(an)*ry+b*sin(an)*rx)); uv.append((j/sides,i/max(1,len(centers)-1)))
    fs=[]
    for i in range(len(centers)-1):
        for j in range(sides): fs.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    fs.extend([tuple(reversed(range(sides))),tuple((len(centers)-1)*sides+j for j in range(sides))])
    return mesh(name,vs,fs,material,uv)

def fuse(name,objects,voxel=.011,ratio=.7):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]; bpy.ops.object.join(); o=objects[0]; o.name=name
    m=o.modifiers.new('Continuous anatomy union','REMESH'); m.mode='VOXEL'; m.voxel_size=voxel; m.use_smooth_shade=True; apply(o,m)
    m=o.modifiers.new('Anatomical surface relaxation','SMOOTH'); m.factor=.55; m.iterations=4; apply(o,m)
    if ratio<1:
        m=o.modifiers.new('Game topology reduction','DECIMATE'); m.ratio=ratio; apply(o,m)
    for p in o.data.polygons: p.use_smooth=True
    unwrap(o); return o

# ------ Continuous body, limb and paw contours ------
parts=[]
torso=[((0,0,1.035),.147,.111),((0,.005,1.115),.175,.126),((0,0,1.22),.157,.112),((0,0,1.31),.152,.108),((0,-.004,1.42),.187,.128),((0,-.004,1.51),.219,.136),((0,0,1.586),.224,.117),((0,0,1.63),.184,.098)]
parts.append(loft('Anatomy | athletic torso',torso,FUR,sides=40))
parts.append(loft('Anatomy | continuous neck',[((0,.022,1.58),.097,.078),((0,.019,1.69),.084,.08),((0,.013,1.80),.086,.093),((0,.011,1.88),.095,.10)],CREAM,sides=32))
for s,side in [(-1,'R'),(1,'L')]:
    shoulder=(s*.213,.002,1.59); elbow=(s*.403,-.008,1.285); wrist=(s*.505,-.026,1.015)
    centers=[(s*.204,0,1.598),(s*.247,0,1.565),(s*.28,-.003,1.504),(s*.332,-.006,1.415),(s*.376,-.008,1.337),elbow,(s*.425,-.012,1.239),(s*.456,-.015,1.172),(s*.484,-.022,1.093),wrist]
    radii=[(.071,.074),(.073,.072),(.068,.062),(.062,.057),(.052,.048),(.048,.047),(.051,.045),(.050,.043),(.038,.033),(.030,.029)]
    parts.append(sweep('Anatomy | shaped arm.'+side,centers,radii,FUR,24))
    leg=[((s*.123,.009,1.12),.10,.103),((s*.137,.009,1.036),.102,.109),((s*.145,.005,.916),.085,.085),((s*.149,-.014,.785),.067,.069),((s*.151,-.025,.70),.057,.061),((s*.156,.014,.625),.069,.065),((s*.161,.027,.532),.067,.07),((s*.164,.021,.42),.051,.05),((s*.166,.012,.31),.038,.038),((s*.166,0,.235),.035,.039)]
    parts.append(loft('Anatomy | shaped leg.'+side,leg,FUR,sides=28))
    foot=loft('Anatomy | paw foot.'+side,[((s*.167,-.02,.005),.053,.106),((s*.167,-.025,.065),.060,.116),((s*.167,-.017,.108),.060,.112),((s*.167,-.012,.154),.056,.096),((s*.166,.003,.196),.038,.045),((s*.166,0,.244),.034,.038)],FUR,28)
    parts.append(foot)
    footparts=[foot];parts.remove(foot)
    for j in range(4):
        x=s*.167+(j-1.5)*.033; y=-.166-.014*(1-abs(j-1.5)/1.5)
        footparts.append(uv_sphere('Anatomy | toe '+side+str(j),(x,y,.047),(.0183,.047,.038),FUR,20,12))
    footmesh=fuse('FOOT | shaped four-toed paw.'+side,footparts,.0046,.10)
body=fuse('BODY | continuous skinned anatomy',parts,.014,.32)
# Matte cream on inner forearms, with warm ochre outer surfaces and charcoal nape.
body.data.materials.clear()
for m in [FUR,CREAM,SADDLE]: body.data.materials.append(m)
for p in body.data.polygons:
    c=p.center
    if c.z>1.69 and c.y<.013: p.material_index=1
    elif c.z>1.28 and c.y>.077 and abs(c.x)<.14: p.material_index=2
    elif False: p.material_index=1
    else:p.material_index=0

# ------ Purpose-built foxlike jackal skull; long narrow snout ------
# (Y, half width, lower Z, upper Z) sections taper steadily into the nose.
sec=[(.127,.040,1.862,2.043),(.11,.085,1.825,2.083),(.072,.122,1.805,2.125),(.021,.141,1.803,2.141),(-.032,.146,1.808,2.136),(-.082,.132,1.803,2.095),(-.126,.112,1.805,2.053),(-.17,.082,1.815,2.004),(-.2432,.063,1.825,1.960),(-.316,.047,1.839,1.942),(-.3706,.034,1.853,1.920),(-.3953,.022,1.865,1.910)]
vs=[]; uv=[]; n=40
for i,(y,w,z0,z1) in enumerate(sec):
    zc=(z0+z1)/2; rz=(z1-z0)/2
    for j in range(n):
        a=2*pi*j/n
        # cheek cheekbone flattening while keeping a refined long wedge muzzle
        x=cos(a)*w*(1+.022*cos(a*4)); z=zc+sin(a)*rz
        vs.append((x,y,z)); uv.append((j/n,i/(len(sec)-1)))
fs=[]
for i in range(len(sec)-1):
    for j in range(n): fs.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
fs.extend([tuple(reversed(range(n))),tuple((len(sec)-1)*n+j for j in range(n))])
head=mesh('HEAD | long jackal muzzle and sculpted skull',vs,fs,[MAT['17 | painted jackal face']],uv)
finish(head,sub=1)
# Eye projection uses the actual smoothed surface, avoiding guessed floating coordinates.
head_bvh=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
def project_face(p,n,offset=.001):
    hit,normal,idx,dist=head_bvh.ray_cast(Vector(p)+n*.20,-n,.5)
    return (hit+n*offset) if hit is not None else Vector(p)
# Jackal lower cheek/jaw lobes taper seamlessly into the muzzle.
for s,side in [(-1,'R'),(1,'L')]:
    # Mouth line held in a slight alert half-smile.
    mouth=tube('Defined mouth corner.'+side,[(s*.010,-.331,1.875),(s*.031,-.292,1.865),(s*.050,-.248,1.856),(s*.068,-.197,1.855),(s*.087,-.15,1.868)], [.0018,.0022,.0022,.0026,.0031],BLACK,8)
    # Fine follicle dots, actual mesh details rather than transparency cards.
    for k,(y,z) in enumerate([(-.26,1.893),(-.23,1.91),(-.215,1.886),(-.28,1.882)]):
        x=s*(.045+(.28+y)*.24)
        uv_sphere('Muzzle follicle.'+side+'.'+str(k),(x,y,z),(.00165,.0015,.00165),BLACK,8,6)
# Faceted heart-shaped dark nose with a readable nostril depression.
nose_vs=[(-.024,-.345,1.914),(.024,-.345,1.914),(.027,-.358,1.896),(.015,-.362,1.879),(-.015,-.362,1.879),(-.027,-.358,1.896),(-.019,-.330,1.895),(.019,-.330,1.895), (0,-.371,1.901)]
nose_fs=[(0,1,8),(1,2,8),(2,3,8),(3,4,8),(4,5,8),(5,0,8),(0,6,7,1),(1,7,2),(2,7,3),(3,7,6,4),(4,6,5),(5,6,0)]
nose=mesh('NOSE | shaped jackal nose',nose_vs,nose_fs,BLACK); finish(nose,sub=1)
for s,side in [(-1,'R'),(1,'L')]:
    uv_sphere('Nostril.'+side,(s*.0165,-.358,1.898),(.006,.003,.004),PUPIL,14,8)

# Extend face detail with the longer snout, keeping the skull/eyes unchanged.
for o in list(char.objects):
    if o.type=='MESH' and o.name.startswith(('NOSE','Nostril','Muzzle','Defined mouth')):
        mw=o.matrix_world.copy()
        for v in o.data.vertices:
            w=mw@v.co
            if w.y<-.16:w.y=-.16+(w.y+.16)*1.3
            v.co=mw.inverted()@w
# ------ Tall pointed ears, distinct outer shell and inset velvet ------
for s,side in [(-1,'R'),(1,'L')]:
    # Not round cones: custom curved ear rim with front concavity, tilted outward.
    profile=[(-.049,2.055),(-.075,2.111),(-.063,2.198),(-.028,2.293),(.008,2.358),(.025,2.340),(.048,2.251),(.063,2.151),(.050,2.078)]
    centerx=s*.077
    vs=[]
    # Local profile x is mirrored; ear backs are broad and swept rearward.
    for layer in [0,1]:
        for xx,zz in profile:
            x=centerx+s*xx; height=(zz-2.055)/.303
            y=.005+.037*height + (0 if layer==0 else .025*(1-height*.5))
            vs.append((x,y,zz))
    vs.extend([(centerx+s*.002,-.014,2.23),(centerx+s*.003,.052,2.22)])
    nn=len(profile); fs=[]
    for j in range(nn): fs.append((j,(j+1)%nn,2*nn)); fs.append((nn+j,2*nn+1,nn+(j+1)%nn));fs.append((j,nn+j,nn+(j+1)%nn,(j+1)%nn))
    ear=mesh('EAR | pointed outer shell.'+side,vs,fs,FUR); finish(ear,sub=1)
    # inner is in front of shell, tapered deep velvet region with cream rim hair.
    c=Vector((centerx+s*.004,-.020,2.200)); inner=[]
    for xx,zz in profile:
        v=Vector((centerx+s*xx,-.003+.036*(zz-2.055)/.303,zz))
        v=c+(v-c)*.77; v.y-=.004; inner.append(tuple(v))
    inner.append(tuple(c-Vector((0,.004,0))))
    ine=mesh('EAR | inset velvet.'+side,inner,[(j,(j+1)%nn,nn) for j in range(nn)],EAR); finish(ine,sub=1,solid=.002)
    # sculpted lower inner hair with a few clean, solid points
    fan=[(centerx-s*.022,-.021,2.108),(centerx+s*.030,-.012,2.143),(centerx+s*.019,-.032,2.16),(centerx+s*.031,-.009,2.20),(centerx+s*.008,-.030,2.185),(centerx+s*.011,-.007,2.257),(centerx-s*.003,-.029,2.210),(centerx-s*.014,-.011,2.236),(centerx-s*.019,-.025,2.157)]
    inn=mesh('EAR | cream inner fur.'+side,fan,[tuple(range(len(fan)))],CREAM); finish(inn,sub=1,solid=.002)

# ------ Amber almond eyes with dark lid silhouette ------
def eye_patch(name,center,hor,normal,rx,rz,material,bulge=.002,steps=32):
    layer=.001
    if 'amber almond' in name:layer=.0025
    if 'dark round iris' in name:layer=.0040
    if 'amber iris rim' in name:layer=.0050
    if 'vertical pupil' in name:layer=.0060
    bulge=.0007
    vs=[tuple(project_face(center,normal,layer+bulge))]; uv=[(.5,.5)]
    for j in range(steps):
        a=2*pi*j/steps
        # almond ellipse is slightly pinched at the corners and slanted outward.
        z=sin(a)*rz*(.82+.18*abs(sin(a))) + cos(a)*.002
        vs.append(tuple(project_face(center+hor*(cos(a)*rx)+Vector((0,0,z)),normal,layer)))
        uv.append((.5+cos(a)*.5,.5+sin(a)*.5))
    return mesh(name,vs,[(0,j+1,(j+1)%steps+1) for j in range(steps)],material,uv)
for s,side in [(-1,'R'),(1,'L')]:
    norm=Vector((s*.65,-.76,0)).normalized();hor=Vector((.76,s*.65,0)).normalized()
    c=project_face(Vector((s*.080,-.105,2.014)),norm,.0005)
    # flattering angular lids and amber cornea all lie on the same inset eye plane.
    ep=eye_patch('EYE | dark almond socket.'+side,c,hor,norm,.033,.017,BLACK,.003); finish(ep,sub=1)
    ep=eye_patch('EYE | amber almond.'+side,c+norm*.004,hor,norm,.029,.012,AMBER,.003); finish(ep,sub=1)
    iris_c=c+norm*.006+hor*(s*-.002)
    ep=eye_patch('EYE | dark round iris.'+side,iris_c,hor,norm,.009,.011,PUPIL,.0033)
    ep=eye_patch('EYE | amber iris rim.'+side,iris_c+norm*.0013,hor,norm,.0073,.0095,AMBER,.0035)
    ep=eye_patch('EYE | vertical pupil.'+side,iris_c+norm*.0028,hor,norm,.0057,.0091,PUPIL,.0037)
    uv_sphere('EYE | catchlight.'+side,project_face(iris_c+hor*-.003+Vector((0,0,.004)),norm,.0081),(.0016,.0016,.0016),GLINT,12,8)
    # sculpted ochre upper brow and cream lower cheekbone follow almond edge.
    bp=[]
    for j in range(9):
        a=pi*j/8
        bp.append(tuple(project_face(c+hor*(cos(a)*.034)+Vector((0,0,sin(a)*.016+.004)),norm,.002)))
    tube('BROW | alert brow.'+side,bp,[.0028,.0045,.006,.0062,.0062,.006,.005,.0035,.002],FUR,10)
    lp=[]
    for j in range(9):
        a=pi+pi*j/8
        lp.append(tuple(project_face(c+hor*(cos(a)*.031)+Vector((0,0,sin(a)*.016-.003)),norm,.0015)))
    tube('LID | lower ochre lid.'+side,lp,.0018,FUR,8)

# ------ Controlled sculpted fur tufts: clean stylized silhouette ------
def tuft(name,base,tip,width,depth,material):
    b=Vector(base); t=Vector(tip); d=(t-b).normalized()
    a=d.cross(Vector((0,1,0)))
    if a.length<.1:a=d.cross(Vector((1,0,0)))
    a.normalize(); c=d.cross(a).normalized(); mid=b+(t-b)*.39
    vs=[tuple(b+a*width),tuple(b-a*width),tuple(b+c*depth),tuple(b-c*depth),tuple(mid+a*width*.72+c*depth*.48),tuple(mid-a*width*.72+c*depth*.48),tuple(mid-c*depth*.72),tuple(t)]
    fs=[(0,2,4),(2,1,5,4),(1,3,6,5),(3,0,4,6),(4,5,7),(5,6,7),(6,4,7),(0,3,1,2)]
    o=mesh(name,vs,fs,material)
    crease=o.data.attributes.new('crease_edge','FLOAT','EDGE')
    for ed in o.data.edges:
        if 7 in ed.vertices:crease.data[ed.index].value=.67
    finish(o,sub=1); return o
for s,side in [(-1,'R'),(1,'L')]:
    tuft('FUR | upper cheek sweep.'+side,(s*.121,-.022,1.975),(s*.181,.006,1.914),.031,.021,FUR)
    for k,(b,t,w,dep) in enumerate([
        ((s*.108,-.044,1.93),(s*.163,-.030,1.894),.028,.015),
        ((s*.107,-.012,1.883),(s*.147,.014,1.845),.023,.013),
    ]):tuft('FUR | cream cheek tuft.'+side+str(k),b,t,w,dep,CREAM)
    for k in range(4):
        z=2.108-k*.068
        tuft('FUR | ochre nape tuft.'+side+str(k),(s*.070,.072,z),(s*(.127-k*.008),.138,z-.059),.034,.021,FUR if k<3 else SADDLE)
    for k in range(2):
        tuft('FUR | shoulder tuft.'+side+str(k),(s*(.25+k*.021),.021,1.563-k*.035),(s*(.307+k*.010),.030,1.529-k*.039),.027,.014,FUR)
    tuft('FUR | forearm crest.'+side,(s*.432,.013,1.24),(s*.48,.036,1.185),.025,.015,FUR)
    tuft('FUR | calf crest.'+side,(s*.178,.053,.593),(s*.213,.068,.538),.028,.013,FUR)
# A dark crown stripe and 3 small solid points identify the black-backed species.
for k in range(3):
    tuft('FUR | charcoal crown '+str(k),((k-1)*.022,.07,2.105),((k-1)*.027,.089,2.177-abs(k-1)*.019),.018,.012,SADDLE)

# ------ Anatomical hands with four digits and thumb, no mitten meshes ------
finger_specs={}
for s,side in [(-1,'R'),(1,'L')]:
    hp=[]
    palm_center=(s*.520,-.031,.954)
    palm=loft('HAND | palm.'+side,[((s*.505,-.026,1.024),.029,.026),((s*.515,-.030,.981),.038,.031),((s*.524,-.032,.942),.041,.029),((s*.528,-.033,.918),.036,.021)],FUR,24); hp.append(palm)
    for j,label in enumerate(['Index','Middle','Ring','Little']):
        x=s*(.493+j*.021); z=.928-.009*(j==3); length=[.090,.102,.095,.073][j]
        if side=='R':
            pts=[(x,-.035,z),(x,-.058,z-.037),(x,-.094,z-.046),(x,-.096,z-.014)]
        else:
            pts=[(x,-.040,z),(x+s*.006,-.059,z-length*.44),(x+s*.003,-.073,z-length*.83),(x-s*.002,-.082,z-length)]
        hp.append(sweep('HAND | '+label+'.'+side,pts,[.0108,.011,.009,.0068],FUR,12))
        finger_specs[(label,side)]=pts
        # very small solid black claw at each tip
        end=Vector(pts[-1]); direction=(end-Vector(pts[-2])).normalized()
        cl=tuft('CLAW | '+label+'.'+side,tuple(end-direction*.008),tuple(end+direction*.015),.006,.004,BLACK)
    if side=='R':pts=[(s*.486,-.037,.975),(s*.475,-.066,.949),(s*.481,-.103,.946),(s*.496,-.107,.934)]
    else:pts=[(s*.486,-.04,.978),(s*.461,-.061,.953),(s*.455,-.075,.923),(s*.460,-.082,.908)]
    hp.append(sweep('HAND | Thumb.'+side,pts,[.016,.013,.011,.008],FUR,14));finger_specs[('Thumb',side)]=pts
    end=Vector(pts[-1]); direction=(end-Vector(pts[-2])).normalized(); tuft('CLAW | Thumb.'+side,tuple(end-direction*.008),tuple(end+direction*.015),.007,.004,BLACK)
    hand=fuse('HAND | continuous palm and digits.'+side,hp,.0045,.32)
    for j in range(4):
        x=s*.167+(j-1.5)*.033; y=-.201-.014*(1-abs(j-1.5)/1.5)
        tuft('CLAW | toe.'+side+str(j),(x,y,.067),(x,y-.021,.027),.010,.007,BLACK)

# ------ Tail with broad black saddle and warm side planes ------
tail_points=[(0,.087,1.10),(.008,.176,1.054),(.019,.29,.958),(.035,.402,.831),(.061,.489,.694),(.100,.541,.583),(.133,.568,.516)]
tail_r=[(.043,.044),(.074,.080),(.096,.09),(.105,.101),(.092,.092),(.061,.061),(.003,.003)]
tail=sweep('TAIL | medium bushy skinned tail',tail_points,tail_r,[FUR,SADDLE,CREAM],32)
for p in tail.data.polygons:
    c=p.center
    # Dark outer dorsal saddle continues onto the tail; ochre lateral and cream underside.
    ring=min(max(int(p.index/32),0),len(tail_points)-2)
    cp=Vector(tail_points[ring])
    p.material_index=1 if cos(2*pi*((p.index%32)+.5)/32)>.15 else (2 if cos(2*pi*((p.index%32)+.5)/32)<-.7 else 0)
finish(tail,sub=1)
for i in range(1,6):
    b=Vector(tail_points[i]); r=tail_r[i][0]
    for s,side in [(-1,'R'),(1,'L')]:
        tuft('FUR | tail edge.'+side+str(i),tuple(b+Vector((s*r*.6,0,0))),tuple(b+Vector((s*(r+.029),.045,-.069))),r*.42,.021,FUR)
    tuft('FUR | tail dorsal '+str(i),tuple(b+Vector((0,.012,r*.55))),tuple(b+Vector((.004,.068,r*.6-.056))),r*.37,.021,SADDLE)

# ------ Tailored sleeveless leather jerkin: real open neckline and arm holes ------
vest_rows=[(1.124,.032,.19,.138),(1.18,.020,.184,.136),(1.254,.009,.169,.12),(1.325,.012,.171,.122),(1.40,.025,.195,.143),(1.481,.045,.218,.151),(1.548,.073,.214,.142),(1.599,.099,.193,.116),(1.647,.091,.142,.098)]
for s,side in [(-1,'R'),(1,'L')]:
    for back in [False,True]:
        vs=[]; uv=[]; cols=12
        for i,(z,inner,outer,dep) in enumerate(vest_rows):
            if back: inner=(.025 if z<1.254 else (.054 if z<1.4 else .081))
            for j in range(cols):
                f=j/(cols-1); x=inner+(outer-inner)*f
                # Tailored sides curl around body; shoulder tops are distinct straps.
                maxr=outer+(.017 if z<1.55 else .026)
                y=dep*sqrt(max(.12,1-(x/maxr)**2))*(1 if back else -1)
                zz=z + (.017*(1-f) if i==0 else 0)
                if back and i==0:zz+=.025
                vs.append((s*x,y,zz));uv.append((f,i/(len(vest_rows)-1)))
        fs=[]
        for i in range(len(vest_rows)-1):
            for j in range(cols-1):
                face=(i*cols+j,i*cols+j+1,(i+1)*cols+j+1,(i+1)*cols+j)
                if (s<0)^back:face=tuple(reversed(face))
                fs.append(face)
        v=mesh('JERKIN | '+('back ' if back else 'front ')+side,vs,fs,LEATHER,uv); finish(v,sub=1,solid=.006)
        # top-to-bottom seam outlines on front create readable craft without noisy detail.
        if not back:
            for edge in ['inner','outer']:
                path=[]
                for i,(z,inner,outer,dep) in enumerate(vest_rows):
                    x=inner if edge=='inner' else outer; maxr=outer+(.017 if z<1.55 else .026)
                    y=-dep*sqrt(max(.12,1-(x/maxr)**2))-.004
                    zz=z+(.017 if i==0 and edge=='inner' else 0)
                    path.append((s*x,y,zz))
                tube('JERKIN | stitched '+edge+' edge.'+side,path,.0022,THREAD,8)
        # crafted shoulder cap connecting front to back with a rounded leather band
    points=[]
    for j in range(15):
        t=j/14; y=-.104+.213*t; z=1.642+.026*sin(pi*t)
        points.append((s*.127,y,z))
    vs=[];uv=[]
    for i,p in enumerate(points):
        for k in [-1,1]:vs.append((p[0]+k*.020,p[1],p[2]));uv.append(((k+1)/2,i/(len(points)-1)))
    sh=mesh('JERKIN | shoulder strap.'+side,vs,[(i*2,i*2+1,(i+1)*2+1,(i+1)*2) for i in range(len(points)-1)],LEATHER,uv);finish(sh,sub=1,solid=.008)
    for k in [-1,1]:tube('JERKIN | shoulder piping.'+side+str(k),[(p[0]+k*.018,p[1],p[2]+.004) for p in points],.0021,THREAD,8)
    for j in [2,6,10]:uv_sphere('JERKIN | brass shoulder rivet.'+side+str(j),(s*.128,points[j][1]-.001,points[j][2]+.006),(.004,.004,.0022),BRASS,12,8)
# four simple leather ties across front opening
for i,z in enumerate([1.258,1.335,1.407,1.473]):
    x=[.022,.025,.039,.056][i]; y=-[.123,.126,.143,.151][i]-.007
    for s in [-1,1]:uv_sphere('JERKIN | closure stud '+str(i)+str(s),(s*x,y,z),(.0042,.0025,.0042),BRASS,12,8)
    tube('JERKIN | crossing lace '+str(i),[(-x,y-.002,z+.005),(0,y-.007,z-.006),(x,y-.002,z+.005)],.0025,THREAD,8)
# belt follows waist, with actual rectangular buckle and holes
belt=loft('BELT | waist leather belt',[((0,0,1.178),.188,.143),((0,0,1.23),.178,.136)],WRAP,64,False);finish(belt,solid=.007,bevel=.001)
for z,rx,ry in [(1.181,.188,.144),(1.225,.179,.138)]:
    tube('BELT | stitched perimeter '+str(z),[(cos(2*pi*i/64)*rx,sin(2*pi*i/64)*ry,z) for i in range(65)],.0014,THREAD,6)
for i in range(5):uv_sphere('BELT | punched hole '+str(i),(-.040-i*.017,-.144+(.04+i*.017)**2*.66,1.204),(.0023,.0012,.0023),BLACK,8,6)
for name,p in [('top',[(-.032,-.154,1.226),(.032,-.154,1.226)]),('bottom',[(-.032,-.154,1.181),(.032,-.154,1.181)]),('left',[(-.032,-.154,1.181),(-.032,-.154,1.226)]),('right',[(.032,-.154,1.181),(.032,-.154,1.226)])]:tube('BELT | brass buckle '+name,p,.0045,BRASS,10)
tube('BELT | buckle prong',[(0,-.158,1.203),(-.027,-.159,1.203)],.0025,BRASS,8)
# One pouch, anatomical left hip.
pouch=box('POUCH | single left belt pouch',(.217,-.065,1.16),(.103,.080,.143),LEATHER,.015)
flap=box('POUCH | rounded flap',(.219,-.111,1.187),(.100,.019,.087),LEATHER,.012)
tube('POUCH | stitched flap seam',[(.177,-.123,1.210),(.177,-.123,1.160),(.186,-.123,1.149),(.250,-.123,1.149),(.261,-.123,1.16),(.261,-.123,1.21)],.0018,THREAD,6)
box('POUCH | closing strap',(.220,-.125,1.17),(.022,.007,.069),WRAP,.004)
box('POUCH | small brass clasp',(.220,-.132,1.166),(.021,.004,.019),BRASS,.003)

# Broad charcoal fur saddle visible through the jerkin's open back.
vs=[];uv=[]
for i,(z,w,d) in enumerate([(1.256,.027,.121),(1.34,.06,.128),(1.45,.09,.145),(1.56,.098,.136),(1.626,.07,.108)]):
    for j in range(13):
        f=(j/12)*2-1;x=f*w;y=d+.006-.014*f*f
        vs.append((x,y,z));uv.append((j/12,i/4))
fs=[(i*13+j,i*13+j+1,(i+1)*13+j+1,(i+1)*13+j) for i in range(4) for j in range(12)]
sad=mesh('FUR | charcoal back saddle',vs,fs,SADDLE,uv);finish(sad,sub=1,solid=.003)
for sign in [-1,1]:
    for k in range(3):
        tuft('FUR | saddle edge '+str(sign)+str(k),(sign*(.066-k*.01),.143,1.51-k*.07),(sign*(.084-k*.015),.150,1.46-k*.07),.025,.006,SADDLE)
# ------ Linen shorts with continuous crotch and folded cuffs ------
pants=[loft('SHORTS | linen pelvis coverage',[((0,.004,1.00),.153,.124),((0,.004,1.045),.170,.138),((0,.005,1.135),.185,.141),((0,0,1.188),.182,.140)],LINEN,36)]
for s,side in [(-1,'R'),(1,'L')]:
    rings=[((s*.089,.005,1.188),.109,.137),((s*.104,.002,1.122),.120,.137),((s*.126,.002,1.04),.112,.126),((s*.139,-.001,.956),.104,.11),((s*.144,-.006,.864),.095,.10),((s*.148,-.009,.777),.096,.098),((s*.149,-.010,.748),.10,.098)]
    pants.append(loft('SHORTS | '+side+' linen leg',rings,LINEN,32,True,wrinkle=.035))
shorts=fuse('SHORTS | coherent linen knee shorts',pants,.012,.42)
for s,side in [(-1,'R'),(1,'L')]:
    cuff=loft('SHORTS | folded cuff.'+side,[((s*.149,-.01,.745),.101,.10),((s*.149,-.01,.756),.107,.103),((s*.148,-.01,.790),.106,.102),((s*.148,-.01,.797),.10,.098)],LINEN,40,False,wrinkle=.025);finish(cuff,solid=.005)
    tube('SHORTS | outer seam.'+side,[(s*.228,.029,1.148),(s*.242,.031,1.073),(s*.244,.023,.97),(s*.244,.014,.89),(s*.246,.003,.80)],.0018,THREAD,6)
    # a small stitch at the folded cuff edge
    tube('SHORTS | cuff seam.'+side,[(s*.149+cos(2*pi*i/40)*.108,-.01+sin(2*pi*i/40)*.104,.767) for i in range(41)],.0011,THREAD,6)

# ------ Olive scarf with fitted neck roll and a tucked triangular drape ------
vs=[];uv=[];ns=48;nr=6
for k in range(nr):
    t=k/(nr-1)
    for j in range(ns):
        a=2*pi*j/ns;front=max(0,-sin(a));rx=.096+.022*sin(pi*t);ry=.10+.025*sin(pi*t)
        z=1.781-t*.113-front*(.039+.021*sin(pi*t)) + .005*sin(a*3+t*5)
        vs.append((cos(a)*rx,sin(a)*ry+.013,z));uv.append((j/ns,t))
fs=[]
for k in range(nr-1):
    for j in range(ns):fs.append((k*ns+j,k*ns+(j+1)%ns,(k+1)*ns+(j+1)%ns,(k+1)*ns+j))
sc=mesh('SCARF | layered neck wrap',vs,fs,SCARF,uv);finish(sc,sub=1,solid=.004)
vs=[];uv=[];nrow=9;nc=15
for i in range(nrow):
    t=i/(nrow-1);width=.101*(1-t)+.006*t
    for j in range(nc):
        f=2*j/(nc-1)-1;x=width*f;z=1.715-.247*t
        y=-.134-.036*sin(pi*t*.8)-.009*cos(f*pi*3)*(1-t)
        vs.append((x,y,z));uv.append((j/(nc-1),t))
fs=[]
for i in range(nrow-1):
    for j in range(nc-1):fs.append((i*nc+j,i*nc+j+1,(i+1)*nc+j+1,(i+1)*nc+j))
bib=mesh('SCARF | tucked pointed front',vs,fs,SCARF,uv);finish(bib,sub=1,solid=.004)
for sign in [-1,1]:
    path=[]
    for i in range(12):
        t=i/11;x=sign*(.101*(1-t)+.006*t);z=1.715-.247*t;y=-.136-.036*sin(pi*t*.8)+.009*(1-t)
        path.append((x,y,z))
    tube('SCARF | hem edge '+str(sign),path,.0015,SCARF,6)
# A few raised folds, following the scarf rather than floating above the chest.
for k in range(3):
    path=[]
    for i in range(17):
        a=pi+pi*i/16; x=cos(a)*(.104+k*.004);y=.008+sin(a)*(.118+k*.001)
        z=1.755-k*.028-max(0,-sin(a))*.044
        path.append((x,y-.002,z))
    tube('SCARF | soft fold '+str(k),path,.0042,SCARF,10)

# ------ Wrist and ankle wraps with a visible layered winding ------
for s,side in [(-1,'R'),(1,'L')]:
    centers=[(s*.473,-.020,1.119),(s*.49,-.023,1.071),(s*.51,-.028,1.011)]
    wrap=sweep('WRAP | fitted wrist.'+side,centers,[(.040,.036),(.037,.033),(.033,.031)],WRAP,28);finish(wrap,sub=1)
    A=Vector(centers[0]);B=Vector(centers[-1]);d=(B-A).normalized();ax=Vector((0,1,0));bx=d.cross(ax).normalized();path=[]
    for i in range(61):
        t=i/60;c=A+(B-A)*t;r=.040*(1-t)+.034*t;a=t*2*pi*3.7
        path.append(tuple(c+(ax*cos(a)+bx*sin(a))*r))
    tube('WRAP | wrist spiral.'+side,path,.0022,WRAP,6)
    ank=loft('WRAP | fitted ankle.'+side,[((s*.166,.013,.229),.040,.045),((s*.166,.013,.254),.043,.046),((s*.166,.013,.345),.048,.052),((s*.166,.013,.38),.048,.051)],WRAP,32,False);finish(ank,solid=.004)
    path=[]
    for i in range(61):
        t=i/60;a=t*pi*2*4.2;r=.043+.007*t
        path.append((s*.166+cos(a)*r,.013+sin(a)*(r+.004),.236+.141*t))
    tube('WRAP | ankle spiral.'+side,path,.0025,WRAP,6)
    # diagonal foot wraps leave toe/claw silhouette exposed
    for k in range(2):
        path=[]
        for i in range(17):
            t=i/16;ang=pi*t;x=s*.167+cos(ang)*.067;y=-.082+k*.041-.016*cos(ang);z=.11+sin(ang)*.055
            path.append((x,y,z))
        tube('WRAP | foot strap.'+side+str(k),path,.009,WRAP,12)

# ------ Single short utilitarian machete, in anatomical RIGHT hand ------
# Grip axis follows -Y, the blade has one visibly sharpened convex edge.
wp=[]
wp.append(sweep('MACHETE | leather grip',[(-.519,.039,.935),(-.519,.005,.935),(-.519,-.055,.935),(-.519,-.117,.935)],[(.015,.015),(.014,.014),(.013,.013),(.016,.016)],WRAP,20))
wp.append(sweep('MACHETE | wooden butt cap',[(-.519,.033,.935),(-.519,.049,.935)],[(.018,.017),(.021,.019)],LEATHER,20))
for i in range(8):
    yy=.028-i*.018
    wp.append(tube('MACHETE | grip winding '+str(i),[(-.519+cos(2*pi*j/20)*.015,yy+sin(2*pi*j/20)*.002,.935+sin(2*pi*j/20)*.015) for j in range(21)],.0018,WRAP,6))
wp.append(box('MACHETE | simple iron guard',(-.519,-.125,.935),(.039,.014,.082),STEEL,.006))
# Blade outline ordered; flat spine, gently swept utilitarian cutting edge.
outline=[(-.132,.966),(-.41,.966),(-.562,.968),(-.587,.949),(-.563,.907),(-.518,.872),(-.455,.865),(-.285,.879),(-.133,.897)]
vs=[]
for xx in [-.523,-.515]:
    for yy,zz in outline:vs.append((xx,yy,zz))
n=len(outline);fs=[tuple(reversed(range(n))),tuple(n+j for j in range(n))]
for j in range(n):fs.append((j,(j+1)%n,(j+1)%n+n,j+n))
blade=mesh('MACHETE | single edged steel blade',vs,fs,STEEL);finish(blade,bevel=.0015);wp.append(blade)
# Narrow sharpened edge is a separate metal strip; all follow the same hand bone.
vs=[]
edge_outline=outline[3:]+[outline[0]]
for yy,zz in edge_outline:
    vs.extend([(-.524,yy,zz),(-.524,yy,zz+.009)])
es=mesh('MACHETE | sharpened cutting bevel',vs,[(i*2,i*2+1,(i+1)*2+1,(i+1)*2) for i in range(len(edge_outline)-1)],EDGE);finish(es,solid=.001);wp.append(es)
# rivets on the utilitarian blade root, not ornament
for yy in [-.14,-.158]:wp.append(uv_sphere('MACHETE | root rivet '+str(yy),(-.525,yy,.940),(.002,.003,.003),BRASS,10,6))


# Game density budget: retain feature contours, reduce oversampled flat/fold surfaces.
for o in list(char.objects):
    if o.type!='MESH':continue
    n=o.name
    if n.startswith(('BODY','HEAD','HAND','FOOT','EYE','BROW','LID','NOSE','Nostril','Cream cheek','Muzzle','Defined mouth','CLAW')):continue
    if len(o.data.polygons)<35:continue
    m=o.modifiers.new('Game detail density','DECIMATE');m.ratio=.50;apply(o,m)

# ------ Native humanoid deform skeleton with finger and tail chains ------
rig_data=bpy.data.armatures.new('Jackal Scout humanoid skeleton')
rig=bpy.data.objects.new('RIG | JackalScout humanoid',rig_data);char.objects.link(rig);rig.show_in_front=True
active(rig);bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None,connected=False,deform=True):
    eb=rig_data.edit_bones.new(name);eb.head=head;eb.tail=tail;eb.use_deform=deform
    if parent:eb.parent=rig_data.edit_bones[parent];eb.use_connect=connected
    bone_specs[name]=(Vector(head),Vector(tail));return eb
bone('Root',(0,0,0),(0,0,.20),deform=False)
bone('Hips',(0,0,1.105),(0,0,1.236),'Root')
bone('Spine',(0,0,1.236),(0,0,1.416),'Hips',True)
bone('Chest',(0,0,1.416),(0,0,1.623),'Spine',True)
bone('Neck',(0,0,1.623),(0,.010,1.822),'Chest',True)
bone('Head',(0,.010,1.822),(0,.015,2.135),'Neck',True)
for s,side in [(-1,'R'),(1,'L')]:
    bone('Shoulder.'+side,(s*.045,0,1.589),(s*.213,.002,1.59),'Chest')
    bone('UpperArm.'+side,(s*.213,.002,1.59),(s*.403,-.008,1.285),'Shoulder.'+side,True)
    bone('LowerArm.'+side,(s*.403,-.008,1.285),(s*.505,-.026,1.015),'UpperArm.'+side,True)
    bone('Hand.'+side,(s*.505,-.026,1.015),(s*.528,-.033,.924),'LowerArm.'+side,True)
    bone('UpperLeg.'+side,(s*.123,.009,1.105),(s*.151,-.025,.70),'Hips')
    bone('LowerLeg.'+side,(s*.151,-.025,.70),(s*.166,0,.235),'UpperLeg.'+side,True)
    bone('Foot.'+side,(s*.166,0,.235),(s*.166,-.125,.104),'LowerLeg.'+side,True)
    bone('Toes.'+side,(s*.166,-.125,.104),(s*.166,-.222,.087),'Foot.'+side,True)
    for label in ['Thumb','Index','Middle','Ring','Little']:
        pts=finger_specs[(label,side)]
        for j in range(3):bone(label+str(j+1)+'.'+side,pts[j],pts[j+1],('Hand.'+side if j==0 else label+str(j)+'.'+side),j>0)
for i in range(4):
    h=tail_points[[0,2,3,4][i]];t=tail_points[[2,3,4,6][i]]
    bone('Tail'+str(i+1),h,t,'Hips' if i==0 else 'Tail'+str(i),i>0)
bpy.ops.object.mode_set(mode='OBJECT')
rig_data.display_type='OCTAHEDRAL';rig['character']='Jackal Scout, black-backed jackal'
rig['weapon_hand']='Anatomical RIGHT (Hand.R, source -X side)'
rig['rest_front']='Blender -Y; glTF +Z after standard axis conversion'
rig['pipeline']='Blender native surface modeling, painted/generated PBR texture maps, analytical skinning and authored poses'
# Named bone collections make editing simple in Blender 4.x.
for cname,selector in [('Torso',lambda n:n in ['Root','Hips','Spine','Chest','Neck','Head']),('Arms',lambda n:any(q in n for q in ['Shoulder','UpperArm','LowerArm','Hand'])),('Legs',lambda n:any(q in n for q in ['UpperLeg','LowerLeg','Foot','Toes'])),('Digits',lambda n:any(n.startswith(q) for q in ['Thumb','Index','Middle','Ring','Little'])),('Tail',lambda n:n.startswith('Tail'))]:
    c=rig_data.collections.new(cname)
    for b in rig_data.bones:
        if selector(b.name):c.assign(b)

def seg_dist(v,a,b):
    d=b-a;t=max(0,min(1,(v-a).dot(d)/max(d.length_squared,1e-9)))
    return (v-(a+d*t)).length,t

def torso_weights(v):
    z=v.z
    if z<1.16:return {'Hips':1}
    if z<1.34:
        t=max(0,min(1,(z-1.16)/.18));return {'Hips':1-t,'Spine':t}
    if z<1.51:
        t=(z-1.34)/.17;return {'Spine':1-t,'Chest':t}
    if z<1.68:return {'Chest':1}
    if z<1.83:
        t=(z-1.68)/.15;return {'Neck':1-t*.55,'Head':t*.55}
    return {'Head':1}

def nearest_weights(v,names,power=4,only2=True):
    ds=[]
    for name in names:
        a,b=bone_specs[name];d,t=seg_dist(v,a,b);ds.append((max(d,.008),name))
    ds.sort();ds=ds[:2] if only2 else ds[:3]
    ws=[d**(-power) for d,n in ds];total=sum(ws)
    return {n:w/total for (d,n),w in zip(ds,ws)}

def auto_weights(o):
    name=o.name
    if name.startswith('MACHETE'):return lambda v:{'Hand.R':1}
    if name.startswith(('HEAD','EAR','EYE','BROW','LID','NOSE','Nostril','Muzzle','Cream cheek','Defined mouth','FUR | cream cheek','FUR | ochre nape','FUR | charcoal crown','FUR | upper cheek')):return lambda v:{'Head':1}
    if name.startswith('SCARF'):return lambda v:torso_weights(v)
    if name.startswith(('JERKIN','BELT','POUCH')):return lambda v:torso_weights(v) if not name.startswith(('BELT','POUCH')) else {'Hips':1}
    if name.startswith(('TAIL','FUR | tail')):return lambda v:nearest_weights(v,['Tail1','Tail2','Tail3','Tail4'],3)
    if name.startswith('WRAP | foot'):return lambda v:{'Foot.'+('R' if v.x<0 else 'L'):1}
    if name.startswith('CLAW | toe'):return lambda v:{'Toes.'+('R' if v.x<0 else 'L'):1}
    if name.startswith('CLAW | '):
        parts=name.split(' | ')[1].split('.'); lab,side=parts[0],parts[1];return lambda v:{lab+'3.'+side:1}
    if name.startswith('WRAP | ankle'):return lambda v:{'LowerLeg.'+('R' if v.x<0 else 'L'):1}
    if name.startswith(('WRAP | wrist','WRAP | fitted wrist')):return lambda v:nearest_weights(v,['LowerArm.'+('R' if v.x<0 else 'L'),'Hand.'+('R' if v.x<0 else 'L')],4)
    def general(v):
        side='R' if v.x<0 else 'L'
        if name.startswith('HAND'):
            n=['Hand.'+side]+[l+str(i)+'.'+side for l in ['Thumb','Index','Middle','Ring','Little'] for i in [1,2,3]]
            return nearest_weights(v,n,5)
        if name.startswith('SHORTS'):
            if v.z>1.12:return {'Hips':1}
            t=max(0,min(1,(1.12-v.z)/.13));return {'Hips':1-t,'UpperLeg.'+side:t}
        if v.z<1.12 and abs(v.x)<.28:
            return nearest_weights(v,['UpperLeg.'+side,'LowerLeg.'+side,'Foot.'+side,'Toes.'+side],5)
        if abs(v.x)>.215 and v.z>.84:
            return nearest_weights(v,['UpperArm.'+side,'LowerArm.'+side,'Hand.'+side,'Shoulder.'+side],4)
        return torso_weights(v)
    return general

for o in list(char.objects):
    if o.type!='MESH':continue
    rule=auto_weights(o);groups={}
    # World coordinates for primitives and local coordinates for custom meshes are unified here.
    for vert in o.data.vertices:
        v=o.matrix_world@vert.co; weights=rule(v)
        for n,w in weights.items():
            if w<.002:continue
            if n not in groups:groups[n]=o.vertex_groups.new(name=n)
            groups[n].add([vert.index],w,'REPLACE')
    m=o.modifiers.new('Jackal humanoid skin','ARMATURE');m.object=rig;m.use_deform_preserve_volume=False
    o.parent=rig
    o['export_role']='skinned character mesh' if not o.name.startswith('MACHETE') else 'rigid right-hand weapon skin'

# ------ Clean studio presentation; this collection is excluded from GLB ------
mat('PRESENTATION | slate',(.055,.07,.065),rough=.94)
# Non-export ground.
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.010));floor=bpy.context.object;floor.name='Studio ground';move_col(floor,pres);floor.data.materials.append(MAT['PRESENTATION | slate'])
world=bpy.data.worlds.new('Soft studio ambience');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.22,.25,1);world.node_tree.nodes['Background'].inputs[1].default_value=.35;scene.world=world

def area(name,loc,power,size,color):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size;data.color=color
    o=bpy.data.objects.new(name,data);pres.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1.2))-o.location).to_track_quat('-Z','Y').to_euler();return o
area('Key | warm softbox',(-3,-4,5),470,3.0,(1.0,.86,.68))
area('Fill | broad neutral',(3,-2,3),280,3.5,(.71,.83,1.0))
area('Rim | warm back edge',(1,3,4),620,2.4,(1.0,.72,.43))
area('Face | soft catchlight',(-.3,-3,2.8),70,1.5,(1,.95,.83))
camdata=bpy.data.cameras.new('Portrait camera');cam=bpy.data.objects.new('Portrait camera',camdata);pres.objects.link(cam)
cam.location=(3.5,-6.5,3.15);target=Vector((0,.0,1.22));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();camdata.type='ORTHO';camdata.ortho_scale=2.88;scene.camera=cam
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
# A human-readable note travels with the .blend.
readme=bpy.data.texts.new('START HERE | Jackal Scout')
readme.write('JACKAL SCOUT\nNative Blender skinned game character.\n\nFacing source -Y, anatomical RIGHT is -X / Hand.R.\nOne machete; left hand empty. Packed PBR texture images.\nPresentation lights/camera are excluded from GLB.\n\nRun build_jackal.py with Blender 4.3.2 to reproduce geometry.\nAnimations are authored in the separate animation stage.\n')
# Viewport for direct review.
active(rig)
for a in bpy.context.screen.areas if bpy.context.screen else []:
    if a.type=='VIEW_3D':
        a.spaces.active.region_3d.view_distance=3.7;a.spaces.active.region_3d.view_location=Vector((0,0,1.22));a.spaces.active.shading.type='MATERIAL'
scene.frame_start=1;scene.frame_end=60;scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'jackal_scout_working.blend'))
scene.render.filepath=str(OUT/'previews'/'final_base_threequarter.png')
bpy.ops.render.render(write_still=True)
cam.location=(0,-6,2.90);cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/'previews'/'final_base_front.png');bpy.ops.render.render(write_still=True)
cam.location=(6,0,2.9);cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(OUT/'previews'/'final_base_profile.png');bpy.ops.render.render(write_still=True)
cam.location=(2.0,-4.5,2.40);face_target=Vector((0,-.05,2.04));cam.rotation_euler=(face_target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.77;scene.cycles.samples=32;scene.render.filepath=str(OUT/'previews'/'final_face.png');bpy.ops.render.render(write_still=True)
# Statistics used by the animation and validation stages.
stats={'mesh_objects':len([o for o in char.objects if o.type=='MESH']),'vertices':sum(len(o.data.vertices) for o in char.objects if o.type=='MESH'),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in char.objects if o.type=='MESH'),'bones':len(rig.data.bones),'materials':len([m for m in bpy.data.materials if not m.name.startswith('PRESENTATION')])}
(OUT/'model_counts.json').write_text(json.dumps(stats,indent=2))
print('JACKAL MODEL COMPLETE',stats,flush=True)
