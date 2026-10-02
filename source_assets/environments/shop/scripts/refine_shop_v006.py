import bpy,json,math
from pathlib import Path
from mathutils import Vector
B=Path('E:/ShopGame/source_assets/environments/shop');s=bpy.context.scene
# The approved scene appearance is serialized using the same helper as the build.
code=(B/'scripts/decorate_shop_v005.py').read_text(encoding='utf-8-sig')
exec(code[code.index('def appearance():'):code.index('before=appearance()')])
baseline=json.loads((B/'reports/v005_appearance_baseline.json').read_text())
assert appearance()==baseline
# Fit new island to the existing room proportions without decimating its 19,132 triangles.
table=bpy.data.objects['Central merchandise island HD'];table.scale.z*=1.60/table.dimensions.z
# Vase stands on the ground beside the entrance rather than above irregular cabinet goods.
vase=bpy.data.objects['Dried flowers on right cabinet'];vase.name='Entrance dried flower vase';vase.location=(-4.18,-1.98,.05);vase.scale*=.72/.42;vase.rotation_euler.z=0
for name,drop in [('Right herbal cabinet fern',.24),('Front cabinet hanging ivy',.15)]:bpy.data.objects[name].location.z-=drop
# Crown support blocks connect the supplemental ledge to its bookcase frame.
mat=bpy.data.materials['Aged oak beams']
for x in [3.29,4.77]:
 bpy.ops.mesh.primitive_cube_add(size=1,location=(x,3.98,2.67));o=bpy.context.object;o.name='Relics crown support';o.dimensions=(.09,.10,.23);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for c in list(o.users_collection):c.objects.unlink(o)
 bpy.data.collections['Furniture'].objects.link(o);o.data.materials.append(mat);m=o.modifiers.new('Soft edge','BEVEL');m.width=.01;m.segments=2;o['revision']='shop_v006'
bpy.context.view_layer.update();assert appearance()==baseline
p=bpy.context.preferences.addons['cycles'].preferences;p.compute_device_type='OPTIX';p.refresh_devices()
for d in p.devices:d.use=d.type=='OPTIX'
s.cycles.device='GPU';s.cycles.samples=128;s.render.resolution_percentage=100;s.render.filepath=str(B/'previews/shop_interior_v006.png');s.name='Shop_Interior_Decor_v006'
# Validate the saved geometry and image packing. No claims about Godot runtime performance.
dg=bpy.context.evaluated_depsgraph_get();triangles=0
for o in s.objects:
 if o.type in {'MESH','CURVE'}:
  ev=o.evaluated_get(dg);me=ev.to_mesh();triangles+=sum(len(p.vertices)-2 for p in me.polygons);ev.to_mesh_clear()
added=[o for o in s.objects if o.get('source_file')=='item2.blend']
report={'scene':s.name,'objects':len(s.objects),'evaluated_triangles':triangles,'item2_instances':len(added),'source_ids':sorted(set(o['source_object'] for o in added)),'lights_camera_world_exposure_volume_unchanged':appearance()==baseline,'table_source_id':table['source_object'],'table_triangles':sum(len(p.vertices)-2 for p in table.data.polygons),'table_dimensions_m':list(table.dimensions),'old_central_table_removed':bpy.data.objects.get('Central merchandise island') is None,'godot_validated':False}
bpy.ops.file.pack_all()
report['unpacked_images']=[im.name for im in bpy.data.images if im.type=='IMAGE' and im.size[0]>0 and not im.packed_file]
(B/'reports/shop_v006_validation.json').write_text(json.dumps(report,indent=2))
manifest=[{'name':o.name,'source':o['source_object'],'location':list(o.location),'rotation_radians':list(o.rotation_euler),'scale':list(o.scale)} for o in added]
(B/'reports/shop_v006_item2_placements.json').write_text(json.dumps(manifest,indent=2))
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(B/'blender/shop_interior_v006.blend'))
print('FINAL_SAVED',report,flush=True)
bpy.ops.render.render(write_still=True)
