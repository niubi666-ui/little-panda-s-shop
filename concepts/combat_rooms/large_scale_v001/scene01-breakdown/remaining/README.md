# 场景1剩余环境元素

内置 imagegen 生成的补充建模参考；是根据原场景补全的造型，不是精确多视图或已实现模型。墙体与五种花草、苔藓在上一级目录。本批不包含板条箱、宝箱或角色敌人。

| 图 | 内容 |
| --- | --- |
| 06-ancient-oak.png | 古树整株，含树根、扭曲主干、大枝与树冠 |
| 07-shrine-components.png | 左上空神龛；右上守护者雕像；左下三阶台阶；右下花盆 |
| 08-banner-lanterns-barrel.png | 左上绿金旗；右上柱顶灯；左下壁挂灯与支架；右下木桶 |
| 09-floor-medallion-topdown.png | 六叶放射圆形石质镶嵌纹章，正俯视 |
| 10-paving-ground-details.png | 左上铺地；右上饰边石条；左下小岩石组；右下落叶与细枝 |

## 建模交接

- 古树树干与树冠建议分开处理，避免AI把树冠做成实心疙瘩。正图中不可见的背面和顶部由建模补全；树冠与根系要检查游戏镜头遮挡。
- 神龛图附带两面旗，为生成时补充；需要使用独立旗帜时从神龛模型拆除它们，避免重复。雕像底座和独立台阶不要再叠加多余高底座。空神龛有背板，雕像放在凹槽前。
- 花盆中的花可替换成上批五种花草，不新增固定植物种类。壁挂灯是灯具的组合变体，可复用柱顶灯主体，单独制作支架。灯玻璃、金属和火焰应有独立材质/节点。
- 圆形图案按本张统一六叶与同心环；原场景中被裁切的其他圆章不必重新设计，可复用、旋转。图案嵌入地面齐平，推荐分出石底、绿石镶嵌、铜线材质；也可烘焙到低模。图像含材质与光照，不是已校正无缝PBR贴图。
- 铺地模块平面边界、石缝和尺寸需在Blender校准，图像不保证无缝。右上饰边图生成得较厚，可用于花坛边界；用作可走地面拼花时须压平/改造，不能形成绊脚高坎。
- 小岩石、落叶分别作为独立实例，避免把整组连同灰背景建成一块模型。叶片可用少量几何或透明裁切材质，不宜为每片叶子制作高密度网格。
- 水洼使用独立水面/湿润遮罩，树影来自灯光和树冠，光束来自照明与体积效果；这些不雕刻成实体。外围地形可在Blender/Godot中连续搭建，无需将概念图背景当成底座。

## 提示词

### 1

Use case stylized-concept. Modeling reference for the attached high-quality stylized PBR fantasy forest sanctuary. Faithfully match warm aged cream limestone, bronze, deep forest green cloth and restrained botanical leaf motifs. Neutral warm gray studio background, soft even light, no labels/text/people/crates/treasure chests, no scenic terrain base, no environment or baked scenic shadows. Complete isolated asset silhouettes with generous margins. ONE complete monumental ANCIENT OAK TREE matching huge left-hand tree of scene: massive twisting deeply fissured trunk, gnarled root flares, several strong branching limbs, asymmetrical broad airy crown of small olive-green oak leaves with distinct foliage clusters and visible gaps, believable living old woodland tree not a monster face. Full trunk, roots, branch tips and canopy visible, three-quarter view slightly above, tree fills canvas but has margins. Tree by itself, roots terminate neatly without ground island or surrounding ferns. Detailed bark material and restrained moss on sheltered trunk creases. No pots, rocks or shrine. This is the main ancient tree model reference.

### 2

Use case stylized-concept. Modeling reference for the attached high-quality stylized PBR fantasy forest sanctuary. Faithfully match warm aged cream limestone, bronze, deep forest green cloth and restrained botanical leaf motifs. Neutral warm gray studio background, soft even light, no labels/text/people/crates/treasure chests, no scenic terrain base, no environment or baked scenic shadows. Complete isolated asset silhouettes with generous margins. Exactly FOUR isolated sanctuary furnishing assets in 2x2 grid with wide gutters, slight elevated three-quarter view. Top-left EMPTY tall stone shrine niche shell with carved pointed arch, solid recessed back wall, small cornice, NO statue inside and NO attached stairs, simple flat base. Top-right ONE standing robed woodland guardian stone statue on a modest square plinth, normal adult human proportions, serene hooded face, hands holding a small leafy branch, NO niche or tall backplate. Bottom-left ONE standalone set of three wide shallow cream limestone steps, rectangular, no railings or walls, steps can sit in front of shrine. Bottom-right ONE modest carved round limestone planter with purple flowers and green leaves, matching reference shrine-side pot. Complete separate pieces, should assemble without duplicate statue bases or duplicated steps; no creeping foliage attached to shrine or statue. Style from source scene, clear shapes for 3D modeling.

### 3

Use case stylized-concept. Modeling reference for the attached high-quality stylized PBR fantasy forest sanctuary. Faithfully match warm aged cream limestone, bronze, deep forest green cloth and restrained botanical leaf motifs. Neutral warm gray studio background, soft even light, no labels/text/people/crates/treasure chests, no scenic terrain base, no environment or baked scenic shadows. Complete isolated asset silhouettes with generous margins. FOUR separate isolated props in a spacious 2x2 grid, elevated three-quarter view. Top-left: ONE complete hanging deep forest green long pointed-bottom banner, bronze horizontal mounting rod and two small suspension rings, fine gold trim and a single elegant three-leaf botanical emblem, gentle cloth folds, no wall. Top-right: ONE small squat bronze lantern intended to stand on a stone pillar, glazed sides, sloping roof, small loop on top, visible candle inside, gentle warm flame WITHOUT bloom or glow obscuring geometry, no pillar. Bottom-left: ONE bronze hanging lantern with its short L-shaped decorative wall bracket and hook, glass panes, candle, no wall. Bottom-right: ONE standalone modest weathered wooden barrel with iron hoops, matching side props in scene, no crates or chest. Show full mounting pieces and readable material differences, four standalone assets. No plants or ground base.

### 4

Use case stylized-concept. Modeling reference for the attached high-quality stylized PBR fantasy forest sanctuary. Faithfully match warm aged cream limestone, bronze, deep forest green cloth and restrained botanical leaf motifs. Neutral warm gray studio background, soft even light, no labels/text/people/crates/treasure chests, no scenic terrain base, no environment or baked scenic shadows. Complete isolated asset silhouettes with generous margins. ONE large circular floor medallion, STRICT ORTHOGRAPHIC TOP VIEW looking perfectly vertically down, full circle centered on square canvas with clear margin. Reconstruct the prominent round botanical pavement design from scene: elegant radial rosette of SIX elongated olive-green stone leaves meeting at a small bronze central knot, each leaf delicately outlined in aged bronze, embedded flush into pale limestone paving; two thin concentric bronze rings and narrow segmented stone outer border. Subtle worn surface and hairline cracks but every leaf shape legible. Flat walkable mosaic, NOT a raised pedestal, coin, shield or chunky slab; no visible side thickness or perspective. NO scattered leaves, moss, tree shadows, reflection, lettering, characters or surrounding courtyard. Even neutral illumination. A clear modeling/UV pattern reference, not a ready-made PBR texture.

### 5

Use case stylized-concept. Modeling reference for the attached high-quality stylized PBR fantasy forest sanctuary. Faithfully match warm aged cream limestone, bronze, deep forest green cloth and restrained botanical leaf motifs. Neutral warm gray studio background, soft even light, no labels/text/people/crates/treasure chests, no scenic terrain base, no environment or baked scenic shadows. Complete isolated asset silhouettes with generous margins. Exactly FOUR ground construction/dressing assets in spacious 2x2 sheet, high three-quarter view. Top-left: one square reusable thin limestone paving module assembled from irregular rectangular weathered cream flagstones, tight shallow joints, subtle chipped edges, nearly flat continuous walkable top, no moss/leaves or raised pedestal, thickness very shallow. Top-right: one narrow straight segmented stone edging/curb strip with a shallow incised bronze botanical trim line, same thin paving thickness, clean straight joining ends. Bottom-left: one small cluster of THREE distinct irregular weathered cream limestone rocks, low shapes with very sparse olive moss creases, no attached dirt base. Bottom-right: a sparse loose cluster of fallen oak leaves and two thin short twigs, autumn olive/tan muted colors, all lying flat, no soil patch or terrain slab. No puddles, no painted shadows, no architecture, no crate/chest or barrel. Separate complete silhouettes, room for cropping, detailed model references.
