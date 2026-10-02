import bpy, json
from pathlib import Path

BASE = Path(__file__).resolve().parents[1]
reports = []
def values(modifier):
    try:
        return {k: (v.name if isinstance(v, bpy.types.ID) else str(v)) for k,v in modifier.items()}
    except TypeError:
        return {'rna_properties': [p.identifier for p in modifier.bl_rna.properties]}
for path in sorted((BASE / 'original').rglob('*.blend')):
    bpy.ops.wm.open_mainfile(filepath=str(path), load_ui=False, use_scripts=False)
    report = {'file': str(path), 'version': bpy.app.version_string,
        'scenes': [{'name': s.name, 'frames': [s.frame_start, s.frame_end], 'fps': s.render.fps} for s in bpy.data.scenes],
        'objects': [], 'materials': [], 'groups': [], 'images': []}
    for o in bpy.data.objects:
        report['objects'].append({'name': o.name, 'type': o.type, 'asset': bool(o.asset_data),
            'location': list(o.location), 'dimensions': list(o.dimensions),
            'animation': bool(o.animation_data), 'parent': o.parent.name if o.parent else None,
            'modifiers': [{'name': m.name, 'type': m.type, 'node_group': m.node_group.name if m.type == 'NODES' and m.node_group else None,
                           'values': values(m) if m.type == 'NODES' else {}} for m in o.modifiers]})
    for m in bpy.data.materials:
        report['materials'].append({'name': m.name, 'asset': bool(m.asset_data), 'nodes': len(m.node_tree.nodes) if m.node_tree else 0})
    for g in bpy.data.node_groups:
        if g.bl_idname != 'GeometryNodeTree': continue
        report['groups'].append({'name': g.name, 'nodes': len(g.nodes), 'interface': [
            {'name': i.name, 'id': i.identifier, 'direction': i.in_out, 'type': i.socket_type,
             'value': str(getattr(i, 'default_value', ''))} for i in g.interface.items_tree if i.item_type == 'SOCKET']})
    for i in bpy.data.images:
        report['images'].append({'name':i.name, 'path':i.filepath, 'packed':bool(i.packed_file), 'size':list(i.size)})
    reports.append(report)
(BASE / 'reports/library_inventory.json').write_text(json.dumps(reports, ensure_ascii=False, indent=2), encoding='utf-8')
print('LIBRARY_INVENTORY', [(x['file'], len(x['objects']), len(x['materials']), len(x['groups'])) for x in reports])
