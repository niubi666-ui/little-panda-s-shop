"""Read-only asset validation; runtime scene exercise belongs to integration."""
import bpy,json,re,hashlib
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
ROOT=BASE.parents[3]
manifest=json.loads((BASE/'bake_manifest.json').read_text(encoding='utf-8'))
result={'blender':bpy.app.version_string,'effects':{},'failures':[]}
for kind in ['fire','frost']:
    source=BASE/'blender'/f'{kind}_study.blend'
    bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False,use_scripts=False)
    mat=bpy.data.objects[kind.upper()+'_Editable_Arc'].data.materials[0]
    scene_dir=ROOT/'game/presentation/combat/fx/elemental_slashes_v001'/kind
    references=[]
    for path in [scene_dir/'slash.tscn',scene_dir/'ribbon.tres']:
        for ref in re.findall(r'path="res://([^"]+)"',path.read_text(encoding='utf-8')):
            references.append(ref)
            if not (ROOT/'game'/ref).exists():result['failures'].append('Missing dependency '+ref)
    for record in manifest['effects'][kind]:
        path=ROOT/record['runtime']
        if hashlib.sha256(path.read_bytes()).hexdigest()!=record['sha256']:result['failures'].append('Hash mismatch '+str(path))
        image=bpy.data.images.load(str(path),check_existing=False)
        if list(image.size)!=[1024,256]:result['failures'].append('Incorrect texture size '+str(path))
        bpy.data.images.remove(image)
    result['effects'][kind]={'blend':str(source.relative_to(ROOT)),'shader_nodes':len(mat.node_tree.nodes),'shader_links':len(mat.node_tree.links),'scene_dependency_count':len(references),'texture_files':len(manifest['effects'][kind]),'source_reopen':'ok'}
(BASE/'validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
if result['failures']:raise RuntimeError('Asset validation failed')
