# 逐光 · 蓄力箭：独立 Godot 美术样机

2026-10-07。本目录保留已认可的独立演示工程与资产快照。用户后续授权后，技能已接入主游戏精灵游侠：直接箭50伤害，裂隙每0.5秒8伤害。主游戏唯一规则来源为 `game/data/enemies/roles.json`，本目录样机JSON保持原演示数值，不是游戏权威配置。

运行项目→店铺F6→训练工具→刷新精英游侠。主游戏接口与当前验证见 `docs/ELITE_RANGER.md`；运行表现资源为 `game/presentation/combat/fx/charged_arrow_v001/`。`export_to_game.py`复制认可美术并剔除样机UI/角色模型引用；状态适配、多开口材质和战斗规则单独维护，不从样机生成。

## 观看与操作

- 双击本目录的 `启动蓄力箭演示.cmd`。
- 也可以在 Godot 打开 `godot_demo/project.godot`，运行主场景。
- 按钮：站立测试、射出后侧移、锁向后闪避、踩入裂隙、手动测试。
- 手动模式：WASD 移动，Shift 闪避；R 重新蓄力，P 暂停，L 切换中英文，Esc 关闭这个演示。
- 慢放开关为 0.2 倍逻辑时间，用于观察极速光箭和短暂尾迹。
- `previews/charged_arrow_godot.mp4`：实际 Godot Forward+ 固定步长录制，包含正常速度、明确标注的慢放、侧移、闪避和裂隙伤害演示。
- `previews/charge.png`、`release.png`、`scar.png` 为实际渲染的精选帧；`ui_en.png` 为英文界面检查。

## 当前外观

1. **蓄力**：精灵采样真实拉弓/瞄准动作；弓口出现旋转符环、汇聚光丝、金色碎光与局部照明。
2. **射出**：加长的发光箭、金白亮芯、金色外晕、缠绕细丝、短促释放环和命中闪光。弹速固定，连续扫掠检测不会因速度过快穿过测试角色。
3. **裂隙**：根据最新反馈加宽开口，采用非周期轮廓、两端收尖、不对称崩边和四处分叉状石片。裂隙内壁深 1.15 米，光源埋在地面下 0.35 米。地砖、基础层、下方地形和薄水面共享同一轮廓裁切，避免底层遮住裂隙内部。边缘不再是完整、凸起的连续镶边。
4. **向上透光**：两层弯曲光雾使用二维多频噪声及流动扭曲，形成强弱错落的光团和暗部间隔；去掉密集正弦细条。承载几何高度约 1.9–3.5 米，透明度随高度消退，实际可见高度随噪声变化。内壁仅留不规则微弱发光纹，上升碎光和局部照明保留，脉冲按伤害节奏轻微加亮。
5. **消散**：测试伤害结束后保留有限余辉；裂口逐渐闭合并还原演示地砖。当前属于视觉开口，演示角色仍在平面上移动。

## 配置与代码边界

| 文件 | 职责 |
|---|---|
| `godot_demo/data/demo_rules.json` | 样机的蓄力、锁向、固定弹速、射程、测试伤害、裂隙有效范围与 0.5 秒伤害间隔、测试移动与闪避 |
| `godot_demo/rules.gd` | 单独的只读定义与测试时间线、相对连续扫掠、周期伤害；不加载主项目战斗类 |
| `godot_demo/fx/profile.tres` | 箭尺寸、尾迹、蓄力层次、裂隙深度/锯齿、光束高度、碎光、声音、镜头和资源引用 |
| `godot_demo/fx/*.tres` / `*.gdshader` | 材质、颜色与亮度；时间参数由样机显式推进，不使用 Shader TIME 计时 |
| `godot_demo/fx/lightseeker.gd` | 消费已提交发射/伤害事实和只读规则状态；可关闭，不能判定或施加伤害 |
| `godot_demo/fx/rift.gd` | 独立裂隙几何、分叉、光雾与共享轮廓纹理；开口被限制在配置的测试危险带内 |
| `godot_demo/fx/rift_cut.gdshaderinc` | 各地面层共用的裂隙裁切；采样与几何完全相同的 160 点轮廓纹理 |
| `godot_demo/courtyard_surfaces.gd` | 演示用静态表面适配与开口，还原时恢复地砖；没有遭遇/房间逻辑依赖 |
| `godot_demo/ui.tscn` / `ui_theme.tres` | 界面布局与风格 Resource |
| `godot_demo/data/text.json` | 中英文界面文案与命名参数 |

样机数值仅用于验证这个技能：蓄力 2.4 秒、弹速 160 米/秒、射程 12.5 米、裂隙有效 6 秒。本轮为容纳更宽裂口，将样机危险带半宽从 0.56 米调整为 1.15 米；规则危险带为直线带状，视觉裂口宽窄变化并处于其内部，外侧金线标识规则边界，石片分叉不会改变伤害判定。末段只锁向很短时间；以当前移动速度和受击半径，在测试射程内，锁向后再侧移的距离不足以离开箭路，及时闪避可以避免箭伤。射程和弹速不按目标距离改变。

裂隙伤害采用固定全局脉冲：发射后每 0.5 秒检查一次当前占据危险带的测试角色，首次在 0.5 秒，退出危险带不受伤；不因重新进入重置脉冲。6 秒到期后停止伤害，余辉仅作表现。箭穿过测试角色并继续完成演示射程。

独立样机没有主项目接口。主游戏接入另外实现了世界阻挡、相对扫掠、来源清理、有界多区域与暂停；仍未接正式精英池、持久化或玩家Build派生。主观难度与长期性能仍需试玩，不能用本页历史样机验证替代当前主游戏验证。

## 重建与录制

`build_demo.py` 只写本目录：复制现有 GLB/字体到忽略入库的 `godot_demo/assets/`，生成表现 Resource、界面与原创临时声音。参数调整后优先编辑相应 Resource；重跑生成器会重新生成其管理的文件。

```powershell
& 'C:/Users/陈旭辉/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' 'E:/ShopGame/source_assets/vfx/charged_arrow_v001/build_demo.py'
& 'E:/GoDot/Godot_v4.7.2-stable_win64/Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path 'E:/ShopGame/source_assets/vfx/charged_arrow_v001/godot_demo' --quit
```

`godot_demo/capture.gd` 在独立后台进程中录制真实渲染帧；原帧在 `builds/charged_arrow_v001_frames/`，不在正式游戏项目内。离屏窗口使用显式 `RenderingServer.force_draw`，避免依赖桌面窗口是否可见。`encode_preview.py` 编码这些帧，按实际模拟事件混合本目录原创临时音效。

## 验证记录

- `check_rules.gd` 本轮在加宽危险带后 **29 项通过**（`builds/charged_arrow_rift_v2_rules.log`）：高速扫掠、固定半秒脉冲、站立/侧移/闪避、进入/离开、到期、锁向、暂停、闪避冷却、粗时间步一致，以及最大射程内侧移距离约束。
- 本轮图形录制 **14 项检查通过**：原有宽度、脉冲、暂停、表现隔离、闪避、深度、光雾、边界与布局检查，加上基础层/地形裁切、全部地面共享轮廓、160 个采样点与几何一致。记录在 `previews/capture_report.json`；日志在 `builds/charged_arrow_rift_v2_movie.log`。
- 本轮视频 `previews/charged_arrow_rift_v2.mp4` 已逐帧解码验证（772 帧）：约 **25.7 秒、1280×800、30fps**。包含正常速度和明确标注的 0.2 倍慢放；记录在 `previews/video_report.json`。
- 图形退出仍出现既有的 **7 个 Texture RID 警告**；未做释放专项修复。未做长期性能或正式多敌战斗验收。

未生成 Release，未提交或推送 Git。
