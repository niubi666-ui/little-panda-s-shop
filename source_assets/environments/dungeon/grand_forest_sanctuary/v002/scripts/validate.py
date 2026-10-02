import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Vector
BASE=Path(bpy.data.filepath).parent.parent
s=bpy.context.scene
build=json.loads((BASE/'reports/build_report.json').read_text(encoding='utf-8'))
src=Path('E:/ShopGame/source_assets/characters/red_panda/blender/forest_yard_item.blend')
tree=Path(build['tree_source'])
images=[im for im in bpy.data.images if im.source=='FILE' and im.users]
missing=[im.name for im in images if not im.packed_file and not Path(bpy.path.abspath(im.filepath)).is_file()]
hero=bpy.data.objects['Hero_Sacred_Oak_v005']
bpy.context.view_layer.update()
pts=[o.matrix_world@v.co for o in hero.children for v in o.data.vertices]
tri=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in hero.children)
player=[o for o in s.objects if o.name.startswith('Player_reference_')]
ppts=[o.matrix_world@v.co for o in player for v in o.data.vertices]
finite=all(math.isfinite(v) for o in s.objects for row in o.matrix_world for v in row)
checks={'source_library_unchanged':hashlib.sha256(src.read_bytes()).hexdigest()==build['source_sha256'],
 'tree_source_unchanged':hashlib.sha256(tree.read_bytes()).hexdigest()==build['tree_sha256'],
 'textures_resolve':not missing,'finite_transforms':finite,'approved_tree_triangle_count':tri==29768,
 'hero_tree_has_62_parts':len(hero.children)==62,'three_medallions':len([o for o in s.objects if o.name.startswith('Six_leaf_medallion_')])==3,
 'court_four_times_previous':s['court_area_m2']==1152 and s['area_ratio']==4,
 'player_1_2m':abs(max(v.z for v in ppts)-min(v.z for v in ppts)-1.2)<.001,
 'gameplay_frame_narrower_than_court':bpy.data.objects['Camera_Gameplay'].data.ortho_scale<36}
report={'checks':checks,'all_pass':all(checks.values()),'missing_images':missing,'file_images_used':len(images),'packed_images_used':sum(bool(i.packed_file) for i in images),
 'hero_tree_height_m':max(v.z for v in pts)-min(v.z for v in pts),'hero_tree_triangles':tri,'cameras':[o.name for o in s.objects if o.type=='CAMERA'],
 'object_count':len(s.objects),'mesh_instances':sum(o.type=='MESH' for o in s.objects),'unique_meshes':len(set(o.data for o in s.objects if o.type=='MESH')),
 'scope':'Blender art source only; no runtime navigation, collisions, draw calls, LOD, performance or Godot lighting parity tested'}
(BASE/'reports/validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
assert report['all_pass']
