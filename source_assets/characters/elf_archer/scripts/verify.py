import bpy,json,hashlib
from pathlib import Path
b=Path('E:/ShopGame/source_assets/characters/elf_archer')
bpy.ops.wm.open_mainfile(filepath=str(b/'blender/jingling_assembled_v001.blend'),load_ui=False,use_scripts=False)
images=[i for i in bpy.data.images if i.type=='IMAGE']
assert len([o for o in bpy.data.objects if o.type=='MESH'])==2
assert all(i.packed_file for i in images)
src=Path('E:/ShopGame/source_assets/characters/red_panda/blender/jingling.blend')
assert hashlib.sha256(src.read_bytes()).digest()==hashlib.sha256((b/'original/jingling_source.blend').read_bytes()).digest()
(b/'reports/verification.json').write_text(json.dumps({'reopen_ok':True,'source_unchanged':True,'packed_images':[{ 'name':i.name,'size':list(i.size)} for i in images]},indent=2),encoding='utf-8')
print('VERIFY_OK')
