# 随机冒险地图预览

2026-10-08。当前只生成、校验和展示地图；点击节点查看信息，不进入房间、不推进Run、不生成怪物/奖励。重要Build选择次数尚未确定，早期“约8次”不作为生成约束。

## 入口与操作

- 双击根目录[启动地图预览.cmd](../启动地图预览.cmd)直接打开；场景为`game/app/map_preview_demo.tscn`。
- 店铺、F6训练、双动作测试、短路线入口均已挂载同一个`app/map_preview.tscn`，按M打开/关闭。已有设置暂停或弹出窗口时不抢占。
- “生成新地图”更换种子；输入种子后按回车或“按种子生成”复现。关闭再打开保留当前图；退出场景后丢弃，不保存磁盘。
- 滚轮浏览自下向上的地图；点击图标仅显示层数、类型、ID和后继数量，并高亮相邻连线。起点/终点是展示标记，不是Boss或可进入房间。
- M/Esc关闭，L切换中英文；输入种子时M/L属于文本输入，Esc仍可关闭。打开预览暂停当前场景，关闭/销毁恢复其暂停状态。
- 六类房间：小怪、精英、随机事件、休息、宝箱、商店。图例同时提供图形、颜色与名称，不仅靠颜色区分。
- 地图采用错落节点、柔和虚线路径与相邻连线高亮；层数仍保留在左侧，但不再绘制横向网格线。相同地图在相同画布尺寸下位置稳定。

## 数据与模块职责

| 入口 | 职责 |
|---|---|
| [map_preview_manifest.json](../game/data/run/map_preview_manifest.json) | 此独立预览的内容入口，由场景显式注入；未扩展正式Run manifest/schema |
| [map_preview.json](../game/data/run/map_preview.json) / [schema](../game/data/schemas/map_preview.schema.json) | 层数、列数、路径数、重试上限、固定层、房型权重、允许层段、最低数量、禁止连续规则 |
| [map_preview_loader.gd](../game/content/run/map_preview_loader.gd) | 严格JSON/重复键、schema、引用/固定层约束；成功后发布嵌套只读定义 |
| [map_preview_generator.gd](../game/rogue/run/map_preview_generator.gd) | 注入规则与种子，生成独立候选；不依赖场景、UI、RunSession或全局随机流 |
| [map_branch_pruner.gd](../game/rogue/run/map_branch_pruner.gd) | 对合法候选作保守重复支路裁剪；包含虚拟起终点、嵌套简化和外部连接保护 |
| [map_graph_validator.gd](../game/rogue/run/map_graph_validator.gd) | 节点/边、起终层可达、无死路、无交叉、分叉汇合、房型限制和最低数量 |
| [map_preview.gd](../game/app/map_preview.gd) | 场景拥有的预览协调器；惰性加载、M开关、种子和候选发布、暂停/焦点恢复 |
| [map_preview_view.gd](../game/presentation/map_preview/map_preview_view.gd) / [map_graph_canvas.gd](../game/presentation/map_preview/map_graph_canvas.gd) | 控件、图例、滚动和节点信息；不执行路线选择或场景跳转 |
| [map_visual_layout.gd](../game/presentation/map_preview/map_visual_layout.gd) | 纯表现排版：居中、邻居方向调整、稳定错位、曲线和几何保护；不修改MapPlan |
| [map_preview_style.tres](../game/presentation/map_preview/map_preview_style.tres) | 配色、图标、尺寸、排版/错位/曲线/虚线参数、M键InputEvent资源 |
| `data/locales/map_preview/{zh_CN,en}.json` | 人工翻译源；[生成工具](../tools/content/build_map_preview_content.py)产出独立PO |

### 接口

- `Loader.load_rules(manifest_path) -> Dictionary`：失败返回空字典，`errors`给出文件/字段原因；不提供隐藏配置兜底。
- `Generator.generate(rules, seed_text) -> Dictionary`：成功为`{ok, plan, attempt, pruned_node_count}`，失败为`{ok:false,error_key}`。调用者只传入已验证规则；裁剪计数仅用于诊断，不是奖励或玩家进度。
- `Pruner.prune(graph, rng) -> Dictionary`：输入已通过图校验的候选及独立RNG，返回`{graph, removed_node_ids}`；深复制后只删节点及关联边，不修改调用方、保留节点、房型或连接方向。调用方负责最终完整校验。
- `Validator.validate(graph, rules) -> PackedStringArray`：验证内部生成的图值，空数组代表通过；不是不可信存档的反序列化入口。
- MapPlan含`seed/algorithm/content_version/rows/columns/nodes/edges`；节点为`id/layer/column/kind`，边为`from/to`。定义与计划嵌套只读。没有当前节点、已访问状态、难度、奖励、具体遭遇或场景引用。
- app只有在生成和校验成功后替换`plan`；失败保留旧图。预览不读写现有RunSession。

## 生成过程与边界

1. 从底层不同起点作多次向上随机游走，每步列差不超过1；共享格子合并为同一节点，拒绝无节点的交叉斜线。第二条路径保证与第一条起点不同。
2. 优先赋予固定层房型，再按权重和允许层段选择类型；检查已分配前驱及固定后继的连续性限制。
3. 校验候选，再裁剪同起点、同汇合点、相同房型顺序的独立支路。路径内部必须每个节点恰有一个前驱和一个后继；有外部连接的节点不删除。虚拟起点连接底层入口，顶层连接虚拟终点，仅用于分析，不写入MapPlan。
4. 等价支路组按稳定ID排序，由独立裁剪RNG随机保留一条，移除其余支路内部节点及关联边；每轮重建连接索引，继续处理内层简化后出现的外层重复。每轮至少删一个真实节点，轮数天然受输入节点数限制。
5. 裁剪后重新完整校验，包括六类房型最低数量和保留分叉/汇合。不合格则丢弃候选，在原有重试预算内重新生成；不强补房型、不放宽约束、不发布未通过的简化结果。
6. 表现排版器从网格生成独立显示坐标及路径折线；经过邻接方向调整、错位与曲线处理，界面据此绘制、命中检测。节点ID、逻辑层列、房型、连接和玩法种子保持不变。

拓扑、房型和裁剪使用本地独立RNG，命名域为`branch_preview.v2:topology/types/pruning`；新种子来源另有app私有RNG。种子字符串通过Godot `String.hash()`派生；复现限定同引擎、算法、配置版本，不承诺不同字符串绝不发生哈希碰撞。v2包含裁剪，旧v1种子生成的布局不保证相同。重试会推进本次调用的独立流，调整房型约束后不承诺拓扑不变；始终不消耗玩法随机流。

六类全图最低数量来自预览配置，不代表每条玩家路径均经过六类。当前裁剪比较房型序列；相同房型但有不同外部连接的复杂子图仍保留，不做任意子图等价化。同级分叉类型差异优化、完整奖励节奏和逐路径奖励预算尚未实现；以后增加可见的危险/奖励/订单差异时须扩展等价判定，不能继续只比较房型。正式可玩路线仍是原固定短图，本次不把其`run_route.schema.json`扩展为虚假的可玩事件/商店。

算法参考：分层随机游走、先连线后赋房型的思路参考[视频](https://www.bilibili.com/video/BV1qgHr6AEKq/)及[第三方反编译镜像StandardActMap.cs](https://github.com/Hexpion/Slay-the-spire-2/blob/64ed626b7ec9692bc54536b0123fc3cb580c28da/Slay%20the%20Spire%202/src/Core/Map/StandardActMap.cs)。本模块为按项目边界重新编写的实现，图标自行绘制，未复制游戏代码或美术资源；没有宣称该镜像为官方开源源码。

## 表现排版

- `VisualLayout.minimum_size(plan, style)`给出画布最小尺寸；起终点扇形连线的纵向留白根据地图宽度和图标净距计算，避免外侧路径擦过同层图标。
- `VisualLayout.build(plan, style, canvas_size)`返回`positions/paths/start/end`；真实节点坐标按ID索引，路径为`{from,to,points:PackedVector2Array}`。虚拟起终点只出现在路径索引，不污染真实节点或MapPlan。
- 全局按已占列居中，再参考相邻节点位置缓和横向折返；叠加按层平滑变化的横向偏移及每节点的横/纵偏移。原层列只作为初始布局和左右顺序约束。
- 每次移动检查标签预留间距、同层左右顺序、向上前进、无新增线段交叉及无关图标净距；不合格时减小位移，仍不合格保留上一个合法位置。
- 将直线转换为轻微弯曲的Bezier采样折线，逐条检查与其他路径/无关图标的关系；必要时缩小弯曲幅度，最后可保留直线。共用端点处只有被该端点图标遮住的重合被允许。
- 普通路径按沿线距离绘制连续相位的虚线；悬停/选择高亮相邻曲线。图标、连线端点和鼠标命中检测使用同一套显示坐标。
- 视觉随机域`map_visual.v1`按地图种子、节点/边ID派生，不使用全局或玩法RNG。调整样式不会改变`branch_preview.v2`的生成结果。同地图、同尺寸、同Resource参数可复现显示；窗口尺寸变化可以重新排版。
- Canvas缓存相同计划和尺寸的排版结果；悬停、重绘、语言切换和重复打开不重算。新计划/尺寸变更才触发计算；样式参数修改后重新启动预览。本轮本机批量测试观测单次排版最大641ms，不是逐帧操作，未作低配性能验收。

## 验证

2026-10-08本轮表现排版验证：

- `tests/map_visual_layout.gd`：40个种子×两种画布宽度（最小宽度与1400px），203875项断言通过；MapPlan不变、视觉可复现、原连接完整、图标/标签预留区域不重叠、曲线向上且不穿过无关图标、无新增可见交叉、全局RNG隔离。
- `tests/map_preview_ui.gd`：Forward+的24项通过；包含1280×800和1440×900窗口切换后的计划隔离与真实点击，及已有暂停、种子、双语、设置/销毁流程。本轮已检查中文起点/中段/终点和英文截图：`builds/map_preview_zh.png`、`map_preview_zh_middle.png`、`map_preview_zh_top.png`、`map_preview_en.png`。

此前同日的裁剪验证（本轮未修改生成器，未复跑）：

- `tests/map_branch_pruning.gd`：127项通过；起点/终点、内部菱形、连续房间、嵌套/三重分支，房型顺序、外部入边/出边保护，完整路径房型序列集合保持不变、深复制、输入顺序独立、固定点与随机隔离。配额用例验证裁剪后不合法时有限重试，不能发布该候选。
- `tests/map_generation.gd`：1217项通过；300种子全部生成合法图、300种不同拓扑，共裁剪749节点；再次简化无可安全移除的重复支路，并通过独立可达检查、复现/全局RNG隔离、只读、非法配置与有限失败。

此前同日的预览入口验证（本轮未复跑）：内容/schema和23个双语key/PO一致；`map_preview_ui.gd` headless 22项通过；`map_preview_hosts.gd` headless真实店铺和双动作训练入口通过M/Esc、场景保留及训练暂停检查。

这些结果不代表随机地图已可选路、不代表正式内容平衡、全分辨率UI或全部种子都已穷尽验证。未导出Release。
