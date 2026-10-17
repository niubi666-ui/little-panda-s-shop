"""Export the Nodachi Combo Attack 05 group without saving source UE assets."""
import unreal, json, traceback
from pathlib import Path
ROOT=Path('E:/ShopGame/source_assets/animations/nodachi/review_v001')
DEST=ROOT/'fbx/attack05'
DEST.mkdir(parents=True,exist_ok=True)
report={'group':'05_Combo_Attack_05','exports':[],'errors':[]}
opts=unreal.FbxExportOption()
for k,v in {'ascii':False,'fbx_export_compatibility':unreal.FbxExportCompatibility.FBX_2018,
            'level_of_detail':False,'collision':False,'export_preview_mesh':True,
            'export_morph_targets':False,'map_skeletal_motion_to_root':False,
            'bake_material_inputs':unreal.FbxMaterialBakeMode.DISABLED}.items():
    opts.set_editor_property(k,v)
for suffix in ['01','02','03','04','All']:
    name=f'AS_Combo_Attack_05_{suffix}_Seq'
    path='/Game/Nodachi/Animations/Sequence/02_Attack/05_Combo_Attack_05/'+name
    try:
        a=unreal.load_asset(path)
        if not a: raise RuntimeError('Missing '+path)
        task=unreal.AssetExportTask()
        task.object=a
        task.filename=str(DEST/(name+'.fbx'))
        task.automated=True
        task.prompt=False
        task.replace_identical=True
        task.options=opts
        task.exporter=unreal.AnimSequenceExporterFBX()
        ok=unreal.Exporter.run_asset_export_task(task)
        row={'name':name,'asset':path,'sequence_length':a.get_play_length(),
             'skeleton':a.get_skeleton().get_path_name(),'ok':bool(ok),'file':task.filename,
             'bytes':Path(task.filename).stat().st_size if Path(task.filename).exists() else 0,
             'errors':list(task.errors)}
        report['exports'].append(row)
        unreal.log('ATTACK05_EXPORT '+json.dumps(row))
    except Exception:
        report['errors'].append({'asset':path,'traceback':traceback.format_exc()})
    (ROOT/'reports/attack05_ue_export.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
unreal.log('ATTACK05_EXPORT_DONE')
