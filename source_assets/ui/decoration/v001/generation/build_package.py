"""Inspect generated PNGs without changing pixels; write manifest, icons, gallery.

Run with the bundled Python. This script does not generate/edit raster artwork.
"""
from pathlib import Path
import hashlib
import json
import shutil
import html
import xml.etree.ElementTree as ET
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[3]
RUNTIME = PROJECT / 'game/assets/ui/decoration/v001'

ICON_PATHS = {
    'confirm': '<path d="M24 64 51 89 106 34"/>',
    'close': '<path d="m32 32 64 64 M96 32 32 96"/>',
    'rotate': '<path d="M99 61a36 36 0 1 1-13-27 M87 17v22h23"/>',
    'undo': '<path d="m42 31-22 22 22 22 M22 53h53c35 0 35 43 0 43H59"/>',
    'remove': '<path d="M33 36h62 M48 36V22h32v14 M40 44l5 63h38l5-63 M56 54v37 M72 54v37"/>',
    'mouse_left': '<rect x="35" y="15" width="58" height="98" rx="28"/><path d="M64 16v40H35"/><path d="M39 53V43c0-13 8-23 21-25v35Z" fill="#f2e3b9" stroke="none"/>',
    'mouse_right': '<rect x="35" y="15" width="58" height="98" rx="28"/><path d="M64 16v40h29"/><path d="M89 53V43c0-13-8-23-21-25v35Z" fill="#f2e3b9" stroke="none"/>',
    'chair': '<path d="M38 63V20h49v43 M47 23v33 M60 23v33 M76 23v33 M29 64h70v17H29Z M34 83v26 M92 83v26 M39 65v-9 M89 65V56"/>',
}

NAMES = {
    'catalog_panel': '目录 / 详情面板底图', 'item_slot': '家具格 · 常态',
    'item_selected': '选中描边 · 中心透明', 'button_primary': '主要动作按钮',
    'button_secondary': '次要动作按钮', 'mode_banner': '装修模式标题牌',
    'tab_button': '分类标签底图', 'leaf_corner': '独立角落叶饰',
    'barrel': '小木桶', 'scroll_bin': '卷轴桶', 'supply_crate': '药罐货箱',
    'storage_chest': '宝箱', 'chair_oak': '木质椅子', 'bookshelf_potions': '魔药书架',
    'potted_fern': '盆栽蕨叶', 'rug_crimson': '酒红地毯', 'wall_lantern': '壁挂灯笼',
}
MAPPING = {'barrel': 'barrel', 'scroll_bin': 'scroll_bin', 'supply_crate': 'supply_crate', 'storage_chest': 'chest'}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    svg_records=[]
    for name, path in ICON_PATHS.items():
        data = f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><g fill="none" stroke="#f2e3b9" stroke-width="7" stroke-linecap="round" stroke-linejoin="round">{path}</g></svg>\n'
        source = ROOT / 'exports/icons' / f'{name}.svg'
        target = RUNTIME / 'icons' / source.name
        source.parent.mkdir(parents=True, exist_ok=True)
        target.parent.mkdir(parents=True, exist_ok=True)
        source.write_text(data, encoding='utf-8')
        shutil.copy2(source, target)
        assert ET.fromstring(data).tag == '{http://www.w3.org/2000/svg}svg'
        assert sha(source) == sha(target)
        svg_records.append({'name':name,'sha256':sha(source),'runtime_path':'res://assets/ui/decoration/v001/icons/'+source.name})
    assets = []
    for source in sorted((ROOT / 'exports').glob('*/*.png')):
        rel = source.relative_to(ROOT / 'exports')
        target = RUNTIME / rel
        assert target.is_file(), f'Missing runtime copy: {target}'
        assert sha(source) == sha(target), f'Copy differs: {rel}'
        with Image.open(source) as im:
            assert im.mode == 'RGBA', f'Not RGBA: {rel}: {im.mode}'
            alpha = im.getchannel('A')
            histogram = alpha.histogram()
            assert histogram[0] > 0, f'No transparent pixels: {rel}'
            assert sum(histogram[5:]) > 0, f'Empty image: {rel}'
            bbox = alpha.point(lambda a: 255 if a > 4 else 0).getbbox()
            x0,y0,x1,y1 = bbox
            pad = 8
            ax0,ay0 = max(0,x0-pad),max(0,y0-pad)
            ax1,ay1 = min(im.width,x1+pad),min(im.height,y1+pad)
            entry = {
                'id': f'decoration.{rel.parent.name}.{source.stem}',
                'label_zh_for_handoff_only': NAMES.get(source.stem,source.stem),
                'source_path': source.relative_to(PROJECT).as_posix(),
                'runtime_path': 'res://assets/ui/decoration/v001/'+rel.as_posix(),
                'size_px': list(im.size), 'mode': im.mode,
                'alpha_gt_4_bbox_xywh': [x0,y0,x1-x0,y1-y0],
                'atlas_region_xywh': [ax0,ay0,ax1-ax0,ay1-ay0],
                'transparent_pixel_fraction': round(histogram[0]/(im.width*im.height),6),
                'center_alpha': alpha.getpixel((im.width//2,im.height//2)),
                'sha256': sha(source),
                'furniture_definition_id': MAPPING.get(source.stem),
                'status': 'current_catalog_thumbnail_candidate' if source.stem in MAPPING else ('future_visual_only' if rel.parent.name == 'thumbnails' else 'ui_art_ready_for_integration'),
            }
            if source.stem == 'item_selected':
                assert entry['center_alpha'] == 0, 'Selection overlay center must be transparent'
            assets.append(entry)
    expected={'catalog_panel','item_slot','item_selected','button_primary','button_secondary','mode_banner','tab_button','leaf_corner','barrel','scroll_bin','supply_crate','storage_chest','chair_oak','bookshelf_potions','potted_fern','rug_crimson','wall_lantern'}
    assert {a['id'].split('.')[-1] for a in assets} == expected, 'Incomplete or unexpected asset set'
    manifest = {
        'schema_version': 1, 'asset_pack_version': 'decoration_v001',
        'purpose': 'Art handoff manifest only; not a gameplay content schema or runtime JSON source',
        'reference': 'reference/decoration_reference.png',
        'integration_status': 'Artwork delivered; Godot UI integration and acceptance owned by 写godot具体代码',
        'assets': assets,
        'vector_icons': list(ICON_PATHS),
        'reuse_existing_icons': ['res://assets/ui/foliage/leaf.svg', 'res://assets/ui/foliage/lamp.svg', 'res://assets/ui/foliage/coin.svg', 'res://assets/ui/foliage/bag.svg'],
        'current_furniture_mapping': {v: 'res://assets/ui/decoration/v001/thumbnails/'+k+'.png' for k,v in MAPPING.items()},
    }
    (ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (ROOT/'reports/asset_validation.json').write_text(json.dumps({'png_count':len(assets),'svg_count':len(ICON_PATHS),'all_rgba':True,'all_runtime_copies_sha256_match':True,'svg_xml_valid':True,'html_browser_validation':'not_run_local_URL_security_block','godot_integration_validation':'pending_code_task','assets':assets,'svg_assets':svg_records},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    cards = []
    for a in assets:
        rel = a['runtime_path'].split('/v001/',1)[1]
        status = '已存在家具 · '+str(a['furniture_definition_id']) if a['furniture_definition_id'] else ('备用缩略图 · 尚未配置为可摆放家具' if a['status']=='future_visual_only' else '独立 UI 组件')
        cards.append(f'<article><a class="art" href="../exports/{rel}" target="_blank"><img src="../exports/{rel}" loading="lazy"></a><h3>{html.escape(a["label_zh_for_handoff_only"])}</h3><code>{rel}</code><p>{status}</p><small>{a["size_px"][0]} × {a["size_px"][1]} · RGBA</small></article>')
    icons=''.join(f'<div><img src="../exports/icons/{n}.svg"><small>{n}</small></div>' for n in ICON_PATHS)
    gallery = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>店铺装修 UI · 素材交付 v001</title><style>*{box-sizing:border-box}body{margin:0;background:#0a1713;color:#eadfbd;font:16px/1.5 "Microsoft YaHei",sans-serif}header,main{max-width:1450px;margin:auto;padding:28px}header{border-bottom:1px solid #8c7649}h1{font-family:serif;font-size:36px;margin:8px 0}p,small{color:#b5b7a1}a{color:#ebd3a0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(235px,1fr));gap:20px}article{border:1px solid #455b46;border-radius:12px;overflow:hidden;background:#12221c;padding:12px}.art{height:225px;display:flex;align-items:center;justify-content:center;background:repeating-conic-gradient(#28342b 0% 25%,#213026 0% 50%) 50%/24px 24px;border-radius:8px}.art img{max-width:100%;max-height:100%;object-fit:contain}h3{font-size:18px;margin:10px 0 4px}code{font-size:12px;overflow-wrap:anywhere}article p{font-size:13px;margin:6px 0}small{font-size:12px}.icons{display:flex;flex-wrap:wrap;gap:22px}.icons div{width:105px;text-align:center}.icons img{display:block;width:64px;height:64px;margin:auto}button{background:#244537;color:#eadfbd;border:1px solid #c2aa72;border-radius:5px;padding:8px 20px;cursor:pointer}</style><header><small>小熊猫的小店 / ART HANDOFF</small><h1>店铺装修 · 树叶主题素材 v001</h1><p>可拼装透明 PNG · 无烘焙文字 · 独立家具图标 · 本页是素材浏览器，不是 Godot 实机截图。</p><p><a href="layout_preview.html">查看拼装示意 →</a>　<a href="../README.md">接入说明</a>　<a href="../manifest.json">像素尺寸与透明区域清单</a></p><button onclick="document.querySelectorAll('.art').forEach(x=>x.style.background=this.dataset.light==='1'?'#18241e':'#dedacb');this.dataset.light=this.dataset.light==='1'?'0':'1'">切换深 / 浅底检查透明边缘</button></header><main><div class="grid">'''+''.join(cards)+'''</div><h2>独立操作图标（SVG）</h2><div class="icons">'''+icons+'''</div><p>分类树叶、灯笼、金币沿用项目既有 foliage 图标；图中的名称与库存由游戏数据生成。备用缩略图不代表新增家具规则或模型。</p></main></html>'''
    (ROOT/'previews/index.html').write_text(gallery,encoding='utf-8')
    template=(ROOT/'generation/layout_template.html').read_text(encoding='utf-8')
    (ROOT/'previews/layout_preview.html').write_text(template.replace('__ASSETS__',json.dumps(assets,ensure_ascii=False)),encoding='utf-8')
    print(json.dumps({'png_count':len(assets),'svg_count':len(ICON_PATHS),'manifest':str(ROOT/'manifest.json')},ensure_ascii=False))

if __name__ == '__main__':
    main()
