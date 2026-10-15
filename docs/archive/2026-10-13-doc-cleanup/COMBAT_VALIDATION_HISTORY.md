# 战斗原型历史制作与验证记录

2026-10-13 从当前模块文档移出；以下保留当时表述，不代表当前实现或本轮通过。当前入口见[战斗原型](../../COMBAT_PROTOTYPE.md)。

## 验证

### 霜冠天坠表现原型（2026-10-03）

- 训练“技能特效演示”增加第六项「霜冠天坠」。沿用霜冠裂地的冰晶材质、碎冰、寒雾和冰冠：七段落点从近到远推进，每段主锥及两枚侧锥尖端朝下，从空中加速坠落；末端补五枚冰冠锥。落地时触发闪光、扩散环、碎片与寒雾，随后缩退消散。当前仅表现演示，不造成伤害、冻结或地形碰撞。
- 场景 `game/presentation/combat/fx/frostfall_v001/frostfall.tscn`，局部负Z为推进方向。`frostfall_profile.gd` 扩展冰岩表现Resource，`frostfall_effect.gd` 复用既有碎屑、雾、冲击环采样，仅替换冰锥轨迹并增加尾迹/落地闪光。全部层共享局部可暂停时钟，材质和视觉RNG按实例隔离；支持重播、确定性时间采样及显式/自动清理。
- 冰锥的局部+Y尖端沿下降曲线移动，落地后固定在嵌入点；消散时围绕尖端缩小。坠落尾迹只在空中显示，地面碎屑、雾与闪光从落地时刻开始，不能把视觉落地回调用于正式命中判定。
- 表现参数以 `profile.tres` 和材质为权威。初稿生成器 `source_assets/vfx/frostfall_v001/build_resources.py` 重跑会覆盖本组Resource；模型沿用 `game/assets/vfx/elemental_eruptions_v001/models/`，源文件仍在冰岩源素材目录。
- 六选项改为三列两行Grid，列数来自 `skill_vfx_picker/style.tres.option_columns`，按钮恢复16px字号。可收起、重播、清理、3实例上限及既有模态门禁沿用原接口。
- 独立入口 `启动落冰特效演示.cmd` / `game/presentation/combat/frostfall_showcase/showcase.tscn`，支持空格重播、暂停、慢放、循环和L中英切换。复现录制用 `source_assets/vfx/frostfall_v001/preview_tools/capture_frostfall.ps1` 和 `encode_preview.py`。
- 本次实际验证：资源导入通过；专项轨迹/采样29项和训练集成43项headless检查通过，覆盖向下尖端、近到远落点、撞地前无地面碎屑/雾/闪光、倒放采样、材质/RNG隔离、暂停/销毁、真实按钮点击、六选项与HP/Build隔离。默认庭院Forward+中英各6项边界/按钮检查通过，截图已查看；385个双语key与PO一致。完整180帧Shader图形验收及阶段图已检查，修正了尾迹UV边缘负值导致的异常亮斑。庭院退出仍有已知7个Texture RID警告；正式技能规则、主观手感和完整性能尚未验收。
- 实际渲染预览 `source_assets/vfx/frostfall_v001/previews/final/frostfall_godot.mp4` 为1280×720、30fps、6秒；同目录有 `frostfall_timeline.jpg`。采用固定时间采样，录制帧率不代表实时性能。

### 雷霆裁决表现原型（2026-10-03）

- 训练“技能特效演示”增加第五项「雷霆裁决」。短暂聚能后，中心主雷与三道侧雷错开落下；白蓝雷芯、蓝紫辉光、地面电弧、两层扩散环、电火花、飞石和余雾分层收尾。4.2秒自动结束，目前只演示外观，不造成伤害、眩晕或地形变化。
- 独立入口 `启动雷电特效演示.cmd` / `game/presentation/combat/lightning_showcase/showcase.tscn`，沿用冰岩展示台；支持空格重播、暂停、0.35倍慢放、循环及L中英切换。训练场沿用局部负Z朝向、3实例上限和模态门禁，当前六项布局见上方霜冠天坠段落。
- 场景为 `game/presentation/combat/fx/lightning_verdict_v001/lightning_verdict.tscn`。雷光在Godot中预生成交叉面带及分叉，每道雷预备4种形态，运行时只切换可见形态；电火花/石屑使用MultiMesh。沿用已认可的岩石碎块、冲击环和雾Shader，无需新增高模。
- 全部动态层共享可暂停的局部时钟；支持 `set_time_running`、`set_playback_speed`、`restart`、`seek_visual`、`finish`。可变材质按实例复制，视觉RNG独立，采样不消耗随机流。表现参数以 `.tres` 为权威，初稿生成器 `source_assets/vfx/lightning_verdict_v001/build_resources.py` 重跑会覆盖本组Resource。
- 雷电接入时的实际验证：Godot导入及Forward+完整150帧渲染通过；headless专项51项通过，覆盖确定性倒放采样、材质/随机隔离、暂停恢复、自动/显式销毁、实际按钮点击、既有四选项、HP/Build隔离及模态门禁。默认庭院中英各6项检查通过，使用真实Viewport点击雷电按钮并检查房间、刀光、深度面板和底部说明边界；截图已人工查看。当时380个双语key及PO一致。无新增脚本/Shader错误；庭院退出仍有既有7个Texture RID警告。尚未验收正式技能伤害、主观手感和完整战斗性能。
- 预览 `source_assets/vfx/lightning_verdict_v001/previews/final/lightning_verdict_godot.mp4` 为Godot实际渲染，1280×720、30fps、5秒；同目录有 `lightning_timeline.jpg`。录制采用固定时间采样，不能据此声称实时帧率；复现用源素材目录中的 `preview_tools/capture_lightning.ps1` 和 `encode_preview.py`。

### 普通与寒冰剑气表现

- 训练“技能特效演示”现在提供冰晶突进、岩脊冲击、普通剑气、寒冰剑气、雷霆裁决、霜冠天坠六选项；剑气纯视觉样片按固定路径飞行并播放终点爆发，不造成伤害。独立入口为 `启动剑气特效演示.cmd` / `game/presentation/combat/sword_wave_showcase/showcase.tscn`，支持重播、慢放、暂停与中英切换。
- 实战已有的 `sword_wave` 投射物已映射新普通剑气；本次已提交快照包含 `contact_freeze` 或确实满蓄力时选寒冰剑气。美术不会添加冻结；带 `frost_blast` 但不带直接冻结的构筑保持普通飞行外观，沿用既有寒霜范围反馈。规则选择语义见[Build API](../../BUILD_IMPLEMENTATION_CONTRACT.md)。
- `normal_wave.tscn/frost_wave.tscn` 仅负责局部飞行外观，由 `configure_effect(fact)` 进入外部时钟模式，`sync_effect(fact,delta)` 接受推进；父适配器独占位置、朝向、半径缩放和销毁。`set_time_running(false)` 冻结全部视觉层，局部随机及材质按实例隔离。普通/寒冰弧刃各940三角面，Blender源文件在 `source_assets/vfx/sword_waves_v001/models/sword_wave_models_v001.blend`。
- 普通/寒冰剑气主体及残影刃面保持平行地面，随发射方向只做平面转向；对应profile取消刃面倾斜，源资源生成器同步。粒子仍可上下散落，不改变攻击半径/速度/伤害。2026-10-06 `post_clear_skills.gd` 检查真实节点360方向、跨清场起手、重复空放、暂停、奖励隔离和退出清理；headless及Forward+通过，图形退出仍有已知7个Texture RID警告。路线集成343项、训练工具回归通过。
- 演示的宽弧用于外观评审；真实投射物通过Resource中的 `projectile_unit_scale` 将主体归一到局部宽1，再接受适配器的真实 `2×radius` 宽度。稀薄尾流/柔光不是攻击几何，未修改任何伤害、半径、速度或状态JSON。
- `normal_impact.tscn/frost_impact.tscn` 的完整命中爆发目前用于独立与训练演示；实战仍使用既有命中反馈，未改全局事件TTL。`normal_demo.tscn/frost_demo.tscn` 分别组合发射、飞行、命中及尾流消散，支持 `seek_visual(seconds)` 确定性采样。表现参数以 `.tres` 为权威，初稿生成器 `source_assets/vfx/sword_waves_v001/build_wave_resources.py` 重跑会覆盖手工调参。
- 剑气接入时的历史验证：真实投射物绑定27项、既有 `action_build_vfx.gd` 表现隔离114项、四按钮headless及Forward+各37项通过；当时375个翻译key及PO一致。普通/直接冻结/仅寒霜爆破选型、旧弹Build快照、null关闭、半径缩放和暂停均覆盖。通过真实Viewport右键→Runner cue→Runtime→表现适配器在默认庭院截图；亮刃宽约0.746/0.748m，前尖距中心约0.358/0.360m，原规则半径0.38m未变。中英UI与既有面板/底部说明无交叠。无新增Shader或脚本错误，默认庭院退出仍有已知7个Texture RID警告；完整战斗性能未验收。
- 动态预览 `source_assets/vfx/sword_waves_v001/previews/final/sword_waves_godot.mp4` 为Godot固定时间采样的6秒实际渲染，1280×720、30fps；同目录保存普通/寒冰分片、`sword_wave_comparison.jpg` 和 `sword_wave_timeline.jpg`。采样帧率不代表实时性能。

### 冰晶与岩脊技能表现原型

- 训练场“技能特效演示”可施放冰晶突进/岩脊冲击、剑气及雷电样片；标题右侧↻再次施放、×清理。跟随角色朝向，默认最多3个实例。紧凑面板可收起，位于操作说明之上；房间信息显示时居中，否则停靠右侧。随“界面显示→刀光效果”隐藏恢复。
- 独立入口：根目录 `启动冰岩特效演示.cmd`，场景 `game/presentation/combat/eruption_showcase/showcase.tscn`。支持1/2切换、空格重播、按钮暂停/慢放/循环、L中英切换。只是开发预览入口，不是Release。
- 当前只实现视觉，不产生伤害、冻结状态或地形碰撞。正式技能应由Combat逻辑时间线确认命中后驱动表现，不能从地刺出现、碎石接地或材质时间反推命中。
- 表现由独立 `TrainingSkillVfx` 显式注入；根节点局部负Z为前进方向、Y=0为地面。`set_time_running(bool)` 暂停全部视觉层，`set_playback_speed(float)` 调整预览速度，`restart()` 重播，`seek_visual(seconds)` 确定性采样，`finish()` 清理。到期自动释放；死亡/换房/重试/退出显式清理。
- 模型在独立Blender后台进程生成，源文件 `source_assets/vfx/elemental_eruptions_v001/models/elemental_eruption_models_v001.blend`；运行时8个OBJ在 `game/assets/vfx/elemental_eruptions_v001/models/`。每个主尖176–514三角面，碎块各44三角面。
- 地刺依次冲出、过冲回落、末端外张冠簇、碎片弹跳与缩退、寒雾/扬尘、地裂和扩散环共享局部时钟。碎片使用MultiMesh批次，雾为独立Billboard；视觉随机流独立于玩法RNG，可变材质按实例复制。表现参数以Resource为权威，`source_assets/vfx/elemental_eruptions_v001/build_effect_resources.py` 是初稿生成器；重新运行会覆盖这组美术Resource，保留手工调参前不要运行它。
- 本次实际验证：Godot资源导入通过；训练headless 28项通过；Forward+ 26项通过并检查1280×800中英面板截图，覆盖指针按钮、位置朝向、3实例上限、暂停/模态、HP/Build/RNG隔离和清理。图形验收覆盖Shader、主体/碎屑/雾层及独立展示画面。录制采用固定时间采样，不表示实时帧率；正式战斗性能、手感与伤害判定尚未验收。
- 已检查真实默认庭院的冰/岩1.2秒画面及紧凑面板，房间信息/刀光菜单/底部说明与返回按钮均无交叠，Forward+退出码0；仅有项目既有7个Texture RID退出警告。展示视频 `source_assets/vfx/elemental_eruptions_v001/previews/final/elemental_eruptions_godot.mp4` 为Godot实际渲染，1280×720、30fps、共10秒；同目录有分技能视频和时序对照图。复现用 `preview_tools/capture_eruptions.ps1`、`encode_previews.py`（相对于该源素材目录）。

### 2026-10-02 左右键动作：历史验证

- 内容/PO、Combat schema3与Build v5通过；dual_actions规则测试通过，覆盖仲裁、连段、冷却、缓冲、取消、快照、姿态/空VFX、Control焦点与Popup阻塞。
- action_build_runtime通过；action_build_vfx的114项表现隔离检查通过。实际动作快照、旧弹体、默认/关闭/替换表现、暂停取消清房有针对性验证。
- action_build_integration通过headless和Forward+1280×800：真实卡片指针、右键、预设菜单信号、三预设、普通选择/替换说明、双语和真实重试。截图已检查，长描述可滚动。
- 本轮training_tools、training_damage_override及控制/真实时序回归通过。仍有7个Texture RID图形退出警告；主观手感、完整性能与人工输入法未验收。详细列表见[验证索引](../../VALIDATION.md)。
### 2026-10-02 训练工具

- 已通过：`training_damage_override.gd`，覆盖伤害无敌、实损反馈、闪避独立、无敌目标接触冻结、恢复生命不复活。
- 已通过：`training_tools_content.gd`39项运行时内容检查、`combat_rules.gd`及`enemy_roles.gd`（360个遭遇计划）核心回归。
- 已通过：`training_tools.gd`机制入口无头与Forward+1280×800集成，以及`-- --ordinary`普通训练无头完整路径。覆盖Viewport实际按钮点击、模态门禁、新旧及自然下一波敌人继承无敌、追加保留Build/锁定计划、人数与出生空间约束、整组失败隔离、显示恢复、奖励/掉落不重复、胜利后续练、死亡与真实场景重试。
- 内容Python校验与PO一致性通过，共266个双语key；专项31项配置校验通过，27个非法样本拒绝。
- 已检查中英文工具面板截图`builds/training_tools_{zh_CN,en}.png`及边界；显示菜单通过PopupMenu信号验证。图形退出仍有既有7个Texture RID警告，本轮无SCRIPT ERROR。人工鼠标试玩、主观手感与性能验收尚未完成。未生成Release，未新增Git提交。

按 [验证索引](../../VALIDATION.md) 运行战斗、反馈、连段/镜头与对应刀光测试。历史包含规则、真实移动攻击、剑尖轨迹、暂停/取消、双语/重试及美术切换隔离；旧截图/数量/逐轮日志在归档，不作为本次全量通过声明。性能未解决项见 [KNOWN_ISSUES](../../KNOWN_ISSUES.md)。

