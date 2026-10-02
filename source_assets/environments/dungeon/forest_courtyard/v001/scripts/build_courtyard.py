"""Forest courtyard assembled from the user's item2.blend, in a fresh process.
Art dimensions and lighting only. No gameplay configuration or engine files.
"""
import bpy,bmesh,math,random,json,sys,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform
import numpy as np

BASE=Path('E:/ShopGame/source_assets/environments/dungeon/forest_courtyard/v001')
SOURCE=Path('E:/ShopGame/source_assets/characters/red_panda/blender/item2.blend')
SHARED=Path('E:/ShopGame/source_assets/environments/dungeon/shared')
sys.path.insert(0,str(SHARED/'scripts'))
from room_kit import Kit,enum
from room_foliage import _Geometry,_leaf,fern
assert bpy.app.background
kit=Kit('forest_courtyard/v001',270927);kit.dir=BASE
s=kit.scene;s.name='Forest_Courtyard_Item2_v001';rng=random.Random(270927)
IDS={
'rail':'e1d52510-bdaf-4998-a4ff-2e5695223a85',
'ivy':'738cffd6-948f-4d6f-87e3-1c13fa4187bc',
'flowers':'115c48f7-0bd2-42f7-891a-cd0c6f8bac05',
'flowerpot':'616287b3-b6ea-477c-98bd-52087b9d563c',
'statue':'fc0c452e-9249-4128-a768-9aa9497ee7d0',
'lantern':'cf33c108-6e2a-4dc3-852f-70f26a56023a',
'banner':'8699bc23-8e8d-4983-a663-33ff118c3da3',
'broken_wall':'ba956f36-4051-4087-a2ba-15b622e9bb75',
'stairs':'86cfab13-f1e3-42c3-9c47-d59979d63457',
'corner':'37f091a1-93ce-490e-ab23-2dd5cc2d41e4',
'shrine':'2759e1c7-e152-4b7b-8389-bf8bfc3e4cc2',
'pillar':'6d00c541-9c1e-42f5-bdd1-3475b0d613d0',
'arch':'5f2e94b5-7733-4499-9e3e-d6fbc5dcda57',
'bridge':'ef6632ad-5997-4333-a080-b492a7b4b3fb',
'oak':'oak tree 3d model'}
with bpy.data.libraries.load(str(SOURCE),link=False) as (src,dst):
    assert all(name in src.objects for name in IDS.values())
    dst.objects=list(IDS.values())
prototypes={};sizes={};source_use={k:0 for k in IDS};loaded={o.name:o for o in dst.objects}
for key,name in IDS.items():
    obj=loaded[name]
    mesh=obj.data
    # Source front +X becomes the courtyard front -Y. All pivots bottom-centre.
    rotation=Matrix.Rotation(-math.pi/2,4,'Z')
    mesh.transform(rotation);mesh.update()
    verts=[v.co for v in mesh.vertices]
    low=Vector([min(v[a] for v in verts) for a in range(3)])
    high=Vector([max(v[a] for v in verts) for a in range(3)])
    offset=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
    mesh.transform(Matrix.Translation(-offset));sizes[key]=high-low
    mesh.name='Item2_'+key+'_shared_mesh';prototypes[key]=mesh
    bpy.data.objects.remove(obj,do_unlink=True)

def asset(key,name,loc,dim=None,height=None,angle=0,group='Architecture'):
    obj=bpy.data.objects.new(name,prototypes[key]);kit.collection(group).objects.link(obj)
    obj.location=loc;obj.rotation_euler.z=angle
    if dim:obj.scale=tuple(dim[i]/sizes[key][i] for i in range(3))
    elif height:obj.scale=(height/sizes[key].z,)*3
    obj['source_file']='item2.blend';obj['source_object']=IDS[key];obj['asset_role']=key
    source_use[key]+=1;return obj

def principled(mat):return next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
for key,mesh in prototypes.items():
    for mat in mesh.materials:
        if not mat or not mat.use_nodes:continue
        mat.name='Item2_'+key+'_PBR';p=principled(mat);nodes=mat.node_tree.nodes;links=mat.node_tree.links
        for link in list(p.inputs['Normal'].links):links.remove(link)
        tex=nodes.new('ShaderNodeTexCoord');noise=nodes.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value=85;noise.inputs['Detail'].default_value=3
        links.new(tex.outputs['Generated'],noise.inputs['Vector'])
        bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.22;bump.inputs['Distance'].default_value=.006
        links.new(noise.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],p.inputs['Normal'])
        p.inputs['Roughness'].default_value=.69 if key not in ['ivy','flowers','oak'] else .64
        if key=='banner':p.inputs['Roughness'].default_value=.84;p.inputs['Sheen Weight'].default_value=.16
        if key=='lantern':
            p.inputs['Metallic'].default_value=.72;p.inputs['Roughness'].default_value=.28
            color=p.inputs['Base Color'].links[0].from_socket
            bw=nodes.new('ShaderNodeRGBToBW');links.new(color,bw.inputs[0])
            mask=nodes.new('ShaderNodeMapRange');mask.clamp=True;mask.inputs['From Min'].default_value=.48;mask.inputs['From Max'].default_value=.77;mask.inputs['To Max'].default_value=7
            links.new(bw.outputs[0],mask.inputs['Value']);links.new(mask.outputs['Result'],p.inputs['Emission Strength'])
            p.inputs['Emission Color'].default_value=(1,.37,.055,1)
        if key in ['ivy','flowers','oak']:
            out=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
            trans=nodes.new('ShaderNodeBsdfTranslucent')
            links.new(p.inputs['Base Color'].links[0].from_socket,trans.inputs[0])
            mix=nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=.18 if key!='oak' else .06
            links.new(p.outputs[0],mix.inputs[1]);links.new(trans.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],out.inputs['Surface'])

# Improve the supplied tree with individually lit leaves at its leaf-clump sites.
tree_mesh=prototypes['oak'];m=tree_mesh.materials[0]
im=next(n.image for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
pixels=np.empty(len(im.pixels),dtype=np.float32);im.pixels.foreach_get(pixels);pixels=pixels.reshape(im.size[1],im.size[0],4)
leaf_sites=[];uv=tree_mesh.uv_layers.active
for p in tree_mesh.polygons:
    if p.center.z<.32:continue
    loop=p.loop_indices[0];u,v=uv.data[loop].uv
    color=pixels[min(im.size[1]-1,int(v*im.size[1])),min(im.size[0]-1,int(u*im.size[0]))]
    if color[1]>color[0]*.85 and color[1]>color[2]*1.25:leaf_sites.append(p.center.copy())
assert leaf_sites,'No leaf clusters detected in supplied oak'
leafgeo=_Geometry()
for i in range(22000):
    center=rng.choice(leaf_sites)+Vector((rng.uniform(-.042,.042),rng.uniform(-.042,.042),rng.uniform(-.012,.048)))
    a=rng.uniform(0,math.tau);direction=(math.cos(a),math.sin(a),rng.uniform(-.5,.5))
    normal=Vector((rng.uniform(-.5,.5),rng.uniform(-.5,.5),1)).normalized()
    _leaf(leafgeo,center,direction,normal,rng.uniform(.015,.027),rng.uniform(.008,.016),rng.randrange(5))
leafdata=bpy.data.meshes.new('Oak_supplementary_individual_leaves');leafdata.from_pydata(leafgeo.verts,[],leafgeo.faces);leafdata.update()
for i in range(5):leafdata.materials.append(kit.mats['leaf_'+str(i)])
for p,mi in zip(leafdata.polygons,leafgeo.materials):p.material_index=mi
def oak(name,loc,height=9,angle=0):
    o=asset('oak',name,loc,height=height,angle=angle,group='Forest')
    leaves=bpy.data.objects.new(name+'_Living_Canopy',leafdata);kit.collection('Forest').objects.link(leaves)
    leaves.parent=o;return o

# Dedicated paving: irregular individual stone silhouettes with actual joints.
floor_mats=[]
for i in range(12):
    mat=kit.mats['floor_'+str(i%8)].copy();mat.name='Courtyard_limestone_'+str(i)
    p=principled(mat);nodes=mat.node_tree.nodes;links=mat.node_tree.links
    prior=p.inputs['Base Color'].links[0].from_socket
    tint=nodes.new('ShaderNodeMixRGB');enum(tint,'blend_type','MULTIPLY');tint.inputs[0].default_value=1
    value=.70+i*.042;tint.inputs[2].default_value=(value*1.05,value,value*.87,1)
    links.new(prior,tint.inputs[1]);links.new(tint.outputs[0],p.inputs['Base Color'])
    floor_mats.append(mat)
wet_mats=[]
for i,mat in enumerate(floor_mats):
    wet=mat.copy();wet.name='Damp_edge_limestone_'+str(i);p=principled(wet)
    for link in list(p.inputs['Roughness'].links):wet.node_tree.links.remove(link)
    p.inputs['Roughness'].default_value=.17+.012*(i%4);p.inputs['Coat Weight'].default_value=.45;p.inputs['Coat Roughness'].default_value=.07
    wet_mats.append(wet)
water_locations=[(-7.25,-4.4,1.45,.66),(7.1,-2.3,1.5,.68),(-7.15,2.55,1.10,.56),(7.8,5.7,.98,.60)]

def add_uv(o):
    layer=o.data.uv_layers.new(name='SurfaceUV_2m');offset=(rng.uniform(0,2),rng.uniform(0,2))
    for p in o.data.polygons:
        for loop in p.loop_indices:
            v=o.data.vertices[o.data.loops[loop].vertex_index].co
            layer.data[loop].uv=(v.x*.65+offset[0],v.y*.65+offset[1])

def pavement(bounds,name='Courtyard',step=.67):
    x0,x1,y0,y1=bounds;row=0;y=y0;mv=[];mf=[]
    kit.box(name+'_joint_bed',((x0+x1)/2,(y0+y1)/2,-.10),(x1-x0,y1-y0,.14),'mortar',0,'Ground')
    while y<y1-.02:
        h=min(step*rng.uniform(.8,1.12),y1-y);x=x0
        while x<x1-.02:
            w=min(step*rng.choice([.85,1,1.15,1.4]),x1-x)
            if x1-x-w<.15:w=x1-x
            gap=.024;ww=(w-gap)/2;hh=(h-gap)/2
            cut=[rng.uniform(.04,.17)*min(w,h) for _ in range(4)]
            outline=[(-ww+cut[0],-hh),(ww-cut[1],-hh),(ww,-hh+cut[1]),(ww,hh-cut[2]),(ww-cut[2],hh),(-ww+cut[3],hh),(-ww,hh-cut[3]),(-ww,-hh+cut[0])]
            vertices=[(a,b,-.13) for a,b in outline]+[(a,b,rng.uniform(-.012,.003)) for a,b in outline]+[(0,0,rng.uniform(-.008,.004))]
            faces=[tuple(reversed(range(8)))]+[(j,(j+1)%8,8+(j+1)%8,8+j) for j in range(8)]+[(8+j,8+(j+1)%8,16) for j in range(8)]
            px=x+w/2;py=y+h/2
            wet=any(((px-a)/r)**2+((py-b)/(r*sy))**2<1.5 for a,b,r,sy in water_locations)
            mat=rng.choice(wet_mats if wet else floor_mats)
            ob=kit.mesh(f'{name}_stone_{row}_{x:.2f}',vertices,faces,mat,'Ground');ob.location=(px,py,0);add_uv(ob)
            kit.bevel(ob,.014,2)
            if rng.random()<.80:
                for axis in [0,1]:
                    for j in range(rng.randrange(3,10)):
                        a=x+(j*.060 if axis==0 else 0);b=y+(j*.060 if axis else 0);rr=rng.uniform(.028,.10);start=len(mv)
                        mv.extend((a+rr*math.cos(k*math.tau/7),b+rr*.65*math.sin(k*math.tau/7),.007) for k in range(7));mf.append(tuple(range(start,start+7)))
            x+=w
        y+=h;row+=1
    moss=kit.mesh(name+'_seam_moss',mv,mf,'joint_moss','Ground')

# The supplied bridge contains a textured old paving surface. Extract its centre
# with UVs intact, then instance it as the main courtyard's stone modules.
bm=bmesh.new();bm.from_mesh(prototypes['bridge'])
for co,no in [((-.13,0,0),(1,0,0)),((.13,0,0),(-1,0,0)),((0,-.37,0),(0,1,0)),((0,.37,0),(0,-1,0)),((0,0,.185),(0,0,1)),((0,0,.245),(0,0,-1))]:
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=co,plane_no=no,clear_inner=True,dist=.00001)
patchmesh=bpy.data.meshes.new('Item2_bridge_extracted_paving_shared');bm.to_mesh(patchmesh);bm.free()
for v in patchmesh.vertices:v.co.z=(v.co.z-.218)*.7
patchmesh.update()
patchmat=prototypes['bridge'].materials[0].copy();patchmat.name='Item2_paving_dry_and_wet_limestone';patchmesh.materials.append(patchmat)
p=principled(patchmat);nodes=patchmat.node_tree.nodes;links=patchmat.node_tree.links
position=nodes.new('ShaderNodeNewGeometry');combined=None
for x,y,r,sy in water_locations:
    offset=nodes.new('ShaderNodeVectorMath');offset.operation='SUBTRACT';links.new(position.outputs['Position'],offset.inputs[0]);offset.inputs[1].default_value=(x,y,0)
    divide=nodes.new('ShaderNodeVectorMath');divide.operation='DIVIDE';divide.inputs[1].default_value=(r,r*sy,100);links.new(offset.outputs[0],divide.inputs[0])
    length=nodes.new('ShaderNodeVectorMath');length.operation='LENGTH';links.new(divide.outputs[0],length.inputs[0])
    ramp=nodes.new('ShaderNodeMapRange');ramp.clamp=True;ramp.inputs['From Min'].default_value=.7;ramp.inputs['From Max'].default_value=1.3;ramp.inputs['To Min'].default_value=1;ramp.inputs['To Max'].default_value=0;links.new(length.outputs['Value'],ramp.inputs['Value'])
    if combined:
        union=nodes.new('ShaderNodeMath');union.operation='MAXIMUM';links.new(combined,union.inputs[0]);links.new(ramp.outputs['Result'],union.inputs[1]);combined=union.outputs[0]
    else:combined=ramp.outputs['Result']
rough=nodes.new('ShaderNodeMapRange');rough.inputs['To Min'].default_value=.72;rough.inputs['To Max'].default_value=.13;links.new(combined,rough.inputs['Value']);links.new(rough.outputs['Result'],p.inputs['Roughness']);links.new(combined,p.inputs['Coat Weight']);p.inputs['Coat Roughness'].default_value=.045
original=p.inputs['Base Color'].links[0].from_socket
wet_color=nodes.new('ShaderNodeMixRGB');wet_color.blend_type='MULTIPLY';links.new(combined,wet_color.inputs[0]);links.new(original,wet_color.inputs[1]);wet_color.inputs[2].default_value=(.25,.34,.40,1);links.new(wet_color.outputs[0],p.inputs['Base Color'])
def provided_paving(bounds,label):
    x0,x1,y0,y1=bounds;nx=math.ceil((x1-x0)/4);ny=math.ceil((y1-y0)/8);w=(x1-x0)/nx;h=(y1-y0)/ny
    kit.box(label+'_foundation',((x0+x1)/2,(y0+y1)/2,-.13),(x1-x0,y1-y0,.20),'mortar',0,'Ground')
    for j in range(ny):
        for i in range(nx):
            obj=bpy.data.objects.new(f'{label}_Item2_Paving_{j}_{i}',patchmesh);kit.collection('Ground').objects.link(obj)
            obj.location=(x0+(i+.5)*w,y0+(j+.5)*h,0);obj.scale=(w/.26,h/.74,1);obj.rotation_euler.z=math.pi*((i+j)%2)
            obj['source_object']=IDS['bridge'];obj['derived_geometry']='UV-preserving cropped walkway centre'
            source_use['bridge']+=1
provided_paving((-9,9,-8,8),'Courtyard');provided_paving((-14,14,-18,-8),'Foreground_Continuation')
pavement((-9,-5.6,8,24),'Northwest_Path');pavement((4.8,8.4,8,19),'Arch_Path')

# Continuous terrain outside the courtyard, dropping away into layered forest.
terrain_verts=[];terrain_faces=[];n=48
for j in range(n+1):
    y=-28+j*2.25
    for i in range(n+1):
        x=-55+i*2.25
        z=-.24 if y<12 else -.3-min(8,(y-12)*.35)+1.2*math.sin(x*.12)*math.sin(y*.17)
        terrain_verts.append((x,y,z))
for j in range(n):
    for i in range(n):a=j*(n+1)+i;terrain_faces.append((a,a+1,a+n+2,a+n+1))
terrain=kit.mesh('Continuous_forest_valley_ground',terrain_verts,terrain_faces,'forest_ground','Forest');add_uv(terrain)

def lantern(name,loc,h=.58):
    ob=asset('lantern',name,loc,height=h,group='Props')
    kit.light(name+'_candle_pool','POINT',(loc[0],loc[1]-.11,loc[2]+h*.52),(1,.49,.15),18,.13)
    return ob

def rail_between(name,a,b):
    length=math.dist(a,b);count=max(1,round(length/2.9));span=length/count
    angle=math.atan2(b[1]-a[1],b[0]-a[0])
    for j in range(count):
        t=(j+.5)/count
        asset('rail',name+f'_{j:02d}',(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,-.025),dim=(span+.12,.57,1.22),angle=angle)
    for j in range(count+1):
        t=j/count;pos=(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,0)
        pillar=asset('pillar',name+f'_Pillar_{j}',pos,dim=(.69,.69,1.43))
        lantern(name+f'_Lantern_{j}',(pos[0],pos[1],1.43))

rail_between('West_Railing',(-9,-8),(-9,7.9))
rail_between('East_Railing',(9,-8),(9,7.9))
rail_between('Rear_Center_Railing',(-1.3,8.15),(4.75,8.15))
rail_between('Rear_Left_Railing',(-5.65,8.15),(-5.4,8.15)) if False else None
rail_between('Front_Left_Short_Rail',(-9,-8),(-6.0,-8))
rail_between('Front_Right_Short_Rail',(6,-8),(9,-8))
asset('corner','Northwest_corner',(-9,8,0),dim=(1.7,1.7,1.25),angle=math.pi)
asset('broken_wall','Path_garden_old_wall',(-9.6,12.1,-.08),dim=(3.5,.65,1.15),angle=math.pi/2)

asset('arch','Hero_Ancient_Arch',(6.55,8.45,-.025),dim=(4.8,1.15,4.65))
asset('shrine','Hero_Guardian_Shrine',(-3.55,8.05,-.015),dim=(4.25,1.7,4.5))
asset('statue','Guardian_Statue_Insert',(-3.55,7.65,.85),height=2.52,group='Props')
asset('flowerpot','Shrine_Offering_Left',(-5.78,6.73,.015),height=.85,group='Props')
asset('flowerpot','Shrine_Offering_Right',(-1.32,6.73,.015),height=.85,angle=.2,group='Props')
for x in [-4.77,-2.33]:lantern('Shrine_Offering_Candle',(x,7.20,.80),.38)
for name,pos in [('Shrine_Left',(-5.35,7.30,1.78)),('Shrine_Right',(-1.69,7.30,1.78)),('Arch_Left',(4.35,7.96,2.25)),('Arch_Right',(8.62,7.96,2.25)),('West_Front',(-8.89,-5.47,.95)),('East_Front',(8.78,-5.57,.95))]:
    asset('banner',name+'_Leaf_Banner',pos,height=1.8,group='Props')
asset('stairs','Path_Three_Steps',(-7.25,9.25,-.62),dim=(3.3,1.5,.72))
asset('bridge','Raised_Northwest_Walkway',(-7.25,13.65,-1.08),dim=(3.4,6.1,1.22))
asset('bridge','Far_Arch_Continuation',(6.5,15.8,-1.10),dim=(3.6,5.3,1.26))

# Three-leaf bronze inlay and cut-stone roundel, surface almost flush with paving.
cx,cy=.05,-.4
disk=kit.cylinder('Roundel_recessed_stone_bed',(cx,cy,-.06),1.92,.125,'mortar',96,'Ground')
# Voronoi cut stones make the inlay part of the old paving instead of a flat plate.
sites=[Vector((cx+rng.uniform(-1.6,1.6),cy+rng.uniform(-1.6,1.6))) for _ in range(24)]
patchmesh.calc_loop_triangles();tris=list(patchmesh.loop_triangles)
projection=BVHTree.FromPolygons([v.co for v in patchmesh.vertices],[tuple(t.vertices) for t in tris],all_triangles=True)
def inherited_stone_uv(obj):
    layer=obj.data.uv_layers.new(name='Inherited_Item2_Stone_UV')
    source_uv=patchmesh.uv_layers.active
    for loop in obj.data.loops:
        v=obj.data.vertices[loop.vertex_index].co
        test=Vector(((v.x-cx)*.060,(v.y-cy)*.17,1))
        hit,normal,idx,distance=projection.ray_cast(test,Vector((0,0,-1)),3)
        if hit is None:hit,normal,idx,distance=projection.find_nearest(Vector((test.x,test.y,0)))
        tri=tris[idx];a,b,c=[patchmesh.vertices[k].co for k in tri.vertices]
        ta,tb,tc=[Vector((*source_uv.data[k].uv,0)) for k in tri.loops]
        mapped=barycentric_transform(hit,a,b,c,ta,tb,tc);layer.data[loop.index].uv=(mapped.x,mapped.y)
def clip_cell(poly,normal,limit):
    result=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        fa=a.dot(normal)-limit;fb=b.dot(normal)-limit
        if fa<=0:result.append(a)
        if (fa<=0)!=(fb<=0):result.append(a.lerp(b,fa/(fa-fb)))
    return result
for idx,site in enumerate(sites):
    poly=[Vector((cx+1.92*math.cos(k*math.tau/96),cy+1.92*math.sin(k*math.tau/96))) for k in range(96)]
    for other in sites:
        if other==site:continue
        poly=clip_cell(poly,other-site,(other.length_squared-site.length_squared)/2)
        if not poly:break
    if len(poly)<3:continue
    center=sum(poly,Vector((0,0)))/len(poly);poly=[p.lerp(center,.012) for p in poly]
    vv=[(p.x,p.y,.019+rng.uniform(-.0015,.0015)) for p in poly]
    stone=kit.mesh('Roundel_hand_cut_stone_'+str(idx),vv,[tuple(range(len(vv)))],floor_mats[idx%12],'Ground');add_uv(stone)
for radius in [1.68,1.83]:
    kit.curve('Roundel_inlaid_bronze_ring',[(cx+radius*math.cos(k*math.tau/180),cy+radius*math.sin(k*math.tau/180),.025) for k in range(181)],.015,'brass','Ground')
for j in range(48):
    a=j*math.tau/48
    kit.curve('Roundel_radial_stone_joint',[(cx+r*math.cos(a),cy+r*math.sin(a),.022) for r in [1.845,1.917]],.004,'mortar','Ground')
kit.curve('Roundel_leaf_main_stem',[(cx,cy-1.10,.028),(cx+.03,cy-.50,.028),(cx,cy+.70,.028)],.019,'brass','Ground')
for base,tip,width in [((cx,cy+.18),(cx,cy+1.22),.29),((cx,cy-.38),(cx-.98,cy+.55),.32),((cx,cy-.19),(cx+.96,cy+.65),.32)]:
    a=Vector((*base,.028));b=Vector((*tip,.028));side=Vector((-(b-a).y,(b-a).x,0)).normalized()*width
    pts=[]
    for sign,seq in [(1,range(25)),(-1,range(24,-1,-1))]:
        for k in seq:
            t=k/24;pts.append(tuple(a.lerp(b,t)+side*sign*math.sin(math.pi*t)))
    kit.mesh('Roundel_dark_patinated_leaf',pts,[tuple(reversed(range(len(pts))))],'mosaic','Ground')
    kit.curve('Roundel_gold_leaf_edge',pts+[pts[0]],.018,'brass','Ground');kit.curve('Roundel_leaf_vein',[tuple(a),tuple(b)],.009,'brass','Ground')

# Edge water films: Fresnel reflection over the real stones, no painted reflection.
water=bpy.data.materials.new('Rainwater_thin_Fresnel_film');water.use_nodes=True;n=water.node_tree.nodes;l=water.node_tree.links;n.clear()
out=n.new('ShaderNodeOutputMaterial');transparent=n.new('ShaderNodeBsdfTransparent');reflection=n.new('ShaderNodeBsdfPrincipled')
reflection.inputs['Base Color'].default_value=(.72,.86,.97,1);reflection.inputs['Metallic'].default_value=1;reflection.inputs['Roughness'].default_value=.035
fres=n.new('ShaderNodeFresnel');fres.inputs['IOR'].default_value=1.42;mix=n.new('ShaderNodeMixShader')
boost=n.new('ShaderNodeMath');boost.operation='MULTIPLY';boost.inputs[1].default_value=2.8;boost.use_clamp=True
l.new(fres.outputs[0],boost.inputs[0]);l.new(boost.outputs[0],mix.inputs[0]);l.new(transparent.outputs[0],mix.inputs[1]);l.new(reflection.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs['Surface'])
for i,(x,y,r,sy) in enumerate(water_locations):
    vv=[(x,y,.016)];count=100
    for j in range(count):
        a=j*math.tau/count;rr=r*(1+.09*math.sin(a*7+i)+.07*math.sin(a*13+i*.7))
        vv.append((x+rr*math.cos(a),y+rr*sy*math.sin(a),.016))
    kit.mesh('Peripheral_reflecting_rain_pool_'+str(i),vv,[(0,j+1,(j+1)%count+1) for j in range(count)],water,'Water')

# Supplied flowers and hanging ivy: dense edges, open movement centre.
for i in range(85):
    side=i%3
    if side==0:x,y=-8.45+rng.uniform(-.15,.20),rng.uniform(-7.5,7.5)
    elif side==1:x,y=8.42+rng.uniform(-.2,.12),rng.uniform(-7.5,7.5)
    else:x,y=rng.uniform(-5.0,4.45),7.48+rng.uniform(-.25,.14)
    if -5.6<x<-1.3 and y>6.6:continue
    h=rng.uniform(.34,.63)
    asset('flowers',f'Edge_meadow_{i:03d}',(x,y,-.015),height=h,angle=rng.uniform(0,math.tau),group='Vegetation')
for i,(x,y,z,h) in enumerate([(-5.5,7.95,2.2,2.2),(-1.9,7.95,2.5,1.8),(4.45,8.10,2.75,1.8),(8.60,8.10,2.75,1.8),(-8.9,-4,0,1.5),(8.9,-4,0,1.4),(-8.9,2,0,1.4),(8.9,2,0,1.5)]):
    asset('ivy',f'Hanging_ivy_{i:02d}',(x,y,z),height=h,group='Vegetation')
for side in [-1,1]:
    for j in range(10):
        x=side*rng.uniform(9.65,13.5);y=rng.uniform(-12,13)
        asset('flowers',f'Forest_flower_border_{side}_{j}',(x,y,-.25),height=rng.uniform(.5,.9),angle=rng.uniform(0,math.tau),group='Vegetation')
        fern(kit,f'Forest_fern_{side}_{j}',(x+.3,y-.2,-.24),rng.uniform(.65,1.3),i*71+j+int(side>0))

oak('Hero_Left_Ancient_Oak',(-12.5,6.0,-.28),10.6,-.28)
kit.curve('Oak_high_sun_filter_branch',[(-12.5,6,5.5),(-10.4,6,8),(-8,5.8,9.8),(-5.0,5.3,11.5)],.14,'bark','Forest')
overhang=_Geometry()
for center in [(-9,5.8,9.8),(-7.5,5.8,10.6),(-5.9,5.3,11.2),(-4.5,5.3,11.8)]:
    for i in range(480):
        base=Vector(center)+Vector((rng.gauss(0,.77),rng.gauss(0,.70),rng.gauss(0,.28)))
        a=rng.uniform(0,math.tau);_leaf(overhang,base,(math.cos(a),math.sin(a),rng.uniform(-.2,.2)),(0,0,1),rng.uniform(.12,.27),rng.uniform(.065,.14),rng.randrange(5))
overhang_obj=kit.mesh('Airy_overhanging_oak_leaf_sprays',overhang.verts,overhang.faces,'leaf_0','Forest')
for i in range(1,5):overhang_obj.data.materials.append(kit.mats['leaf_'+str(i)])
for p,mi in zip(overhang_obj.data.polygons,overhang.materials):p.material_index=mi
oak('Overhanging_Sun_Filter_Oak',(-12.5,13.5,-.40),12.4,.6)
oak('Rear_Oak',(-.1,20,-3.8),10.2,1.5)
oak('Right_Forest_Frame',(17,17,-2.5),10.7,2.0)
for i in range(65):
    y=rng.uniform(19,66);x=rng.uniform(-45,48)
    z=-.3-min(8,(y-12)*.35)+1.2*math.sin(x*.12)*math.sin(y*.17)
    oak(f'Valley_Oak_{i:03d}',(x,y,z),rng.uniform(7,15),rng.uniform(0,math.tau))
for i in range(8):
    side=-1 if i%2 else 1
    oak(f'Side_forest_{i}',(side*rng.uniform(16,26),rng.uniform(-2,17),-.8),rng.uniform(8,13),rng.uniform(0,math.tau))

# Low varied shrub layers conceal the bare forest floor without enclosing the arena.
shrubs=_Geometry()
for i in range(950):
    a=rng.uniform(0,math.tau);r=rng.random()**.5*.72;z=.14+.58*(1-(r/.8)**2)+rng.uniform(-.15,.15)
    _leaf(shrubs,(r*math.cos(a),r*math.sin(a),z),(math.cos(a),math.sin(a),rng.uniform(-.4,.6)),(0,0,1),rng.uniform(.09,.18),rng.uniform(.045,.09),rng.randrange(5))
shrubmesh=bpy.data.meshes.new('Low_forest_shrub_shared');shrubmesh.from_pydata(shrubs.verts,[],shrubs.faces);shrubmesh.update()
for k in range(5):shrubmesh.materials.append(kit.mats['leaf_'+str(k)])
for p,mi in zip(shrubmesh.polygons,shrubs.materials):p.material_index=mi
for i in range(185):
    if i<100:
        side=-1 if i%2 else 1;x=side*rng.uniform(9.3,17);y=rng.uniform(-14,16);z=-.25
    else:
        x=rng.uniform(-20,22);y=rng.uniform(10,25);z=-.24 if y<12 else -.3-min(8,(y-12)*.35)+1.2*math.sin(x*.12)*math.sin(y*.17)
        if (-9<x<-5.6 or 4.8<x<8.4) and y<20:continue
    ob=bpy.data.objects.new('Forest_understory_shrub_'+str(i),shrubmesh);kit.collection('Vegetation').objects.link(ob);ob.location=(x,y,z);ob.rotation_euler.z=rng.uniform(0,math.tau);ob.scale=(rng.uniform(.8,1.8),rng.uniform(.8,1.8),rng.uniform(.7,1.5))

# Modest real leaf litter keeps the centre sparse and the boundaries lived in.
litter=_Geometry()
for i in range(360):
    x=rng.uniform(-8.8,8.8);y=rng.uniform(-7.8,8)
    if abs(x)<6 and abs(y)<5.5 and rng.random()<.82:continue
    a=rng.uniform(0,math.tau);_leaf(litter,(x,y,.022),(math.cos(a),math.sin(a),.02),(0,0,1),rng.uniform(.06,.14),rng.uniform(.025,.058),rng.randrange(3))
obj=kit.mesh('Scattered_real_leaf_litter',litter.verts,litter.faces,'leaf_2','Ground')

# Warm back-left sunlight; cool sky keeps shadowed masonry legible.
sun=kit.light('Sun_Warm_Left_Back','SUN',(-14,10,21),(1,.77,.45),5.0,target=(0,0,0));sun.data.angle=.025
kit.light('Warm_canopy_opening','AREA',(-8,7,14),(1,.77,.44),500,5,(0,-1,0))
kit.light('Sky_Soft_Fill','AREA',(0,-2,16),(.64,.78,1),500,18,(0,2,0))
world=bpy.data.worlds.new('Cool_open_forest_sky');world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(.38,.56,.85,1);bg.inputs['Strength'].default_value=.65;s.world=world
fog=bpy.data.materials.new('Thin_canopy_atmosphere');fog.use_nodes=True;nodes=fog.node_tree.nodes;links=fog.node_tree.links;nodes.clear()
out=nodes.new('ShaderNodeOutputMaterial');volume=nodes.new('ShaderNodeVolumePrincipled');volume.inputs['Density'].default_value=.0025;volume.inputs['Anisotropy'].default_value=.45
links.new(volume.outputs[0],out.inputs['Volume']);kit.box('Fine_forest_atmosphere',(0,19,11),(96,108,32),fog,0,'Atmosphere')
distance_fog=bpy.data.materials.new('Cool_background_forest_depth');distance_fog.use_nodes=True;n=distance_fog.node_tree.nodes;l=distance_fog.node_tree.links;n.clear()
out=n.new('ShaderNodeOutputMaterial');v=n.new('ShaderNodeVolumePrincipled');v.inputs['Density'].default_value=.009;v.inputs['Color'].default_value=(.60,.76,1,1);v.inputs['Anisotropy'].default_value=.25;l.new(v.outputs[0],out.inputs['Volume'])
kit.box('Distant_forest_aerial_perspective',(0,51,2),(105,62,44),distance_fog,0,'Atmosphere')

def camera(name,location,target,lens=48,ortho=None):
    data=bpy.data.cameras.new(name);ob=bpy.data.objects.new(name,data);kit.collection('Cameras').objects.link(ob);ob.location=location
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();data.lens=lens;data.clip_end=350
    if ortho:enum(data,'type','ORTHO');data.ortho_scale=ortho
    return ob
s.camera=camera('Camera_Hero_Daylight',(12,-25,19),(0,2.4,.7),46)
camera('Camera_Topdown',(0,0,34),(0,0,0),ortho=24)
camera('Camera_Shrine_Detail',(2,-3,6),(-3.1,7.4,2.1),57)
camera('Camera_Material_Detail',(-4,-5,2.8),(-7,-1,.2),60)
try:s.render.engine='CYCLES'
except TypeError:raise
s.cycles.samples=192;s.cycles.use_denoising=True;s.cycles.max_bounces=10;s.cycles.transparent_max_bounces=16
pref=bpy.context.preferences.addons['cycles'].preferences
if 'OPTIX' in [p[0] for p in pref.get_device_types(bpy.context)]:
    pref.compute_device_type='OPTIX';pref.refresh_devices()
    for dev in pref.devices:dev.use=dev.type=='OPTIX'
    enum(s.cycles,'device','GPU')
s.render.resolution_x=2560;s.render.resolution_y=1440;s.render.resolution_percentage=100
enum(s.render.image_settings,'file_format','PNG');s.render.filepath=str(BASE/'previews/forest_courtyard_hero.png')
s.view_settings.exposure=.5
ocio=Path(bpy.app.binary_path).parent/'5.2/datafiles/colormanagement/config.ocio'
if ocio.is_file() and 'name: AgX - Medium High Contrast' in ocio.read_text(encoding='utf-8'):
    try:s.view_settings.look='AgX - Medium High Contrast'
    except TypeError:pass
s['source_item2']=str(SOURCE);s['reference']='concepts/forest-courtyard-breakdown-v001/07-scene-daylight.png'
s['delivery_stage']='Blender editable art scene; Godot integration not performed';s['metres_per_unit']=1
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            enum(area.spaces.active.region_3d,'view_perspective','CAMERA');area.spaces.active.overlay.show_overlays=False
            enum(area.spaces.active.shading,'type','MATERIAL')
bpy.context.view_layer.update()
# Keep a local copy of every embedded texture and remove obsolete D:/Temp paths.
(BASE/'textures').mkdir(exist_ok=True)
for im in bpy.data.images:
    if not im.packed_file:continue
    data=bytes(im.packed_file.data);extension='.png' if data.startswith(b'\x89PNG') else '.jpg'
    target=BASE/'textures'/(im.name+extension);target.write_bytes(data)
    im.filepath=str(target)
bpy.ops.file.pack_all()
path=BASE/'blender/forest_courtyard_item2_v001.blend';bpy.ops.wm.save_as_mainfile(filepath=str(path))
report={'source':str(SOURCE),'source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'output':str(path),'item2_roles_used':source_use,'objects':len(s.objects),'packed_images':[im.name for im in bpy.data.images if im.packed_file],'new_geometry':['chipped paving','leaf medallion','water films','supplementary canopy leaves','forest terrain','ferns'],'reference':s['reference']}
(BASE/'reports/build_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('BUILD_COMPLETE '+str(path),flush=True)
exec(compile((BASE/'scripts/finalize_shrine.py').read_text(encoding='utf-8'),str(BASE/'scripts/finalize_shrine.py'),'exec'))
