林庭秘契：三选一卡牌原画与实装资源
2026-10-18

内容
共 51 张独立原画，覆盖当前 builds/prototype.json 的所有 upgrade ID。
按能力分类：武技与通用强化 10 张；火 6 张；冰与冰协同 10 张；雷 6 张；土 6 张；双元素反应 6 张；训练与旧版卡 7 张。
旧版、未进入当前抽取池的卡牌也保留对应原画；本次没有修改它们的启用状态、权重或玩法数值。
品质由候选数据决定，升级复用同一张原画。传说边框已准备好，现有卡池没有因此新增传说能力。

归档与运行时
本目录：完整原始 PNG、分类目录、提示词、生成来源、校验值、预览截图。
game/assets/ui/build_cards/v001/：Godot 实际使用的图片，保留相同分类与文件名。
catalog.json：卡牌 ID、分类、品质、图片路径、等级数和当前卡池状态。
index.html：全部原画、透明组件和游戏实际截图的本地浏览页。

独立图层
1. illustrations/<分类>/<卡牌ID>.png：只有能力插画，不含 UI 文字、边框或正文装饰。
2. frames/common.png、rare.png、epic.png、legendary.png：4 张带透明通道的品质边框。
3. ornaments/botanical_body.png：正文区域独立植物纹样，可在资源中调整透明度、位置或移除。
4. 标题、品质名、按键、等级、醒目收益、简短描述、选择按钮文字：Godot Label 实时绘制，没有烘焙进图片。
5. 正文底色与插画渐隐：程序创建的独立控件，参数位于 Resource。
6. 选择按钮底图：复用 assets/ui/foliage/frame_normal.svg，文字仍独立。

维护入口
game/presentation/builds/build_card_art_library.tres
  每张卡牌的图片路径、标题/收益/正文翻译键，以及品质边框、强调色。
game/presentation/builds/build_card_skin.tres
  卡牌布局、尺寸、文字字号、插画区域、装饰透明度、背景和渐隐。
game/presentation/builds/build_card_view.gd
  负责把独立图层组装成一个可鼠标或键盘选择的卡牌。
game/presentation/builds/build_choice_panel.gd
  使用现有候选、绑定动作、升级等级及替换规则；保持原选择接口。
game/data/locales/zh_CN.json 与 en.json
  双语文字的权威来源。build.card.* 为卡面短文案；原 description_key 的完整规则放在悬停提示中。
  数值仍读取卡牌当前等级的 JSON 配置。改翻译后运行 tools/content/build_shop_preview_content.py。

替换图片
修改运行时同名 PNG 即可自动重导入；同时把定稿原图同步到本归档目录。
如果改路径，更新 art_library.tres。品质边框、插画和植物装饰可分别替换。
增加新卡时必须同时提供原画与词条；configure 会检查卡牌原画映射是否齐全。
generation/card_copy.json 与 card_body_copy.json 保存本次创作时的文案草案，用于追溯，不取代游戏内 locales。
scripts/build_catalog_resources.py 是本次首次建立映射的工具；后续手改 Resource 后不要用旧草案覆盖。

生成与验证
图片均使用内置 image_gen 模式生成；完整提示词和输出来源见 generation/prompts_and_sources.json。
final_assets.json 保存原始生成结果到归档文件的对应关系；每张原画有独立 SHA256 校验。
原画按需载入当前候选，启动时不预加载全部 51 张。
game/tests/build_card_ui.gd 覆盖全部卡牌的中英文、初始/最高等级、文字溢出、1/2/3 张布局、独立图层、实际奖励提交与键盘选择。
game/tests/build_choices.gd 验证已有构筑会话规则；内容生成器 --check 验证双语数据与生成 PO 一致。
previews/validation.json 为界面检查结果；in_game_*.png 来自实际 forest_run 场景。
本轮界面检查 3498 项通过；构筑会话测试通过，686 项双语键与生成 PO 一致。
实景捕获成功并正常退出；退出日志仍有 7 个 Texture RID 释放警告，来源尚未定位，未在本次界面改动中扩展处理。
scripts/capture_gallery.gd 用 Godot 本地渲染分类检查图与真实游戏界面，不改图片源文件。

本次只接入美术表现；没有增加刷新次数、刷新费用或新的抽卡规则。
