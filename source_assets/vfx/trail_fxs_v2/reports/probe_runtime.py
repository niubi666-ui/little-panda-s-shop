import bpy, json
from pathlib import Path
base = Path(__file__).resolve().parents[1]
path = next((base / 'original').rglob('TrailFXs_Blades.blend'))
bpy.ops.wm.open_mainfile(filepath=str(path), load_ui=False, use_scripts=False)
o = bpy.data.objects['Trail_Blade']
m = o.modifiers[0]
r = {'properties_type': str(type(m.properties)), 'properties': repr(m.properties), 'keys': [p.identifier for p in m.properties.bl_rna.properties],
     'values': {p.identifier:str(getattr(m.properties,p.identifier)) for p in m.properties.bl_rna.properties},
     'inputs': {p.identifier: {'type':p.type, 'value':str(getattr(m.properties.inputs,p.identifier))} for p in m.properties.inputs.bl_rna.properties},
     'socket_fields': {key: {p.identifier:str(getattr(getattr(m.properties.inputs,key),p.identifier)) for p in getattr(m.properties.inputs,key).bl_rna.properties} for key in ['Input_2','Input_3','Input_8']},
     'objects': {x.name: {'vertices': [list(v.co) for v in x.data.vertices][:8] if x.type=='MESH' else [],
                         'drivers': [(d.data_path, d.driver.expression) for d in x.animation_data.drivers] if x.animation_data else []} for x in bpy.data.objects},
     'shader_attributes': {mat.name:[(n.type, getattr(n,'attribute_name','')) for n in mat.node_tree.nodes if n.type in ['ATTRIBUTE','UVMAP','TEX_COORD','GROUP']] for mat in bpy.data.materials if mat.node_tree},
     'bake_operator': str(bpy.ops.object.simulation_nodes_cache_bake.get_rna_type().properties.keys()),
     'bake_data': [{'type':type(b).__name__, 'props':[p.identifier for p in b.bl_rna.properties]} for b in m.bakes],
     'render_enum': [i.identifier for i in bpy.context.scene.render.image_settings.bl_rna.properties['file_format'].enum_items]}
(base / 'reports/runtime_probe.json').write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(r,ensure_ascii=False))
