"""Replace only allowlisted foliage meshes in an existing glTF binary.
Repack reachable data to keep all protected geometry, UVs, materials and transforms
byte-identical, including any previous export-specific evaluated UV coordinates.
"""
import argparse
import copy
import json
import struct
from pathlib import Path
from check_forest_foliage import GLB


def assemble(original, candidate, report, output):
    sources = [GLB(original), GLB(candidate)]
    changed = {x['name'] for x in json.loads(Path(report).read_text())['foliage_optimization']['changed']}
    categories = ['meshes','accessors','bufferViews','materials','textures','images','samplers']
    result = copy.deepcopy(sources[0].doc)
    assert not result.get('skins') and not result.get('animations')
    for key in categories: result[key] = []
    maps = {key:{} for key in categories}
    binary = bytearray()

    def transfer(category, source_id, index):
        key=(source_id,index)
        if key in maps[category]: return maps[category][key]
        source=sources[source_id]
        entry=copy.deepcopy(source.doc[category][index])
        if category=='bufferViews':
            binary.extend(b'\0'*(-len(binary)%4))
            start=entry.get('byteOffset',0)
            payload=source.binary[start:start+entry['byteLength']]
            entry['byteOffset']=len(binary);entry['buffer']=0
            binary.extend(payload)
        elif category=='accessors':
            assert 'sparse' not in entry
            entry['bufferView']=transfer('bufferViews',source_id,entry['bufferView'])
        elif category=='images':
            entry['bufferView']=transfer('bufferViews',source_id,entry['bufferView'])
        elif category=='textures':
            entry['source']=transfer('images',source_id,entry['source'])
            if 'sampler' in entry:entry['sampler']=transfer('samplers',source_id,entry['sampler'])
        elif category=='materials':
            def patch(obj):
                if isinstance(obj,dict):
                    for name,value in obj.items():
                        if name.endswith('Texture') and isinstance(value,dict) and 'index' in value:
                            value['index']=transfer('textures',source_id,value['index'])
                        else:patch(value)
                elif isinstance(obj,list):
                    for value in obj:patch(value)
            patch(entry)
        elif category=='meshes':
            for primitive in entry['primitives']:
                primitive['attributes']={k:transfer('accessors',source_id,v) for k,v in primitive['attributes'].items()}
                primitive['indices']=transfer('accessors',source_id,primitive['indices'])
                primitive['material']=transfer('materials',source_id,primitive['material'])
                assert 'targets' not in primitive
        new_index=len(result[category]);result[category].append(entry);maps[category][key]=new_index
        return new_index

    for node in result['nodes']:
        if 'mesh' not in node:continue
        name=node['name'];source_id=1 if name in changed else 0
        node['mesh']=transfer('meshes',source_id,sources[source_id].nodes[name]['mesh'])
    binary.extend(b'\0'*(-len(binary)%4))
    result['buffers']=[{'byteLength':len(binary)}]
    for key in categories:
        if not result[key]:del result[key]
    payload=json.dumps(result,separators=(',',':')).encode()
    payload+=b' '*(-len(payload)%4)
    raw=struct.pack('<III',0x46546C67,2,28+len(payload)+len(binary))+struct.pack('<II',len(payload),0x4E4F534A)+payload+struct.pack('<II',len(binary),0x004E4942)+binary
    Path(output).write_bytes(raw)
    print('Assembled foliage derivative:',len(raw),'bytes')


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ['original','candidate','report','output']:parser.add_argument(name)
    args=parser.parse_args()
    assemble(args.original,args.candidate,args.report,args.output)
