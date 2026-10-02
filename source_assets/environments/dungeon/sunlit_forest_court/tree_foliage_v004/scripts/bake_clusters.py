import bpy,math,json,numpy as np
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(R.parent/'tree_foliage_v003/blender/sacred_oak_foliage_v003.blend'))
s=bpy.context.scene
meshes=sorted([m for m in bpy.data.meshes if m.name.startswith('OakVolumeModule_')],key=lambda m:m.name)
assert len(meshes)==6
for o in list(s.objects):bpy.data.objects.remove(o,do_unlink=True)
for c in list(s.collection.children):s.collection.children.unlink(c)
collection=bpy.data.collections.new('BAKE');s.collection.children.link(collection)
s.render.film_transparent=True;s.render.resolution_x=512;s.render.resolution_y=512;s.render.resolution_percentage=100
s.render.engine='CYCLES';s.cycles.samples=16;s.cycles.use_denoising=False;s.cycles.transparent_max_bounces=48
try:
    prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
    for d in prefs.devices:d.use=d.type=='OPTIX'
    s.cycles.device='GPU'
except Exception as e:print(e)
s.view_settings.view_transform='Standard';s.view_settings.exposure=0;s.view_settings.gamma=1
cam=bpy.data.objects.new('BakeCamera',bpy.data.cameras.new('BakeCamera'));collection.objects.link(cam);s.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=2.4
directions=[Vector((0,-1,.28)).normalized(),Vector((1,0,.28)).normalized(),Vector((0,1,.28)).normalized(),Vector((0,0,1))]
records=[];arrays={kind:np.zeros((2048,3072,4),dtype=np.float32) for kind in ['albedo','normal']}

def bake_material(source,kind):
    mat=bpy.data.materials.new(source.name+'_'+kind);mat.use_nodes=True;n=mat.node_tree.nodes;n.clear();l=mat.node_tree.links
    out=n.new('ShaderNodeOutputMaterial');emit=n.new('ShaderNodeEmission');tr=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader')
    source_tex=next((a for a in source.node_tree.nodes if a.type=='TEX_IMAGE'),None)
    if source_tex:
        tex=n.new('ShaderNodeTexImage');tex.image=source_tex.image
        cut=n.new('ShaderNodeMath');cut.operation='GREATER_THAN';cut.inputs[1].default_value=.45
        l.new(tex.outputs['Alpha'],cut.inputs[0]);l.new(cut.outputs[0],mix.inputs[0])
        if kind=='albedo':l.new(tex.outputs['Color'],emit.inputs['Color'])
    else:
        mix.inputs[0].default_value=1
        emit.inputs['Color'].default_value=(.13,.075,.028,1)
    if kind=='normal':
        geo=n.new('ShaderNodeNewGeometry');transform=n.new('ShaderNodeVectorTransform');transform.vector_type='NORMAL';transform.convert_from='WORLD';transform.convert_to='CAMERA'
        mul=n.new('ShaderNodeVectorMath');mul.operation='SCALE';mul.inputs['Scale'].default_value=.5
        add=n.new('ShaderNodeVectorMath');add.operation='ADD';add.inputs[1].default_value=(.5,.5,.5)
        l.new(geo.outputs['Normal'],transform.inputs[0]);l.new(transform.outputs[0],mul.inputs[0]);l.new(mul.outputs[0],add.inputs[0]);l.new(add.outputs[0],emit.inputs[0])
    l.new(tr.outputs[0],mix.inputs[1]);l.new(emit.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs['Surface']);return mat

for k,mesh in enumerate(meshes):
    ob=bpy.data.objects.new('Module',mesh.copy());collection.objects.link(ob)
    original=list(ob.data.materials)
    for kind in ['albedo','normal']:
        ob.data.materials.clear()
        for m in original:ob.data.materials.append(bake_material(m,kind))
        for j,direction in enumerate(directions):
            cam.location=direction*5;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler()
            # EXR retains linear color/data; atlases are saved below with explicit color spaces.
            s.render.image_settings.file_format='OPEN_EXR';s.render.image_settings.color_mode='RGBA'
            path=R/'bake_tiles'/('%s_%02d_%02d.exr'%(kind,k,j));s.render.filepath=str(path)
            if not path.exists():bpy.ops.render.render(write_still=True)
            im=bpy.data.images.load(str(path),check_existing=False)
            data=np.empty(512*512*4,dtype=np.float32);im.pixels.foreach_get(data);data=data.reshape(512,512,4)
            if kind=='normal':
                normals=data[:,:,:3]*2-1
                normals[normals[:,:,2]<0]*=-1
                normals/=np.maximum(np.linalg.norm(normals,axis=2,keepdims=True),1e-6)
                data[:,:,:3]=normals*.5+.5
            # EXR pixels are straight after loading with explicit channel-packed interpretation.
            arrays[kind][j*512:(j+1)*512,k*512:(k+1)*512,:]=data
            bpy.data.images.remove(im)
            if kind=='albedo':records.append({'module':k,'view':j,'direction':list(direction),'rotation':list(cam.rotation_euler),'size':2.4})
            print('BAKE_TILE',kind,k,j,flush=True)
    bpy.data.objects.remove(ob,do_unlink=True)

for kind,a in arrays.items():
    # Edge RGB dilation in each tile, preserving alpha, helps mipmapped transparent edges.
    for k in range(6):
        for j in range(4):
            tile=a[j*512:(j+1)*512,k*512:(k+1)*512,:]
            valid=tile[:,:,3]>.05
            for _ in range(8):
                sums=np.zeros_like(tile[:,:,:3]);count=np.zeros_like(valid,dtype=np.float32)
                for dy,dx in [(-1,0),(1,0),(0,-1),(0,1)]:
                    v=np.roll(valid,(dy,dx),(0,1));rgb=np.roll(tile[:,:,:3],(dy,dx),(0,1));sums+=rgb*v[:,:,None];count+=v
                fill=(~valid)&(count>0);tile[fill,:3]=sums[fill]/count[fill,None];valid|=fill
    im=bpy.data.images.new('cluster_'+kind,width=3072,height=2048,alpha=True,float_buffer=True)
    im.colorspace_settings.name='Non-Color' if kind=='normal' else 'Linear Rec.709'
    im.pixels.foreach_set(a.reshape(-1));im.file_format='PNG'
    im.filepath_raw=str(R/'textures'/('cluster_'+kind+'.png'))
    # save_render supplies linear->sRGB for albedo only; normal map stays numeric.
    if kind=='albedo':
        s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.image_settings.color_depth='8';im.save_render(im.filepath_raw,scene=s)
    else:im.save()
(R/'reports/bake_views.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print('BAKE_DONE',flush=True)
