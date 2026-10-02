# 森林庭院：随机可交互物概念 v001

使用内置 imagegen，基于已认可的 Blender 庭院实际渲染生成。2026-09-27。

`01-random-props-concept.png` 是摆放与美术概念，不是已修改的 Blender 场景或 Godot 实机。以下均为待讨论方案，不修改当前项目契约。

建议分组：可破坏的木箱、桶、陶罐、朽木；影响走位的苔石、断柱、短残墙；可搜刮的宝箱、背包、药草篮。后续可扩展可采集菌丛、蜂巢、藏物树洞、需钥匙的旧石匣。特殊交互需另行设计，不默认已实现。

随机化建议：制作多个摆放组合，在合法锚点抽取；入口和出口留空，中心保持主要战斗空间，生成后验证通路。一次地牢探索中首次进入房间生成并保存方案，再次回到同一房间不重刷掉落。此规则是本轮建议，等待用户确认。

图中保留神龛、石拱门、中央叶纹、米灰石材、绿金旗帜和森林日照；新增边缘补给箱和陶罐、左后断柱、右侧短墙与石块、后侧宝箱、前侧背包和药草篮。原 Blender 文件未修改。

## 生成提示词

Use case: stylized-concept. Create ONE beautiful wide 16:9 gameplay-environment concept image, based closely on the attached actual Blender forest courtyard render. Input is the reference for exact environment, camera, architecture and material style. Preserve the same high oblique gameplay camera, open cream weathered limestone paved courtyard, central brass three-leaf medallion, shrine and guardian statue at back left, stone arch at back right, low balustrades, ancient oak trees, green-and-gold banners, warm sunlight with cool leafy shadows, peripheral puddles. High-end stylized PBR 3D game visual quality. Add a restrained, plausible randomized encounter dressing example: left edge a small cluster of 3 breakable weathered wooden supply crates, one small barrel and two cracked terracotta pots; near rear left a fallen short stone column and an old mossy stone block forming one obstacle island; on the mid-right off-centre a short L-shaped ruined knee-to-waist-high limestone wall with 2 chunky mossy rocks, with clearly generous walkable routes around BOTH sides; near the rear right balustrade one closed green-and-bronze treasure chest with extremely subtle warm light at the latch; near a left foreground edge a discarded leather travel backpack and herb gathering wicker basket with lavender; one small rotten fallen branch along the edge. Props must be readable at this game camera scale, finely modeled, grounded with accurate contact shadows, harmonize with the existing scene rather than look pasted in. Retain at least 65 percent of the combat floor empty, keep medallion fully visible and clear, all doorways and exits unobstructed, no random junk carpet. Show intact interactable props, no destruction action. No player, enemies, UI, labels, text, diagram panels or watermark. This is a concept of possible prop placement, not a newly implemented Blender render. Match the reference room closely while giving a polished cinematic warm forest atmosphere.
