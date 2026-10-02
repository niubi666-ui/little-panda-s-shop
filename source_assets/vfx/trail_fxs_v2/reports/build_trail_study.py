"""Author a Blender-only motion study using the supplied Trail FXs v2 assets."""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector, Matrix

BASE = Path(__file__).resolve().parents[1]
ROOT = BASE.parents[2]
OUT = BASE / 'blender'
PREVIEW = BASE / 'previews' / 'study_v001'
OUT.mkdir(parents=True, exist_ok=True)
PREVIEW.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = 'Trail_Study_Amber_v001'
scene.frame_start, scene.frame_end = 1, 150
scene.render.fps = 30
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
scene.render.resolution_percentage = 100
try:
    scene.render.engine = 'BLENDER_EEVEE'
except TypeError as exc:
    raise RuntimeError(f'Current Blender EEVEE engine unavailable: {exc}')
scene.eevee.taa_render_samples = 32
scene.eevee.use_raytracing = True
scene.render.image_settings.file_format = 'PNG'

def enum_set(obj, field, value):
    valid = [e.identifier for e in obj.bl_rna.properties[field].enum_items]
    if value not in valid:
        raise RuntimeError(f'{field}: {value} not in {valid}')
    setattr(obj, field, value)

def append_objects(path, names):
    with bpy.data.libraries.load(str(path), link=False) as (available, target):
        target.objects = names
    for obj in target.objects:
        if obj is None: raise RuntimeError(f'Asset missing in {path}')
        scene.collection.objects.link(obj)
        obj.animation_data_clear()
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.hide_render = False
    return target.objects

blade_file = next((BASE / 'original').rglob('TrailFXs_Blades.blend'))
particle_file = next((BASE / 'original').rglob('TrailFXs_Blades_Particles.blend'))
trail, reference = append_objects(blade_file, ['Trail_Blade', 'Blade_Reference'])
particles = append_objects(particle_file, ['Trail_Blade_Particles'])[0]
with bpy.data.libraries.load(str(blade_file), link=False) as (available, target):
    target.materials = ['Trail_Blade_14']
main_material = target.materials[0]
main_material.name = 'Study_Amber_Flow__Trail_Blade_14'
with bpy.data.libraries.load(str(particle_file), link=False) as (available, target):
    target.materials = ['Trail Blade particles']
particle_material = target.materials[0]
particle_material.name = 'Study_Amber_Sparks__Trail_Blade_particles'

trail.name = 'FX_01_Flowing_Blade'
particles.name = 'FX_02_Scattered_Sparks'
reference.name = 'REFERENCE_Sword_Edge'
reference.location = (0, 0, 0)
reference.rotation_euler = (0, 0, 0)
reference.scale = (1, 1, 1)
reference.data = reference.data.copy()
for v in reference.data.vertices: v.co *= 1.75
reference.hide_render = True
enum_set(reference, 'display_type', 'WIRE')
for effect in [trail, particles]:
    effect.location = (0, 0, 0)
    effect.rotation_euler = (0, 0, 0)
    effect.scale = (1, 1, 1)
    effect.modifiers[0].show_viewport = True
    effect.modifiers[0].show_render = True

def socket(modifier, name):
    item = next(i for i in modifier.node_group.interface.items_tree
                if i.item_type == 'SOCKET' and i.in_out == 'INPUT' and i.name == name)
    return getattr(modifier.properties.inputs, item.identifier)

def settings(obj, values):
    mod = obj.modifiers[0]
    for name, value in values.items(): socket(mod, name).value = value
    obj.update_tag()
    return mod

main_settings = {
    'Run Simulation': True, 'Trail Reference': reference, 'Max Age': 15,
    'Subdivisions': 2, 'Flip Faces': False, 'Flip UVs (Y)': False,
    'Speed': 1.25, 'Displacement': True, 'Scale': 2.6, 'Strength': .085,
    'Roughness': .48, 'Distortion': .24, 'Material': main_material,
    'Hue': .5, 'Use Glow Colors': True, 'Glow Color 1': (1.0,.66,.18,1),
    'Glow Color 2': (1.0,.13,.018,1), 'Glow Strength': 5.5,
}
tm = settings(trail, main_settings)
pm = settings(particles, {
    'Run Simulation': True, 'Trail Reference': reference, 'Particles per Frame': 0,
    'Max Age': 21, 'Age Randomness': .55, 'Trail Substeps': .65,
    'Gravity': .003, 'Noise Strength': .025, 'Scale': 5.2, 'Distortion': .2,
    'Noise Speed': 1.25, 'Particle Radius': .013, 'Radius Randomness': .78,
    'Rotate Particles': True, 'Rotation Speed': .7,
    'Use Custom Particle Material': False, 'Material': particle_material,
    'Hue': .5, 'Use Glow Colors': True, 'Glow 1': (1.0,.75,.25,1),
    'Glow 2': (1.0,.14,.015,1), 'Glow Strength': 7.0,
})

controller = bpy.data.objects.new('SWING_Control', None)
scene.collection.objects.link(controller)
controller.location = (0, 0, .95)
reference.parent = controller
sword_file = ROOT / 'source_assets/weapons/longsword/v001/longsword_v001.blend'
with bpy.data.libraries.load(str(sword_file), link=False) as (available, target):
    target.objects = available.objects
for obj in target.objects:
    if obj.type != 'MESH': continue
    scene.collection.objects.link(obj)
    # Existing sword uses -Z tip. Convert each mesh to a +Z sword at the hand pivot.
    transform = Matrix.Translation((0, 0, 1.125)) @ Matrix.Diagonal((1.75,1.75,-1.75,1)) @ obj.matrix_world
    obj.data = obj.data.copy()
    obj.data.transform(transform)
    obj.matrix_world = Matrix.Identity(4)
    obj.parent = controller
    obj.name = 'Weapon_' + obj.name

def smooth(t):
    t = max(0.0, min(1.0, t))
    return t*t*(3.0-2.0*t)

for f in range(1, 151):
    if f < 10:
        yaw=-2.1; tilt=.65+.53*smooth((f-1)/9)
    elif f <= 21:
        t=(f-10)/11; yaw=-2.1+3.75*smooth(t); tilt=1.18+.16*math.sin(t*math.pi)
    elif f < 48:
        yaw=1.65; tilt=1.18
    elif f < 66:
        t=smooth((f-48)/18); yaw=1.65-3.75*t; tilt=1.18-.53*math.sin(t*math.pi)
    elif f < 78:
        yaw=-2.1; tilt=1.18
    elif f <= 108:
        t=(f-78)/30; yaw=-2.1+3.75*smooth(t); tilt=1.18+.16*math.sin(t*math.pi)
    else:
        yaw=1.65; tilt=1.18
    controller.rotation_euler = (tilt, .10*math.sin(yaw), yaw)
    controller.keyframe_insert(data_path='rotation_euler', frame=f)
    count = 25 if 11 <= f <= 21 else 13 if 79 <= f <= 108 else 0
    socket(pm,'Particles per Frame').value = count
    socket(pm,'Particles per Frame').keyframe_insert(data_path='value', frame=f)
    age = 15 if f < 60 else 30
    socket(tm,'Max Age').value = age
    socket(tm,'Max Age').keyframe_insert(data_path='value', frame=f)
    # Hide return swing while its simulation continues to age out.
    trail.hide_render = 45 <= f < 76
    trail.keyframe_insert(data_path='hide_render', frame=f)
    trail.hide_viewport = 45 <= f < 76
    trail.keyframe_insert(data_path='hide_viewport', frame=f)

def mat(name, color, metal=0.0, rough=.5):
    material=bpy.data.materials.new(name)
    material.use_nodes=True
    bsdf=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value=(*color,1)
    bsdf.inputs['Metallic'].default_value=metal
    bsdf.inputs['Roughness'].default_value=rough
    return material

floor=mat('Stage_Charcoal_Slate',(.025,.034,.048),.18,.36)
n=floor.node_tree.nodes; links=floor.node_tree.links
bsdf=next(x for x in n if x.type=='BSDF_PRINCIPLED')
coords=n.new('ShaderNodeTexCoord')
brick=n.new('ShaderNodeTexBrick'); brick.offset=0
brick.inputs['Color1'].default_value=(.021,.029,.042,1)
brick.inputs['Color2'].default_value=(.026,.034,.046,1)
brick.inputs['Mortar'].default_value=(.04,.054,.068,1)
brick.inputs['Scale'].default_value=1
brick.inputs['Brick Width'].default_value=1
brick.inputs['Row Height'].default_value=1
brick.inputs['Mortar Size'].default_value=.006
brick.inputs['Mortar Smooth'].default_value=.005
links.new(coords.outputs['Object'],brick.inputs['Vector'])
links.new(brick.outputs['Color'],bsdf.inputs['Base Color'])
bpy.ops.mesh.primitive_plane_add(size=200)
ground=bpy.context.object;ground.name='Stage_Floor';ground.data.materials.append(floor)

def point_at(obj, target): obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
def area(name, loc, power, color, size):
    light=bpy.data.lights.new(name,'AREA');light.energy=power;light.color=color;light.shape='DISK';light.size=size
    obj=bpy.data.objects.new(name,light);scene.collection.objects.link(obj);obj.location=loc;point_at(obj,(0,0,1));return obj
area('Key_Softbox',(1,-3,6),700,(.78,.87,1),5)
area('Rim_Cool',(-4,1,4),1000,(.24,.51,1),3)
area('Fill_Warm',(3,4,3),480,(1,.58,.26),3)
world=bpy.data.worlds.new('Studio_Dark');world.use_nodes=True
background=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
background.inputs['Color'].default_value=(.018,.025,.05,1)
background.inputs['Strength'].default_value=.3
scene.world=world
bpy.ops.object.camera_add(location=(5,-8,6.5))
camera=bpy.context.object;camera.name='Camera_Hero';enum_set(camera.data,'type','ORTHO');camera.data.ortho_scale=7.0
point_at(camera,(0,0,1.15));scene.camera=camera

# Modern Blender compositor group: retain the original colors and add restrained bloom.
compositor=bpy.data.node_groups.new('Study_Compositor','CompositorNodeTree')
compositor.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
scene.compositing_node_group=compositor
rl=compositor.nodes.new('CompositorNodeRLayers')
glare=compositor.nodes.new('CompositorNodeGlare')
glare.inputs['Type'].default_value='Fog Glow'
glare.inputs['Threshold'].default_value=1.5
glare.inputs['Strength'].default_value=.24
glare.inputs['Size'].default_value=.30
output=compositor.nodes.new('NodeGroupOutput')
compositor.links.new(rl.outputs['Image'],glare.inputs['Image'])
compositor.links.new(glare.outputs['Image'],output.inputs['Image'])

scene.timeline_markers.new('01  NORMAL SWEEP',frame=10)
scene.timeline_markers.new('02  DETAIL SWEEP',frame=78)
scene['description']='Blender motion study using supplied Trail FXs v2 material 14 + blade particles. Not a Godot runtime export.'
scene['source_library']=str(blade_file.relative_to(ROOT))
scene['study_version']='v001'
text=bpy.data.texts.new('READ_ME')
text.write('金色流光刀光与散射火星。使用用户提供的Trail FXs v2预设。\n播放1–150帧；10–21快速挥砍，78–108细节挥砍。\n选中FX_01/FX_02，在修改器面板调整材质、寿命、发光和粒子。\n本文件为Blender效果样片，尚未转入Godot。\n')
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':
            a.spaces.active.region_3d.view_perspective='CAMERA'

# Bake actual library simulations into the .blend for repeatable playback and rendering.
bpy.ops.object.select_all(action='DESELECT')
for obj in [trail,particles]:
    obj.hide_viewport=False
    obj.select_set(True)
    modifier=obj.modifiers[0]
    enum_set(modifier,'bake_target','PACKED')
    for bake in modifier.bakes:
        bake.use_custom_simulation_frame_range=True
        bake.frame_start=1;bake.frame_end=150
        enum_set(bake,'bake_mode','ANIMATION')
bpy.context.view_layer.objects.active=trail
scene.frame_set(1)
path=OUT/'trail_study_amber_v001.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(path))
result=bpy.ops.object.simulation_nodes_cache_bake(selected=True)
print('BAKE_RESULT',result,flush=True)
scene.frame_set(100)
report={'blend':str(path),'blender':bpy.app.version_string,'frames':150,'fps':30,
        'asset_material':main_material.name,'objects':len(scene.objects),'bake_result':list(result),'evaluated':{}}
for obj in [trail,particles]:
    evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    report['evaluated'][obj.name]={'vertices':len(evaluated.data.vertices),'bounds':list(evaluated.dimensions)}
bpy.ops.wm.save_as_mainfile(filepath=str(path))
(BASE/'reports/study_v001_build.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
scene.render.filepath=str(PREVIEW/'hero_100.png')
bpy.ops.render.render(write_still=True)
print('STUDY_READY',json.dumps(report),flush=True)
