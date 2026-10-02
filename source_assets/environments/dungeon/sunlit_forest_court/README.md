# 日照林庭 · v001

用户选中的参考是 [日照林庭概念图](../../../../concepts/combat_rooms/v003/01_sunlit_forest_court.png)，本目录保存对应的 **Blender 原生美术源场景**。

## 打开与查看

- 可编辑工程：[sunlit_forest_court_art_v001.blend](blender/sunlit_forest_court_art_v001.blend)
- 制作参考：[sunlit_forest_court_target.png](reference/sunlit_forest_court_target.png)
- 已输出全景渲染：[sunlit_forest_court_v001.png](previews/sunlit_forest_court_v001.png)，1920 × 1080。
- 已输出细节渲染：[sunlit_forest_court_v001_detail.png](previews/sunlit_forest_court_v001_detail.png)，1600 × 1000。
- 验证记录：[validation_v001.json](reports/validation_v001.json)；源工程重新打开及文件、几何、贴图检查未报告失败。上述图片是 Blender 美术预览，`_draft` 文件仅用于过程检查。

## 场景内容

- 大面积石板庭院，中央叶纹镶嵌，近景连续地面；中心保留清楚的移动空间。
- 后左延伸小径和后右宽石拱门，低石栏、方柱、石压顶及独立台阶。
- 层叠神龛、凹入拱龛、楣饰、台座及披风守护者雕像。
- 森林绿金纹旗帜、黄铜灯笼、连续栏脚花草、蕨类、常春藤、乔木与外围地被。
- 斜照日光、冷色天空补光、轻薄气氛及少量边缘浅水反光。

建筑、地面、装饰、植物、灯光、相机、气氛与替换模型按集合组织，未合并成单个场景网格。可以在 Blender 直接继续精修；源脚本为 [build_sunlit_court_v001.py](scripts/build_sunlit_court_v001.py)，共享构件和植物脚本位于 [shared/scripts](../shared/scripts/)。重新生成前请另存手工修改过的版本。

## 替换守护者雕像

集合：`Replacement_Props`。锚点：`REPLACE_ANCHOR_prop.forest_keeper_statue`。

披风、兜帽、脸、手臂及持物是独立可编辑形体，子物件带有替换标记。当前雕塑属于轮廓与摆放版本，细节未达到概念图雕刻精度；后续可导入 Tripo 模型，用锚点下的新模型替换这组子物件。保留锚点变换、台座、神龛、灯光和周围藤蔓，避免移动整个建筑。

## 材质与后续使用

两套 Poly Haven 2K CC0 贴图为 `worn_rock_natural_01` 与 `leafy_grass`，详见 [来源记录](../shared/reports/material_sources.json)。工程已打包两套材质使用的六张基础色/粗糙度/法线图片；具体记录见验证报告。

这份 `.blend` 可继续编辑，但尚未导出、接入 Godot 或确认运行性能。程序材质、叶片透光、浅水、体积雾与光照不能假设跨引擎一致，需要重建或烘焙。正式游戏碰撞、导航、出口和性能优化仍需单独制作与验收。

详细布局意图见 [layout_notes.md](reports/layout_notes.md)；构建统计与日志保留在 `reports/`。
