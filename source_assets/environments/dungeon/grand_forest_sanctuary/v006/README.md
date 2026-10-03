# 古树圣庭 v006 · 暖光与林冠叶影

日期：2026-10-03。Blender 美术光照评审版，等待用户评审。

## 打开与查看

- 工程：[grand_forest_sanctuary_v006_golden_canopy.blend](blender/grand_forest_sanctuary_v006_golden_canopy.blend)
- 实际渲染及同镜头对比：[图集](previews/index.html)
- 用户的概念参考与原版截图：[reference](reference/)
- 制作参数：[lighting_profile.json](scripts/lighting_profile.json)

打开工程默认使用 EEVEE、场景世界与场景灯光、全景相机，关闭视口叠加线。若切换了显示模式，请回到“渲染”视图；材质预览中的工作室环境不能用于判断本轮光照。小键盘 0 回到相机视图。

沿用原微风时间轴，空格播放。此轮检查了微风节点和修改器的保留情况，没有重新制作或认证动画视频。Cycles 正式渲染与 EEVEE 预览存在渲染方式差异，图集分别提供两者。

## 本轮美术调整

1. 降低均匀天空环境光和冷色补光，调整太阳方向、暖色直射与曝光，使阴影和受光区有更明显的差别。
2. 重做头顶投影辅助物体：较高的叶团形成柔影，较低的枝叶簇形成较清楚的阴影；较高叶团使用程序透明孔隙，让阳光能从叶团中漏到地面。它们不在相机画面中显示。
3. 调整古树冠、蕨类及原有花草的粗糙度、反射和透光混合，让受光面与边缘更亮，同时保留阴影里的绿色。没有给植物添加自发光。
4. 调整石材色彩和地面粗糙度；地面纹章使用更高的粗糙度，避免大面积反光覆盖图案。
5. 增加两侧植被的暖色受光补光，调整古树反射光和轮廓光，保留神龛前火光。使用轻微体积空气与高光辉光。

参考图是概念图；本轮交付的预览来自实际 Blender 渲染，没有生成式修图。外围森林仍隐藏，因此尚未表现完整森林包围庭院的景观。

## 投影辅助几何

| 项目 | 三角面 |
| --- | ---: |
| 原头顶投影辅助物体 | 187,200 |
| 本轮实际使用的两层投影辅助物体 | 36,544 |

仅这部分活动投影几何减少 80.48%。旧物体在新版中保留并隐藏，不参与视口或渲染。数字不代表整个场景面数，也不是 Godot 帧率测试结果。透明投影仍有着色计算成本。

185 组较高叶团、128 组较低枝叶簇，最终合并为两个辅助网格。沿用 `BREEZE_controls` 和共享微风弯曲节点，不需要逐片增加精细叶片模型。

## 实际验证与渲染

[validation.json](reports/validation.json) 的 11 项只读检查通过：

- 原 v005 文件哈希一致，所有源对象仍保留。
- 原网格的顶点坐标、索引与数量一致，原共享网格引用一致。
- 非灯光对象变换一致，原 Geometry Nodes 修改器和节点组引用一致。
- 原头顶遮影物体隐藏，外围树仍隐藏。
- 两个新辅助物体具有微风修改器；三角面数量与制作报告一致。
- 新工程保存了 EEVEE 默认预览设置。

保留了 36 × 32 m 主庭院、约 1.2 m 主角参照、双柱入口、古树根部绕行路线和神龛的 v005 布局。本轮没有重新验证碰撞、完整路线宽度或导航。

正式渲染由 [render_review.py](scripts/render_review.py) 读取保存的 v006 工程，帧 1，最多 96 采样。Cycles 使用 OptiX、自适应采样与降噪。

| 图片 | 相机 | 渲染器 |
| --- | --- | --- |
| `sanctuary_v006_overview.png` | `Camera_Panorama` | Cycles |
| `sanctuary_v006_gameplay.png` | `Camera_Gameplay` | Cycles |
| `sanctuary_v006_shrine_gateway.png` | `Camera_V005_Shrine_Gateway` | Cycles |
| `sanctuary_v006_eevee_gameplay.png` | `Camera_Gameplay` | EEVEE |

实际文件尺寸与耗时见 [render_review.json](reports/render_review.json)。`draft_*` 是调整过程的试渲染，正式评审请看上表文件。

## 制作范围与复现

所有修改由独立 Blender 后台进程完成。v005 工程保留；没有操作其他对话的 Blender / Godot 进程，没有修改 Godot、导出游戏模型、提交 Git 或生成 Release。

`lighting_profile.json` 是本轮制作参数来源；[refine_lighting.py](scripts/refine_lighting.py) 从原 v005 生成新版，正式渲染脚本只读取新版，不保存场景。

```powershell
& 'E:/blender/blender.exe' --factory-startup --background 'E:/ShopGame/source_assets/environments/dungeon/grand_forest_sanctuary/v005/blender/grand_forest_sanctuary_v005_layout.blend' --python-exit-code 1 --python 'E:/ShopGame/source_assets/environments/dungeon/grand_forest_sanctuary/v006/scripts/refine_lighting.py'
& 'E:/blender/blender.exe' --factory-startup --background 'E:/ShopGame/source_assets/environments/dungeon/grand_forest_sanctuary/v006/blender/grand_forest_sanctuary_v006_golden_canopy.blend' --python-exit-code 1 --python 'E:/ShopGame/source_assets/environments/dungeon/grand_forest_sanctuary/v006/scripts/render_review.py'
```
