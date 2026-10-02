# 清泉回廊 · v001

用户选中的参考是 [清泉回廊概念图](../../../../concepts/combat_rooms/v003/02_springwater_cloister.png)，本目录保存对应的 **Blender 原生美术源场景**。

## 打开与查看

- 可编辑工程：[springwater_cloister_art_v001.blend](blender/springwater_cloister_art_v001.blend)
- 制作参考：[springwater_cloister_target.png](reference/springwater_cloister_target.png)
- 已输出全景渲染：[springwater_cloister_v001.png](previews/springwater_cloister_v001.png)，1920 × 1080。
- 已输出细节渲染：[springwater_cloister_v001_detail.png](previews/springwater_cloister_v001_detail.png)，1600 × 1000。
- 验证记录：[validation_v001.json](reports/validation_v001.json)；源工程重新打开及文件、几何、贴图检查未报告失败。上述图片是 Blender 美术预览，`_draft` 文件仅用于过程检查。

## 场景内容

- 高石拱廊、层叠柱脚、拼砌石柱、附壁细柱与连续檐线。
- 开阔石板地面、中央圆形铺地镶嵌、林地通路与宽台阶，前方地面延续到取景之外。
- 后侧和右侧浅水渠，槽底、石质护岸及分缝均有独立几何；荷叶、芦苇与边缘植物可单独编辑。
- 右后方狮首壁泉、空心石碗、支座、落水、溢流、水滴与涟漪几何。
- 深绿金纹旗、暖灯、白紫花卉、蕨类、常春藤及分层林地背景；自然光、天空补光和薄雾共同组织空间。

建筑、地面、水体细节、装饰、植物、灯光、相机、气氛与替换模型分集合保留。水束和涟漪是此次静态美术场景的几何表现，不表示已经实现实时水流或粒子系统。

源脚本：[build_springwater_cloister_v001.py](scripts/build_springwater_cloister_v001.py)；共享构件和植物脚本位于 [shared/scripts](../shared/scripts/)。可以直接在 Blender 调整模块；重新生成前请另存手工修改过的版本。

## 当前镜头的剖切显示

为使当前斜俯视镜头看清水渠与地面，最前方东侧 `East_Arcade_00` 及其相关子构件，以及对应的 `East_Cornice_Lower_00`、`East_Cornice_Upper_00`，设为 `hide_render=True`。相关物件带有 `preview_cutaway` 属性，完整模型仍保留在工程中。

恢复完整拱廊时，在 Blender Outliner 中显示“渲染可见”相机列，为这些物件及其相关子构件重新启用渲染可见即可。此设置只是本次取景的剖切处理，不是删除模型，也不代表已经实现游戏运行时的遮挡系统。

## 替换狮首泉雕

集合：`Replacement_Props`。锚点：`REPLACE_ANCHOR_lion_head_fountain`。

狮首的鬃毛、眉骨、眼窝、口鼻等形体独立保留，带有 `lion_head_fountain` 替换族标记。当前形体可用于确认尺寸与轮廓，尚未雕刻到概念图精度。后续可用 Tripo 或手工雕刻模型替换锚点下的雕塑子物件，保持锚点位置；壁泉背板、石碗、槽体、落水和周围建筑独立保留。

替换后需要重新对齐嘴部出水位置，检查水束是否与石雕穿插，再复核主镜头轮廓。

## 材质与后续使用

两套 Poly Haven 2K CC0 贴图为 `worn_rock_natural_01` 与 `leafy_grass`，详见 [来源记录](../shared/reports/material_sources.json)。工程已打包两套材质使用的六张基础色/粗糙度/法线图片；具体记录见验证报告。

此次交付是可编辑 Blender 源场景，尚未导出、接入 Godot 或确认运行性能。程序材质、叶片透光、水渠折射、落水、体积雾与光照需要按引擎方案重建或烘焙，不能将 Blender 渲染效果直接视作游戏实机效果。碰撞、导航、出口连接及运行优化仍需单独制作与验收。

详细布局意图见 [layout_notes.md](reports/layout_notes.md)；构建统计与日志保留在 `reports/`。
