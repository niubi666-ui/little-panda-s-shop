# 森林庭院植被优化与后台加载

2026-09-27。用户要求优先处理树冠和外围背景，主体建筑不修改；随后授权增加后台加载和临时进度条。

## 运行入口

- 新试玩包：`builds/windows-release-foliage/LittlePandasShop.exe`，同目录 `.pck` 必须保留。
- 原始 Release 留在 `builds/windows-release/`，用于对照。它不包含本轮优化与进度条。
- 店铺 F6 进入战斗；重新训练、回店也走新的过渡流程。

## 植被实际做了什么

- 原来的补充叶片每片由 8 个三角形形成弯曲叶缘和凸起中脉。离线工具将该叶片模板的轮廓、三角面法线投影到 256×256 贴图，低模使用每片 2 个三角形的面片。
- 使用五种原叶色贴图派生的 RGBA 颜色图，以及一张切线空间法线图；glTF 使用 `MASK` 透明裁切，而不是整片半透明混合。贴图只含表面信息，不烘焙环境光照。
- 保留每片叶子的原始局部坐标系、位置、朝向和数量；没有随机抽掉树叶。法线用统一叶宽模板近似，扁平面片不能完整保留高模卷曲的空间轮廓，因此叶面明暗和树影存在差异。
- 处理共享树冠、外围灌木、悬垂树叶；背景古树网格保留原纹理，减到约 25% 面数，两棵近景古树约 50%。主体建筑、庭院石材、神龛、拱门、围栏、灯光和碰撞均不调整。
- `tools/assets/assemble_forest_runtime.py` 从旧 GLB 直接复制所有非目标节点的几何流、UV、材质/纹理及变换，只换明确列出的植被网格，避免重新导出对其他对象造成细微变化。
- `tools/assets/check_forest_foliage.py` 对 545 个非目标网格实例逐项比对，结果一致。327 个植被实例发生变更。

## 数据与实机比较

机器：RTX 4060 Laptop，Godot 4.7.2 Forward+；1280×800，同游戏相机、默认缩放、静止暂停战斗、隐藏 HUD、关闭 VSync/帧率上限、预热 5 秒后采样 180 帧。这里只是短时样本，不能推断完整战斗或低配电脑帧率。

| 指标 | 原版 | 植被优化版 |
|---|---:|---:|
| 按实例累计三角形 | 19,090,507 | 6,159,304（减少约 68%） |
| 单个共享树冠实例三角形 | 176,000 | 44,000 |
| 该视角每帧绘制图元（含额外通道） | 8,814,884 | 4,857,394（减少约 45%） |
| Draw calls | 1,103 | 1,107 |
| 平均帧耗时 | 10.07ms | 6.70ms；第二次 6.83ms |
| P95 帧耗时 | 11.01ms | 7.51ms；第二次 8.78ms |
| 引擎视频内存统计 | 2,532,165,568 bytes | 2,519,413,520 bytes |
| 直接同步创建战斗宿主 | 7,654ms | 7,505ms；第二次 7,336ms |

因此本轮改善的是几何/渲染负载；显存、绘制调用和同步加载时间没有明显下降。没有改变场景整体画质档位。自动 LOD 仍开启，累计模型面数不等于实际每帧面数。

实机对照：[优化前](previews/forest_foliage_before.png) / [优化后](previews/forest_foliage_after.png)。另检查了最近和最远缩放；原始截图在 `builds/foliage_{baseline,optimized}_zoom_{12,17,24}.png`。

## 后台加载与界面分工

- `game/app/scene_transition.gd` 是每次过渡独立的临时节点，挂在 SceneTree 根下以跨越 `current_scene` 替换；完成/关闭失败提示后释放。不增加全局服务定位器或 Autoload。
- `main.gd` / `combat_training.gd` 明确发出切换请求，持有本次 operation 防止重复。旧战斗在真正退出树时清理；加载失败仍保留旧场景。
- 冷资源使用 `ResourceLoader.load_threaded_request` 后台读取，每帧查询真实进度；只有状态 LOADED 后才取资源。已缓存 PackedScene 直接复用。没有假进度计时或故意等待数秒。
- 加载期暂停玩法并暂时禁用当前 Viewport 的 3D 绘制，先显示界面，完成后恢复原暂停/3D 状态。场景实例化仍在主线程。新场景初始渲染期间保留加载界面。
- 进度数值只代表资源读取阶段，资源读完显示“资源已就绪，正在准备场景…”，不声称全流程已完成。复杂资源的引擎进度可能跳跃。
- `game/presentation/loading/loading_screen.tscn/.gd` 只负责显示和失败返回请求。以后替换动画/插画时保留 `show_progress(ratio)`、`show_preparing()`、`show_failure()` 和 `dismiss_requested` 接口即可；业务切换不依赖动画时间。
- 使用已有字体 Theme；五个 `loading.*` 文案来自双语 JSON，PO 由内容工具生成。没有新增经济或战斗参数。
- 这仍是临时训练场的整场景切换；没有提前实现正式冒险的持久 Main/RoomSlot，也没有改成“保留房间节点只重置敌人”。

### 最终后台加载实测及限制

`builds/loading_transition_final.log`：商店首次进入战斗约 8,233ms，其中后台资源 7,088ms、实例化约 61ms、初始渲染帧约 1,066ms；过渡期间观察到 1,152 次主循环刷新，最长单帧约 1,047ms。连续四次重开约 59–72ms；回到已加载过的商店约 95ms。

早期启用依赖子线程的试验曾有约 3.8–4.5 秒记录，但不是最终配置。最终保守地不启用额外依赖子线程。不要把后台加载解读成所有操作异步、保证首次秒进，或把缓存重开的耗时当冷启动耗时。首次渲染长帧和此前偶发低帧率仍待后续单独分析。

### 诊断注意

- 优化前、优化后图形测试都存在 `7 RIDs of type Texture were leaked` 的退出警告。引擎仓库有相符的 [Reflection atlas 报告](https://github.com/godotengine/godot/issues/122498)，本项目未独立证明它与第三次重开低帧率的因果关系。本轮不改引擎或关闭反射。
- 连续切换诊断脚本还出现无脚本名称、引用计数为 0 的 RefCounted 退出警告（最终样本 7 个）；普通战斗/构筑回归没有该 ObjectDB 警告。引擎有 [threaded LoadToken 报告](https://github.com/godotengine/godot/issues/120661)，但未证实本机警告与该报告同源；禁用额外依赖子线程后诊断脚本仍有警告，故只列为待查，不能声称已修复泄漏。测试确认过渡节点均释放、只剩一个当前场景，但这不等于全引擎资源无泄漏。

## 资产源与复现

- 原 `.blend` 未保存或覆盖，SHA256 仍为 `cf129bd1c3d3fbb9f7091226d2e2a991418c1b9073b36f88f4db70e153eb5ce9`。
- 精确保留旧导出：`source_assets/environments/dungeon/forest_courtyard/v001/exports/forest_courtyard_high_reference.glb`，不进入游戏包。
- 配置与离线转换：源目录 `scripts/foliage_runtime.json`、`scripts/optimize_foliage.py`。贴图归档于 `textures/runtime_foliage/`。
- 实际游戏资源沿用 `game/assets/environments/forest_courtyard_v001/forest_courtyard.glb` 路径和导入 UID；未改房间契约或 JSON 内容池。
- 报告：源目录 `reports/foliage_runtime.json` / `reports/foliage_protected_geometry.json`。

复现流程：后台 Blender 打开原 blend，运行 `scripts/export_godot.py`，传入 `--foliage-config`、独立 `--output-dir` 和 `--report`；再运行 `tools/assets/assemble_forest_runtime.py 原版GLB 候选GLB 转换报告 输出GLB`；用 `check_forest_foliage.py` 验证输出后再安装到游戏资源路径。不要直接用未经合并验证的全场景重导出覆盖运行版。

## 验证

- 保护性几何/材质比较：`failures: []`；源 blend 哈希未变。
- `tests/forest_foliage_preview.gd`：前后同条件截图、帧耗时与图元统计。
- `tests/scene_transition.gd`：实际商店进入战斗、重复输入保护、连续四次重开、回店、缺失资源失败保留旧场景、中英文错误提示、关闭后恢复状态，`failures: []`。
- `tests/forest_room.gd`：场景出生/碰撞、真实近战两波、三选一、重开、回店与重新进入；等待真实过渡完成信号，替代固定 0.4 秒等待。
- `tests/combat_training.gd`、`tests/build_training.gd`：真实图形运行回归均 `failures: []`。双语内容工具校验 145 个 key 与生成 PO 一致。
- 最终独立 Release exe 无窗口启动商店退出码 0；从工程目录外加载最终 PCK，以引擎运行外部切换验证脚本，完成商店→战斗、四次重开、回店与失败恢复，`failures: []`。该包测试首进约 8,148ms，缓存重开约 63–73ms；它验证打包资源/脚本，不冒充实际 Release 全战斗性能测试。
- 导出与最终回归日志在 `builds/loading_*`、`builds/foliage_*`。退出警告与性能边界见上，不把成功导出等同于无卡顿验收。
