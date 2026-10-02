import bpy,math,json,random
from pathlib import Path
from mathutils import Vector,Euler
R=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(R.parent/'tree_foliage_v003/blender/sacred_oak_foliage_v003.blend'))
s=bpy.context.scene;canopy=bpy.data.collections['CROWN_compact_oak_clusters']
prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
for d in prefs.devices:d.use=d.type=='OPTIX'
s.cycles.device='GPU'
views=json.loads((R/'reports/bake_views.json').read_text())
source_tri=0
for o in canopy.objects:o.data.calc_loop_triangles();source_tri+=len(o.data.loop_triangles)
# Reuse the original material for the sparse outer leaf cards.
single=bpy.data.materials['Oak_IndividualCurvedLeaves']
mat=bpy.data.materials.new('BakedLeafCluster_Albedo_Normal_Alpha');mat.use_nodes=True
n=mat.node_tree.nodes;n.clear();l=mat.node_tree.links
out=n.new('ShaderNodeOutputMaterial');bs=n.new('ShaderNodeBsdfPrincipled');mix=n.new('ShaderNodeMixShader');tr=n.new('ShaderNodeBsdfTransparent')
color=n.new('ShaderNodeTexImage');color.image=bpy.data.images.load(str(R/'textures/cluster_albedo.png'));color.image.pack()
normal=n.new('ShaderNodeTexImage');normal.image=bpy.data.images.load(str(R/'textures/cluster_normal.png'));normal.image.colorspace_settings.name='Non-Color';normal.image.pack()
nm=n.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.72
bs.inputs['Roughness'].default_value=.86;bs.inputs['Specular IOR Level'].default_value=.14
cut=n.new('ShaderNodeMath');cut.operation='GREATER_THAN';cut.inputs[1].default_value=.42
thin=n.new('ShaderNodeBsdfTranslucent');lm=n.new('ShaderNodeMixShader');lm.inputs[0].default_value=.25
l.new(color.outputs['Color'],bs.inputs['Base Color']);l.new(color.outputs['Color'],thin.inputs['Color'])
l.new(normal.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs['Normal'],bs.inputs['Normal']);l.new(nm.outputs['Normal'],thin.inputs['Normal'])
l.new(color.outputs['Alpha'],cut.inputs[0]);l.new(cut.outputs[0],mix.inputs[0]);l.new(tr.outputs[0],mix.inputs[1]);l.new(bs.outputs[0],lm.inputs[1]);l.new(thin.outputs[0],lm.inputs[2]);l.new(lm.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs['Surface'])
# Brighten leaf surfaces only; retain original lighting, bark and alpha.
def brighten_leaf_material(material):
    nodes=material.node_tree.nodes;links=material.node_tree.links
    texture=next(n for n in nodes if n.type=='TEX_IMAGE' and n.image.colorspace_settings.name!='Non-Color')
    destinations=[link.to_socket for link in list(texture.outputs['Color'].links)]
    for link in list(texture.outputs['Color'].links):links.remove(link)
    gamma=nodes.new('ShaderNodeGamma');gamma.name='Leaf_Midtone_Lift';gamma.inputs['Gamma'].default_value=.90
    hue=nodes.new('ShaderNodeHueSaturation');hue.inputs['Saturation'].default_value=1.08;hue.inputs['Value'].default_value=1.16
    balance=nodes.new('ShaderNodeVectorMath');balance.operation='MULTIPLY';balance.inputs[1].default_value=(.98,1.13,1.05)
    links.new(texture.outputs['Color'],gamma.inputs['Color']);links.new(gamma.outputs['Color'],hue.inputs['Color']);links.new(hue.outputs['Color'],balance.inputs[0])
    for socket in destinations:links.new(balance.outputs[0],socket)
brighten_leaf_material(mat)
brighten_leaf_material(single)
random.seed(491)
def module(k):
    vs=[];fs=[];uv=[];mi=[]
    for v in range(4):
        rec=next(r for r in views if r['module']==k and r['view']==v)
        rot=Euler(rec['rotation']).to_matrix();base=len(vs);size=rec['size']
        rows=4;cols=3
        for j in range(rows+1):
            for i in range(cols+1):
                x=(i/cols-.5)*size;y=(j/rows-.5)*size
                z=.24*(1-(x/1.2)**2)*(1-(y/1.2)**2)+.08*math.sin(y*2.2+v)*x
                vs.append(rot@Vector((x,y,z)))
                uv.append(((k+i/cols)/6,(v+j/rows)/4))
        for j in range(rows):
            for i in range(cols):
                a=base+j*(cols+1)+i;fs.append((a,a+1,a+cols+2,a+cols+1));mi.append(0)
    # Twenty individually folded edge leaves, four triangles each.
    for j in range(20):
        a=j*2.399963;center=Vector((math.cos(a)*random.uniform(.58,.94),math.sin(a)*random.uniform(.58,.94),random.uniform(-.35,.58)))
        rot=Euler((random.uniform(-1.1,1.1),random.uniform(-.7,.7),a)).to_matrix();length=random.uniform(.16,.24);base=len(vs)
        for row in range(3):
            t=row/2
            for i in range(2):
                x=i-.5
                vs.append(center+rot@Vector((x*length*.85,t*length,.045*math.sin(t*math.pi))))
                uv.append((((k+j)%2+i)/2,(1-((k+j)%4)//2+t)/2))
        fs.extend([(base,base+1,base+3,base+2),(base+2,base+3,base+5,base+4)]);mi.extend([1,1])
    me=bpy.data.meshes.new('BalancedModule_%02d'%k);me.from_pydata(vs,[],fs);me.materials.append(mat);me.materials.append(single)
    layer=me.uv_layers.new(name='UVMap')
    for p in me.polygons:
        p.material_index=mi[p.index];p.use_smooth=True
        for idx in p.loop_indices:layer.data[idx].uv=uv[me.loops[idx].vertex_index]
    wind=me.color_attributes.new(name='wind_rgba',type='FLOAT_COLOR',domain='POINT')
    for i,p in enumerate(vs):wind.data[i].color=(min(1,Vector(p).length/1.35),k/6,(math.sin(i*12.9898)*43758.5453)%1,1)
    me.calc_loop_triangles();assert len(me.loop_triangles)==176
    return me
meshes=[module(k) for k in range(6)]
for o in canopy.objects:
    k=int(o.data.name.rsplit('_',1)[-1]);o.data=meshes[k];o.name=o.name.replace('CrownCluster','BakedCrownCluster')
for c in list(s.collection.children):
    if c.name.startswith('LIBRARY'):
        for o in list(c.objects):bpy.data.objects.remove(o,do_unlink=True)
        bpy.data.collections.remove(c)
for m in list(bpy.data.meshes):
    if m.users==0:bpy.data.meshes.remove(m)
lowtri=sum(len(o.data.loop_triangles) for o in canopy.objects)
assert lowtri+19032<=30000
trunk=next(o for o in s.objects if o.name.startswith('SacredOak_Trunk'))
report={'crown_source_triangles':source_tri,'crown_low_triangles':lowtri,'reduction_percent':100*(1-lowtri/source_tri),'trunk_triangles':sum(len(p.vertices)-2 for p in trunk.data.polygons),'clusters':len(canopy.objects),'unique_modules':6,'triangles_per_module':176,'whole_tree_triangles':lowtri+19032,'budget_scope':'whole tree <= 30000 triangles','leaf_color_adjustment':{'gamma':.90,'value':1.16,'saturation':1.08,'rgb_multiplier':[.98,1.13,1.05]},'views_per_module':4,'atlas_resolution':[3072,2048],'wind_attribute':'wind_rgba: R=local bend weight,G=variant phase,B=leaf variation,A=1','note':'Blender candidate only. No wind shader, LOD switching or Godot performance test.'}
(R/'reports/optimization.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(R/'blender/sacred_oak_balanced_v005.blend'))
s.cycles.samples=64;s.render.filepath=str(R/'previews/tree_hero.png');bpy.ops.render.render(write_still=True)
cam=s.camera;cam.location=(20,-14,20);cam.rotation_euler=(Vector((0,0,5))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=15
s.render.filepath=str(R/'previews/tree_gameplay_angle.png');bpy.ops.render.render(write_still=True)
print('LOW_DONE',report)
