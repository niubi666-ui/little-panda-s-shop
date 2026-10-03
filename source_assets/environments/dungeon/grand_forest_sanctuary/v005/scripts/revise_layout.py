"""v005 art-only revision. Run in a separate background Blender; never save v004.
Preserves source mesh sharing, leaf cutouts and the v004 animated flora batches.
"""
import bpy, math, json, hashlib, random, sys, bmesh
from pathlib import Path
from mathutils import Vector, Matrix
assert bpy.app.background
R=Path(__file__).resolve().parents[1]
C=json.loads((R/'scripts/layout_profile.json').read_text(encoding='utf-8'))
assert Path(bpy.data.filepath).resolve()==Path(C['source']).resolve()
source_hash=hashlib.sha256(Path(C['source']).read_bytes()).hexdigest()
s=bpy.context.scene
rng=random.Random(261003)
original=list(s.objects)
hidden=[]; moved=[]
def collection(name):
    c=bpy.data.collections.get(name)
    if not c:c=bpy.data.collections.new(name);s.collection.children.link(c)
    return c
revision=collection('V005_Layout_Revision')
def hide(o):
    o.hide_render=True;o.hide_set(True);o['v005_omitted']=True;hidden.append(o.name)
def transform(obs,mat):
    obs=set(obs)
    # Children inherit the transformed root; do not apply the matrix twice.
    for o in obs:
        if o.parent not in obs:o.matrix_world=mat@o.matrix_world;moved.append(o.name)
def mapping(old,new,angle):
    return Matrix.Translation(Vector(new))@Matrix.Rotation(angle,4,'Z')@Matrix.Translation(-Vector(old))
gate_old=Vector((17.4,9.75,0));gate_new=Vector(C['gate_location'])
ga=math.radians(C['gate_angle_degrees']);G=mapping(gate_old,gate_new,ga)
SA=math.radians(C['shrine_angle_degrees']);S=mapping((0,13.45,0),C['shrine_location'],SA)
tree_old=Vector((-12.7,7.5,0));tree_new=Vector((*C['hero_location'][:2],0))
grow=C['hero_scale']/1.28*C['hero_width_multiplier']
def plant_map(p):
    # Local gardens follow the corresponding architectural edit, rather than
    # leaving the hidden originals and visible wind batches out of sync.
    if 14.35<p.x<20.25 and 3.8<p.y<16.5:return G@p,ga
    if -4.65<p.x<4.65 and 9.5<p.y<16.1:return S@p,SA
    if (p.xy-tree_old.xy).length<6.6:
        q=p.copy();q.x=tree_new.x+(p.x-tree_old.x)*grow;q.y=tree_new.y+(p.y-tree_old.y)*grow
        return q,0
    return p.copy(),0
for o in original:
    if o.name.startswith('Forest_oak_'):hide(o)
    if o.name.startswith(('Boundary_3_','Boundary_4_','Boundary_5_','Boundary_6_','Boundary_7_',
                           'West_lower_course','West_lower_pier','West_upper_course','West_upper_pier',
                           'West_lower_path_','West_upper_path_')):hide(o)
for i in (4,5,6,7):
    for prefix in ('Bronze_votive_','Votive_warm_light_'):hide(s.objects[prefix+str(i)])
hero=s.objects['Hero_Sacred_Oak_v005'];hero.location=C['hero_location'];hero.scale=(C['hero_scale']*C['hero_width_multiplier'],C['hero_scale']*C['hero_width_multiplier'],C['hero_scale']);hero.rotation_euler.z=math.radians(C['hero_angle_degrees'])
gate=[o for o in original if o.name.startswith(('East_gateway_','Gateway_','East_double_pillar_road_')) or o.name in ['Bronze_votive_17','Bronze_votive_18','Votive_warm_light_17','Votive_warm_light_18']]
shrine=[o for o in original if o.name.startswith(('Shrine_','North_Guardian','Robed_Guardian')) or o.name in ['Bronze_votive_15','Bronze_votive_16','Votive_warm_light_15','Votive_warm_light_16']]
transform(gate,G);transform(shrine,S)
bpy.context.view_layer.update()

# Reuse all authored mesh blocks and materials; object dimensions are in metres.
mesh_bounds={}
def asset(role,name,p,dim=None,height=None,angle=0):
    me=bpy.data.meshes['FY_'+role+'_shared']
    if role not in mesh_bounds:
        mesh_bounds[role]=Vector(tuple(max(v.co[k] for v in me.vertices)-min(v.co[k] for v in me.vertices) for k in range(3)))
    d=mesh_bounds[role];o=bpy.data.objects.new(name,me);revision.objects.link(o)
    o.location=p;o.rotation_euler.z=angle
    if dim:o.scale=tuple(dim[k]/d[k] for k in range(3))
    elif height:o.scale=(height/d.z,)*3
    o['asset_role']=role;o['v005_added']=True
    return o
def interp_path(points,step=2.0):
    pts=[Vector((x,y,0)) for x,y in points]
    # Uniform samples on a Catmull-Rom spline, preserving the route's endpoints.
    dense=[]
    for i in range(len(pts)-1):
        p0,p1,p2,p3=pts[max(0,i-1)],pts[i],pts[i+1],pts[min(len(pts)-1,i+2)]
        for j in range(40):
            t=j/40
            dense.append((p1*2+(-p0+p2)*t+(p0*2-p1*5+p2*4-p3)*t*t+(-p0+p1*3-p2*3+p3)*t*t*t)*.5)
    dense.append(pts[-1]);out=[dense[0]];acc=0
    for a,b in zip(dense,dense[1:]):
        acc+=(b-a).length
        if acc>=step:out.append(b);acc=0
    if (out[-1]-dense[-1]).length>.2:out.append(dense[-1])
    return out
lower=interp_path(C['west_lower_route']);upper=interp_path(C['west_upper_route'])
routes=[lower,upper]
def dist_to_poly(p,pts):
    best=1e6
    for a,b in zip(pts,pts[1:]):
        ab=(b-a).xy;ap=(p-a).xy;t=max(0,min(1,ap.dot(ab)/ab.length_squared));best=min(best,(ap-t*ab).length)
    return best
def in_route(p,margin=0):
    # Only clear upper western route beyond the main central courtyard.
    if p.x<-5.6 and any(dist_to_poly(p,r)<C['west_route_width']*.5+margin for r in routes):return True
    q=G.inverted()@p
    if 15.0<q.x<35 and abs(q.y-9.75)<2.50+margin:return True
    return False
for label,pts in [('West_root_south_route',lower),('West_root_north_route',upper)]:
    for i,(a,b) in enumerate(zip(pts,pts[1:])):
        mid=(a+b)*.5;angle=math.atan2(b.y-a.y,b.x-a.x)
        # Near the centre these would overlap the retained court tiles.
        if -15.8<mid.x<15.8 and -13.7<mid.y<13.8:continue
        o=asset('paving',f'{label}_{i}',(mid.x,mid.y,-.115),((b-a).length+.20,C['west_route_width'],.15),angle=angle)
        bpy.context.view_layer.update()
        corners=[o.matrix_world@Vector(v) for v in o.bound_box]
        # Crop any overlap with the already paved rectangular NW courtyard.
        # Split its exterior into disjoint x<-18 and x>=-18,y>16 half-regions.
        if min(v.x for v in corners)<-18 and max(v.x for v in corners)>-18 or min(v.y for v in corners)<16 and max(v.y for v in corners)>16:
            for part,planes in enumerate([[((-18,0,0),(-1,0,0))],[((-18,0,0),(1,0,0)),((0,16,0),(0,1,0))]]):
                me=o.data.copy();me.transform(o.matrix_world);bm=bmesh.new();bm.from_mesh(me)
                for co,no in planes:bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=co,plane_no=no,clear_inner=True,dist=.00001)
                bm.to_mesh(me);bm.free();me.update()
                if len(me.polygons):
                    cp=bpy.data.objects.new(o.name+'_edge_'+str(part),me);revision.objects.link(cp);cp['asset_role']='paving'
                else:bpy.data.meshes.remove(me)
            hide(o)

# Quiet planted boundaries lead into the diagonal double-pillar opening.
new_walls=[]
def wall(label,a,b,h=1.08):
    a=Vector((*a,0));b=Vector((*b,0));length=(b-a).length;n=max(1,round(length/3.3));angle=math.atan2(b.y-a.y,b.x-a.x)
    for i in range(n):
        p=a.lerp(b,(i+.5)/n);asset('low_wall',label+'_course_'+str(i),(p.x,p.y,.018),(length/n,.62,h),angle=angle)
    for i in range(n+1):
        p=a.lerp(b,i/n);asset('pier',label+'_pier_'+str(i),(p.x,p.y,.02),(.7,.7,h+.35))
    new_walls.append((a,b))
lp=s.objects['East_gateway_tall_pillar_1'].location.copy();rp=s.objects['East_gateway_tall_pillar_0'].location.copy()
wall('North_shrine_return',(3.2,16.5),(8.5,16.5))
wall('North_gate_return',(8.5,16.5),(lp.x-.7,lp.y+.25))
wall('East_court_boundary',(18,-9),(19,6.5))
wall('East_gate_return',(19,6.5),(rp.x+.6,rp.y-.4))

# Transform ground decor near the edited architecture, and clear the walkways.
decor_prefix=('Garden_moss_','Mossy_limestone_','Flagstone_moss_','Root_mushrooms')
for o in original:
    if o.name.startswith(decor_prefix):
        q,a=plant_map(o.matrix_world.translation);o.location=q;o.rotation_euler.z+=a
        if in_route(q,.15) and o.get('asset_role') not in ('moss_seam','moss_patch'):hide(o)
        elif in_route(q,-.5) and o.name.startswith('Garden_moss_'):hide(o)
# Crates were inside the expanded tree buttresses; keep them beside the roots.
for name,p in [('Loose_crate_0',(-6.6,9.3,.06)),('Loose_crate_1',(-6.0,9.8,.06)),('Loose_crate_2',(-8.8,-.25,.06)),('Loose_barrel_0',(-6.0,8.4,.05))]:
    s.objects[name].location=p

# Wind geometry lives in point meshes. Re-bucket complete plants after moving
# them: the local bending direction must compensate their new world rotation.
cleared_points=0;relocated_points=0
plants=[]
for o in original:
    if o.get('breeze_original_retained'):
        p=o.matrix_world.translation;q,a=plant_map(p)
        if (q-p).length>.0001:relocated_points+=1
        o.location=q;o.rotation_euler.z+=a;plants.append(o)
        if in_route(q,.25):o['v005_path_clearance']=True

# Assemble companions at one shared transform, then reuse the original wind
# prototype mesh and node tree. No loose flower bells or leafless fern ribs.
whole={}
for o in plants:
    if o.name.startswith(('Fern_clump_','White_meadow_flower_spray_')):
        whole.setdefault(o.name.rsplit('_',1)[0],[]).append(o)
fern_parts=next(parts for name,parts in whole.items() if name.startswith('Fern_clump_'))
bell_parts=next(parts for name,parts in whole.items() if name.startswith('White_meadow_flower_spray_'))
flowers=[next(o for o in plants if o.get('asset_role')=='white_flower')]
new_plant_count=0
for a,b in new_walls:
    d=(b-a).normalized();side=Vector((-d.y,d.x,0))
    for j in range(max(5,int((b-a).length*2.7))):
        p=a.lerp(b,rng.uniform(.02,.98))+side*rng.choice([-1,1])*rng.uniform(.5,1.2);p.z=.06
        if in_route(p,.45):continue
        parts=[fern_parts,bell_parts,flowers][j%3];rot=rng.uniform(0,math.tau);scale=rng.uniform(.82,1.16)
        for k,part in enumerate(parts):
            o=bpy.data.objects.new(f'V005_border_plant_{new_plant_count}_{k}',part.data);revision.objects.link(o)
            o.location=p;o.rotation_euler.z=rot;o.scale=(scale,)*3;o.hide_render=True;o.hide_set(True);o['breeze_original_retained']=True;plants.append(o)
        new_plant_count+=1
bpy.context.view_layer.update()
direction=Vector((.86,.51,0)).normalized()
sets={}
for o in plants:
    p=o.matrix_world.translation
    if in_route(p,.25):cleared_points+=1;continue
    local=o.matrix_world.to_3x3().inverted()@direction
    d=int(round(math.atan2(local.y,local.x)/math.tau*8))%8;k=int(((p.x*.22+p.y*.15)%math.tau)/math.tau*3)%3
    sets.setdefault((o.data.name,d,k),[]).append(o)
for o in list(collection('WIND_animated_flora_batches').objects):
    name,d,k=o.name[len('Breeze_'):].rsplit('_',2)
    obs=sets.pop((name,int(d),int(k)),[])
    me=o.data;me.clear_geometry();me.from_pydata([p.matrix_world.translation for p in obs],[],[])
    for attr_name,method in [('breeze_rotation','to_euler'),('breeze_scale','to_scale')]:
        attr=me.attributes.get(attr_name) or me.attributes.new(attr_name,'FLOAT_VECTOR','POINT')
        attr.data.foreach_set('vector',[f for p in obs for f in getattr(p.matrix_world,method)()])
    me.update()
assert not sets, ('Missing wind prototype buckets',list(sets))

# Re-evaluate local wind direction after rotating the hero tree.
bpy.context.view_layer.update()
direction=Vector((.86,.51,0)).normalized()
for o in hero.children_recursive:
    for m in o.modifiers:
        if m.type=='NODES' and m.node_group and m.node_group.nodes.get('Breeze'):
            n=m.node_group.nodes['Breeze'];n.inputs['Direction'].default_value=(o.matrix_world.to_3x3().inverted()@direction).normalized()
            p=o.matrix_world.translation;n.inputs['Phase'].default_value=(p.x*.22+p.y*.15)%math.tau

# Layered 3D flame tongues in bronze offering braziers in front of the shrine.
# No image planes: these are visible from every review angle, with real lights.
def material(name,color,metal=0,rough=.5,emit=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    if emit:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emit
    return m
bronze=material('V005_aged_brazier_bronze',(.18,.085,.025),.76,.3)
ember=material('V005_hot_coals',(.9,.055,.002),0,.8,3)
flamegold=material('V005_flame_gold',(1,.30,.012),0,.5,5)
flamecore=material('V005_flame_ivory',(1,.80,.32),0,.5,9)
def meshobj(name,vs,fs,mat):
    me=bpy.data.meshes.new(name+'_mesh');me.from_pydata(vs,[],fs);me.materials.append(mat);me.update()
    o=bpy.data.objects.new(name,me);revision.objects.link(o)
    for p in me.polygons:p.use_smooth=True
    return o
def lathe(name,pos,profile,mat,n=32):
    vs=[(pos[0]+r*math.cos(j/n*math.tau),pos[1]+r*math.sin(j/n*math.tau),pos[2]+z) for r,z in profile for j in range(n)]
    fs=[(k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j) for k in range(len(profile)-1) for j in range(n)]
    return meshobj(name,vs,fs,mat)
def flame(name,p,h,r,seed,mat):
    rr=random.Random(seed);vs=[];fs=[];n=10;rows=8;phase=rr.uniform(0,6.28)
    for k in range(rows):
        t=k/(rows-1);rad=r*(math.sin(math.pi*(.15+.85*t))**.7 if t<1 else .005)
        cx=math.sin(t*5+phase)*r*t;cy=math.sin(t*3+phase)*r*t*.7
        for j in range(n):
            a=j/n*math.tau;vs.append((p.x+cx+rad*math.cos(a),p.y+cy+rad*math.sin(a),p.z+h*t))
    for k in range(rows-1):
        for j in range(n):fs.append((k*n+j,k*n+(j+1)%n,(k+1)*n+(j+1)%n,(k+1)*n+j))
    return meshobj(name,vs,fs,mat)
def volumetric_fire_material():
    m=bpy.data.materials.new('V005_living_flame_volume');m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;n.clear()
    def put(inp,x):
        if hasattr(x,'is_output'):l.new(x,inp)
        else:inp.default_value=x
    def mathnode(op,a,b=None):
        q=n.new('ShaderNodeMath');q.operation=op;put(q.inputs[0],a)
        if b is not None:put(q.inputs[1],b)
        return q.outputs[0]
    tc=n.new('ShaderNodeTexCoord');sep=n.new('ShaderNodeSeparateXYZ');l.new(tc.outputs['Generated'],sep.inputs[0])
    x=mathnode('SUBTRACT',sep.outputs['X'],.5);y=mathnode('SUBTRACT',sep.outputs['Y'],.5);z=sep.outputs['Z']
    noise=n.new('ShaderNodeTexNoise');noise.noise_dimensions='4D';noise.inputs['Scale'].default_value=4.5;noise.inputs['Detail'].default_value=2.0;noise.inputs['Roughness'].default_value=.65;l.new(tc.outputs['Generated'],noise.inputs['Vector'])
    f=noise.inputs['W'].driver_add('default_value');f.driver.expression='frame/31.0'
    x=mathnode('ADD',x,mathnode('MULTIPLY',mathnode('SINE',mathnode('MULTIPLY',z,9)),.065))
    radial=mathnode('SQRT',mathnode('ADD',mathnode('MULTIPLY',x,x),mathnode('MULTIPLY',y,y)))
    radius=mathnode('ADD',.035,mathnode('MULTIPLY',mathnode('SUBTRACT',1,z),.39))
    field=mathnode('SUBTRACT',mathnode('SUBTRACT',radius,radial),mathnode('MULTIPLY',mathnode('SUBTRACT',noise.outputs['Fac'],.37),.42))
    field=mathnode('MAXIMUM',0,mathnode('MULTIPLY',field,10))
    # Fade at volume top to prevent a hard box boundary. Warm translucent fringe.
    fade=mathnode('MINIMUM',1,mathnode('MULTIPLY',mathnode('SUBTRACT',1,z),9));field=mathnode('MULTIPLY',field,fade)
    bb=n.new('ShaderNodeBlackbody');put(bb.inputs[0],mathnode('ADD',1450,mathnode('MULTIPLY',mathnode('MINIMUM',1,field),1250)))
    v=n.new('ShaderNodeVolumePrincipled');put(v.inputs['Density'],mathnode('MULTIPLY',field,.7));v.inputs['Color'].default_value=(.4,.18,.02,1)
    l.new(bb.outputs[0],v.inputs['Emission Color']);put(v.inputs['Emission Strength'],mathnode('MULTIPLY',field,3.3))
    out=n.new('ShaderNodeOutputMaterial');l.new(v.outputs[0],out.inputs['Volume']);return m
fire_volume=volumetric_fire_material()
for i,x in enumerate((-2.55,2.55)):
    p=S@Vector((x,10.22,.03))
    asset('pier','Shrine_front_fire_pedestal_'+str(i),p,(.65,.65,.62),angle=SA)
    lathe('Shrine_front_brazier_'+str(i),(p.x,p.y,.66),[(.17,0),(.16,.13),(.25,.20),(.36,.34),(.36,.40),(.32,.41),(.29,.31),(.10,.22)],bronze)
    lathe('Shrine_coal_bed_'+str(i),(p.x,p.y,1.00),[(0,0),(.28,0),(.24,.055),(0,.06)],ember)
    # 3D density and emission field: wispy tapered fire, without opaque white
    # teardrop meshes. This is a Blender review effect, not a runtime VFX export.
    vs=[(p.x+x*.72,p.y+y*.72,1.025+z*.92) for x,y,z in [(-.5,-.5,0),(.5,-.5,0),(.5,.5,0),(-.5,.5,0),(-.5,-.5,1),(.5,-.5,1),(.5,.5,1),(-.5,.5,1)]]
    fo=meshobj('Shrine_flame_volume_'+str(i),vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],fire_volume)
    for poly in fo.data.polygons:poly.use_smooth=False
    ld=bpy.data.lights.new('Shrine_front_firelight_'+str(i),'POINT');ld.energy=145;ld.color=(1,.34,.065);ld.shadow_soft_size=.28
    lo=bpy.data.objects.new(ld.name,ld);revision.objects.link(lo);lo.location=(p.x,p.y,1.43)
    # Restrained flicker; wind animation remains available on the same timeline.
    f=ld.driver_add('energy');f.driver.expression=f'145*(1+0.045*sin(frame*0.41+{i*2})+0.025*sin(frame*0.91))'

def camera(name,loc,target,width):
    o=bpy.data.objects.get(name)
    if not o:d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);collection('Cameras').objects.link(o)
    o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();o.data.type='ORTHO';o.data.ortho_scale=width;o.data.clip_end=250
    o.data.dof.use_dof=False
    return o
s.camera=camera('Camera_Panorama',C['camera_location'],C['camera_target'],C['camera_width'])
camera('Camera_V005_Root_Routes',(6,-21,21),(-13,8,3.0),30)
camera('Camera_V005_Shrine_Gateway',(23,-13,17),(7,13,2.4),27)
camera('Camera_Shrine_Detail',(10,-6,10),(-.5,12.5,2.7),13)
camera('Camera_Gameplay',(13,-20,22),(-.5,2,0),26)
s.name='Grand_Forest_Sanctuary_v005_Layout_Review'
s['art_stage']='v005 oblique double pillar exit, giant root fork, angled shrine and front fire; Blender review only'
s['peripheral_forest_trees_omitted']=12;s['layout_source_sha256']=source_hash
s['west_paths']=2;s['hero_tree_height_m']=C['hero_scale']*10
s['layout_validation']='Art-layout review only; no Godot navigation/collision/runtime validation.'
s.render.engine='CYCLES';s.cycles.device='GPU';s.cycles.samples=C['render_samples'];s.cycles.use_denoising=True;s.cycles.use_adaptive_sampling=True;s.cycles.adaptive_threshold=.06
s.render.resolution_x,s.render.resolution_y=C['render_resolution'];s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG';s.render.use_persistent_data=True
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.refresh_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
s.frame_set(1)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.overlay.show_overlays=False;area.spaces.active.shading.type='MATERIAL'
out=R/'blender/grand_forest_sanctuary_v005_layout.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(out))
report={'source':C['source'],'source_sha256':source_hash,'output':str(out),'hidden_original_objects':hidden,'transformed_objects':moved,
        'hero_height_m':C['hero_scale']*10,'court_m':[36,32],'player_height_m':s.get('player_height_m'),
        'gate_centres':[list(lp),list(rp)],'west_route_width_m':C['west_route_width'],'flora_batch_points_relocated':relocated_points,
        'flora_batch_points_cleared':cleared_points,'source_mesh_data_shared':True,'godot_modified':False,'profile':C}
(R/'reports/layout_revision.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
assert hashlib.sha256(Path(C['source']).read_bytes()).hexdigest()==source_hash
print('V005_LAYOUT_SAVED',str(out),flush=True)
if '--draft' in sys.argv:
    s.render.resolution_x=1000;s.render.resolution_y=688;s.cycles.samples=24;s.cycles.adaptive_threshold=.12
    s.render.filepath=str(R/'previews/draft_layout_01.png');bpy.ops.render.render(write_still=True)
