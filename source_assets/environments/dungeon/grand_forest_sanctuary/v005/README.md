# 古树圣庭 v005 · 布局修订评审版

日期：2026-10-03。实际 Blender 场景与 Cycles 渲染，等待用户美术评审。

## 打开文件

- 工程：[grand_forest_sanctuary_v005_layout.blend](blender/grand_forest_sanctuary_v005_layout.blend)
- 三张实际渲染：[图集](previews/index.html)
- 本轮用户参考图及红框：[reference](reference/)
- 可重现的修改参数：[layout_profile.json](scripts/layout_profile.json)

## 已修改

1. 东门双柱整体转向 60°并重新定位，道路从两柱之间延伸。两柱中心距 6.8 m；接回北侧及东侧低墙，清理通道花草。
2. 隐藏古树旁西侧护栏、上路旁旧墙及旧直线道路。保留树根本体，扩大古树体量，改成根部南北两侧绕行的两条西路。
3. 古树位置为 `(-15, 9, -0.08)`；父级缩放为 `(1.848, 1.848, 1.68)`；实测树干高度约 16.8 m。三处地面纹章和原约 1.2 m 主角参照保留。
4. 神龛、神像、台阶、藤蔓、供盆及原灯整体转向 −12°。主镜头改为斜看，露出建筑侧面。
5. 台阶前左右增加青铜火盆、程序体积火焰和暖色点光，火光有轻微变化。
6. 12 棵外围树及其全部后代在视口、渲染中隐藏，源对象仍保留。本轮以核心布局评审为主。
7. 原风动花草随建筑迁移后重新按朝向、相位分批，蕨类和铃花组成部件使用配套变换。古树冠层继续使用原微风节点。

## 实际验证

`reports/validation.json` 的 8 项检查已通过：来源文件哈希、外围树隐藏、树侧旧墙隐藏、双柱变换与间距、神龛整体变换、主角比例、树干共享网格、两条西路中心线的树根交叉检查。

路线检查范围为中心线上方 0.15–1.5 m 与树干/树根表面的相交；没有认证完整路线宽度、其他障碍碰撞或 Godot 导航。

三个镜头均为当前保存的 v005 工程实际渲染：

- `Camera_Panorama` → `previews/sanctuary_v005_overview.png`
- `Camera_V005_Root_Routes` → `previews/sanctuary_v005_root_routes.png`
- `Camera_V005_Shrine_Gateway` → `previews/sanctuary_v005_shrine_gateway.png`

Cycles / OptiX，最多 96 采样，自适应阈值 0.025，降噪。图片没有生成式修图。

## 保存与范围

v004 原工程保持原样，哈希记录在 `reports/layout_revision.json` 和 `reports/validation.json`。本轮所有输出均在此 v005 目录。树干、树冠、建筑及植物仍复用原网格；新路与庭院交界处少量铺地做独立裁切，以避免叠面。

只在独立 Blender 后台进程修改和渲染，没有操作已打开的 Blender 窗口，没有修改 Godot、导出游戏模型或提交 Git。

打开工程后默认是全景镜头。时间轴空格播放微风；火焰完整效果请用 Cycles 渲染视图或 F12 查看。体积火焰为本轮 Blender 评审表现，未来接入 Godot 时需对应的实时特效。
