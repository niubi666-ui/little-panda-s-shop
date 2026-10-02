import json,struct,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[6]
BASE=ROOT/'source_assets/environments/dungeon/room_compositions/v004'
report=json.loads((BASE/'reports/runtime_export.json').read_text(encoding='utf-8'))
assert hashlib.sha256(Path(report['source']).read_bytes()).hexdigest()==report['source_sha256']
for preset in report['compositions']:
 for name in [preset['id']]+[m['prop_id'] for m in preset['members'] if m['interactive']]:
  path=ROOT/f'game/assets/environments/room_compositions_v004/{name}.glb'
  binary=path.read_bytes();length=struct.unpack_from('<I',binary,12)[0]
  gltf=json.loads(binary[20:20+length])
  nodes=[n for n in gltf['nodes'] if 'mesh' in n]
  assert len(nodes)==1,(name,[n['name'] for n in nodes])
  assert not any('STAGE' in n.get('name','') for n in gltf['nodes']),name
  assert not any('uri' in im for im in gltf.get('images',[])),name
  for mesh in gltf['meshes']:
   for surface in mesh['primitives']:
    material=gltf['materials'][surface['material']]
    if 'baseColorTexture' not in material.get('pbrMetallicRoughness',{}):continue
    channel=material['pbrMetallicRoughness']['baseColorTexture'].get('texCoord',0)
    accessor=gltf['accessors'][surface['attributes']['TEXCOORD_'+str(channel)]]
    view=gltf['bufferViews'][accessor['bufferView']]
    assert accessor['componentType']==5126
    start=28+length+view.get('byteOffset',0)+accessor.get('byteOffset',0)
    stride=view.get('byteStride',8)
    uv={struct.unpack_from('<ff',binary,start+i*stride) for i in range(accessor['count'])}
    assert len(uv)>3,(name,material['name'],'missing/constant texture UV')
  print(name,len(binary),'bytes;',len(gltf['meshes'][0]['primitives']),'material surfaces;',nodes[0]['name'])
print('EXPORT_VALID: independent parts, one mesh per file, embedded textures, valid material UV, immutable source')
