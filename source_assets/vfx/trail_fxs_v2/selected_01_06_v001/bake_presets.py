import bpy,json
from pathlib import Path
base=Path(__file__).resolve().parent
source=next((base.parent/'original').rglob('TrailFXs_Blades.blend'))
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False,use_scripts=False)
for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
bpy.ops.mesh.primitive_plane_add(size=2)
plane=bpy.context.object
scene=bpy.context.scene
scene.render.engine='CYCLES'; scene.cycles.device='CPU'; scene.cycles.samples=1
scene.render.bake.margin=0; scene.render.bake.use_clear=True
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
report=[]
for number in ['01','06']:
    mat=bpy.data.materials['Trail_Blade_'+number].copy()
    plane.data.materials.clear();plane.data.materials.append(mat)
    nodes=mat.node_tree.nodes;links=mat.node_tree.links
    uv=nodes.new('ShaderNodeTexCoord')
    phase=nodes.new('ShaderNodeValue')
    for node in list(nodes):
        if node.type!='ATTRIBUTE':continue
        for output in node.outputs:
            for link in list(output.links):
                target=link.to_socket; name=node.attribute_name
                links.remove(link)
                if name=='BladeUVs':links.new(uv.outputs['UV'],target)
                elif name=='Speed':links.new(phase.outputs[0],target)
                elif name=='Hue':target.default_value=.5
                elif name=='UseGlowColors':target.default_value=0.0 if number=='01' else 1.0
                elif name in ['Glow','Glow2']:
                    if output.name=='Alpha':target.default_value=20.0
                    elif hasattr(target.default_value,'__len__'):
                        target.default_value=(.025,.001,.16,1) if name=='Glow' else (.34,.065,1,1)
    output=nodes.get('Material Output'); emission=nodes.get('Emission')
    alpha_socket=nodes.get('Mix Shader').inputs[0].links[0].from_socket
    gray=nodes.new('ShaderNodeEmission');links.new(alpha_socket,gray.inputs['Color']);gray.inputs['Strength'].default_value=1.0
    target=nodes.new('ShaderNodeTexImage');nodes.active=target
    for frame in range(1 if number=='01' else 4):
        phase.outputs[0].default_value=frame*.15
        for kind,socket in [('emission',emission.outputs[0]),('mask',gray.outputs[0])]:
            for link in list(output.inputs['Surface'].links):links.remove(link)
            links.new(socket,output.inputs['Surface'])
            image=bpy.data.images.new(f'{number}_{frame}_{kind}',width=1024,height=512,alpha=False,float_buffer=True)
            image.colorspace_settings.name='Non-Color'
            target.image=image;nodes.active=target
            bpy.ops.object.bake(type='EMIT')
            ext='exr' if kind=='emission' else 'png'
            image.file_format='OPEN_EXR' if kind=='emission' else 'PNG'
            image.filepath_raw=str(base/'textures'/f'blade_{number}_{frame}_{kind}.{ext}')
            image.save()
            report.append({'preset':number,'phase':frame*.15,'kind':kind,'path':image.filepath_raw})
            bpy.data.images.remove(image)
(base/'bake_manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('BAKE_COMPLETE',len(report))
