"""Check the staged derivative against the original GLB before installing it.
All nodes outside the explicit foliage change report must preserve mesh streams,
material definitions/textures, and transforms. No Blender or Godot is required.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path


class GLB:
    def __init__(self, path):
        raw = Path(path).read_bytes()
        length = struct.unpack_from('<I', raw, 12)[0]
        self.doc = json.loads(raw[20:20+length])
        self.binary = raw[28+length:]
        self.nodes = {n['name']: n for n in self.doc['nodes']}

    def accessor(self, index):
        a = self.doc['accessors'][index]
        view = self.doc['bufferViews'][a['bufferView']]
        widths = {'SCALAR':1, 'VEC2':2, 'VEC3':3, 'VEC4':4, 'MAT4':16}
        size = widths[a['type']] * {5120:1,5121:1,5122:2,5123:2,5125:4,5126:4}[a['componentType']]
        start = view.get('byteOffset',0)+a.get('byteOffset',0)
        stride = view.get('byteStride',size)
        data = b''.join(self.binary[start+i*stride:start+i*stride+size] for i in range(a['count']))
        return (a['count'],a['type'],a['componentType'],hashlib.sha256(data).hexdigest())

    def material(self, index):
        mat = json.loads(json.dumps(self.doc['materials'][index]))
        def resolve(obj):
            if isinstance(obj, dict):
                for key,value in list(obj.items()):
                    if key.endswith('Texture') and isinstance(value,dict) and 'index' in value:
                        tex=self.doc['textures'][value['index']]
                        im=self.doc['images'][tex['source']]
                        view=self.doc['bufferViews'][im['bufferView']]
                        start=view.get('byteOffset',0)
                        value['index']=hashlib.sha256(self.binary[start:start+view['byteLength']]).hexdigest()
                    resolve(value)
            elif isinstance(obj,list):
                for value in obj: resolve(value)
        resolve(mat)
        return mat

    def mesh(self,node):
        result=[]
        for p in self.doc['meshes'][node['mesh']]['primitives']:
            result.append({'attributes':{k:self.accessor(v) for k,v in p['attributes'].items()},
                           'indices':self.accessor(p['indices']), 'material':self.material(p['material'])})
        return result

    def triangles(self):
        counts=[sum(self.doc['accessors'][p['indices']]['count']//3 for p in m['primitives']) for m in self.doc['meshes']]
        return sum(counts[n['mesh']] for n in self.nodes.values() if 'mesh' in n)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('original');parser.add_argument('optimized');parser.add_argument('report');parser.add_argument('output')
    args=parser.parse_args()
    old,new=GLB(args.original),GLB(args.optimized)
    changed={x['name'] for x in json.loads(Path(args.report).read_text())['foliage_optimization']['changed']}
    failures=[];protected=0
    if old.nodes.keys()!=new.nodes.keys(): failures.append('Node inventory changed')
    for name,node in old.nodes.items():
        other=new.nodes.get(name,{})
        for key in ['matrix','translation','rotation','scale','children']:
            if node.get(key)!=other.get(key):failures.append(name+': '+key)
        if name not in changed and 'mesh' in node:
            protected+=1
            if old.mesh(node)!=new.mesh(other):failures.append(name+': protected geometry/material')
    result={'protected_mesh_instances':protected,'changed_foliage_instances':len(changed),'before_triangles':old.triangles(),'after_triangles':new.triangles(),'failures':failures}
    Path(args.output).write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result))
    assert not failures


if __name__=='__main__':main()
