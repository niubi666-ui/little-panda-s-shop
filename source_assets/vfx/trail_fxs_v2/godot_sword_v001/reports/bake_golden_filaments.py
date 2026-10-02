"""Bake the approved Blender material, preserving HDR radiance and opacity separately."""
import bpy,json,shutil,hashlib
import numpy as np
from pathlib import Path

BASE=Path(__file__).resolve().parents[1]
SOURCE=BASE.parent/'blender/sword_trail_study.blend'
ROOT=BASE.parents[3]
TEXTURES=BASE/'textures'
GAME=ROOT/'game/assets/vfx/golden_trail_v001'
for path in [TEXTURES,GAME]:path.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE),load_ui=False,use_scripts=False)
scene=bpy.context.scene
scene.frame_set(99)
source_trail=bpy.data.objects['FX_01_Flowing_Blade']
evaluated=source_trail.evaluated_get(bpy.context.evaluated_depsgraph_get())
source_attributes={}
for name in ['Speed','Hue','UseGlowColors','Glow','Glow2']:
    attribute=evaluated.data.attributes[name]
    datum=attribute.data[0]
    source_attributes[name]=list(datum.color) if name in ['Glow','Glow2'] else datum.value
material=bpy.data.materials['01_Golden_Filaments'].copy()
material.name='BAKE_Golden_Filaments'
for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.mesh.primitive_plane_add(size=2)
plane=bpy.context.object
plane.name='UV_Bake_Surface'
plane.data.materials.append(material)
scene.render.engine='CYCLES'
scene.cycles.device='CPU'
scene.cycles.samples=4
scene.render.bake.margin=0
scene.render.bake.use_clear=True
scene.view_settings.view_transform='Standard'
scene.view_settings.look='None'
nodes=material.node_tree.nodes
links=material.node_tree.links
uv=nodes.new('ShaderNodeTexCoord')
phase=nodes.new('ShaderNodeValue')
for node in list(nodes):
    if node.type!='ATTRIBUTE':continue
    name=node.attribute_name
    for output in node.outputs:
        for link in list(output.links):
            target=link.to_socket
            links.remove(link)
            if name=='BladeUVs':links.new(uv.outputs['UV'],target)
            elif name=='Speed':links.new(phase.outputs[0],target)
            elif name in ['Hue','UseGlowColors']:target.default_value=float(source_attributes[name])
            elif name in ['Glow','Glow2']:
                value=source_attributes[name]
                if output.name=='Alpha':target.default_value=value[3]
                else:target.default_value=tuple(value[:3])+ (1.0,)
            else:raise RuntimeError('Unexpected attribute: '+name)
output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
emission=next(n for n in nodes if n.type=='EMISSION')
mix=next(n for n in nodes if n.type=='MIX_SHADER')
alpha_socket=mix.inputs[0].links[0].from_socket
gray=nodes.new('ShaderNodeEmission')
links.new(alpha_socket,gray.inputs['Color'])
gray.inputs['Strength'].default_value=1.0
target=nodes.new('ShaderNodeTexImage')
nodes.active=target
report={'source':str(SOURCE.relative_to(ROOT)),'material':'01_Golden_Filaments','blender':bpy.app.version_string,
        'resolution':[1024,256],'source_attributes_at_frame_99':source_attributes,
        'uv':{'u':'chronological trail coordinate: oldest=0, current sword=1',
              'v':'0=sword tip / outer edge, 1=sword base / inner edge'},
        'baked_taper':True,'color_encoding':'emission EXR is scene-linear HDR; mask PNG is linear data',
        'files':[]}
preview_pixels=[]
for frame in range(4):
    phase_value=source_attributes['Speed']+frame*.15
    phase.outputs[0].default_value=phase_value
    frame_pixels={}
    for kind,socket in [('emission',emission.outputs[0]),('mask',gray.outputs[0])]:
        for link in list(output.inputs['Surface'].links):links.remove(link)
        links.new(socket,output.inputs['Surface'])
        image=bpy.data.images.new(f'golden_{frame}_{kind}',width=1024,height=256,alpha=False,float_buffer=True)
        image.colorspace_settings.name='Non-Color'
        target.image=image
        nodes.active=target
        bpy.ops.object.bake(type='EMIT')
        ext='exr' if kind=='emission' else 'png'
        path=TEXTURES/f'golden_filaments_{frame}_{kind}.{ext}'
        image.file_format='OPEN_EXR' if kind=='emission' else 'PNG'
        image.filepath_raw=str(path)
        image.save()
        pixels=np.empty(1024*256*4,dtype=np.float32)
        image.pixels.foreach_get(pixels)
        pixels=pixels.reshape((256,1024,4))
        frame_pixels[kind]=pixels
        rgb=pixels[:,:,:3]
        report['files'].append({'frame':frame,'phase':phase_value,'kind':kind,'path':str(path.relative_to(ROOT)),
                                'game_path':str((GAME/path.name).relative_to(ROOT)),
                                'channel_min':rgb.min(axis=(0,1)).tolist(),'channel_max':rgb.max(axis=(0,1)).tolist(),
                                'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
        shutil.copy2(path,GAME/path.name)
        bpy.data.images.remove(image)
    # Small preview generated from radiance and mask; game controls final exposure.
    color=frame_pixels['emission'][:,:,:3]*frame_pixels['mask'][:,:,:1]
    color=color/(1+color)
    color=np.where(color<=.0031308,color*12.92,1.055*np.power(color,1/2.4)-.055)
    preview_pixels.append(np.concatenate([color,np.ones((256,1024,1),dtype=np.float32)],axis=2))
preview=bpy.data.images.new('Baked_Frame_Contact',width=1024,height=1024,alpha=True,float_buffer=False)
preview.colorspace_settings.name='Non-Color'
preview.pixels.foreach_set(np.concatenate(preview_pixels[::-1],axis=0).astype(np.float32).ravel())
preview.file_format='PNG'
preview.filepath_raw=str(BASE/'reports/baked_frames_contact.png')
preview.save()
(BASE/'reports/bake_manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('GOLDEN_BAKE_COMPLETE',str(GAME),flush=True)
