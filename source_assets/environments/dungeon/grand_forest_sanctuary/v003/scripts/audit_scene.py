import bpy, json, collections, time
from pathlib import Path
assert bpy.app.background
BASE=Path(__file__).resolve().parents[1]
(BASE/'reports').mkdir(parents=True,exist_ok=True)
s=bpy.context.scene
def tris(me): return sum(len(p.vertices)-2 for p in me.polygons)
cache={}
groups=collections.defaultdict(lambda: {'objects':0,'triangles':0,'mesh_names':set()})
meshes={}
for o in s.objects:
 if o.type!='MESH':continue
 me=o.data
 if me.name not in cache: cache[me.name]=tris(me)
 role=o.get('asset_role') or ('Fern' if o.name.startswith('Fern_clump') else 'White_meadow_flower_spray' if o.name.startswith('White_meadow_flower_spray') else 'Trees' if o.get('tree_source') else 'Small_fallen_oak_leaves' if o.name=='Small_fallen_oak_leaves' else 'Other')
 g=groups[role];g['objects']+=1;g['triangles']+=cache[me.name];g['mesh_names'].add(me.name)
 if me.name not in meshes:meshes[me.name]={'mesh':me.name,'triangles_each':cache[me.name],'users':0,'example':o.name}
 meshes[me.name]['users']+=1
for g in groups.values():g['unique_meshes']=len(g.pop('mesh_names'))
for m in meshes.values():m['triangles_expanded']=m['triangles_each']*m['users']
details=[]
for o in s.objects:
 if o.name=='Small_fallen_oak_leaves' or (o.name.startswith('Forest_oak_7') and ('Trunk' in o.name or o.type=='EMPTY')):
  details.append({'name':o.name,'type':o.type,'data':o.data.name if o.data else None,'polygons':len(o.data.polygons) if o.type=='MESH' else 0,'triangles':cache.get(o.data.name,0) if o.data else 0,'data_users':o.data.users if o.data else 0,'parent':o.parent.name if o.parent else None,'modifiers':[{'name':m.name,'type':m.type} for m in o.modifiers],'instance_type':o.instance_type,'dimensions':list(o.dimensions),'materials':[m.name for m in o.data.materials] if o.type=='MESH' else []})
leaf=bpy.data.objects.get('Small_fallen_oak_leaves')
mats=[]
for mat in leaf.data.materials:
 nodes=[]
 for n in mat.node_tree.nodes:
  nodes.append({'name':n.name,'type':n.type,'inputs':{i.name:list(i.default_value) if hasattr(i.default_value,'__iter__') else i.default_value for i in n.inputs if hasattr(i,'default_value') and isinstance(i.default_value,(float,int,str)) or (hasattr(i,'default_value') and hasattr(i.default_value,'__iter__'))}})
 mats.append({'name':mat.name,'nodes':nodes,'links':[(l.from_node.name,l.from_socket.name,l.to_node.name,l.to_socket.name) for l in mat.node_tree.links]})
stats={}
for o in s.objects:o.select_set(False)
for name in ['Small_fallen_oak_leaves','Forest_oak_7','Forest_oak_7__SacredOak_Trunk_Preserved','Hero_Sacred_Oak_v005__SacredOak_Trunk_Preserved']:
 o=bpy.data.objects.get(name)
 if o:
  o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.context.view_layer.update()
  stats[name]=s.statistics(bpy.context.view_layer)
  o.select_set(False)
r={'blender_version':bpy.app.version_string,'file':bpy.data.filepath,'scene':s.name,'objects':len(s.objects),'mesh_objects':sum(m['users'] for m in meshes.values()),'unique_meshes':len(cache),'unique_mesh_triangles':sum(cache.values()),'expanded_base_triangles':sum(m['triangles_expanded'] for m in meshes.values()),'groups':dict(sorted(groups.items(),key=lambda kv:-kv[1]['triangles'])),'top_meshes':sorted(meshes.values(),key=lambda m:-m['triangles_expanded'])[:35],'target_details':details,'selection_statistics':stats,'leaf_materials':mats,'leaf_sample_vertices':[list(v.co) for v in leaf.data.vertices[:18]],'leaf_sample_polygons':[{'vertices':list(p.vertices),'material':p.material_index} for p in leaf.data.polygons[:16]],'scene_render_engine':s.render.engine,'cameras':[o.name for o in s.objects if o.type=='CAMERA'],'active_camera':s.camera.name if s.camera else None}
(BASE/'reports/baseline_audit.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in r.items() if k not in ['leaf_materials','top_meshes','leaf_sample_vertices','leaf_sample_polygons']},ensure_ascii=False))
