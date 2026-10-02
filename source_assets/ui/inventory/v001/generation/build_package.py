"""Inventory art packaging. Inspect RGBA only; never edit generated PNG pixels."""
from pathlib import Path
from PIL import Image
import hashlib, json, shutil, html, re
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
PROJECT=ROOT.parents[3]
RUNTIME=PROJECT/'game/assets/ui/inventory/v001'
CHROME={
 'window_panel':'背包主面板', 'details_parchment':'羊皮纸详情区',
 'slot_regular':'物品格常态', 'slot_selected':'金色选中框',
 'tab_regular':'分类页签常态', 'tab_selected':'分类页签选中态',
 'button_primary':'主要操作按钮', 'button_secondary':'仓库操作按钮',
 'close_socket':'关闭按钮底板', 'header_leaf_sprig':'独立标题叶饰',
}
ITEMS={
 'potion_red':('potion','红色药剂','potions'),
 'sword_iron':('sword','旅行短剑','equipment'),
 'travel_pouch':('bag','旅行布袋','equipment'),
 'herb_sprig':('herb','芳香草叶','materials'),
 'crystal_blue':('crystal','蓝色晶簇','materials'),
 'scroll_parchment':('scroll','旧卷轴','materials'),
}
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def icons():
    paths={
      'action_use':'<path d="M50 16h28v11H50z M54 28v23C22 75 35 111 64 111s42-36 10-60V28 M40 78h48"/>',
      'action_store':'<path d="M22 61h84v48H22z M22 61V48q0-22 25-22h12 M25 74h78 M58 73v18h13V73 M88 15v35 M75 38l13 13 13-13"/>',
      'action_sort':'<path d="M40 28h65 M40 62h48 M40 96h31 M17 26h3 M17 60h3 M17 94h3 M100 72v35 M90 95l10 12 10-12"/>',
      'close':'<path d="m33 33 62 62 M95 33 33 95"/>',
    }
    made={}
    for name,p in paths.items():
        made[name]=f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><g fill="none" stroke="#f2e3b9" stroke-width="7" stroke-linecap="round" stroke-linejoin="round">{p}</g></svg>'
    made['quantity_badge']='<svg xmlns="http://www.w3.org/2000/svg" width="96" height="48" viewBox="0 0 96 48"><path d="M8 2H88L94 8V40L88 46H8L2 40V8Z" fill="#081c15" fill-opacity=".9" stroke="#8d7848" stroke-width="2"/></svg>'
    made['empty_slot_mark']='<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><g fill="none" stroke="#8d8c61" stroke-width="2" opacity=".45"><path d="M64 29 99 64 64 99 29 64Z M64 44 84 64 64 84 44 64Z M64 21v86 M21 64h86"/></g></svg>'
    for name,color in [('divider_gold','#b69a62'),('divider_ink','#9a8559')]:
        made[name]=f'<svg xmlns="http://www.w3.org/2000/svg" width="640" height="28" viewBox="0 0 640 28"><g fill="none" stroke="{color}" stroke-width="1.5"><path d="M0 14h298 M342 14h298 M320 5l9 9-9 9-9-9Z M301 14l4-4 4 4-4 4Z M331 14l4-4 4 4-4 4Z"/></g></svg>'
    for color,light,dark in [('blue','#90e7f5','#236f9b'),('green','#b6f0ca','#326f50'),('olive','#e0e991','#637b24'),('amber','#ffe4a3','#9d641c'),('violet','#e9c3ff','#7243a5')]:
        made['marker_'+color]=f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><path d="M32 6 56 32 32 58 8 32Z" fill="{dark}" stroke="{light}" stroke-width="3"/><path d="M32 10 12 32h20Z" fill="{light}" opacity=".75"/><path d="M32 10v42L52 32Z" fill="{light}" opacity=".16"/></svg>'
    records=[]
    for name,data in made.items():
        p=ROOT/'exports/icons'/f'{name}.svg';p.parent.mkdir(parents=True,exist_ok=True)
        ET.fromstring(data);p.write_text(data+'\n',encoding='utf-8')
        q=RUNTIME/'icons'/p.name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
        records.append({'file':p.name,'provenance':'authored_simple_vector','sha256':sha(p),'runtime_path':'res://assets/ui/inventory/v001/icons/'+p.name})
    for name in ['bag','coin']:
        origin=PROJECT/'game/assets/ui/foliage'/f'{name}.svg';p=ROOT/'exports/icons'/f'title_{name}.svg';q=RUNTIME/'icons'/p.name
        shutil.copy2(origin,p);shutil.copy2(p,q);ET.parse(p)
        records.append({'file':p.name,'provenance':origin.relative_to(PROJECT).as_posix(),'sha256':sha(p),'runtime_path':'res://assets/ui/inventory/v001/icons/'+p.name})
    for r in records:assert sha(ROOT/'exports/icons'/r['file'])==sha(RUNTIME/'icons'/r['file'])
    return records

def main():
    vector_records=icons()
    assets=[]
    for p in sorted((ROOT/'exports').glob('*/*.png')):
        rel=p.relative_to(ROOT/'exports');q=RUNTIME/rel
        assert q.is_file() and sha(p)==sha(q),f'Missing/different runtime copy {rel}'
        with Image.open(p) as im:
            assert im.mode=='RGBA',f'{rel} not RGBA'
            a=im.getchannel('A');hist=a.histogram();assert hist[0]>0 and sum(hist[5:])>0
            x0,y0,x1,y1=a.point(lambda x:255 if x>4 else 0).getbbox()
            bx,by,ex,ey=max(0,x0-8),max(0,y0-8),min(im.width,x1+8),min(im.height,y1+8)
            label=CHROME[p.stem] if p.stem in CHROME else ITEMS[p.stem][1]
            entry={'id':'inventory.'+rel.parent.name+'.'+p.stem,'label_zh_for_art_browser_only':label,
              'source_path':p.relative_to(PROJECT).as_posix(),'runtime_path':'res://assets/ui/inventory/v001/'+rel.as_posix(),
              'size_px':list(im.size),'mode':im.mode,'alpha_gt_4_bbox_xywh':[x0,y0,x1-x0,y1-y0],
              'atlas_region_xywh':[bx,by,ex-bx,ey-by],'center_alpha':a.getpixel((im.width//2,im.height//2)),
              'transparent_pixel_fraction':round(hist[0]/(im.width*im.height),6),'sha256':sha(p),
              'sample_entry_id':ITEMS[p.stem][0] if p.stem in ITEMS else None,
              'status':'sample_catalog_concept_icon' if p.stem in ITEMS else 'ui_art_candidate'}
            if p.stem=='slot_selected':assert entry['center_alpha']==0,'Selection center must be alpha0'
            assets.append(entry)
    assert {a['id'].split('.')[-1] for a in assets}==set(CHROME)|set(ITEMS),'Wrong asset set'
    manifest={'schema_version':1,'pack_version':'inventory_v001','purpose':'Art metadata only, not gameplay content/InventoryDef/schema',
      'integration_status':'not_integrated_user_requested_art_only','notify_code_thread':False,
      'reference':'reference/inventory_reference.png','assets':assets,'svg_assets':vector_records,
      'sample_mapping':{v[0]:'res://assets/ui/inventory/v001/items/'+k+'.png' for k,v in ITEMS.items()},
      'marker_semantics':'Color variants are optional art only. No rarity names, ranks or assignment are defined.'}
    (ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    report={'png_count':len(assets),'svg_count':len(vector_records),'all_rgba':True,'selection_center_transparent':True,'all_runtime_hashes_match':True,'svg_xml_valid':True,'no_game_code_modified':True,'godot_validation':'not_run_art_only','browser_validation':'not_run_prior_local_URL_policy_block','assets':assets,'svg_assets':vector_records}
    (ROOT/'reports/asset_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    cards=[]
    for a in assets:
        rel=a['runtime_path'].split('/v001/',1)[1]
        label=html.escape(a['label_zh_for_art_browser_only'])
        tag='样例 ID: '+a['sample_entry_id'] if a['sample_entry_id'] else '独立界面组件'
        cards.append(f'<article><a class="art" href="../exports/{rel}" target="_blank"><img src="../exports/{rel}"></a><h3>{label}</h3><code>{rel}</code><p>{tag} · {a["size_px"][0]}×{a["size_px"][1]} RGBA</p></article>')
    svgs=''.join(f'<article class="small"><div class="art"><img src="../exports/icons/{r["file"]}"></div><code>{r["file"]}</code></article>' for r in vector_records)
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>背包 UI 素材 v001</title><style>*{box-sizing:border-box}body{background:#0b1b16;color:#f2e3b9;margin:0;font:15px/1.6 "Microsoft YaHei",sans-serif}header,main{max-width:1420px;margin:auto;padding:28px}header{border-bottom:1px solid #8a774f}h1{font-family:serif;font-size:36px;margin:8px 0}a{color:#e3ce98}p,small{color:#b2b49b}button{background:#254536;color:#f2e3b9;border:1px solid #a99460;padding:8px 20px;cursor:pointer}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:20px}article{padding:12px;border:1px solid #516345;border-radius:9px;background:#13271e}.art{height:220px;display:flex;align-items:center;justify-content:center;background:repeating-conic-gradient(#354338 0% 25%,#29392e 0% 50%) 50%/24px 24px;border-radius:6px}.art img{max-width:100%;max-height:100%;object-fit:contain}h3{margin:10px 0 4px;font-size:18px}code{font-size:12px;overflow-wrap:anywhere}article p{font-size:12px;margin:6px 0}.small .art{height:100px}.small .art img{max-width:88%;max-height:80px}</style><header><small>小熊猫的小店 · INVENTORY ART</small><h1>背包 UI · 树叶主题拆分素材 v001</h1><p>10 个界面图层 · 6 个物品图标 · 独立辅助 SVG · 无烘焙文字与数字</p><p>本轮仅制作美术，没有通知代码任务，也没有接入或改变游戏背包。</p><p><a href="layout_preview.html">拼装示意</a>　<a href="../README.md">装配说明</a>　<a href="../manifest.json">像素尺寸 / 透明范围</a></p><button onclick="document.querySelectorAll('.art').forEach(n=>n.style.background=this.dataset.light==='yes'?'#17281d':'#e3dccb');this.dataset.light=this.dataset.light==='yes'?'no':'yes'">深 / 浅底检查透明边缘</button></header><main><div class="grid">'''+''.join(cards)+'''</div><h2>操作、数量底板与可选标记</h2><p>菱形仅为色彩变体，本包不定义稀有度规则。</p><div class="grid">'''+svgs+'''</div></main></html>'''
    (ROOT/'previews/index.html').write_text(page,encoding='utf-8')
    template=(ROOT/'generation/layout_template.html').read_text(encoding='utf-8')
    (ROOT/'previews/layout_preview.html').write_text(template.replace('__ASSETS__',json.dumps(assets,ensure_ascii=False)),encoding='utf-8')
    missing=[]
    for page_name in ['index.html','layout_preview.html']:
        p=ROOT/'previews'/page_name;text=p.read_text(encoding='utf-8')
        refs=re.findall(r'(?:src|href)="([^"]+)"',text)+re.findall(r"url\(['\"]?([^'\")]+)",text)
        for ref in refs:
            if ref.startswith(('http','data:','#')):continue
            if not (p.parent/ref).resolve().exists():missing.append(page_name+': '+ref)
    assert not missing,missing
    print(json.dumps({'png_count':len(assets),'svg_count':len(vector_records),'missing_static_refs':missing,'manifest':str(ROOT/'manifest.json')},ensure_ascii=False))

if __name__=='__main__':main()
