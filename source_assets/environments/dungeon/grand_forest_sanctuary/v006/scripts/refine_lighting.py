"""v006 golden canopy lighting. Standalone background process, art assets only.
Keep v005 layout and wind prototypes; replace expensive lighting-only gobo.
"""
import bpy,math,random,json,hashlib,sys,time
from pathlib import Path
from mathutils import Vector
assert bpy.app.background
R=Path(__file__).resolve().parents[1]
C=json.loads((R/'scripts/lighting_profile.json').read_text(encoding='utf-8'))
assert Path(bpy.data.filepath).resolve()==Path(C['source']).resolve()
s=bpy.context.scene;rng=random.Random(C['seed'])
source_hash=hashlib.sha256(Path(C['source']).read_bytes()).hexdigest()
before_transform={o.name:tuple(v for row in o.matrix_world for v in row) for o in s.objects}
def look(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
sun=s.objects['Warm_golden_sun'];sun.location=C['sun_location'];look(sun,C['sun_target']);sun.data.energy=C['sun_energy'];sun.data.color=C['sun_color'];sun.data.angle=C['sun_angle']
bg=next(n for n in s.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs['Color'].default_value=(*C['world_color'],1);bg.inputs['Strength'].default_value=C['world_strength']
s.objects['Broad_cool_skylight'].data.energy=C['cool_fill_energy']
s.objects['Broad_cool_skylight'].data.color=(.65,.76,1)
front=s.objects['Warm_tree_bounce'];front.location=(-13,-5,14);look(front,(-12,9,5));front.data.energy=C['warm_front_fill_energy'];front.data.color=(.88,.94,.82);front.data.size=7
rim=s.objects['Oak_warm_rim_bounce'];rim.location=(-17,16,20);look(rim,(-12,7,7));rim.data.energy=C['oak_rim_energy'];rim.data.color=(1,.69,.26);rim.data.size=5
for i in range(3):s.objects['Forest_canopy_sunshaft_'+str(i)].data.energy=4500
for item in C['plant_rim_lights']:
    d=bpy.data.lights.new(item['name'],'AREA');o=bpy.data.objects.new(item['name'],d);s.collection.objects.link(o)
    o.location=item['location'];look(o,item['target']);d.energy=item['energy'];d.size=item['size'];d.color=(1,.78,.35)
s.view_settings.view_transform='AgX';s.view_settings.exposure=C['exposure']
s.view_settings.look='AgX - Medium High Contrast'

# Tune response to incoming light. Emission is not added to foliage.
material_changes=[]
def tint_input(m,p,tint):
    n=m.node_tree.nodes;l=m.node_tree.links;src=p.inputs['Base Color'].links[0].from_socket if p.inputs['Base Color'].is_linked else None
    q=n.new('ShaderNodeMixRGB');q.name='V006_warm_stone_tint';q.blend_type='MULTIPLY';q.inputs[0].default_value=1;q.inputs[2].default_value=(*tint,1)
    if src:l.new(src,q.inputs[1])
    else:q.inputs[1].default_value=p.inputs['Base Color'].default_value
    l.new(q.outputs[0],p.inputs['Base Color'])
for m in bpy.data.materials:
    if not m.use_nodes:continue
    ps=[n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED']
    leaf=m.name.startswith(('Living leaf variation','BakedLeafCluster_','BalancedLeaf')) and '_ground_leaf_' not in m.name
    floral=m.name.startswith(('Sanctuary_white_flower','Sanctuary_purple_flower'))
    if leaf or floral:
        for p in ps:
            p.inputs['Roughness'].default_value=C['leaf_roughness'];p.inputs['Specular IOR Level'].default_value=C['leaf_specular'];p.inputs['IOR'].default_value=1.45
            p.inputs['Coat Weight'].default_value=.08;p.inputs['Coat Roughness'].default_value=.28
        # Existing leaf shader already separates translucent leaf shading and
        # transparent cutout. Change the former without disturbing the latter.
        for node in m.node_tree.nodes:
            if node.type=='MIX_SHADER' and any(link.from_node.type=='BSDF_TRANSLUCENT' for inp in list(node.inputs)[1:] for link in inp.links):
                node.inputs[0].default_value=C['leaf_translucency']
            if node.type=='BSDF_TRANSLUCENT' and leaf:
                if not node.inputs['Color'].is_linked and ps and ps[0].inputs['Base Color'].is_linked:
                    m.node_tree.links.new(ps[0].inputs['Base Color'].links[0].from_socket,node.inputs['Color'])
        material_changes.append(m.name)
    if m.name=='Ivory meadow petals':
        for p in ps:
            p.inputs['Base Color'].default_value=(*C['petal_color'],1);p.inputs['Roughness'].default_value=.46
            p.inputs['Subsurface Weight'].default_value=.06;p.inputs['Subsurface Scale'].default_value=.002
        material_changes.append(m.name)
    if m.name.startswith(('Sanctuary_paving','Sanctuary_roundel','Sanctuary_low_wall','Sanctuary_pier','Sanctuary_steps','Sanctuary_shrine','Sanctuary_statue')):
        for p in ps:tint_input(m,p,C['stone_tint'])
        material_changes.append(m.name)
    if m.name.startswith(('Sanctuary_paving','Sanctuary_roundel')):
        for p in ps:
            noise=m.node_tree.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=4;noise.inputs['Detail'].default_value=2
            ramp=m.node_tree.nodes.new('ShaderNodeMapRange');ramp.inputs['From Min'].default_value=0;ramp.inputs['From Max'].default_value=1
            ramp.inputs['To Min'].default_value=C['paving_roughness']-.06;ramp.inputs['To Max'].default_value=C['paving_roughness']+.13
            if m.name.startswith('Sanctuary_roundel'):
                ramp.inputs['To Min'].default_value=.61;ramp.inputs['To Max'].default_value=.78
            m.node_tree.links.new(noise.outputs['Fac'],ramp.inputs[0]);m.node_tree.links.new(ramp.outputs[0],p.inputs['Roughness'])

# Shade-only silhouette material, with a camera-transparent surface for Eevee
# as well as Cycles camera-ray exclusion. Broad overlapping forms create dense
# canopy shade; lower leaf clusters supply sharp highlights and leaf edges.
mat=bpy.data.materials.new('V006_CameraInvisible_CanopySilhouette');mat.use_nodes=True
nodes=mat.node_tree.nodes;links=mat.node_tree.links;nodes.clear()
out=nodes.new('ShaderNodeOutputMaterial');diff=nodes.new('ShaderNodeBsdfDiffuse');diff.inputs['Color'].default_value=(.025,.04,.009,1)
trans=nodes.new('ShaderNodeBsdfTransparent');lp=nodes.new('ShaderNodeLightPath');mix=nodes.new('ShaderNodeMixShader')
links.new(lp.outputs['Is Camera Ray'],mix.inputs[0]);links.new(diff.outputs[0],mix.inputs[1]);links.new(trans.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],out.inputs['Surface'])
if hasattr(mat,'surface_render_method'):mat.surface_render_method='DITHERED'
if hasattr(mat,'use_transparent_shadow'):mat.use_transparent_shadow=True
# Small openings inside larger leaf masses allow bright, irregular flecks of
# sunlight through. World-space procedural cutouts avoid extra leaf geometry.
far_mat=mat.copy();far_mat.name='V006_Perforated_Distant_LeafMass'
fn=far_mat.node_tree.nodes;fl=far_mat.node_tree.links
position=fn.new('ShaderNodeNewGeometry');noise=fn.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=3.3;noise.inputs['Detail'].default_value=1.2
holes=fn.new('ShaderNodeMath');holes.operation='GREATER_THAN';holes.inputs[1].default_value=.56
camera_or_hole=fn.new('ShaderNodeMath');camera_or_hole.operation='MAXIMUM'
fl.new(position.outputs['Position'],noise.inputs['Vector']);fl.new(noise.outputs['Fac'],holes.inputs[0])
far_lp=next(n for n in fn if n.type=='LIGHT_PATH');far_mix=next(n for n in fn if n.type=='MIX_SHADER')
fl.new(far_lp.outputs['Is Camera Ray'],camera_or_hole.inputs[0]);fl.new(holes.outputs[0],camera_or_hole.inputs[1]);fl.new(camera_or_hole.outputs[0],far_mix.inputs[0])
col=bpy.data.collections.new('V006_LIGHTING_ONLY_canopy');s.collection.children.link(col)
old=s.objects['LIGHTING_ONLY_overhead_leaf_shadows'];old.hide_render=True;old.hide_set(True);old['v006_replaced_for_lighting']=True
oldtris=sum(len(p.vertices)-2 for p in old.data.polygons)
sun_ray=(Vector(C['sun_target'])-sun.location).normalized();shift=sun_ray.xy/(-sun_ray.z)
def xyz(p,h):return Vector((p[0]-shift.x*h,p[1]-shift.y*h,h))
def canopy(name,centres,height_range,macro):
    verts=[];faces=[]
    def leaf(p,h,rx,ry,a,edges=8):
        start=len(verts);verts.append(xyz(p,h))
        for k in range(edges):
            t=math.tau*k/edges;r=rng.uniform(.86,1.15)
            u=rx*math.cos(t)*r;v=ry*math.sin(t)*r
            verts.append(xyz((p[0]+math.cos(a)*u-math.sin(a)*v,p[1]+math.sin(a)*u+math.cos(a)*v),h+rng.uniform(-.06,.06)))
        for k in range(edges):faces.append((start,start+1+k,start+1+(k+1)%edges))
    for cx,cy in centres:
        h=rng.uniform(*height_range)
        if macro:
            # Interlocking broad leaf masses, not thousands of individual leaves.
            spread=rng.uniform(1.2,2.1)
            for k in range(rng.randrange(7,12)):
                a=rng.uniform(0,math.tau);rad=rng.uniform(.05,spread)
                p=(cx+math.cos(a)*rad,cy+math.sin(a)*rad)
                if math.hypot(p[0]-1.3,p[1]+2.7)<1.35:continue
                leaf(p,h,rng.uniform(.42,1.02),rng.uniform(.28,.68),a,10)
        else:
            a=rng.uniform(0,math.tau);length=rng.uniform(1.0,2.4)
            for k in range(13):
                t=k/12-.5;px=cx+math.cos(a)*length*t;py=cy+math.sin(a)*length*t
                for sign in (-1,1):
                    side=rng.uniform(.16,.48)
                    p=(px-math.sin(a)*side*sign,py+math.cos(a)*side*sign)
                    if math.hypot(p[0]-1.3,p[1]+2.7)<1.10:continue
                    leaf(p,h,rng.uniform(.16,.30),rng.uniform(.09,.19),a+sign*.5,6)
            # Slender continuous twig with branching leaf pairs.
            a0=xyz((cx-math.cos(a)*length*.55,cy-math.sin(a)*length*.55),h)
            a1=xyz((cx+math.cos(a)*length*.55,cy+math.sin(a)*length*.55),h)
            side=Vector((-math.sin(a)*.022,math.cos(a)*.022,0));idx=len(verts);verts.extend((a0-side,a0+side,a1+side,a1-side));faces.append((idx,idx+1,idx+2,idx+3))
    me=bpy.data.meshes.new(name+'_mesh');me.from_pydata(verts,[],faces);me.materials.append(far_mat if macro else mat);me.update()
    o=bpy.data.objects.new(name,me);col.objects.link(o);o.visible_camera=False;o.visible_glossy=False;o.visible_transmission=False
    o['purpose']='Lighting silhouette only, not a runtime model or obstacle';o['camera_invisible']=True
    attr=me.attributes.new('breeze_weight','FLOAT','POINT');attr.data.foreach_set('value',[rng.uniform(.65,1) for _ in me.vertices])
    # Copy only a small settings wrapper; all movement logic stays in the v004
    # shared bend group and still responds to BREEZE_controls.strength.
    oldmod=next(m for m in old.modifiers if m.type=='NODES');ng=oldmod.node_group.copy();ng.name=name+'_breeze_settings'
    bend=ng.nodes['Breeze'];bend.inputs['Amplitude'].default_value=.085 if macro else .14;bend.inputs['Phase'].default_value=.65 if macro else 1.3
    mod=o.modifiers.new('Canopy silhouette micro wind','NODES');mod.node_group=ng
    return o
# Deliberate sparse light lanes between dense island clusters. A jittered field
# prevents the floor from looking uniformly peppered or like a regular lattice.
macro=[]
for i in range(C['macro_clusters']):
    x=rng.uniform(-23,23);y=rng.uniform(-20,23)
    # Centre and leaf-mosaic focus areas retain some warm light windows.
    if -3<x<5 and -9<y<9 and rng.random()<.35:continue
    macro.append((x,y))
details=[(rng.uniform(-20,20),rng.uniform(-18,19)) for _ in range(C['detail_clusters'])]
casters=[canopy('Canopy_far_soft_leaf_masses',macro,C['macro_height_range'],True),canopy('Canopy_near_branch_leaf_clusters',details,C['detail_height_range'],False)]
newtris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in casters)

# Mild volumetric atmosphere and low-threshold bloom: light catches leaves and
# flame edges, while shaded floor remains readable.
fog=bpy.data.materials.get('Fine_golden_forest_air')
if fog:
    for n in fog.node_tree.nodes:
        if n.type=='PRINCIPLED_VOLUME':n.inputs['Density'].default_value=.0021;n.inputs['Anisotropy'].default_value=.42
cg=bpy.data.node_groups.new('V006_Subtle_Golden_Highlight_Glow','CompositorNodeTree');s.compositing_node_group=cg
cg.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
n=cg.nodes;l=cg.links;rl=n.new('CompositorNodeRLayers');g=n.new('CompositorNodeGlare')
g.inputs['Type'].default_value='Fog Glow';g.inputs['Quality'].default_value='High';g.inputs['Threshold'].default_value=1.8
g.inputs['Strength'].default_value=.12;g.inputs['Size'].default_value=.28
co=n.new('NodeGroupOutput');l.new(rl.outputs['Image'],g.inputs['Image']);l.new(g.outputs['Image'],co.inputs['Image'])

s.name='Grand_Forest_Sanctuary_v006_Golden_Canopy'
s['lighting_stage']='v006 golden dappled canopy, contrast and leaf response; Blender art review'
s['lighting_source_sha256']=source_hash;s['lighting_only_proxy_triangles']=newtris
s.render.engine='CYCLES';s.cycles.device='GPU';s.cycles.samples=C['render_samples'];s.cycles.use_denoising=True;s.cycles.use_adaptive_sampling=True;s.cycles.adaptive_threshold=.035
s.render.resolution_x=1800;s.render.resolution_y=1238;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.use_persistent_data=True
s.cycles.transparent_max_bounces=24;s.frame_set(1)
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.refresh_devices()
for dev in prefs.devices:dev.use=dev.type=='OPTIX'
if hasattr(s,'eevee'):
    s.eevee.taa_render_samples=96;s.eevee.use_shadows=True;s.eevee.use_shadow_jitter_viewport=True;s.eevee.shadow_ray_count=3;s.eevee.shadow_step_count=12
    s.eevee.use_fast_gi=True;s.eevee.use_volumetric_shadows=True
s.camera=s.objects['Camera_Panorama']
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;space.shading.type='RENDERED';space.shading.use_scene_lights=True;space.shading.use_scene_world=True
            if hasattr(space.shading,'use_compositor'):space.shading.use_compositor='CAMERA'
            space.overlay.show_overlays=False;space.region_3d.view_perspective='CAMERA'
s.render.engine=C['preview_engine']
out=R/'blender/grand_forest_sanctuary_v006_golden_canopy.blend';bpy.ops.wm.save_as_mainfile(filepath=str(out))
layout_moved=[name for name,matrix in before_transform.items() if s.objects.get(name) and tuple(v for row in s.objects[name].matrix_world for v in row)!=matrix and s.objects[name].type not in ['LIGHT']]
assert not layout_moved,layout_moved
report={'output':str(out),'source':C['source'],'source_sha256':source_hash,'profile':C,'layout_transforms_preserved':True,'material_changes':material_changes,
        'old_lighting_proxy_triangles':oldtris,'new_lighting_proxy_triangles':newtris,'active_proxy_reduction_percent':round((1-newtris/oldtris)*100,2),
        'macro_shadow_clusters':len(macro),'detail_shadow_clusters':len(details),'original_shadow_proxy_retained_hidden':True,'godot_modified':False}
(R/'reports/lighting_build.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
assert hashlib.sha256(Path(C['source']).read_bytes()).hexdigest()==source_hash
print('LIGHTING_V006_SAVED',json.dumps(report,ensure_ascii=False),flush=True)
if '--draft' in sys.argv:
    s.render.resolution_x=1152;s.render.resolution_y=792;s.cycles.samples=32;s.cycles.adaptive_threshold=.09
    label=sys.argv[sys.argv.index('--label')+1] if '--label' in sys.argv else '01'
    if '--eevee-only' not in sys.argv:
        s.render.engine='CYCLES'
        s.render.filepath=str(R/'previews'/f'draft_cycles_{label}.png');bpy.ops.render.render(write_still=True)
    s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=32;s.render.filepath=str(R/'previews'/f'draft_eevee_{label}.png')
    if '--gameplay-only' not in sys.argv:bpy.ops.render.render(write_still=True)
    if '--gameplay' in sys.argv:
        s.render.engine='BLENDER_EEVEE' if '--eevee-only' in sys.argv else 'CYCLES';s.camera=s.objects['Camera_Gameplay'];s.render.resolution_x=1152;s.render.resolution_y=720
        s.render.filepath=str(R/'previews'/f'draft_gameplay_{label}.png');bpy.ops.render.render(write_still=True)
