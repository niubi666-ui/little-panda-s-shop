"""Native Blender fire slash study, actual EMIT bakes and a rendered sprite atlas.

Run: blender --background --factory-startup --python art_build.py -- body|atlas|movie
"""
import bpy, math, random, json, hashlib, shutil, sys
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

BASE=Path(__file__).resolve().parents[1]
ROOT=BASE.parents[2]
GAME=ROOT/'game/assets/vfx/fire_slash_v002'
for p in [BASE/'blender',BASE/'bakes',BASE/'blender_previews',BASE/'reports',GAME]:p.mkdir(parents=True,exist_ok=True)

def node_math(ns,ls,operation,*values,label=''):
    n=ns.new('ShaderNodeMath');n.operation=operation;n.label=label
    for socket,value in zip(n.inputs,values):
        if hasattr(value,'node'):ls.new(value,socket)
        else:socket.default_value=value
    return n.outputs[0]

def make_body():
    m=bpy.data.materials.new('FireSlash_V002_Thick_Curling_Body');m.use_nodes=True
    ns,ls=m.node_tree.nodes,m.node_tree.links;ns.clear()
    op=lambda code,*v,label='':node_math(ns,ls,code,*v,label=label)
    uv=ns.new('ShaderNodeTexCoord');sep=ns.new('ShaderNodeSeparateXYZ');ls.new(uv.outputs['UV'],sep.inputs[0]);u,v=sep.outputs['X'],sep.outputs['Y']
    phase=ns.new('ShaderNodeValue');phase.name='FLOW_PHASE';phase.label='Flow phase - bake frame control';phase.outputs[0].default_value=.3
    time=op('MULTIPLY',phase.outputs[0],3.0)
    def noise(scale,mult,detail):
        vm=ns.new('ShaderNodeVectorMath');vm.operation='MULTIPLY';ls.new(uv.outputs['UV'],vm.inputs[0]);vm.inputs[1].default_value=mult
        n=ns.new('ShaderNodeTexNoise');n.noise_dimensions='4D';ls.new(vm.outputs[0],n.inputs['Vector']);ls.new(phase.outputs[0],n.inputs['W']);n.inputs['Scale'].default_value=scale;n.inputs['Detail'].default_value=detail;n.inputs['Roughness'].default_value=.63
        return n
    broad=noise(2.1,(2.7,1.6,1),3)
    fine=noise(5.0,(3.8,2.4,1),2)
    # Warped longitudinal coordinate lets orange/red regions roll into the blade.
    warp=op('ADD',v,op('MULTIPLY',op('SUBTRACT',broad.outputs['Fac'],.5),.28))
    outer=op('ADD',.055,op('MULTIPLY',op('SUBTRACT',fine.outputs['Fac'],.5),.014))
    shoulder=op('ADD',.05,op('ADD',op('MULTIPLY',op('SQRT',u),.56),op('MULTIPLY',u,.14)))
    tongue_wave=op('ADD',op('MULTIPLY',op('SINE',op('ADD',op('MULTIPLY',u,39),time)),.065),op('MULTIPLY',op('SINE',op('SUBTRACT',op('MULTIPLY',u,71),time)),.033))
    inner=op('ADD',shoulder,op('ADD',tongue_wave,op('MULTIPLY',op('SUBTRACT',broad.outputs['Fac'],.5),.24)))
    width=op('MAXIMUM',op('SUBTRACT',inner,outer),.015)
    distance_outer=op('SUBTRACT',v,outer);distance_inner=op('SUBTRACT',inner,v)
    edge=op('MINIMUM',distance_outer,distance_inner)
    coverage=op('MULTIPLY',edge,80);coverage.node.use_clamp=True
    fade=op('MULTIPLY',u,8);fade.node.use_clamp=True
    coverage=op('MULTIPLY',coverage,fade)
    # Wide holes and curved tears; the outside cutting edge stays connected.
    tear_masks=[]
    rng=random.Random(802)
    for i in range(11):
        cx=.14+i*.078;cy=.18+.36*math.sqrt(cx)+rng.uniform(-.07,.045)
        rx=rng.uniform(.029,.066);ry=rng.uniform(.016,.046)
        x=op('DIVIDE',op('SUBTRACT',u,cx),rx)
        curl=op('MULTIPLY',op('SINE',op('ADD',op('MULTIPLY',u,40+i*2),time)),.017)
        y=op('DIVIDE',op('SUBTRACT',warp,op('ADD',cy,curl)),ry)
        d=op('ADD',op('MULTIPLY',x,x),op('MULTIPLY',y,y))
        hole=op('MULTIPLY',op('SUBTRACT',1,d),3);hole.node.use_clamp=True
        tear_masks.append(hole)
    holes=tear_masks[0]
    for a in tear_masks[1:]:holes=op('MAXIMUM',holes,a)
    coverage=op('MULTIPLY',coverage,op('SUBTRACT',1,holes),label='Continuous body with torn turbulent windows')
    # Additional short heavy tongues sprout inward rather than parallel fine ribbons.
    tongues=[]
    for i in range(19):
        start=rng.uniform(.13,.91);length=rng.uniform(.045,.11);cx=start+length*.45
        local=op('DIVIDE',op('SUBTRACT',u,start),length)
        t=op('MINIMUM',op('MAXIMUM',local,0),1)
        bell=op('SINE',op('MULTIPLY',t,math.pi))
        peak=.10+.63*math.sqrt(cx)+rng.uniform(-.025,.05)
        center=op('SUBTRACT',peak,op('MULTIPLY',op('POWER',op('SUBTRACT',1,t),1.7),.15))
        thick=op('ADD',.001,op('MULTIPLY',bell,.055))
        tongue=op('SUBTRACT',1,op('DIVIDE',op('ABSOLUTE',op('SUBTRACT',v,center)),thick));tongue.node.use_clamp=True
        tongue=op('MULTIPLY',tongue,op('MINIMUM',op('MULTIPLY',bell,10),1));tongues.append(tongue)
    for t in tongues:coverage=op('MAXIMUM',coverage,t)
    radial=op('DIVIDE',op('SUBTRACT',warp,outer),width)
    radial=op('MINIMUM',op('MAXIMUM',radial,0),1)
    heat=op('ADD',op('MULTIPLY',op('SUBTRACT',1,radial),.62),op('MULTIPLY',broad.outputs['Fac'],.29))
    heat=op('ADD',heat,op('MULTIPLY',op('SUBTRACT',fine.outputs['Fac'],.5),.13))
    # Fold a stretched fluid field into the broad body. It is coloured marbling
    # inside the connected flame sheet, not four isolated parallel ribbon masks.
    fold=op('ADD',v,op('ADD',op('MULTIPLY',op('SINE',op('ADD',op('MULTIPLY',u,13.0),op('MULTIPLY',broad.outputs['Fac'],5))),.085),op('MULTIPLY',op('SUBTRACT',broad.outputs['Fac'],.5),.24)))
    coord=ns.new('ShaderNodeCombineXYZ');ls.new(op('SUBTRACT',op('MULTIPLY',u,3.0),op('MULTIPLY',phase.outputs[0],.3)),coord.inputs[0]);ls.new(op('MULTIPLY',fold,12.0),coord.inputs[1])
    curl=ns.new('ShaderNodeTexNoise');curl.noise_dimensions='4D';ls.new(coord.outputs[0],curl.inputs['Vector']);ls.new(phase.outputs[0],curl.inputs['W']);curl.inputs['Scale'].default_value=2.0;curl.inputs['Detail'].default_value=3.1;curl.inputs['Roughness'].default_value=.57
    strokes=op('MULTIPLY',op('SUBTRACT',curl.outputs['Fac'],.5),3.7)
    heat=op('ADD',heat,op('MULTIPLY',strokes,.36),label='Uneven molten-yellow veins and red cooling grooves')
    # Short directional transparency cuts only affect the inner fluid, leaving
    # the cutting rim and the majority of the broad flame connected.
    flowtear=op('MULTIPLY',op('SUBTRACT',curl.outputs['Fac'],.685),35);flowtear.node.use_clamp=True
    tear_zone=op('MULTIPLY',op('SUBTRACT',v,.19),6);tear_zone.node.use_clamp=True
    flowtear=op('MULTIPLY',flowtear,tear_zone)
    coverage=op('MULTIPLY',coverage,op('SUBTRACT',1,flowtear))
    rim=op('SUBTRACT',1,op('DIVIDE',op('ABSOLUTE',op('SUBTRACT',v,op('ADD',outer,.011))),.020));rim.node.use_clamp=True
    heat=op('MAXIMUM',heat,op('MULTIPLY',rim,1.05))
    ramp=ns.new('ShaderNodeValToRGB');ramp.label='Yellow cutting heart / orange belly / red torn fringe';ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1])
    colors=[(0,(.25,.001,.0001,1)),(.22,(1,.012,.0002,1)),(.40,(1,.068,.001,1)),(.61,(1,.27,.005,1)),(.78,(1,.62,.035,1)),(.96,(1,.93,.48,1))]
    for i,(pos,col) in enumerate(colors):
        e=ramp.color_ramp.elements[0] if i==0 else ramp.color_ramp.elements.new(pos);e.position=pos;e.color=col
    ls.new(heat,ramp.inputs[0])
    emission=ns.new('ShaderNodeEmission');ls.new(ramp.outputs['Color'],emission.inputs[0]);ls.new(op('ADD',1.4,op('MULTIPLY',rim,5.0)),emission.inputs[1])
    trans=ns.new('ShaderNodeBsdfTransparent');mix=ns.new('ShaderNodeMixShader');ls.new(coverage,mix.inputs[0]);ls.new(trans.outputs[0],mix.inputs[1]);ls.new(emission.outputs[0],mix.inputs[2]);out=ns.new('ShaderNodeOutputMaterial');ls.new(mix.outputs[0],out.inputs[0]);m.use_backface_culling=False
    for i,n in enumerate(ns):n.location=(-2500+(i//24)*215,800-(i%24)*125)
    return m,phase,emission.outputs[0],coverage,mix.outputs[0],out

def bake_body(data):
    m,phase,emit,mask,surface,out=data;s=bpy.context.scene
    s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=1;s.render.bake.margin=0;s.render.bake.use_clear=True;s.view_settings.view_transform='Standard';s.view_settings.look='None'
    bpy.ops.mesh.primitive_plane_add(size=2);plane=bpy.context.object;plane.name='BakePlane';plane.data.materials.append(m)
    ns,ls=m.node_tree.nodes,m.node_tree.links;gray=ns.new('ShaderNodeEmission');ls.new(mask,gray.inputs[0]);target=ns.new('ShaderNodeTexImage');ns.active=target
    manifest={'resolution':[2048,512],'uv':'U0=old tail U1=current sword; V0=outer sword tip V1=root','encoding':'Scene linear HDR EXR, linear data mask PNG','frames':[]};contact=[]
    for f in range(4):
        phase.outputs[0].default_value=.3+f*.18;sample={}
        for kind,socket in [('emission',emit),('mask',gray.outputs[0])]:
            ls.new(socket,out.inputs[0]);im=bpy.data.images.new(f'body_{f}_{kind}',width=2048,height=512,alpha=False,float_buffer=True);im.colorspace_settings.name='Non-Color';target.image=im;ns.active=target
            bpy.ops.object.bake(type='EMIT');ext='exr' if kind=='emission' else 'png';path=BASE/'bakes'/f'ribbon_body_{f}_{kind}.{ext}';im.file_format='OPEN_EXR' if kind=='emission' else 'PNG';im.filepath_raw=str(path);im.save();shutil.copy2(path,GAME/path.name)
            pix=np.empty(2048*512*4,dtype=np.float32);im.pixels.foreach_get(pix);pix=pix.reshape(512,2048,4);sample[kind]=pix
            manifest['frames'].append({'file':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'rgb_max':pix[:,:,:3].max(axis=(0,1)).tolist()});bpy.data.images.remove(im)
        c=sample['emission'][:,:,:3]*sample['mask'][:,:,:1];c=c/(1+c);c=np.where(c<=.0031308,c*12.92,1.055*c**(1/2.4)-.055);contact.append(np.concatenate([c,np.ones((512,2048,1))],axis=2))
    ls.new(surface,out.inputs[0]);ns.remove(target);ns.remove(gray);bpy.data.objects.remove(plane,do_unlink=True)
    img=bpy.data.images.new('BodyBakes_Contact',width=2048,height=2048,alpha=True);img.colorspace_settings.name='Non-Color';img.pixels.foreach_set(np.concatenate(contact[::-1],axis=0).astype(np.float32).ravel());img.file_format='PNG';img.filepath_raw=str(BASE/'blender_previews/body_bakes.png');img.save()
    (BASE/'reports/art_bake_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')

def simple_mat(name,col,metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Base Color'].default_value=(*col,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.35;return m

def arc_mesh(material):
    verts=[];uvs=[];faces=[]
    for i in range(145):
        u=i/144;a=math.radians(-155+u*160)
        for j in range(33):
            v=j/32;r=2.2-v*1.62;verts.append((math.cos(a)*r,math.sin(a)*r,1.0+.12*math.sin(a*1.2)*v));uvs.append((u,v))
    for i in range(144):
        for j in range(32):a=i*33+j;faces.append((a,a+1,a+34,a+33))
    mesh=bpy.data.meshes.new('FireSlash_160deg_Editable');mesh.from_pydata(verts,[],faces);mesh.update();uv=mesh.uv_layers.new(name='BladeUVs')
    for p in mesh.polygons:
        for li in p.loop_indices:uv.data[li].uv=uvs[mesh.loops[li].vertex_index]
    o=bpy.data.objects.new('FIRE_Main_Arc',mesh);bpy.context.scene.collection.objects.link(o);mesh.materials.append(material);return o

def camera_stage(scene):
    world=bpy.data.worlds.new('SlateWorld');world.use_nodes=True;b=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');b.inputs[0].default_value=(.012,.02,.035,1);b.inputs[1].default_value=.3;scene.world=world
    floor=simple_mat('SlateFloor',(.008,.013,.022),.12);bpy.ops.mesh.primitive_plane_add(size=100);bpy.context.object.data.materials.append(floor)
    for name,pos,color,power in [('Softbox',(-2,-3,6),(.45,.62,1),260),('Rim',(2,2,4),(1,.4,.15),130)]:
        ld=bpy.data.lights.new(name,'AREA');ld.energy=power;ld.shape='DISK';ld.size=4;ld.color=color;o=bpy.data.objects.new(name,ld);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    camd=bpy.data.cameras.new('HeroCamera');cam=bpy.data.objects.new('HeroCamera',camd);scene.collection.objects.link(cam);cam.location=(0,-4.6,8.3);target=Vector((0,-.5,.95));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();camd.type='ORTHO';camd.ortho_scale=5.9;scene.camera=cam
    scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=32;scene.render.resolution_x=1280;scene.render.resolution_y=800;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=-.9
    comp=bpy.data.node_groups.new('Soft Fire Bloom','CompositorNodeTree');comp.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor');scene.compositing_node_group=comp;cn,cl=comp.nodes,comp.links;r=cn.new('CompositorNodeRLayers');g=cn.new('CompositorNodeGlare');g.inputs['Type'].default_value='Fog Glow';g.inputs['Threshold'].default_value=1.4;g.inputs['Strength'].default_value=.18;g.inputs['Size'].default_value=.3;out=cn.new('NodeGroupOutput');cl.new(r.outputs['Image'],g.inputs['Image']);cl.new(g.outputs['Image'],out.inputs[0])

def sword():
    steel=simple_mat('Sword_Steel',(.16,.25,.34),.9);brass=simple_mat('Sword_Brass',(.34,.20,.06),.85);leather=simple_mat('Sword_Leather',(.016,.009,.004))
    pivot=bpy.data.objects.new('Sword_Swing_Control',None);bpy.context.scene.collection.objects.link(pivot)
    for name,center,size,mat in [('Blade',(1.39,0,1.02),(1.58,.10,.045),steel),('Guard',(.56,0,1.02),(.08,.43,.09),brass),('Grip',(.35,0,1.02),(.30,.07,.08),leather),('Pommel',(.16,0,1.02),(.10,.10,.10),brass)]:
        bpy.ops.mesh.primitive_cube_add(size=1,location=center);o=bpy.context.object;o.name='Sword_'+name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat);bev=o.modifiers.new('SmallMetalBevel','BEVEL');bev.width=.014;bev.segments=3;o.modifiers.new('Normal','WEIGHTED_NORMAL');o.parent=pivot
    pivot.rotation_euler[2]=math.radians(5);return pivot

def make_flame_mat(name='Particle_Flame',heat_bias=0):
    m=bpy.data.materials.new(name);m.use_nodes=True;ns,ls=m.node_tree.nodes,m.node_tree.links;ns.clear();op=lambda code,*v,label='':node_math(ns,ls,code,*v,label=label)
    tex=ns.new('ShaderNodeTexCoord');sep=ns.new('ShaderNodeSeparateXYZ');ls.new(tex.outputs['UV'],sep.inputs[0])
    phase=ns.new('ShaderNodeValue');phase.name='FLAME_PHASE';phase.outputs[0].default_value=.5
    dissolve=ns.new('ShaderNodeValue');dissolve.name='DISSOLVE';dissolve.outputs[0].default_value=0
    noise=ns.new('ShaderNodeTexNoise');noise.noise_dimensions='4D';ls.new(tex.outputs['Generated'],noise.inputs['Vector']);ls.new(phase.outputs[0],noise.inputs['W']);noise.inputs['Scale'].default_value=4.7;noise.inputs['Detail'].default_value=2.3
    layer=ns.new('ShaderNodeLayerWeight');layer.inputs[0].default_value=.32
    height=sep.outputs['Y'];face=layer.outputs['Facing']
    heat=op('ADD',op('MULTIPLY',op('SUBTRACT',1,height),.28),op('ADD',op('MULTIPLY',noise.outputs['Fac'],.25),op('MULTIPLY',op('SUBTRACT',1,face),.42)))
    heat=op('ADD',heat,heat_bias)
    ramp=ns.new('ShaderNodeValToRGB');ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1]);cols=[(0,(.18,.001,.0001,1)),(.28,(.7,.008,.0001,1)),(.44,(1,.07,.001,1)),(.60,(1,.25,.004,1)),(.80,(1,.7,.06,1)),(.98,(1,.98,.5,1))]
    for i,(pos,col) in enumerate(cols):e=ramp.color_ramp.elements[0] if i==0 else ramp.color_ramp.elements.new(pos);e.position=pos;e.color=col
    ls.new(heat,ramp.inputs[0]);e=ns.new('ShaderNodeEmission');ls.new(ramp.outputs[0],e.inputs[0]);e.inputs[1].default_value=1.4
    erode=op('SUBTRACT',noise.outputs['Fac'],op('ADD',.22,dissolve.outputs[0]));alpha=op('MULTIPLY',erode,12);alpha.node.use_clamp=True
    alpha=op('MULTIPLY',alpha,op('SUBTRACT',1,op('POWER',height,6)))
    tr=ns.new('ShaderNodeBsdfTransparent');mix=ns.new('ShaderNodeMixShader');ls.new(alpha,mix.inputs[0]);ls.new(tr.outputs[0],mix.inputs[1]);ls.new(e.outputs[0],mix.inputs[2]);out=ns.new('ShaderNodeOutputMaterial');ls.new(mix.outputs[0],out.inputs[0]);m.use_backface_culling=False
    return m

def flame_lobe(name,mat,seed,height=1,spread=1):
    mesh=bpy.data.meshes.new(name+'_Mesh');o=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(o);mesh.materials.append(mat);o['seed']=seed;o['height']=height;o['spread']=spread;return o

def pose_flame(o,phase,age):
    seed=o['seed'];H=o['height'];S=o['spread'];verts=[];uvs=[];faces=[];rings=24;segments=28
    for j in range(rings+1):
        t=j/rings
        shoulder=math.sin(math.pi*t)**.7*(1-.43*t)
        radius=.38*shoulder*S*(.86+.14*math.sin(phase*5+seed))
        cx=(.13*math.sin(t*6-phase*3+seed)+.17*t*t*math.sin(phase*3+seed))*t
        cy=.09*math.sin(t*5+phase*2+seed)*t
        for i in range(segments):
            a=i/segments*math.tau
            r=radius*(1+.16*math.sin(a*3+t*7+phase*4+seed)+.08*math.sin(a*7-t*9))
            verts.append((cx+r*math.cos(a),cy+r*math.sin(a),t*H));uvs.append((i/segments,t))
    for j in range(rings):
        for i in range(segments):a=j*segments+i;b=j*segments+(i+1)%segments;faces.append((a,b,b+segments,a+segments))
    mesh=o.data;mesh.clear_geometry();mesh.from_pydata(verts,[],faces);mesh.update();uv=mesh.uv_layers.get('UVMap') or mesh.uv_layers.new(name='UVMap')
    for p in mesh.polygons:
        p.use_smooth=True
        for li in p.loop_indices:uv.data[li].uv=uvs[mesh.loops[li].vertex_index]

def make_flame_cluster(prefix='Atlas'):
    mats=[make_flame_mat(prefix+'_OuterFlame',-.02),make_flame_mat(prefix+'_HotCore',.14)]
    objects=[]
    for i,(height,spread,pos,rot) in enumerate([(1.25,1,(0,0,0),0),(.99,.75,(-.28,.05,.05),-.28),(.85,.65,(.28,.04,.08),.32),(.94,.58,(.04,-.17,.01),.14)]):
        o=flame_lobe(prefix+'_Lobe'+str(i),mats[1] if i==3 else mats[0],2.8+i*2.1,height,spread);o.location=pos;o.rotation_euler[1]=rot;pose_flame(o,.6,.1);objects.append(o)
    return objects,mats

def build_body():
    bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;data=make_body();bake_body(data);arc=arc_mesh(data[0]);pivot=sword();camera_stage(scene)
    # Volumetric flame lobes grow from the broad arc in the beauty study.
    parent=bpy.data.objects.new('FIRE_Worldspace_Clusters',None);scene.collection.objects.link(parent)
    for i,a in enumerate([-129,-100,-69,-40,-17]):
        objs,mats=make_flame_cluster('SlashFlame'+str(i));angle=math.radians(a);radius=1.72+.12*math.sin(i*2)
        for o in objs:
            local=o.location.copy();o.location=Vector((math.cos(angle)*radius,math.sin(angle)*radius,1.0))+local*.31;o.scale=(.30,.30,.37);o.rotation_euler[0]=.25;o.rotation_euler[2]=angle;o.parent=parent
    phase=data[1];phase.outputs[0].default_value=.3;phase.outputs[0].keyframe_insert(data_path='default_value',frame=1);phase.outputs[0].default_value=1.8;phase.outputs[0].keyframe_insert(data_path='default_value',frame=96)
    scene.frame_start=1;scene.frame_end=96;scene.render.fps=30;scene.frame_set(28)
    doc=bpy.data.texts.new('README');doc.write('Fire Slash V002 - native Blender material and volume-shaped flame cluster study.\nWide continuous 160-degree blade surface, yellow hot cutting rim, orange belly, red torn inner edge.\nFour 2048x512 HDR emission+mask bakes are delivered to Godot; native shader nodes are not executed in game.\nSeparate 16-frame 4x4 transparent particle atlas is generated from deforming 3D flame lobes.\nNo external add-on or downloaded artwork is used. Online reference only informs hue layering and following/dissolving fire motion.\n')
    scene.render.filepath=str(BASE/'blender_previews/fire_slash_v002_hero.png');bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'blender/fire_slash_v002.blend'));bpy.ops.render.render(write_still=True)
    print('BODY_READY',flush=True)

def build_atlas():
    bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;objects,mats=make_flame_cluster('Atlas')
    s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=32;s.render.resolution_x=256;s.render.resolution_y=256;s.render.resolution_percentage=100;s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=-.5
    cd=bpy.data.cameras.new('AtlasCamera');cam=bpy.data.objects.new('AtlasCamera',cd);s.collection.objects.link(cam);cam.location=(0,-5,1.1);target=Vector((0,0,.73));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=2.25;s.camera=cam
    frames=BASE/'bakes/flame_frames';frames.mkdir(exist_ok=True)
    manifest={'atlas':'flame_atlas.png','layout':[4,4],'cell':[256,256],'frame_order':'row-major top-left first','color':'sRGB RGBA, straight alpha','frames':[]}
    for frame in range(16):
        age=frame/15;phase=.25+age*1.7
        grow=min(1,.22+age*4.8);late=max(0,(age-.52)/.48);size=grow*(1-.40*late)
        for o in objects:
            pose_flame(o,phase,age);o.scale=(size*(1+.32*late),size*(1+.32*late),size*(1+.35*late));o.location.z=.12*age
        for mat in mats:
            mat.node_tree.nodes['FLAME_PHASE'].outputs[0].default_value=phase;mat.node_tree.nodes['DISSOLVE'].outputs[0].default_value=.03+late*.82
        s.render.filepath=str(frames/f'flame_{frame:02d}.png');bpy.ops.render.render(write_still=True);manifest['frames'].append(s.render.filepath)
    (BASE/'reports/art_atlas_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    # Save the editable source at a visible, full flame state.
    for o in objects:pose_flame(o,.75,.3);o.scale=(1,1,1);o.location.z=0
    for mat in mats:
        mat.node_tree.nodes['FLAME_PHASE'].outputs[0].default_value=.75
        mat.node_tree.nodes['DISSOLVE'].outputs[0].default_value=.03
    bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'blender/flame_atlas_source.blend'));print('ATLAS_FRAMES_READY',flush=True)

def render_movie():
    bpy.ops.wm.open_mainfile(filepath=str(BASE/'blender/fire_slash_v002.blend'),load_ui=False,use_scripts=False);s=bpy.context.scene
    # Change visible mesh trajectory per frame: deliberate anticipation, fast swing,
    # short held tail and dissolution; second cycle slows the readable sweep.
    arc=bpy.data.objects['FIRE_Main_Arc'];pivot=bpy.data.objects['Sword_Swing_Control'];clusters=bpy.data.objects['FIRE_Worldspace_Clusters']
    if arc.data.shape_keys is not None:arc.shape_key_clear()
    original=[v.co.copy() for v in arc.data.vertices]
    s.render.resolution_x=960;s.render.resolution_y=600;s.eevee.taa_render_samples=24
    frames=BASE/'blender_previews/movie_frames';frames.mkdir(exist_ok=True)
    for frame in range(1,97):
        s.frame_set(frame);cycle=(frame-1)%48;t=cycle/47
        progress=max(0,min(1,(t-.12)/(.22 if frame<=48 else .48)))
        fade=max(0,min(1,(1-t)/.19))
        angle=math.radians(-155+160*progress);pivot.rotation_euler[2]=angle
        for i,v in enumerate(arc.data.vertices):
            col=i//33;rad=i%33;u=col/144;vcoord=rad/32;r=2.2-vcoord*1.62
            a=math.radians(-155+160*progress*u);v.co=(math.cos(a)*r,math.sin(a)*r,1+.12*math.sin(a*1.2)*vcoord)
        arc.hide_render=progress<.025 or fade<.01;clusters.hide_render=progress<.25 or fade<.05
        # Material copies preserve the authored coverage graph with a life fade.
        mat=arc.data.materials[0];nodes=mat.node_tree.nodes;links=mat.node_tree.links;mix=next(n for n in nodes if n.type=='MIX_SHADER')
        life=nodes.get('SHOT_LIFETIME')
        if life is None:
            source=mix.inputs[0].links[0].from_socket;life=nodes.new('ShaderNodeMath');life.name='SHOT_LIFETIME';life.operation='MULTIPLY';links.new(source,life.inputs[0]);links.new(life.outputs[0],mix.inputs[0])
        life.inputs[1].default_value=fade
        for child in clusters.children:
            index=int(child.name.split('SlashFlame')[1][0]);visible_angle=[-129,-100,-69,-40,-17][index]
            child.hide_render=math.radians(visible_angle)>angle or fade<.15
            pose_flame(child,frame*.075,1-fade)
            material=child.data.materials[0]
            material.node_tree.nodes['FLAME_PHASE'].outputs[0].default_value=frame*.075
            material.node_tree.nodes['DISSOLVE'].outputs[0].default_value=(1-fade)*.65
        s.render.filepath=str(frames/f'frame_{frame:03d}.png');bpy.ops.render.render(write_still=True)
    print('MOVIE_FRAMES_READY',flush=True)

if __name__=='__main__':
    arg=sys.argv[-1]
    if arg=='body':build_body()
    elif arg=='atlas':build_atlas()
    elif arg=='movie':render_movie()
    else:raise RuntimeError('Choose body, atlas or movie')
