# 精灵游侠金色箭术特效 v001

2026-10-06。单发箭、五重散射和三轮箭雨均已应用于当前精英游侠。当前接口、玩法与验证见[游侠模块](../../../docs/ELITE_RANGER.md)。

## 文件与权威来源

- `ranger_arrow_v001.blend`：本轮制作的实体箭头、箭杆、羽翎源模型，292三角形。
- `build_arrow.py`、`arrow_report.json`：可复现Blender导出与拓扑报告。
- `game/assets/vfx/elite_ranger_v001/ranger_arrow.glb`：运行模型。
- `game/presentation/combat/fx/elite_ranger_v001/profile.tres`和三个爆发Resource：当前表现参数权威。材质控制颜色、HDR强度和透明度；代码采样已提交事实。
- `game/presentation/combat/enemies/ranger_style.tres`：箭杆基准宽/长、落箭数量/高度/时间以及profile引用。
- `game/data/enemies/roles.json`：现有速度、招式范围、伤害、前后摇与脉冲规则权威。
- [已确认概念图](../../../concepts/vfx/elite_ranger_v001/generation_manifest.json)为外观参考；实机预览为`previews/`。

## 编辑与再导出

在独立后台Blender运行源脚本导出实体箭：

```powershell
& 'E:/blender/blender.exe' --background --factory-startup --python 'E:/ShopGame/source_assets/vfx/elite_ranger_v001/build_arrow.py'
```

调整颜色、尾迹、粒子、冲击层次时编辑对应Godot Resource，并重新开始训练。`build_arrow.py`负责几何源资产；运行表现Resource独立维护。

真实训练场预览使用`capture_training.gd`逐招采样逻辑时间与骨骼姿态，原帧保存到`builds/ranger_vfx_capture_v001/`，用`encode_preview.py`编码。当前合并视频7.43秒、223帧、1280×800/30fps；它是逐招触发的实际Godot演示。自然AI战斗另由`ranger_integration.gd`完成16秒验证。

## 当前检查

游侠规则36项、特效39项、普通敌人360份计划回归与真实Forward+集成33项通过。来源替换、暂停、关闭表现后的伤害一致、最后一轮箭雨及余辉回收均有针对性验证。现有图形退出资源警告仍存在；人工手感和长期多游侠性能待实际试玩。
