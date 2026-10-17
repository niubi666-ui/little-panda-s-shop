"""Export in-place locomotion, base idles and turns; no changes saved to UE source assets."""
import unreal,json,traceback,gc,time
from pathlib import Path
ROOT=Path('E:/ShopGame/source_assets/animations/nodachi/review_v001')
SOURCE=Path('D:/UE5 test/Test58/Content/Nodachi/Animations/Sequence')
report={'exports':[],'errors':[],'selection':'All IP Walk/Run, four base idle/transition sequences, all Turn sequences; excludes additive aim offsets and duplicate RM variants.'}
rows=[]
for f in sorted(SOURCE.rglob('*.uasset')):
    parts=f.relative_to(SOURCE).parts
    category=None
    if parts[0]=='01_Idle' and parts[1] in ('01_Idle','02_Idle_Combat'):
        category='01_idle'
    elif parts[0] in ('03_Walk','04_Run') and '02_IP' in parts:
        mapping={('03_Walk','01_Walk'):'02_walk_normal',('03_Walk','02_Walk_Combat'):'03_walk_combat',
          ('03_Walk','03_Walk_Block'):'04_walk_block',('03_Walk','04_Walk_to_Walk_Combat'):'05_walk_transitions',
          ('03_Walk','05_Walk_Combat_to_Walk'):'05_walk_transitions',('04_Run','01_Run'):'06_run_normal',
          ('04_Run','02_Run_Combat'):'07_run_combat',('04_Run','03_Run_to_Run_Combat'):'08_run_transitions',
          ('04_Run','04_Run_Combat_to_Run'):'08_run_transitions'}
        category=mapping[(parts[0],parts[1])]
    elif parts[0]=='09_Turn':
        category={'01_Turn':'09_turn_normal','02_Turn_Combat':'10_turn_combat','03_Turn_Block':'11_turn_block'}[parts[1]]
    if category:
        rows.append({'name':f.stem,'asset':'/Game/Nodachi/Animations/Sequence/'+f.relative_to(SOURCE).with_suffix('').as_posix(),'category':category,
                     'variant':'IP' if '02_IP' in parts else 'source'})
assert len(rows)==194,len(rows)
(ROOT/'reports/locomotion_export_plan.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
opts=unreal.FbxExportOption()
for k,v in {'ascii':False,'fbx_export_compatibility':unreal.FbxExportCompatibility.FBX_2018,
            'level_of_detail':False,'collision':False,'export_preview_mesh':False,
            'export_morph_targets':False,'map_skeletal_motion_to_root':False,
            'bake_material_inputs':unreal.FbxMaterialBakeMode.DISABLED}.items():
    opts.set_editor_property(k,v)
for index,row in enumerate(rows):
    try:
        asset=unreal.load_asset(row['asset'])
        if not asset:raise RuntimeError('Missing '+row['asset'])
        dest=ROOT/'fbx/locomotion'/row['category']/(row['name']+'.fbx')
        dest.parent.mkdir(parents=True,exist_ok=True)
        task=unreal.AssetExportTask()
        task.object=asset
        task.filename=str(dest)
        task.automated=True
        task.prompt=False
        task.replace_identical=True
        task.options=opts
        task.exporter=unreal.AnimSequenceExporterFBX()
        ok=unreal.Exporter.run_asset_export_task(task)
        row.update({'ok':bool(ok),'file':str(dest),'bytes':dest.stat().st_size if dest.exists() else 0,
                    'sequence_length':asset.get_play_length(),'skeleton':asset.get_skeleton().get_path_name(),'errors':list(task.errors)})
        report['exports'].append(row)
        unreal.log(f'LOCOMOTION_EXPORT {index+1}/{len(rows)} '+row['name'])
        task.object=None
        del task,asset
    except Exception:
        report['errors'].append({'asset':row['asset'],'traceback':traceback.format_exc()})
    (ROOT/'reports/locomotion_ue_export.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    if index%16==15:
        gc.collect()
        unreal.SystemLibrary.collect_garbage()
unreal.log('LOCOMOTION_EXPORT_DONE')
