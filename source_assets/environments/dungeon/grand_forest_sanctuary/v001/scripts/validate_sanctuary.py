"""Read-only saved Blender-art checks, not game-navigation/performance verification."""
import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
BASE=Path(bpy.data.filepath).parent.parent;s=bpy.context.scene
errors=[];checks={}
source=Path('E:/ShopGame/source_assets/characters/red_panda/blender/forest_yard_item.blend')
archived=BASE/'original/forest_yard_item.blend'
hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [source,archived]}
checks['original_archive_sha256_match']=len(set(hashes.values()))==1
floor=bpy.data.objects['Main_court_36m_by_32m_foundation']
checks['main_court_dimensions_m']=list(floor.dimensions)
checks['area_m2']=floor.dimensions.x*floor.dimensions.y
checks['area_ratio_to_18x16']=checks['area_m2']/288
if abs(checks['area_ratio_to_18x16']-4)>.00001:errors.append('Area ratio is not 4')
player=[o for o in s.objects if o.name.startswith('Player_reference_')]
points=[o.matrix_world@v.co for o in player for v in o.data.vertices]
checks['player_height_m']=max(v.z for v in points)-min(v.z for v in points)
coords=[world_to_camera_view(s,s.camera,v) for v in points]
checks['player_screen_height_fraction']=max(v.y for v in coords)-min(v.y for v in coords)
checks['player_screen_bounds']=[min(v.x for v in coords),min(v.y for v in coords),max(v.x for v in coords),max(v.y for v in coords)]
if not .05<checks['player_screen_height_fraction']<.09:errors.append('Player size outside art target 5-9 percent')
corners=[world_to_camera_view(s,s.camera,Vector((x,y,0))) for x,y in [(-18,-16),(18,-16),(18,16),(-18,16)]]
checks['main_court_projected_corners']=[list(v) for v in corners]
checks['full_room_does_not_fit_hero_camera']=not all(0<=v.x<=1 and 0<=v.y<=1 for v in corners)
if not checks['full_room_does_not_fit_hero_camera']:errors.append('Entire room fits gameplay camera')
checks['images']=[]
for im in bpy.data.images:
 if im.source not in ['FILE','TILED']:continue
 resolved=Path(bpy.path.abspath(im.filepath))
 checks['images'].append({'name':im.name,'packed':bool(im.packed_file),'local_file_exists':resolved.is_file(),'size':list(im.size),'path':str(resolved)})
 if not im.packed_file and not resolved.is_file():errors.append('Missing image '+im.name)
 if im.users>0 and min(im.size)==0:errors.append('Zero size image '+im.name)
checks['external_linked_libraries']=[lib.filepath for lib in bpy.data.libraries]
if checks['external_linked_libraries']:errors.append('Linked library dependency')
checks['mesh_objects']=sum(o.type=='MESH' for o in s.objects)
meshes={o.data for o in s.objects if o.type=='MESH'}
checks['unique_mesh_triangles']=sum(sum(len(p.vertices)-2 for p in m.polygons) for m in meshes)
checks['instanced_mesh_triangles']=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in s.objects if o.type=='MESH')
checks['camera_names']=[o.name for o in s.objects if o.type=='CAMERA']
checks['helper_icosphere_present']=any(o.name=='Icosphere' for o in s.objects)
if checks['helper_icosphere_present']:errors.append('Unwanted character helper mesh')
report={'passed':not errors,'errors':errors,'source_hashes':hashes,'checks':checks,'scope':'Saved Blender art, textures and measured scale only. No game runtime, collision or performance claim.'}
(BASE/'reports/validation.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
print(json.dumps({k:v for k,v in checks.items() if k!='images'},indent=2));print('VALIDATION_PASSED',not errors,errors)
if errors:raise RuntimeError('; '.join(errors))
