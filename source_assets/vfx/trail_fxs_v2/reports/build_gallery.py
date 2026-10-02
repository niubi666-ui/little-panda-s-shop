from pathlib import Path
import html,json
root=Path(__file__).resolve().parents[1]
images=next((root/'original').rglob('Images'))
groups={
 '01 刀光材质 · 30 款':[p for p in sorted(images.glob('*.jpg')) if p.stem.startswith('M_Trail_Blade_')],
 '02 刀光、火焰、烟雾与液体':[p for p in sorted(images.glob('*.jpg')) if p.stem.startswith('Trail_Blade')],
 '03 基础线条、管状与粒子拖尾':[p for p in sorted(images.glob('*.jpg')) if not p.stem.startswith(('M_Trail_Blade_','Trail_Blade'))],
}
cards=[]; records=[]
for group, paths in groups.items():
    cards.append(f'<h2>{html.escape(group)}</h2><section>')
    for path in paths:
        src='../'+path.relative_to(root).as_posix()
        cards.append(f'<a class="card" href="{html.escape(src)}" target="_blank"><img loading="lazy" src="{html.escape(src)}"><span>{html.escape(path.stem)}</span></a>')
        records.append({'name':path.stem,'group':group,'file':path.relative_to(root).as_posix()})
    cards.append('</section>')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Trail FXs v2 预设图册</title><style>
body{margin:0;padding:36px;background:#131720;color:#ebe6dc;font:16px system-ui,sans-serif}main{max-width:1500px;margin:auto}h1{font-size:32px}p{color:#b8b9c0;line-height:1.7}h2{margin-top:48px;font-size:23px}section{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:20px}.card{display:block;background:#222733;border-radius:12px;overflow:hidden;color:#fff;text-decoration:none;border:1px solid #3b414e}.card:hover{border-color:#e1b56f}.card img{width:100%;aspect-ratio:1;object-fit:contain;display:block}.card span{display:block;padding:14px;font-size:14px;overflow-wrap:anywhere}</style><main><h1>Trail FXs v2 · 预设图册</h1><p>原资产包附带的预览图片，未经重新绘制。点击可打开原图。图片展示供应方预设效果，不是本项目 Godot 实机截图。下方名称对应原资源名称。</p>'''+''.join(cards)+'</main></html>'
(root/'previews/index.html').write_text(page,encoding='utf-8')
(root/'reports/preview_index.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({g:len(p) for g,p in groups.items()},ensure_ascii=False))
