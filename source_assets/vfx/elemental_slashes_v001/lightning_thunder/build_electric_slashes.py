"""Original electric filaments: authored UV paths -> editable Blender material -> EMIT bake.
No Trail FX texture or third-party texture is reused. Run with Blender --background.
"""
import bpy, math, json, hashlib, shutil
import numpy as np
from pathlib import Path
from mathutils import Vector

BASE = Path(__file__).resolve().parent
ROOT = Path('E:/ShopGame')
W, H = 1024, 256
for folder in ['blender', 'renders', 'textures', 'reports']:
    (BASE/folder).mkdir(parents=True, exist_ok=True)

SETTINGS = {
    'lightning': {'seed': 613, 'centers': [.20,.42,.68,.84], 'width': 1.15, 'wander': .033,
                  'branches': 5, 'primary': (2.8,4.8,6.4,1), 'secondary': (.05,1.9,5.5,1),
                  'halo': (.015,.34,1.2,1), 'spark_count': 32, 'tail': .23, 'rate': 13.0,
                  'runtime_energy': .88, 'description': 'Fine discontinuous cyan-white filaments, narrow root, sparse forks.'},
    'thunder': {'seed': 1783, 'centers': [.25,.52,.76], 'width': 3.7, 'wander': .095,
                'branches': 10, 'primary': (5.5,3.6,7.2,1), 'secondary': (5.8,2.4,.12,1),
                'halo': (.54,.035,1.15,1), 'spark_count': 56, 'tail': .30, 'rate': 10.0,
                'runtime_energy': .78, 'description': 'Wide angular violet-white bolts, braided golden branches, broken shock ripples.'}
}

def paths_for(kind, phase):
    settings=SETTINGS[kind]
    rng=np.random.default_rng(settings['seed'])
    paths=[]
    for index, center in enumerate(settings['centers']):
        count=29 if kind=='lightning' else 19
        xs=np.linspace(.08 + index*.025, .993, count)
        base=rng.uniform(-1,1,count)*settings['wander']
        phase_shift=np.sin(np.arange(count)*1.7 + phase*1.1 + index)*settings['wander']*.42
        ys=center + base + phase_shift + np.sin(xs*5+index)*.032
        taper=.27+.73*xs
        # Tail is sparse and narrows into fine angular forks.
        pts=np.stack([xs, .5+(ys-.5)*taper],axis=1)
        paths.append((pts,settings['width']*(1-index*.10),0))
        for branch_index in range(settings['branches']):
            anchor=int(rng.integers(4,count-2))
            origin=pts[anchor]
            dx=float(rng.uniform(-.135,.08))
            dy=float(rng.choice([-1,1])*rng.uniform(.035,.13 if kind=='lightning' else .22))
            t=np.linspace(0,1,6)
            fork=np.column_stack([origin[0]+dx*t,origin[1]+dy*t])
            fork[1:-1,1]+=rng.uniform(-.019,.019,4)
            fork[1:-1,0]+=rng.uniform(-.009,.009,4)
            fork[:,1]+=np.sin(t*8+phase)*.009*t
            if branch_index % 3 != phase % 3 or kind=='thunder':
                paths.append((fork, settings['width']*.48,1))
    if kind=='thunder':
        # Distinct fractured shock ribs, crossing the main longitudinal bundles.
        for index, u in enumerate([.32,.54,.78]):
            t=np.linspace(-.78,.82,17)
            p=np.column_stack([u+.034*np.cos(t*3.1)+.009*np.sin(t*22+phase),.5+t*.47])
            paths.append((p[:8],1.45,1))
            paths.append((p[10:],1.45,1))
    return paths

def raster(paths):
    main=np.zeros((H,W),np.float32)
    branches=np.zeros_like(main)
    halo=np.zeros_like(main)
    for pts,width,channel in paths:
        for a,b in zip(pts[:-1],pts[1:]):
            a=a*np.array([W,H]); b=b*np.array([W,H])
            pad=width*5+3
            xmin=max(0,int(min(a[0],b[0])-pad)); xmax=min(W,int(max(a[0],b[0])+pad+1))
            ymin=max(0,int(min(a[1],b[1])-pad)); ymax=min(H,int(max(a[1],b[1])+pad+1))
            if xmin>=xmax or ymin>=ymax: continue
            yy,xx=np.mgrid[ymin:ymax,xmin:xmax]
            ab=b-a
            t=np.clip(((xx-a[0])*ab[0]+(yy-a[1])*ab[1])/max(float(ab@ab),1e-5),0,1)
            distance=np.sqrt((xx-a[0]-t*ab[0])**2+(yy-a[1]-t*ab[1])**2)
            taper=np.clip((xx/W-.045)*8,0,1)
            brightness=np.clip(1-(xx/W-.985)*55,0,1)
            core=np.clip((width+.8-distance)/1.3,0,1)*taper*brightness
            glow=np.exp(-distance**2/(width*2.6+1.7)**2)*taper*brightness
            target=main if channel==0 else branches
            target[ymin:ymax,xmin:xmax]=np.maximum(target[ymin:ymax,xmin:xmax],core)
            halo[ymin:ymax,xmin:xmax]=np.maximum(halo[ymin:ymax,xmin:xmax],glow*.8)
    # Blade edges stay clean; source UVs use V=0 tip / V=1 root.
    border=np.minimum(np.linspace(0,1,H),np.linspace(1,0,H))[:,None]
    edge=np.clip(border/.045,0,1)
    rgba=np.stack([main*edge,branches*edge,halo*edge,np.ones_like(main)],axis=2)
    return rgba.astype(np.float32)

def make_image(name, pixels):
    image=bpy.data.images.new(name,width=W,height=H,alpha=False,float_buffer=True)
    image.colorspace_settings.name='Non-Color'
    image.pixels.foreach_set(pixels.ravel())
    image.pack()
    return image

def math_node(nodes, links, operation, a, b=None):
    node=nodes.new('ShaderNodeMath'); node.operation=operation
    for index,value in enumerate([a,b] if b is not None else [a]):
        if isinstance(value,(float,int)): node.inputs[index].default_value=value
        else: links.new(value,node.inputs[index])
    return node.outputs[0]

def material_for(kind, images):
    settings=SETTINGS[kind]
    material=bpy.data.materials.new(kind.title()+'_Editable_Filament_Material')
    material.use_nodes=True
    material.surface_render_method='DITHERED'
    nodes=material.node_tree.nodes; nodes.clear(); links=material.node_tree.links
    uv=nodes.new('ShaderNodeTexCoord'); uv.location=(-950,0)
    tex=nodes.new('ShaderNodeTexImage'); tex.name='PHASE_SOURCE'; tex.label='Authored filament channels: core / forks / glow'
    tex.image=images[0]; tex.location=(-700,0); tex.interpolation='Linear'
    links.new(uv.outputs['UV'],tex.inputs['Vector'])
    split=nodes.new('ShaderNodeSeparateColor'); split.mode='RGB'; split.location=(-440,0)
    links.new(tex.outputs['Color'],split.inputs['Color'])
    add_outputs=[]
    for index,key in enumerate(['primary','secondary','halo']):
        mix=nodes.new('ShaderNodeMixRGB'); mix.blend_type='MULTIPLY'; mix.inputs[0].default_value=1.0
        mix.label=key+' HDR radiance'; mix.location=(-200,index*170)
        links.new(split.outputs[index],mix.inputs[1]); mix.inputs[2].default_value=settings[key]
        add_outputs.append(mix.outputs[0])
    color=add_outputs[0]
    for index,value in enumerate(add_outputs[1:]):
        add=nodes.new('ShaderNodeMixRGB'); add.blend_type='ADD'; add.inputs[0].default_value=1.0
        add.location=(30,index*170); links.new(color,add.inputs[1]); links.new(value,add.inputs[2]); color=add.outputs[0]
    emission=nodes.new('ShaderNodeEmission'); emission.name='HDR_EMISSION'; emission.location=(250,160)
    links.new(color,emission.inputs['Color']); emission.inputs['Strength'].default_value=1
    coverage=math_node(nodes,links,'MAXIMUM',split.outputs[0],split.outputs[1])
    glow=math_node(nodes,links,'MULTIPLY',split.outputs[2],.48)
    coverage=math_node(nodes,links,'ADD',coverage,glow)
    coverage=math_node(nodes,links,'MINIMUM',coverage,1.0)
    mask=nodes.new('ShaderNodeEmission'); mask.name='MASK_EMISSION'; mask.location=(250,-200)
    links.new(coverage,mask.inputs['Color']); mask.inputs['Strength'].default_value=1
    transparent=nodes.new('ShaderNodeBsdfTransparent'); transparent.location=(250,-30)
    mix=nodes.new('ShaderNodeMixShader'); mix.name='TRANSPARENT_SURFACE'; mix.location=(500,70)
    links.new(coverage,mix.inputs[0]); links.new(transparent.outputs[0],mix.inputs[1]); links.new(emission.outputs[0],mix.inputs[2])
    output=nodes.new('ShaderNodeOutputMaterial'); output.location=(740,70); links.new(mix.outputs[0],output.inputs['Surface'])
    return material,tex,emission,mask,mix,output

def build_arc(material):
    verts=[]; uvs=[]; faces=[]
    columns,rows=128,20
    for col in range(columns+1):
        u=col/columns; angle=-2.60+2.80*u
        for row in range(rows+1):
            v=row/rows; radius=2.8+(1.05-2.8)*v
            verts.append((radius*math.cos(angle),radius*math.sin(angle),.44+.07*math.sin(u*math.pi)))
            uvs.append((u,v))
    for col in range(columns):
        for row in range(rows):
            a=col*(rows+1)+row; b=a+rows+1
            faces.append((a,b,b+1,a+1))
    mesh=bpy.data.meshes.new('160_Degree_Editable_Arc'); mesh.from_pydata(verts,[],faces); mesh.update()
    layer=mesh.uv_layers.new(name='BladeUV')
    for polygon in mesh.polygons:
        for loop in polygon.loop_indices: layer.data[loop].uv=uvs[mesh.loops[loop].vertex_index]
    obj=bpy.data.objects.new('160_Degree_Sword_Arc',mesh); bpy.context.collection.objects.link(obj); mesh.materials.append(material)
    return obj

def simple_material(name,color,metallic=0,roughness=.4,emission=0):
    mat=bpy.data.materials.new(name); mat.diffuse_color=(*color,1); mat.use_nodes=True
    p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    p.inputs['Base Color'].default_value=(*color,1); p.inputs['Metallic'].default_value=metallic; p.inputs['Roughness'].default_value=roughness
    p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emission
    return mat

def cube(name,loc,scale,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); obj=bpy.context.object; obj.name=name; obj.scale=scale; obj.data.materials.append(mat)
    return obj

def render_stage(kind,material):
    scene=bpy.context.scene
    scene.render.engine='BLENDER_EEVEE'; scene.eevee.taa_render_samples=32
    scene.render.resolution_x=1100; scene.render.resolution_y=700; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.world=bpy.data.worlds.new('Deep_Slate_World'); scene.world.use_nodes=True
    next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND').inputs[0].default_value=(.015,.022,.038,1)
    next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND').inputs[1].default_value=.20
    scene.view_settings.view_transform='AgX'; scene.view_settings.exposure=-.35
    floor=simple_material('Slate_Metal',(.025,.035,.052),.2,.5)
    cube('Preview_Plinth',(0,0,-.10),(8,7,.15),floor)
    grid=simple_material('Subtle_Grid',(.052,.065,.083),.1,.6)
    for i in range(-6,7):
        cube('Grid_X',(i*.5,0,-.018),(.005,6,.003),grid)
        cube('Grid_Y',(0,i*.5,-.018),(7,.005,.003),grid)
    silver=simple_material('Sword_Silver',(.21,.29,.39),.88,.2)
    gold=simple_material('Guard_Brass',(.35,.16,.04),.8,.3)
    leather=simple_material('Grip_Leather',(.023,.018,.014),.0,.8)
    angle=.20; axis=Vector((math.cos(angle),math.sin(angle),0))
    blade=cube('Long_Sword_Blade',tuple(axis*1.96+Vector((0,0,.455))),(1.70,.09,.035),silver);blade.rotation_euler[2]=angle
    guard=cube('Sword_Guard',tuple(axis*1.08+Vector((0,0,.455))),(.11,.42,.07),gold);guard.rotation_euler[2]=angle
    grip=cube('Sword_Grip',tuple(axis*.84+Vector((0,0,.455))),(.34,.065,.06),leather);grip.rotation_euler[2]=angle
    color=(.08,.52,1.0) if kind=='lightning' else (.64,.20,1.0)
    sparkmat=simple_material('Electric_Fragment',color,0,.3,7.0)
    rng=np.random.default_rng(SETTINGS[kind]['seed']+100)
    for index in range(18 if kind=='lightning' else 30):
        angle=float(rng.uniform(-2.5,.15)); radius=float(rng.uniform(2.68,3.12)); z=float(rng.uniform(.25,.82))
        curve=bpy.data.curves.new('Broken_Electric_Fragment','CURVE');curve.dimensions='3D';curve.resolution_u=1;curve.bevel_resolution=1
        curve.bevel_depth=.006 if kind=='lightning' else .010
        spline=curve.splines.new('POLY');spline.points.add(3)
        for step,p in enumerate(spline.points):
            p.co=(radius*math.cos(angle)+step*.028, radius*math.sin(angle)+(-1 if step%2 else 1)*.018,z+step*.04,1)
        obj=bpy.data.objects.new('Electric_Fragment_%02d'%index,curve);scene.collection.objects.link(obj);curve.materials.append(sparkmat)
    for name,loc,power,color,size in [('Softbox',(1,-3,5),650,(.68,.80,1),5),('Blue_Rim',(-3,2,3),480,(.20,.38,1),4)]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
        obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=loc;obj.rotation_euler=(Vector((0,-.3,.2))-obj.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=(4.4,-6.7,7.2));camera=bpy.context.object;camera.name='Hero_Camera';camera.rotation_euler=(Vector((0,-.55,.3))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=7.1;scene.camera=camera
    tree=bpy.data.node_groups.new('Electric_Subtle_Bloom','CompositorNodeTree');scene.compositing_node_group=tree
    tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
    source=tree.nodes.new('CompositorNodeRLayers');glare=tree.nodes.new('CompositorNodeGlare');out=tree.nodes.new('NodeGroupOutput')
    glare.inputs['Type'].default_value='Fog Glow';glare.inputs['Threshold'].default_value=1.8;glare.inputs['Strength'].default_value=.20;glare.inputs['Size'].default_value=.26
    tree.links.new(source.outputs['Image'],glare.inputs['Image']);tree.links.new(glare.outputs['Image'],out.inputs['Image'])

def godot_resources(kind):
    config=SETTINGS[kind]
    folder=ROOT/'game/presentation/combat/fx/elemental_slashes_v001'/kind; folder.mkdir(parents=True,exist_ok=True)
    lines=['[gd_resource type="ShaderMaterial" load_steps=10 format=3]','[ext_resource type="Shader" path="res://presentation/combat/fx/trail_presets_01_06_v001/baked_trail.gdshader" id="shader"]']
    for frame in range(4):
        for channel,ext in [('emission','exr'),('mask','png')]:
            lines.append(f'[ext_resource type="Texture2D" path="res://assets/vfx/elemental_slashes_v001/{kind}/{kind}_{frame}_{channel}.{ext}" id="{channel}_{frame}"]')
    lines+=['[resource]','shader = ExtResource("shader")']
    for frame in range(4):
        for channel in ['emission','mask']: lines.append(f'shader_parameter/{channel}_{frame} = ExtResource("{channel}_{frame}")')
    lines+=['shader_parameter/frame_phase = 0.0',f'shader_parameter/energy_scale = {config["runtime_energy"]}','shader_parameter/opacity = 1.0']
    (folder/'material.tres').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    scene=(ROOT/'game/presentation/combat/fx/golden_trail_v001/golden_slash.tscn').read_text(encoding='utf-8')
    scene=scene.replace('res://presentation/combat/fx/golden_trail_v001/golden_filaments.tres',f'res://presentation/combat/fx/elemental_slashes_v001/{kind}/material.tres')
    scene=scene.replace('GoldenSwordTrail',kind.title()+'SwordTrail').replace('tip_extension_ratio = 0.0','tip_extension_ratio = 0.28')
    scene=scene.replace('tail_lifetime_sec = 0.26',f'tail_lifetime_sec = {config["tail"]}').replace('noise_frame_rate = 6.6666667',f'noise_frame_rate = {config["rate"]}')
    scene=scene.replace('amount = 64',f'amount = {config["spark_count"]}')
    scene=scene.replace('type="SphereMesh"','type="PrismMesh"').replace('radius = 0.013\nheight = 0.026\nradial_segments = 8\nrings = 4','size = Vector3(0.012, 0.075, 0.014)' if kind=='lightning' else 'size = Vector3(0.025, 0.11, 0.023)')
    scene=scene.replace('Color(1, 0.69, 0.23, 1)','Color(0.35, 0.8, 1, 1)' if kind=='lightning' else 'Color(0.7, 0.35, 1, 1)')
    scene=scene.replace('Color(1, 0.31, 0.03, 1)','Color(0.12, 0.55, 1, 1)' if kind=='lightning' else 'Color(0.75, 0.22, 1, 1)')
    scene=scene.replace('colors = PackedColorArray(1, 0.94, 0.58, 1, 1, 0.5, 0.07, 0.8, 1, 0.13, 0.01, 0)', 'colors = PackedColorArray(0.75, 0.98, 1, 1, 0.08, 0.45, 1, 0.8, 0.02, 0.12, 0.6, 0)' if kind=='lightning' else 'colors = PackedColorArray(1, 0.85, 0.45, 1, 0.65, 0.22, 1, 0.85, 0.22, 0.01, 0.65, 0)')
    scene=scene.replace('gravity = Vector3(0, -1.2, 0)','gravity = Vector3(0, -0.15, 0)').replace('initial_velocity_max = 1.8','initial_velocity_max = 2.1')
    (folder/'slash.tscn').write_text(scene,encoding='utf-8')

manifest={'blender':bpy.app.version_string,'resolution':[W,H],'source':'Original authored zigzag UV paths and native Blender materials; no third-party texture reused','uv':'U0 tail U1 sword head; V0 tip V1 root','effects':{}}
for kind in ['lightning','thunder']:
    print('BUILD_START',kind,flush=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene;scene.name=kind.title()+'_Sword_Study'
    source_images=[];all_paths=[]
    for frame in range(4):
        paths=paths_for(kind,frame);all_paths.append([{'points':p.tolist(),'width_px':w,'layer':c} for p,w,c in paths])
        source_images.append(make_image(kind+'_Authored_Paths_Phase_%d'%frame,raster(paths)))
    material,source,emission,mask,surface,output=material_for(kind,source_images)
    arc=build_arc(material)
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=1;scene.render.bake.margin=0
    bpy.context.view_layer.objects.active=arc;arc.select_set(True)
    target=material.node_tree.nodes.new('ShaderNodeTexImage');target.name='BAKE_TARGET';target.location=(-700,-420)
    game_folder=ROOT/'game/assets/vfx/elemental_slashes_v001'/kind;game_folder.mkdir(parents=True,exist_ok=True)
    source_folder=BASE/'textures'/kind;source_folder.mkdir(exist_ok=True)
    records=[]
    for frame in range(4):
        source.image=source_images[frame]
        for channel,node,extension in [('emission',emission,'exr'),('mask',mask,'png')]:
            for link in list(output.inputs['Surface'].links):material.node_tree.links.remove(link)
            material.node_tree.links.new(node.outputs[0],output.inputs['Surface'])
            image=bpy.data.images.new(kind+'_%d_%s'%(frame,channel),width=W,height=H,alpha=False,float_buffer=True);image.colorspace_settings.name='Non-Color'
            target.image=image;material.node_tree.nodes.active=target
            bpy.ops.object.bake(type='EMIT')
            path=source_folder/f'{kind}_{frame}_{channel}.{extension}'
            image.file_format='OPEN_EXR' if extension=='exr' else 'PNG';image.filepath_raw=str(path);image.save()
            pixels=np.empty(W*H*4,dtype=np.float32);image.pixels.foreach_get(pixels)
            values=pixels.reshape(H,W,4)[:,:,:3]
            records.append({'frame':frame,'channel':channel,'max':values.max(axis=(0,1)).tolist(),'mean':float(values.mean()),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
            shutil.copy2(path,game_folder/path.name);bpy.data.images.remove(image)
            print('BAKED',path.name,flush=True)
    source.image=source_images[1]
    for link in list(output.inputs['Surface'].links):material.node_tree.links.remove(link)
    material.node_tree.links.new(surface.outputs[0],output.inputs['Surface'])
    material.node_tree.nodes.remove(target)
    render_stage(kind,material)
    notes=bpy.data.texts.new('README');notes.write('Original authored electric filaments. Edit PHASE_SOURCE to inspect four packed input images; edit HDR nodes for radiance. build_electric_slashes.py regenerates path shapes and performs actual Cycles EMIT baking. This is an editable Blender art source; Godot uses separate baked outputs. No combat values are defined here.')
    bpy.ops.wm.save_as_mainfile(filepath=str(BASE/'blender'/f'{kind}_slash.blend'))
    scene.render.filepath=str(BASE/'renders'/f'{kind}_hero.png');bpy.ops.render.render(write_still=True)
    (BASE/'reports'/f'{kind}_paths.json').write_text(json.dumps({'settings':SETTINGS[kind],'frames':all_paths},indent=2),encoding='utf-8')
    godot_resources(kind)
    manifest['effects'][kind]={'settings':SETTINGS[kind],'bakes':records,'blend':str(BASE/'blender'/f'{kind}_slash.blend'),'hero':scene.render.filepath}
    (BASE/'reports'/'bake_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('BUILD_COMPLETE',kind,flush=True)
