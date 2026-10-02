# 店铺实机预览 v003

日期：2026-09-25。Godot 4.7.2，Forward+。本次按用户要求优先完成场景、角色和交互预览；完整M0存档/设置系统仍未完成。

## 打开与操作

打开 `game/project.godot`，运行主场景 `game/app/main.tscn`。

UI已接入树叶主题HUD与背包/订单/装修/设置预览，操作和实现边界见[FOLIAGE_UI.md](FOLIAGE_UI.md)。

- WASD：按镜头方向移动；移动播放跑步，停下使用静态站立占位动作。
- 滚轮向上拉近、向下拉远；平滑缩放带上下限。默认近景，镜头在店内限定范围跟随角色，保持斜俯视角度不旋转。
- 靠近售货柜台、中央魔药台、宝箱、药材柜、古物书柜、右侧两柜或窗下两柜，按F打开交互占位面板（共9件家具）。柜台正反面及两端均支持。
- Esc或关闭按钮：关闭面板。面板打开期间不接受移动。
- L或右上按钮：切换中文/英文，当前语言不持久保存。
- R：店内家具摆放原型，支持四种新增家具的网格吸附、旋转、移动和移除；已通过基础引擎及鼠标操作验收，详见[SHOP_DECORATING.md](SHOP_DECORATING.md)。
- 当前没有实际陈列、上架、售卖、订单或经济交易；装修仅保留当前店铺场景内的临时布局。

## 美术来源与转换

- 商店：`source_assets/environments/shop/blender/shop_interior_v006.blend`。
- 主角：`source_assets/characters/red_panda/blender/red_panda_run_v008.blend`；见[角色导入报告](character_import_report.md)。
- 原始Blender文件均未覆盖。Blender MCP未连接，本次使用Blender 5.2.1后台CLI读取、烘焙和导出。
- 保留781个可渲染源物件。v002按用户要求将房间外壳纵深增加14%，后排陈设后移1.26米，柜台左移0.30米，让出背面及两侧通道；家具本身保持尺寸。444个使用程序材质的物件，将表面颜色/切线法线烘焙到4096贴图；未把家具光照或投影烘死在贴图中。
- GLB不包含Cycles面光、世界与体积节点。Godot原生场景重建太阳、窗外光、暖灯、补光、阴影、环境、接触阴影、反射及局部雾；正交镜头由源矩阵转换。明亮窗外面与局部光尘为实时表现适配。
- 已查看Godot运行截图并对照v006调整。实时灯光、反射、雾与Cycles仍有差异；本交付不是逐像素一致的离线渲染复制。

导出限制依据：[Blender/glTF官方说明](https://github.com/KhronosGroup/glTF-Blender-IO/blob/main/docs/blender_docs/scene_gltf2.rst)。

## 场景与后续摆放边界

`game/shop/scenes/shop_interior.tscn`是原生可编辑场景：

- Architecture：地板、墙体与房间边界。
- FixedFixtures：入口门、梁钉、完整壁灯组等固定附属件。
- Furnishings：64个当前顶层家具/装饰组；内部保留子物件，不是64种已设计的装修商品。
- Lighting：窗光、太阳、环境、屋顶仅投影几何和光尘。
- ShopCamera / PlayerSpawn：相机及出生点。
- SurroundingGround：连接建筑基座的连续视觉地面，消除蓝色悬空背景；当前不是可探索的店外区域。

v003沿后墙新增5组可独立移动的库存装饰（小木桶、卷轴桶、两处货箱、箱上药罐），顶层家具/装饰组增至69组。复用原有材质与模型，保持柜台背面通路。装饰仍无新增经营功能。默认镜头显示局部店内而非完整微缩模型，拉远可查看更多布局；屏幕边缘可能显示店外衬底地面。

可摆放组持有稳定的`instance_id`、`definition_id`与`placement_scope`元数据。视觉、碰撞代理、交互标记和附着灯光随根节点移动；桌腿/桌面、挂毯纹样、盾牌部件、罐盖标签、常春藤枝叶及部分柜顶植物已合为逻辑物件。每个组的内部网格仍可单独编辑。

这些ID当前是预览场景身份，未来家具价格、占格、解锁与正式内容引用将进入FurnitureDef/JSON目录。**碰撞代理不是装修业务占格**；不应据此直接生成经济规则。

柜台和中央台来源是包含商品的聚合网格，瓶罐尚未全部拆成可独立上架的商品。后续实现商品陈列时需拆分或换成空台面＋商品挂点。本次提供9件家具的交互入口，仍为功能占位。

单件家具只有一个交互身份。InteractionPoint可包含多个Marker3D子锚点；按最近表面点选择目标，子锚点不单独注册。移动家具时所有锚点一起移动，不增加重复家具ID。

交互控制器显式提供`register_target`与`unregister_target`；装修协调器添加/移除原型家具时调用，卸载当前目标会关闭弹窗。2026-09-26已接入摆放UI和网格通路校验，当前仍无布局存档。原始陈设保持固定，仅本原型新增家具可编辑，详见[SHOP_DECORATING.md](SHOP_DECORATING.md)。

## 代码与配置

| 位置 | 负责内容 |
|---|---|
| game/app/main.gd | 启动、加载Registry、实例化场景/角色、注入依赖 |
| game/content/shop_preview | manifest加载、字段校验、只读Definition与Registry |
| game/data/shop/shop_preview.json | 移速、转身速度、重力、交互距离与初始语言 |
| game/data/locales | 人工翻译源；工具生成generated/locales/PO |
| game/presentation/shop_preview | 本切片的移动/动画适配和交互展示；不处理经营交易 |
| game/presentation/red_panda_preview.tscn | 主角模型缩放、朝向、身体碰撞 |
| game/presentation/shop_preview/shop_preview_style.tres | 动作名、朝向修正、UI样式 |
| game/presentation/shop_preview/shop_camera_controller.gd | 独立镜头跟随与滚轮平滑缩放，由main注入相机/角色/配置 |
| game/presentation/shop_preview/shop_camera_settings.tres | 初始/最小/最大正交尺寸、缩放步长、平滑速度、跟随边界 |
| game/resources/shop | 窗口光尘表现资源 |

当前是一个范围有限的预览控制器。进入正式战斗时，按契约把移动接入CharacterMotor/IntentSource，把交互展示与角色控制分开；不能将其扩大成经营与战斗的通用管理器。当前只有预览控制器调用角色移动，不存在动画和脚本双重移动。

2026-09-26运行界面已改用项目内置字体，配置与来源见[UI_FONTS.md](UI_FONTS.md)；尚未验证Windows独立导出包和其他机器。

## 重建与验证

1. 用Blender后台打开v006，执行 `tools/assets/export_shop.py`；输出GLB及生成清单，不保存源blend。
2. 用Godot `--headless --editor --import --quit` 导入运行资源。
3. 用Godot `--headless --script E:/ShopGame/tools/assets/build_shop_scene.gd` 生成原生店铺场景。生成脚本中的数值用于离线美术场景制作，运行时参数保存在生成的原生资源中；再次生成会覆盖此生成场景。
4. 翻译/内容工具依赖见 `tools/content/requirements.txt`；本机私有环境 `builds/content_venv`。
5. 运行内容检查、`game/tests/shop_preview_controls.gd` 和 `game/tests/shop_scene_integration.gd`。

Godot命令均需 `--path E:/ShopGame/game`。图形集成验证需要Forward+运行，记录至builds，截图归档到docs/previews。普通开发修改原生场景时，应同步必要的生成脚本改动，避免下次重建丢失。

已验证：角色导入及动作、配置错误拒绝、31项控制/动态注册/多锚点检查、双语19个键及PO一致；实景移动/跑步/停止、落地、家具阻挡、F交互、Esc、弹窗阻止移动、语言切换、几何保留与家具携带灯光/交互。

v002新增`game/tests/shop_accessibility.gd`：使用连续移动输入从入口绕柜台右侧进入后方，再从左侧走出；背面按F验证，9件家具逐一验证选择和打开。通路段不使用传送；各家具交互检查单独设置接近位置。实机截图见`docs/previews/shop_counter_rear.png`。这是初始布局的历史通路验证；新装修模块会校验候选布局的网格可达性，基础摆放实机验收已完成，但不代表任意布局均已连续实走。

v003新增`game/tests/shop_camera.gd`，以真实鼠标滚轮事件验证缩放方向、平滑后的目标尺寸及两端限制，并验证入口/后柜台/角落处主角在视野中、镜头朝向不变。1920×1200运行截图：`shop_camera_entrance.png`、`shop_camera_rear.png`、`shop_camera_close.png`、`shop_camera_wide.png`，归档至`docs/previews/`。新增装饰后重新验证绕柜台通路与9处交互。

RTX4060 Laptop GPU上完成1280×800及1920×1200图形运行检查；瞬时FPS不作为正式性能承诺。高数量子网格和多盏动态阴影灯后续仍可合批/限影优化，正式最低配置尚未定。
