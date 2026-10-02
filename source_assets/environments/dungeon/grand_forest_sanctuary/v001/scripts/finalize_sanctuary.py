import bpy,json,math
from pathlib import Path
from mathutils import Vector
BASE=Path(bpy.data.filepath).parent.parent;s=bpy.context.scene
assert 'Layout_Review_Guides' not in bpy.data.collections
guides=bpy.data.collections.new('Layout_Review_Guides');s.collection.children.link(guides)
def material(name,color):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=1.0;return m
def line(name,coords,mat,width=.055):
 d=bpy.data.curves.new(name,'CURVE');d.dimensions='3D';d.bevel_depth=width;d.bevel_resolution=1;sp=d.splines.new('POLY');sp.points.add(len(coords)-1)
 for p,co in zip(sp.points,coords):p.co=(*co,1)
 d.materials.append(mat);o=bpy.data.objects.new(name,d);guides.objects.link(o);return o
gold=material('Layout_only_main_boundary',(1,.55,.04));cyan=material('Layout_only_old_area_comparison',(.02,.8,1));white=material('Layout_only_camera_footprint',(1,1,1))
line('Main_court_36x32m_outline',[(-18,-16,.22),(18,-16,.22),(18,16,.22),(-18,16,.22),(-18,-16,.22)],gold)
for k in range(4):
 a=Vector([(-9,-8,.24),(9,-8,.24),(9,8,.24),(-9,8,.24)][k]);b=Vector([(-9,-8,.24),(9,-8,.24),(9,8,.24),(-9,8,.24)][(k+1)%4])
 for j in range(0,24,2):line('Previous_18x16m_area_comparison',[a.lerp(b,j/24),a.lerp(b,(j+1)/24)],cyan,.035)
cam=s.camera;direction=cam.matrix_world.to_3x3()@Vector((0,0,-1));corners=[]
for p in cam.data.view_frame(scene=s):
 origin=cam.matrix_world@p;hit=origin+direction*((.26-origin.z)/direction.z);corners.append(tuple(hit))
line('Gameplay_camera_ground_footprint',corners+[corners[0]],white,.03)
guides.hide_render=True;guides.hide_viewport=True
s['layout_review_legend']='Gold: actual 36x32m authoring boundary; cyan dashed: previous 18x16m comparison only; white: gameplay camera ground footprint.'
s['player_reference_note']='Static evaluated idle mesh, 1.20m high, from current game GLB; helper Icosphere excluded. No source character changes.'
bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
print('FINALIZED_LAYOUT_GUIDES')
