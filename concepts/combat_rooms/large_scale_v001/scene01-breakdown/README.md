# 古树圣庭：墙体与植被拆分

内置 imagegen 基于场景1生成的建模参考，未包含板条箱、宝箱。不是已经无缝适配的模型或精确尺寸图。

## 图片索引

四件图按左上、右上、左下、右下读取。

| 文件 | 内容 |
| --- | --- |
| 01-low-wall-basic.png | 直矮墙、90度L角、斜向转角外侧造型、独立端柱 |
| 02-wall-variants.png | 弧形墙、T形连接、破损直墙、石栏杆 |
| 03-high-wall-architecture.png | 高墙面板、开放拱门、高柱、高墙L角 |
| 04-five-plants.png | 上排：蕨类、白花、紫花；下排：低灌木、垂藤，共5种 |
| 05-ground-moss.png | 面状薄苔、长条缝苔、分叉缝苔、低矮苔团 |

## 随机拼接的建模要求

- 先从直段确定统一截面和模数，例如矮墙厚0.4m、高1.2m、直段长2m；这些仅为建模建议，非已确认玩法数据。半长段可从直段派生，用于填补短边。
- L形件应做双面完整造型，旋转后可作为房间内凹或外凸转角。不要依赖负缩放镜像解决法线问题。
- 第一张左下是斜转角的视觉方向，图中透视不能保证45度。请在Blender中精确设定转向45度／内角135度，不能照图随意拉伸角度。
- 弧形墙应校准半径、圆心、弧度和两端切面；T形墙用于分岔隔断，十字交点可由直段与独立中心柱组合。生成图的装饰和端柱有差异，接合端的多余柱头需拆出，统一接口后再使用。
- 端点应设置连接锚点，墙底同高，墙厚和石材分缝一致。先摆放直线、矩形、L形、凹形及弧形测试，再进入随机生成。
- 高墙/拱门与低墙是不同高度层级；门洞净宽须按实际角色与通路需求测量。前景高墙需要遮挡处理，不能挡住战斗视野。
- 破墙图是外观变体，是否可穿越或可破坏另由玩法决定。随机生成后检查入口、出口、宝箱互动点与战斗区域可达性。
- 花草单独建模，底部原点；垂藤原点在悬挂点，和墙体分离，便于随机旋转/替换。每格展示尺度不代表真实相对尺寸。
- 地上大面积薄苔优先按表现需求做贴花或材质遮罩，小苔团才做少量低矮几何。这张苔藓图带光照和背景，只是形态参考，不能当成无缝PBR贴图直接使用。
- 图生3D前单独裁切每件；浅灰背景与投影不要雕刻为底座。植物薄叶、墙体角度和接缝要人工检查。

## 生成提示词

### 图1

Use case stylized-concept. A premium stylized PBR fantasy game modular asset modeling reference sheet based on attached grand forest sanctuary. Cream warm weathered limestone masonry, restrained carved botanical motifs, chipped bevels and believable joints, same high quality as reference. Exactly FOUR separate standalone assets arranged 2x2, uniform slightly elevated three-quarter view, neutral warm gray background, soft studio light, complete silhouettes, broad blank gutters for individual cropping. No labels, text, people, crates, chests, floor tile base, scenery or cast shadow sculpted into object. Walls must NOT have attached plants, vines, flower beds or hanging lanterns, only slight age discoloration. Regular consistent wall thickness, masonry course heights and flat vertical module joining ends across all pieces, plausible bottom plane and distinct geometry; practical components for composing random room outlines. Sheet 1 LOW WALL BASIC KIT. Top left: one plain straight waist-high solid masonry wall span, four stone courses, flat capstones, both ends flat with NO pillars. Top right: one L-shaped 90 degree corner of the SAME waist-high solid wall, two equal short arms, inner corner visible, matching thickness and courses, NO pillar. Bottom left: one 45 degree angled corner of same low wall, two short arms meeting with a clearly gentler 135 degree inside angle, not another right angle. Bottom right: ONE standalone square terminal pier slightly taller than the wall, molded square capital and simple recessed botanical relief, no attached wall or lamp. Pieces should look like one construction set matching low ruined walls of the reference.

### 图2

Use case stylized-concept. A premium stylized PBR fantasy game modular asset modeling reference sheet based on attached grand forest sanctuary. Cream warm weathered limestone masonry, restrained carved botanical motifs, chipped bevels and believable joints, same high quality as reference. Exactly FOUR separate standalone assets arranged 2x2, uniform slightly elevated three-quarter view, neutral warm gray background, soft studio light, complete silhouettes, broad blank gutters for individual cropping. No labels, text, people, crates, chests, floor tile base, scenery or cast shadow sculpted into object. Walls must NOT have attached plants, vines, flower beds or hanging lanterns, only slight age discoloration. Regular consistent wall thickness, masonry course heights and flat vertical module joining ends across all pieces, plausible bottom plane and distinct geometry; practical components for composing random room outlines. Sheet 2 WALL VARIATIONS: top left one quarter-circle CURVED low solid stone wall segment, consistent radial thickness with clean radial-cut ends. Top right one T junction low solid wall module, three short arms meeting at right angles, visible from above enough to read T silhouette. Bottom left one damaged straight low wall span with a shallow broken notch on TOP, intact full-width ground courses, two clean joining ends, no loose rubble. Bottom right one straight waist-high BALUSTRADE segment with small carved stone balusters under solid capstone and continuous plinth, no end pillars. Same limestone module family, four separate assets, do not turn T into L.

### 图3

Use case stylized-concept. A premium stylized PBR fantasy game modular asset modeling reference sheet based on attached grand forest sanctuary. Cream warm weathered limestone masonry, restrained carved botanical motifs, chipped bevels and believable joints, same high quality as reference. Exactly FOUR separate standalone assets arranged 2x2, uniform slightly elevated three-quarter view, neutral warm gray background, soft studio light, complete silhouettes, broad blank gutters for individual cropping. No labels, text, people, crates, chests, floor tile base, scenery or cast shadow sculpted into object. Walls must NOT have attached plants, vines, flower beds or hanging lanterns, only slight age discoloration. Regular consistent wall thickness, masonry course heights and flat vertical module joining ends across all pieces, plausible bottom plane and distinct geometry; practical components for composing random room outlines. Sheet 3 TALL ARCHITECTURE from the sanctuary. Top left: single tall straight solid stone wall panel, rectangular, a recessed shallow pointed-arch panel with restrained leaf relief, clean flat joining ends, no shrine/statue. Top right: one tall freestanding OPEN arched doorway frame with square side piers and carved arch voussoirs, absolutely no door or floor, space under arch fully empty. Bottom left: one standalone tall square column with chamfered shaft, molded capital and base, subtle leaf engraving, no banner. Bottom right: one tall 90-degree L corner wall, two plain matching high-wall arms with continuous cornice, inner corner readable. Match material of low walls but taller architectural kit. No roofs or foliage.

### 图4

Use case stylized-concept. Exactly FIVE isolated plant assets for image-to-3D modeling, matching the attached sunlit fantasy forest sanctuary, detailed stylized PBR natural green leaves and white/lavender blooms. Organized spacious 3 across top, 2 centered below, no overlaps, full plants visible, neutral warm gray studio backdrop, soft even lighting, no text or labels. Top-left: one compact clump of arching woodland fern fronds. Top-centre: one loose clump of tiny white daisy-like wildflowers with delicate green leaves. Top-right: one compact clump of lavender purple bell-shaped wildflowers, taller than white flowers. Bottom-left: one low rounded broadleaf woodland shrub, no flowers. Bottom-right: one hanging ivy spray with 3 trailing strands, intended to attach to a wall but NO wall or mounting pot visible. Roots/bases discreet and small, no soil mound, no landscape base, no pot, no rock, no architecture, no crate or chest. Botanical silhouettes airy and readable, not plastic solid clumps. Individual plants are standalone reusable dressing modules, same game-quality materials.

### 图5

Use case stylized-concept. Exactly FOUR separate GROUND MOSS dressing references for the attached fantasy limestone courtyard, clean 2x2 modeling reference sheet. Neutral warm gray background, full silhouettes with wide gaps, high oblique almost topdown view to show footprint and very low profile. Detailed soft olive/emerald moss texture, tiny natural tufts, feathered irregular edges, subtle color variation. Top-left: one flat irregular roughly oval thin moss carpet patch with torn organic perimeter. Top-right: one long narrow slightly curving thin moss strip suitable along a stone paving seam. Bottom-left: one branching Y-shaped thin moss patch suitable for intersecting paving joints. Bottom-right: one small low cushion moss cluster made of three connected gentle lobes, only a few centimetres thick. Moss only, no stone slabs, no rocks, no dirt pedestal, no grass/flowers/mushrooms, no architecture or containers, no text. Distinct modular surface dressing shapes, not spherical bushes or tall topiary, no deep roots. Studio material reference matching the scene; not a technical texture map or seamless texture.
