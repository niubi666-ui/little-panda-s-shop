from pathlib import Path
import shutil,json,hashlib,xml.etree.ElementTree as ET
from PIL import Image
R=Path('E:/ShopGame'); B=R/'source_assets/ui/settings/v002'; O=R/'source_assets/ui/settings/v001'; G=Path('C:/Users/陈旭辉/.codex/generated_images/01a0dbbb-e5a8-7b32-a068-ebcadcf5d960'); RUN=R/'game/assets/ui/settings/v002'
for d in ['reference','exports/chrome','exports/icons','previews','reports']:(B/d).mkdir(parents=True,exist_ok=True)
sources={}
for src in (O/'exports').rglob('*'):
    if src.is_file():
        dst=B/'exports'/src.relative_to(O/'exports');shutil.copy2(src,dst);sources[str(dst.relative_to(B/'exports'))]=str(src)
shutil.copy2(G/'exec-98d00bfb-bc8a-4570-ad32-241ff325ddc4.png',B/'reference/settings_full_concept.png')
for name,raw in [('slider_track','exec-dfdb083c-1829-40f4-9bfa-1d133a62a134.png'),('slider_thumb','exec-26a6a976-30e1-4332-813d-18645e829392.png'),('button_exit','exec-e98213bc-189a-48aa-a1c3-0283b03be299.png')]:
    dst=B/'exports/chrome'/f'{name}.png';shutil.copy2(G/raw,dst);sources[str(dst.relative_to(B/'exports'))]=str(G/raw)
icons={
'check':'<path d="m12 32 13 13 28-29"/>',
'chevron_down':'<path d="m15 25 17 17 17-17"/>',
'monitor':'<rect x="7" y="9" width="50" height="35" rx="3"/><path d="M32 44v11 M20 56h24"/>',
'gamepad':'<path d="M16 18h32q5 0 7 8l4 21q1 11-7 6L41 43H23L12 53q-8 5-7-6l4-21q2-8 7-8Z M16 30h14 M23 23v14"/><circle cx="43" cy="28" r="2"/><circle cx="50" cy="35" r="2"/>',
'save':'<path d="M9 7h38l8 8v42H9Z M19 7v20h26V7 M19 57V36h26v21 M38 12v10"/>',
'load':'<path d="M8 16h19l6 7h23v31H8Z M32 7v29 m-8-8 8 8 8-8"/>',
'exit':'<path d="M32 8H10v48h22 M35 32h23 m-9-10 10 10-10 10 M22 8v48"/>',
'speaker':'<path d="M9 25h12L35 13v38L21 39H9Z M43 23q9 9 0 18 M49 16q17 16 0 32"/>'}
for name,body in icons.items():
    dst=B/'exports/icons'/f'{name}.svg';dst.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><g fill="none" stroke="#e3ce98" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">'+body+'</g></svg>',encoding='utf-8');sources[str(dst.relative_to(B/'exports'))]='New project-native SVG matching foliage palette'
for name,w,h,body in [
('slider_fill',512,16,'<defs><linearGradient id="fill" x2="0" y2="1"><stop stop-color="#9fba65"/><stop offset="1" stop-color="#345239"/></linearGradient></defs><rect x="0" y="0" width="512" height="16" rx="8" fill="url(#fill)"/>'),
('save_slot',800,140,'<rect x="2" y="2" width="796" height="136" rx="6" fill="#152a20" stroke="#ad965a" stroke-width="2"/><path d="M14 24V14h16 M770 14h16v10 M14 116v10h16 M770 126h16v-10" fill="none" stroke="#d0ba7b" stroke-width="2"/>')]:
    dst=B/'exports/icons'/f'{name}.svg';dst.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>',encoding='utf-8');sources[str(dst.relative_to(B/'exports'))]='New project-native SVG supplement'
assets=[]
for src in sorted((B/'exports').rglob('*')):
    if not src.is_file():continue
    rel=src.relative_to(B/'exports');dst=RUN/rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
    a={'file':rel.as_posix(),'origin':sources[str(rel)],'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'runtime':'res://assets/ui/settings/v002/'+rel.as_posix()}
    assert src.read_bytes()==dst.read_bytes()
    if src.suffix=='.png':
        im=Image.open(src);assert im.mode=='RGBA';alpha=im.getchannel('A');assert alpha.getextrema()[0]==0
        x,y,x1,y1=alpha.getbbox();a.update(size=list(im.size),atlas_region_xywh=[x,y,x1-x,y1-y],transparent=True)
    else:ET.parse(src)
    assets.append(a)
(B/'manifest.json').write_text(json.dumps({'stage':'full settings art proposal, no engine logic implemented','assets':assets},ensure_ascii=False,indent=2),encoding='utf-8')
report={'png_count':sum('size' in a for a in assets),'svg_count':sum('size' not in a for a in assets),'all_png_rgba_transparent':True,'all_svg_valid_xml':True,'runtime_copies_match':True,'pixel_edits':False,'godot_integration_tested':False}
(B/'reports/asset_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
cards=''.join(f'<figure><div class="checker"><img src="../exports/{a["file"]}"></div><figcaption>{a["file"]}</figcaption></figure>' for a in assets)
(B/'previews/index.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>完整设置 UI v002</title><style>body{background:#15241d;color:#eee1c0;font:16px system-ui;padding:28px}h1{font-size:28px}.hero{width:100%;max-width:1400px}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:20px}figure{margin:0}.checker{height:190px;display:grid;place-items:center;background:repeating-conic-gradient(#747474 0% 25%,#505050 0% 50%) 0/24px 24px}.checker img{max-height:180px;max-width:96%}figcaption{padding:12px}a{color:#dfc580}</style><h1>完整设置／暂停菜单 · 树叶风格 v002</h1><p>综合设置、画面、操作与按键、存档管理。以下是美术方案，尚未接入游戏。</p><img class="hero" src="../reference/settings_full_concept.png"><h2>独立无字组件</h2><div class="grid">'+cards+'</div></html>',encoding='utf-8')
print(json.dumps(report))
