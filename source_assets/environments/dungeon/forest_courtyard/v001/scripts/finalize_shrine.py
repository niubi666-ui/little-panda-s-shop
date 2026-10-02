import bpy, json
from mathutils import Vector
from pathlib import Path
s=bpy.context.scene
assert 'Shrine_solid_recess_backing' not in bpy.data.objects, 'Shrine already finalized; rebuild the base scene before applying this pass again.'
shrine=bpy.data.objects['Hero_Guardian_Shrine']
inverse=shrine.matrix_world.inverted()
for ob in list(s.objects):
    if not ob.name.startswith('Shrine_Offering_Candle') or ob.type!='MESH':continue
    x,y,z=ob.location
    for delta in [0,.08,.16,.24,.32]:
        origin=inverse@Vector((x,y+delta,12))
        direction=(inverse.to_3x3()@Vector((0,0,-1))).normalized()
        hit,pos,normal,face=shrine.ray_cast(origin,direction)
        if hit:
            world=shrine.matrix_world@pos
            old=ob.location.copy();ob.location=(x,y+delta,world.z+.006)
            candidates=[o for o in s.objects if o.type=='LIGHT' and o.name.startswith('Shrine_Offering_Candle')]
            light=min(candidates,key=lambda o:(o.location-old).length) if candidates else None
            if light:light.location+=ob.location-old
            print('Grounded',ob.name,list(ob.location));break
    else:raise RuntimeError('No support for '+ob.name)
mat=bpy.data.materials.new('Shrine_recess_backing_stone');mat.use_nodes=True
p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
p.inputs['Base Color'].default_value=(.22,.205,.165,1);p.inputs['Roughness'].default_value=.85
bpy.ops.mesh.primitive_cube_add(size=1,location=(-3.55,8.25,2.0))
ob=bpy.context.object;ob.name='Shrine_solid_recess_backing';ob.dimensions=(2.0,.12,2.8)
for c in list(ob.users_collection):c.objects.unlink(ob)
bpy.data.collections['Architecture'].objects.link(ob);ob.data.materials.append(mat)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bevel=ob.modifiers.new('Soft_stone_edges','BEVEL');bevel.width=.025;bevel.segments=2
s.camera=bpy.data.objects['Camera_Hero_Daylight']
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
report_path=Path(bpy.data.filepath).parent.parent/'reports/build_report.json'
report=json.loads(report_path.read_text(encoding='utf-8'));report['objects']=len(s.objects)
report['shrine_finalized']=True
report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('SHRINE_FINALIZED')
