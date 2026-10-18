from pathlib import Path
import json, hashlib, html
ROOT=Path(__file__).resolve().parents[5]
S=Path(__file__).resolve().parents[1]
manifest=json.loads((S/"generation/prompts_and_sources.json").read_text(encoding="utf-8"))
final=json.loads((S/"generation/final_assets.json").read_text(encoding="utf-8"))
by_id={x["id"]:x for x in final["cards"]}
for record in manifest["cards"]:
    record.update(by_id[record["id"]]);record["status"]="generated"
    asset=S/record["project_file"]
    assert asset.exists() and Path(record["source"]).exists()
    record["sha256"]=hashlib.sha256(asset.read_bytes()).hexdigest()
assert len({r["sha256"] for r in manifest["cards"]})==51
manifest["components"]=final["components"]
(S/"generation/prompts_and_sources.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
data=json.loads((S/"catalog.json").read_text(encoding="utf-8"))
zh=json.loads((ROOT/"game/data/locales/zh_CN.json").read_text(encoding="utf-8"))["messages"]
cats={"martial":"武技与通用强化","fire":"火元素","ice":"冰元素与冰协同","thunder":"雷元素","earth":"土元素","reactions":"双元素反应","training_legacy":"训练与旧版卡"}
rarities={"common":"普通","rare":"稀有","epic":"史诗","legendary":"传说"}
out=['''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>林庭秘契 · 全卡牌原画与独立组件</title>
<style>
*{box-sizing:border-box}body{margin:0;color:#e7e7d3;background:#091612;font:16px/1.75 system-ui}
main{max-width:1500px;padding:32px;margin:auto}h1,h2{font-family:serif;font-weight:500}h1{font-size:34px}
p{color:#afc3b1}a{color:#e5c17c}nav{position:sticky;top:0;background:#0c201aee;padding:12px;z-index:2;display:flex;gap:20px;flex-wrap:wrap}
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:22px}.item{background:#10231b;border:1px solid #324333;border-radius:10px;overflow:hidden}
.item img{width:100%;display:block;aspect-ratio:4/3;object-fit:cover}.meta{padding:12px 18px}.meta h3{margin:0;font-weight:500}
code{font-size:12px;color:#9aa99e}.tag{font-size:12px;padding:2px 8px;border:1px solid #566d57;border-radius:20px;margin-left:8px}
.common{color:#dbe5d5}.rare{color:#75c7ff}.epic{color:#ce9cff}.legendary{color:#fbb55b}
section{padding-top:24px;scroll-margin-top:60px}.full{width:100%;border-radius:10px}.layers{display:grid;grid-template-columns:repeat(5,1fr);gap:16px}
.layers figure{margin:0}.checker{background:repeating-conic-gradient(#20382b 0 25%,#122319 0 50%) 50%/24px 24px}
.layers img{display:block;width:100%;height:300px;object-fit:contain}.layers figcaption{text-align:center}
details{border:1px solid #38533d;padding:12px;border-radius:8px;margin:20px 0}
@media(max-width:800px){.grid{grid-template-columns:repeat(2,1fr)}.layers{grid-template-columns:repeat(3,1fr)}main{padding:16px}}
</style><main><h1>林庭秘契 · 全卡牌原画</h1><p>51 张独立原画 · 4 档透明边框 · 1 张独立植物装饰 · 游戏动态文字</p>
<p>原画按能力分类，品质由选卡数据决定。升级复用原画，卡名、等级、收益与完整规则实时读取配置。</p>
<nav><a href="#runtime">游戏实装</a><a href="#layers">独立组件</a>''']
out+=['<a href="#'+k+'">'+v+'</a>' for k,v in cats.items()]
out+=['</nav><section id="runtime"><h2>Godot 实际界面</h2><img class="full" src="previews/cards_zh_CN_final.png" alt="中文三选一实际截图"><details><summary>英文与游戏实景</summary><img class="full" src="previews/cards_en_final.png"><img class="full" src="previews/in_game_awakening_final.png"><img class="full" src="previews/in_game_reward_final.png"></details><p><a href="previews/validation.json">界面验证报告</a> · <a href="README.txt">替换与归档说明</a> · <a href="generation/prompts_and_sources.json">生成提示词、来源与文件校验</a></p></section>']
out+=['<section id="layers"><h2>组件分层</h2><p>下方 PNG 均为透明图层。边框不包含卡名、效果文案或原画；植物装饰可单独隐藏或替换。</p><div class="layers">']
for r in rarities:
    out.append(f'<figure><a href="frames/{r}.png"><img class="checker" src="frames/{r}.png"></a><figcaption class="{r}">{rarities[r]}边框</figcaption></figure>')
out.append('<figure><a href="ornaments/botanical_body.png"><img class="checker" src="ornaments/botanical_body.png"></a><figcaption>正文植物装饰</figcaption></figure></div></section>')
for cat,title in cats.items():
    cards=[c for c in data["cards"] if c["category"]==cat]
    out.append(f'<section id="{cat}"><h2>{title} · {len(cards)} 张</h2><div class="grid">')
    for c in cards:
        name=html.escape(zh[c["name_key"]]);r=c["rarity"];asset=html.escape(c["image"])
        state="" if c["enabled_in_pool"] else '<span class="tag">训练／未入普通卡池</span>'
        out.append(f'<article class="item"><a href="{asset}"><img loading="lazy" src="{asset}" alt="{name}"></a><div class="meta"><h3>{name}<span class="tag {r}">{rarities[r]}</span>{state}</h3><code>{c["id"]}</code></div></article>')
    out.append('</div></section>')
out.append('<p>内置 image_gen 生成。原始大图保存在本目录；运行时按卡牌 ID 加载 game/assets/ui/build_cards/v001。原画内没有 UI 文字。</p></main></html>')
(S/"index.html").write_text("\n".join(out),encoding="utf-8")
print("Gallery, 51 unique artwork hashes, source provenance ready.")

