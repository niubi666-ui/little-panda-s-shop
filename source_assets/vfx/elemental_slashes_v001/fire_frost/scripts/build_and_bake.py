"""Blender-authored fire + crystal blade studies and four-frame runtime bakes.

Run with Blender --background --factory-startup --python this_file.
Original Trail FXs assets remain read-only. Only fire uses its material 15.
"""
import bpy, math, random, json, hashlib, shutil
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

BASE = Path(__file__).resolve().parents[1]
ROOT = BASE.parents[3]
SOURCE = next((ROOT / 'source_assets/vfx/trail_fxs_v2/original').rglob('TrailFXs_Blades.blend'))
for folder in ['blender', 'textures', 'previews']:
    (BASE / folder).mkdir(parents=True, exist_ok=True)

def start():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = 1
    s.render.bake.margin = 0
    s.render.bake.use_clear = True
    s.view_settings.view_transform = 'Standard'
    s.view_settings.look = 'None'
    bpy.ops.mesh.primitive_plane_add(size=2)
    return s, bpy.context.object

def math_node(nodes, links, operation, a, b=None, label=''):
    n = nodes.new('ShaderNodeMath'); n.operation = operation; n.label = label
    for socket, value in zip(n.inputs, [a, b]):
        if value is None: continue
        if hasattr(value, 'node'): links.new(value, socket)
        else: socket.default_value = value
    return n.outputs[0]

def fire_material():
    with bpy.data.libraries.load(str(SOURCE), link=False) as (available, target):
        target.materials = ['Trail_Blade_15']
    mat = target.materials[0]; mat.name = 'FIRE_Rolling_Ember__TrailFXs15_Adaptation'
    ns, ls = mat.node_tree.nodes, mat.node_tree.links
    uv = ns.new('ShaderNodeTexCoord'); uv.label = 'Runtime blade UV: U age, V tip-to-root'
    phase = ns.new('ShaderNodeValue'); phase.name = 'PHASE'; phase.label = 'Animated flow phase'; phase.outputs[0].default_value = .48
    for n in list(ns):
        if n.type != 'ATTRIBUTE': continue
        for output in n.outputs:
            for l in list(output.links):
                dest = l.to_socket; ls.remove(l)
                if n.attribute_name == 'BladeUVs': ls.new(uv.outputs['UV'], dest)
                elif n.attribute_name == 'Speed': ls.new(phase.outputs[0], dest)
                elif n.attribute_name == 'Hue': dest.default_value = .5
                elif n.attribute_name == 'UseGlowColors': dest.default_value = 1.0
                elif n.attribute_name in ['Glow', 'Glow2']:
                    if output.name == 'Alpha': dest.default_value = 6.5
                    else: dest.default_value = (1.0, .30, .025, 1) if n.attribute_name == 'Glow' else (1.0, .018, .001, 1)
                else: raise RuntimeError('Unknown attribute '+n.attribute_name)
    mix = next(n for n in ns if n.type == 'MIX_SHADER')
    emission = next(n for n in ns if n.type == 'EMISSION')
    out = next(n for n in ns if n.type == 'OUTPUT_MATERIAL')
    original_mask = mix.inputs[0].links[0].from_socket
    sp = ns.new('ShaderNodeSeparateXYZ'); ls.new(uv.outputs['UV'], sp.inputs[0])
    op = lambda code,a,b=None,label='': math_node(ns,ls,code,a,b,label)
    fade = op('MULTIPLY',sp.outputs['X'],2.9,'Soft chronological tail fade'); fade.node.use_clamp = True
    width = op('ADD',op('MULTIPLY',sp.outputs['X'],.82),.14)
    taper = op('SUBTRACT',1,op('DIVIDE',sp.outputs['Y'],width)); taper.node.use_clamp = True
    taper = op('POWER',taper,.42)
    mask = op('MULTIPLY',original_mask,op('MULTIPLY',fade,taper),'Flame silhouettes with flowing long tips')
    ls.new(mask,mix.inputs[0]); mat.use_backface_culling = False
    return mat, phase, emission.outputs[0], mask, mix.outputs[0], out

def frost_material():
    mat = bpy.data.materials.new('FROST_Faceted_Shards_Procedural'); mat.use_nodes = True
    ns,ls = mat.node_tree.nodes,mat.node_tree.links; ns.clear()
    uv = ns.new('ShaderNodeTexCoord'); uv.location=(-1800,0)
    phase=ns.new('ShaderNodeValue');phase.name='PHASE';phase.label='Crystal drift phase';phase.outputs[0].default_value=.48
    op=lambda code,a,b=None,label='': math_node(ns,ls,code,a,b,label)
    sep=ns.new('ShaderNodeSeparateXYZ');ls.new(uv.outputs['UV'],sep.inputs[0])
    # Fine perturbation creates frost fluting while retaining the polygon silhouettes.
    noise=ns.new('ShaderNodeTexNoise');noise.noise_dimensions='4D';noise.inputs['Scale'].default_value=21
    noise.inputs['Detail'].default_value=2.2;ls.new(uv.outputs['UV'],noise.inputs['Vector']);ls.new(phase.outputs[0],noise.inputs['W'])
    perturb=op('MULTIPLY',op('SUBTRACT',noise.outputs['Fac'],.5),.011)
    u=sep.outputs['X'];v=op('ADD',sep.outputs['Y'],perturb)
    # Author explicit elongated triangles. Their tails follow the slash and do not
    # look like a blue version of the flame noise.
    rng=random.Random(4903);triangles=[]
    for row,(center,width) in enumerate([(.105,.09),(.27,.115),(.47,.125),(.66,.09)]):
        for index in range(8 if row<2 else 5):
            head=.29+index*.102+rng.uniform(-.015,.02) if row<2 else .53+index*.108+rng.uniform(-.015,.02)
            head=min(head,1.04)
            tail=max(.018,head-rng.uniform(.13,.34))
            c=center+rng.uniform(-.038,.038)
            half=width*rng.uniform(.38,.65)
            triangles.append(((tail,c-half*.4),(head,c-half),(head-.025,c+half)))
    triangles += [((.03,.14),(.56,.036),(.48,.086)), ((.17,.27),(.77,.17),(.72,.22))]
    masks=[]
    for i,pts in enumerate(triangles):
        edges=[]
        for j in range(3):
            a,b=pts[j],pts[(j+1)%3];dx,dy=b[0]-a[0],b[1]-a[1]
            cross=op('SUBTRACT',op('MULTIPLY',op('SUBTRACT',v,a[1]),dx),op('MULTIPLY',op('SUBTRACT',u,a[0]),dy))
            signed=op('DIVIDE',cross,math.hypot(dx,dy))
            edges.append(signed)
        distance=op('MINIMUM',op('MINIMUM',edges[0],edges[1]),edges[2])
        aa=op('MULTIPLY',distance,700.0,f'Crystal shard {i+1}');aa.node.use_clamp=True
        masks.append(aa)
    shard=masks[0]
    for m in masks[1:]:shard=op('MAXIMUM',shard,m)
    # Uneven glacial blade rim with a few disconnected needle trails.
    wiggle=op('MULTIPLY',op('SINE',op('ADD',op('MULTIPLY',u,21.0),phase.outputs[0])),.013)
    center=op('ADD',.055,wiggle)
    line=op('ABSOLUTE',op('SUBTRACT',v,center))
    line=op('SUBTRACT',1.0,op('MULTIPLY',line,115.0));line.node.use_clamp=True
    mask=op('MAXIMUM',op('MULTIPLY',shard,.8),line)
    fade=op('MULTIPLY',u,3.4);fade.node.use_clamp=True
    mask=op('MULTIPLY',mask,fade,'Tapered crystal coverage')
    # Facet shading and thin fracture edges in the emission, baked exactly.
    scale=ns.new('ShaderNodeVectorMath');scale.operation='MULTIPLY';ls.new(uv.outputs['UV'],scale.inputs[0]);scale.inputs[1].default_value=(8.0,16.0,1)
    vor=ns.new('ShaderNodeTexVoronoi');vor.voronoi_dimensions='2D';vor.feature='DISTANCE_TO_EDGE';ls.new(scale.outputs['Vector'],vor.inputs['Vector']);vor.inputs['Scale'].default_value=1
    crack=op('SUBTRACT',1.0,op('MULTIPLY',vor.outputs['Distance'],26.0));crack.node.use_clamp=True
    tiles=ns.new('ShaderNodeTexVoronoi');tiles.voronoi_dimensions='2D';tiles.feature='F1';ls.new(scale.outputs['Vector'],tiles.inputs['Vector']);tiles.inputs['Scale'].default_value=1
    detail=op('ADD',op('MULTIPLY',tiles.outputs['Distance'],.7),op('MULTIPLY',crack,.5))
    color=ns.new('ShaderNodeValToRGB');color.label='Blue ice, silver-cyan fracture planes'
    color.color_ramp.elements.remove(color.color_ramp.elements[1])
    for idx,(pos,col) in enumerate([(0,(.006,.07,.32,1)),(.28,(.025,.30,.85,1)),(.55,(.10,.75,1,1)),(.82,(.62,.95,1,1))]):
        e=color.color_ramp.elements[0] if idx==0 else color.color_ramp.elements.new(pos);e.position=pos;e.color=col
    ls.new(detail,color.inputs[0])
    rimboost=op('ADD',1.4,op('ADD',op('MULTIPLY',crack,1.0),op('MULTIPLY',line,3.4)))
    emission=ns.new('ShaderNodeEmission');ls.new(color.outputs['Color'],emission.inputs['Color']);ls.new(rimboost,emission.inputs['Strength'])
    transparent=ns.new('ShaderNodeBsdfTransparent');mix=ns.new('ShaderNodeMixShader');ls.new(mask,mix.inputs[0]);ls.new(transparent.outputs[0],mix.inputs[1]);ls.new(emission.outputs[0],mix.inputs[2])
    out=ns.new('ShaderNodeOutputMaterial');ls.new(mix.outputs[0],out.inputs['Surface'])
    # Layout the editable graph into orderly columns rather than a pile at origin.
    for i,n in enumerate(ns):n.location=(-2400+(i//22)*210,650-(i%22)*130)
    mat.use_backface_culling=False
    return mat,phase,emission.outputs[0],mask,mix.outputs[0],out

def rolling_flame_material():
    """Flowing tongues are independent curved lobes, with holes between them."""
    mat=bpy.data.materials.new('FIRE_Curling_Tongues_Procedural');mat.use_nodes=True
    ns,ls=mat.node_tree.nodes,mat.node_tree.links;ns.clear()
    uv=ns.new('ShaderNodeTexCoord');phase=ns.new('ShaderNodeValue');phase.name='PHASE';phase.outputs[0].default_value=.48
    op=lambda code,a,b=None,label='': math_node(ns,ls,code,a,b,label)
    sep=ns.new('ShaderNodeSeparateXYZ');ls.new(uv.outputs['UV'],sep.inputs[0]);u=sep.outputs['X'];v=sep.outputs['Y']
    scale=ns.new('ShaderNodeVectorMath');scale.operation='MULTIPLY';ls.new(uv.outputs['UV'],scale.inputs[0]);scale.inputs[1].default_value=(2.8,7.5,1)
    noise=ns.new('ShaderNodeTexNoise');noise.noise_dimensions='4D';ls.new(scale.outputs[0],noise.inputs['Vector']);ls.new(phase.outputs[0],noise.inputs['W']);noise.inputs['Scale'].default_value=2.2;noise.inputs['Detail'].default_value=3.5;noise.inputs['Roughness'].default_value=.62
    turbulence=op('SUBTRACT',noise.outputs['Fac'],.5)
    # Slow curl of lobes plus turbulent notches form amber and orange fringes.
    phase_time=op('MULTIPLY',phase.outputs[0],2.3)
    lobes=[]
    for i,(center,width,tail,frequency) in enumerate([(.07,.021,.018,18),(.22,.037,.025,17),(.43,.032,.075,21),(.61,.025,.30,20)]):
        wave=op('SINE',op('ADD',op('ADD',op('MULTIPLY',u,frequency),i*1.83),phase_time))
        wave2=op('SINE',op('SUBTRACT',op('MULTIPLY',u,frequency*.53),phase_time))
        height=op('ADD',center,op('ADD',op('MULTIPLY',wave,.031),op('MULTIPLY',wave2,.018)))
        height=op('ADD',height,op('MULTIPLY',turbulence,.055))
        taper=op('DIVIDE',op('SUBTRACT',u,tail),1-tail);taper.node.use_clamp=True
        taper=op('POWER',taper,.62)
        bulge=op('ADD',.76,op('MULTIPLY',op('SINE',op('ADD',op('MULTIPLY',u,24+i*3),phase_time)),.24))
        thickness=op('ADD',.0015,op('MULTIPLY',op('MULTIPLY',taper,width),bulge))
        distance=op('DIVIDE',op('ABSOLUTE',op('SUBTRACT',v,height)),thickness)
        tongue=op('SUBTRACT',1,distance);tongue.node.use_clamp=True
        # Separate fine fringes are carried alongside the main hot flame tongues.
        tongue=op('POWER',tongue,.42)
        lobes.append(tongue)
    # Short tongues peel away from the hot spines and curl into the wake.
    # Unlike concentric bands, each tongue has its own start/end and hooked tip.
    rng=random.Random(1583)
    for i in range(26):
        row=i%4;base=[.07,.22,.43,.61][row]
        start=rng.uniform(.11,.84);length=rng.uniform(.10,.28);end=min(1.04,start+length)
        local=op('DIVIDE',op('SUBTRACT',u,start),end-start)
        clipped=op('MAXIMUM',local,0);clipped=op('MINIMUM',clipped,1)
        envelope=op('SINE',op('MULTIPLY',clipped,math.pi))
        bend=op('MULTIPLY',op('POWER',op('SUBTRACT',1,clipped),1.6),rng.uniform(.07,.14)*(-1 if i%3==0 else 1))
        wave=op('MULTIPLY',op('SINE',op('ADD',op('MULTIPLY',clipped,5),phase_time)),.023)
        center=op('ADD',base,op('ADD',bend,wave))
        center=op('ADD',center,op('MULTIPLY',turbulence,.026))
        thickness=op('ADD',.0001,op('MULTIPLY',op('POWER',envelope,.8),rng.uniform(.013,.028)))
        distance=op('DIVIDE',op('ABSOLUTE',op('SUBTRACT',v,center)),thickness)
        tongue=op('SUBTRACT',1,distance);tongue.node.use_clamp=True
        tongue=op('MULTIPLY',op('POWER',tongue,.5),op('MINIMUM',op('MULTIPLY',envelope,10),1))
        lobes.append(tongue)
    hot=lobes[0]
    for lobe in lobes[1:]:hot=op('MAXIMUM',hot,lobe)
    # Erode short segments into turbulent holes, exposing the background.
    perforation=op('ADD',.68,op('MULTIPLY',noise.outputs['Fac'],.6));perforation.node.use_clamp=True
    mask=op('MULTIPLY',hot,perforation)
    fade=op('MULTIPLY',u,4.2);fade.node.use_clamp=True
    mask=op('MULTIPLY',mask,fade,'Long organic taper')
    heat=op('ADD',op('MULTIPLY',hot,.77),op('MULTIPLY',noise.outputs['Fac'],.22))
    ramp=ns.new('ShaderNodeValToRGB');ramp.label='Red fringe / orange flame / molten yellow heart'
    ramp.color_ramp.elements.remove(ramp.color_ramp.elements[1])
    for i,(pos,col) in enumerate([(0,(.36,.004,.0001,1)),(.3,(1,.036,.001,1)),(.6,(1,.19,.004,1)),(.84,(1,.52,.035,1)),(.98,(1,.85,.24,1))]):
        e=ramp.color_ramp.elements[0] if i==0 else ramp.color_ramp.elements.new(pos);e.position=pos;e.color=col
    ls.new(heat,ramp.inputs[0])
    emission=ns.new('ShaderNodeEmission');ls.new(ramp.outputs['Color'],emission.inputs['Color']);emission.inputs['Strength'].default_value=3.4
    transparent=ns.new('ShaderNodeBsdfTransparent');mix=ns.new('ShaderNodeMixShader');ls.new(mask,mix.inputs[0]);ls.new(transparent.outputs[0],mix.inputs[1]);ls.new(emission.outputs[0],mix.inputs[2])
    out=ns.new('ShaderNodeOutputMaterial');ls.new(mix.outputs[0],out.inputs[0])
    for i,n in enumerate(ns):n.location=(-1800+(i//16)*220,700-(i%16)*125)
    mat.use_backface_culling=False
    return mat,phase,emission.outputs[0],mask,mix.outputs[0],out

def bake(kind,scene,plane,data):
    mat,phase,radiance,mask,surface,out=data;plane.data.materials.append(mat)
    ns,ls=mat.node_tree.nodes,mat.node_tree.links
    grayscale=ns.new('ShaderNodeEmission');ls.new(mask,grayscale.inputs['Color']);grayscale.inputs['Strength'].default_value=1
    target=ns.new('ShaderNodeTexImage');target.label='Runtime bake destination';ns.active=target
    target_dir=ROOT/'game/assets/vfx/elemental_slashes_v001'/kind;target_dir.mkdir(parents=True,exist_ok=True)
    report=[];contact=[]
    for frame in range(4):
        phase.outputs[0].default_value=.48+frame*.14
        pixels={}
        for name,socket in [('emission',radiance),('mask',grayscale.outputs[0])]:
            ls.new(socket,out.inputs['Surface'])
            image=bpy.data.images.new(f'{kind}_{frame}_{name}',width=1024,height=256,alpha=False,float_buffer=True)
            image.colorspace_settings.name='Non-Color';target.image=image;ns.active=target
            bpy.ops.object.bake(type='EMIT')
            ext='exr' if name=='emission' else 'png';path=BASE/'textures'/f'{kind}_{frame}_{name}.{ext}'
            image.file_format='OPEN_EXR' if name=='emission' else 'PNG';image.filepath_raw=str(path);image.save()
            shutil.copy2(path,target_dir/path.name)
            arr=np.empty(1024*256*4,dtype=np.float32);image.pixels.foreach_get(arr);arr=arr.reshape(256,1024,4)
            pixels[name]=arr.copy()
            report.append({'path':str(path.relative_to(ROOT)),'runtime':str((target_dir/path.name).relative_to(ROOT)),'max_rgb':arr[:,:,:3].max(axis=(0,1)).tolist(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
            bpy.data.images.remove(image)
        color=pixels['emission'][:,:,:3]*pixels['mask'][:,:,:1];color=color/(1+color)
        color=np.where(color<=.0031308,color*12.92,1.055*np.power(color,1/2.4)-.055)
        contact.append(np.concatenate([color,np.ones((256,1024,1),dtype=np.float32)],axis=2))
    ls.new(surface,out.inputs['Surface']);phase.outputs[0].default_value=.76
    ns.remove(target);ns.remove(grayscale)
    im=bpy.data.images.new(kind+'_baked_contact',width=1024,height=1024,alpha=True,float_buffer=False);im.colorspace_settings.name='Non-Color'
    im.pixels.foreach_set(np.concatenate(contact[::-1],axis=0).astype(np.float32).ravel());im.file_format='PNG';im.filepath_raw=str(BASE/'previews'/f'{kind}_baked_contact.png');im.save()
    return report

def metallic(name,color,metallic=.7):
    m=bpy.data.materials.new(name);m.use_nodes=True;p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metallic;p.inputs['Roughness'].default_value=.3;return m

def arc_mesh(kind,material):
    verts=[];uvs=[];faces=[]
    for i in range(129):
        u=i/128;angle=math.radians(-155+u*160)
        for j in range(17):
            v=j/16;r=2.45-v*1.76
            verts.append((math.cos(angle)*r,math.sin(angle)*r,1.0+.05*math.sin(angle)))
            uvs.append((u,v))
    for i in range(128):
        for j in range(16):
            a=i*17+j;faces.append((a,a+1,a+18,a+17))
    mesh=bpy.data.meshes.new(kind+'_160deg_arc');mesh.from_pydata(verts,[],faces);mesh.update()
    uv=mesh.uv_layers.new(name='BladeUVs')
    for poly in mesh.polygons:
        for li in poly.loop_indices:uv.data[li].uv=uvs[mesh.loops[li].vertex_index]
    o=bpy.data.objects.new(kind.upper()+'_Editable_Arc',mesh);bpy.context.scene.collection.objects.link(o);mesh.materials.append(material);return o

def stage(kind,scene,plane,data):
    bpy.data.objects.remove(plane,do_unlink=True)
    mat,phase,_,_,_,_=data;arc_mesh(kind,mat)
    # Small bevelled sword at the latest edge of the arc.
    steel=metallic('Silver_Steel',(.12,.20,.28));gold=metallic('Antique_Brass',(.31,.18,.055));leather=metallic('Dark_Leather',(.018,.012,.009),.05)
    ang=math.radians(5);basis=Matrix.Rotation(ang,4,'Z')
    def box(name,center,size,material,bevel=.018):
        bpy.ops.mesh.primitive_cube_add(size=1,location=basis@Vector(center));o=bpy.context.object;o.name=name;o.dimensions=size;o.rotation_euler[2]=ang;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material)
        mod=o.modifiers.new('Fine edge highlights','BEVEL');mod.width=bevel;mod.segments=3
        o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');return o
    box('Sword_Blade',(1.59,0,1.016),(1.69,.11,.055),steel,.018)
    box('Sword_Guard',(.70,0,1.016),(.085,.48,.09),gold)
    box('Sword_Grip',(.47,0,1.016),(.33,.07,.085),leather)
    box('Sword_Pommel',(.265,0,1.016),(.105,.125,.10),gold)
    # Preview debris: same shape language as runtime particles, spread behind the arc.
    rng=random.Random(208 if kind=='fire' else 649)
    glow=bpy.data.materials.new(kind+'_Particle_Emission');glow.use_nodes=True;pn=glow.node_tree.nodes;pn.clear();pe=pn.new('ShaderNodeEmission');pe.inputs[0].default_value=(1,.17,.012,1) if kind=='fire' else (.12,.62,1,1);pe.inputs[1].default_value=3.8;po=pn.new('ShaderNodeOutputMaterial');glow.node_tree.links.new(pe.outputs[0],po.inputs[0])
    for i in range(42 if kind=='fire' else 27):
        a=math.radians(rng.uniform(-153,1));r=rng.uniform(1.15,2.66);z=rng.uniform(.85,1.45)
        if kind=='fire':bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=rng.uniform(.008,.023),location=(math.cos(a)*r,math.sin(a)*r,z))
        else:bpy.ops.mesh.primitive_cone_add(vertices=4,radius1=.027,radius2=0,depth=rng.uniform(.065,.135),location=(math.cos(a)*r,math.sin(a)*r,z))
        o=bpy.context.object;o.name=kind+'_Preview_Fragment';o.rotation_euler=(rng.random()*3,rng.random()*3,a);o.data.materials.append(glow)
    floor=metallic('Charcoal_Slate',(.009,.014,.023),.15)
    box('Studio_Ground',(0,0,-.18),(200,200,.1),floor,0)
    world=bpy.data.worlds.new('Dark_Studio');world.use_nodes=True;next(n for n in world.node_tree.nodes if n.type=='BACKGROUND').inputs[0].default_value=(.012,.022,.04,1);next(n for n in world.node_tree.nodes if n.type=='BACKGROUND').inputs[1].default_value=.25;scene.world=world
    for name,pos,color,power,size in [('Cool_Softbox',(0,0,6),(.4,.65,1),300,5),('Warm_Edge',(-3,-1,3),(1,.55,.21),220,3)]:
        ld=bpy.data.lights.new(name,'AREA');ld.energy=power;ld.color=color;ld.shape='DISK';ld.size=size;o=bpy.data.objects.new(name,ld);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    cd=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',cd);scene.collection.objects.link(cam);cam.location=(0,-5.5,9.5);target=Vector((0,-.5,1));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=6.6;scene.camera=cam
    scene.render.engine='BLENDER_EEVEE';scene.eevee.taa_render_samples=64;scene.render.resolution_x=1280;scene.render.resolution_y=800;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX';scene.view_settings.look='None';scene.view_settings.exposure=0
    comp=bpy.data.node_groups.new(kind+'_Gentle_Glow','CompositorNodeTree');comp.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor');scene.compositing_node_group=comp
    cn,cl=comp.nodes,comp.links;rl=cn.new('CompositorNodeRLayers');g=cn.new('CompositorNodeGlare');g.inputs['Type'].default_value='Fog Glow';g.inputs['Threshold'].default_value=1.3;g.inputs['Strength'].default_value=.27;g.inputs['Size'].default_value=.28;out=cn.new('NodeGroupOutput');cl.new(rl.outputs['Image'],g.inputs['Image']);cl.new(g.outputs['Image'],out.inputs['Image'])
    phase.outputs[0].default_value=.48;phase.outputs[0].keyframe_insert(data_path='default_value',frame=1);phase.outputs[0].default_value=.90;phase.outputs[0].keyframe_insert(data_path='default_value',frame=60);scene.frame_start=1;scene.frame_end=60;scene.frame_set(40)
    doc=bpy.data.texts.new('READ_ME');doc.write('Editable Blender sword-trail material study.\nFire uses newly authored curved tongue / turbulence / molten colour shader nodes.\nFrost has newly authored triangular shard / Voronoi facet shader nodes.\nThe arc is a 160-degree material inspection mesh; source UV U0=old trail,U1=sword; V0=tip,V1=root.\nGodot uses four baked 1024x256 HDR emission + opacity textures, not Blender nodes at runtime.\nPreview fragments illustrate the shape language; runtime CPUParticles are configured separately.\n')
    scene['runtime_scene']='res://presentation/combat/fx/elemental_slashes_v001/'+kind+'/slash.tscn'
    scene.render.filepath=str(BASE/'previews'/f'{kind}_hero.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'blender'/f'{kind}_study.blend'))
    bpy.ops.render.render(write_still=True)

manifest={'blender':bpy.app.version_string,'resolution':[1024,256],'color_encoding':'scene-linear HDR EXR + linear mask PNG','uv':'U0=old tail U1=sword; V0=tip V1=root','fire_source':'New native shader graph: flowing tongues, turbulent edges, molten heat colour','frost_source':'New native shader graph: triangular shards and Voronoi facets','effects':{}}
for kind in ['fire','frost']:
    scene,plane=start();data=rolling_flame_material() if kind=='fire' else frost_material()
    manifest['effects'][kind]=bake(kind,scene,plane,data)
    stage(kind,scene,plane,data)
    (BASE/'bake_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print('COMPLETE',kind,flush=True)
