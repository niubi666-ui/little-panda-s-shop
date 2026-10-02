# 店铺装修 UI 分层美术包 v001

日期：2026-09-26。采用用户提供的树叶主题参考：深森林绿、细金属边、暖木家具、独立叶饰。

2026-09-26 接入完成记录：“写godot具体代码”已将本包接入实际家具摆放界面，完成 1280×800 / 1920×1200 中英文与交互验收；美术任务已查看 1280×800 中英文实机图。详见 [Godot 接入记录](../../../../docs/SHOP_DECORATING.md) 和 [中文实机截图](../../../../docs/previews/decoration_v001_zh_CN_1280x800.png)。下文的交接与待验收描述保留为素材制作阶段的记录；网页限制不影响后来完成的 Godot 实机验收。

**交付范围是可拼装美术素材与接入说明。游戏界面的修改、输入接线和 Godot 实机验收交给“写godot具体代码”任务；本目录的网页是美术拼装示意，不是游戏实机。**

## 打开预览

- [素材总览](previews/index.html)：每张独立 PNG / SVG 可单独打开，支持切换背景检查透明边缘。
- [拼装示意](previews/layout_preview.html)：可查看当前四种家具与参考扩展目录，点击缩略图查看详情；明确区分现有家具和备用美术。
- [原始参考](reference/decoration_reference.png)。场景示意背景来自项目已有 `shop_interior_v006.png`，本次未修改店铺场景。

## 目录

```text
source_assets/ui/decoration/v001/
  reference/               用户参考图
  exports/chrome/          8 张独立 UI 底图 / 透明装饰
  exports/thumbnails/      9 张独立家具缩略图
  exports/icons/           8 个简单操作 SVG 图标
  generation/              全部生成提示词、源路径和整理脚本
  previews/                素材总览、HTML 拼装示意
  reports/                 代码接入审计、透明与文件一致性检查
  manifest.json            精确尺寸、alpha 可视范围、文件哈希、家具映射
  HANDOFF.md               发给代码任务的具体接入要求

game/assets/ui/decoration/v001/
  chrome/                  与 exports/chrome 原样一致
  thumbnails/              与 exports/thumbnails 原样一致
  icons/                   与 exports/icons 原样一致
```

`manifest.json` 是美术交付清单，**不是游戏内容目录 / Registry schema**。运行时贴图与布局引用由代码任务放入表现 Resource；禁止每帧读取这个清单。

## 已拆分的界面元素

| 文件（chrome/） | 用途 | 缩放方式 |
|---|---|---|
| `catalog_panel.png` | 左侧目录底板；可复用作详情背景 | 先去透明外边距，再九宫格；保护四角，不整张拉长 |
| `item_slot.png` | 单个家具格的普通状态 | 方形、等比；内容与标签另放 |
| `item_selected.png` | 选中格外圈；**中心透明** | 与卡片可视边对齐；不承载点击 |
| `tab_button.png` | 家具 / 装饰 / 灯具页签及简洁提示条 | 九宫格，标签和图标独立 |
| `mode_banner.png` | 顶部“装修模式”标题牌 | 等比优先，中部可适度伸缩，保护两端叶纹 |
| `button_primary.png` | 完成装修等主要动作 | 保留金边与右侧叶片；中心留给动态标签 |
| `button_secondary.png` | 旋转、取消预览等次要动作 | 保留两端，中部伸缩 |
| `leaf_corner.png` | 左上 / 右下独立枝叶装饰 | 等比，可翻转旋转；不能沿边拉成长藤 |

文本、金币、拥有数量、按键字符、家具内容**没有烘焙进图片**。选中描边以外的 hover / pressed / disabled / focus 用 Theme、颜色调制、轮廓和控件状态实现，不再生成四套相同大图。

简单动作图标为独立 SVG：`confirm`、`close`、`rotate`、`undo`、`remove`、`mouse_left`、`mouse_right`、`chair`。图标笔画暖象牙色，透明底，128×128 viewBox。树叶 / 灯具 / 金币沿用 `game/assets/ui/foliage/` 中既有图标。`undo.svg` 为备用外观，**不代表已实现撤销历史**。

## 家具缩略图映射

| 图片（thumbnails/） | 当前家具 definition ID | 接入状态 |
|---|---|---|
| `barrel.png` | `barrel` | 可映射小木桶 |
| `scroll_bin.png` | `scroll_bin` | 可映射卷轴桶 |
| `supply_crate.png` | `supply_crate` | 可映射药罐货箱 |
| `storage_chest.png` | `chest` | 可映射宝箱；点击传 `chest` |
| `chair_oak.png` | 无 | 木椅备用美术 |
| `bookshelf_potions.png` | 无 | 魔药书架备用美术 |
| `potted_fern.png` | 无 | 蕨叶盆栽备用美术 |
| `rug_crimson.png` | 无 | 酒红地毯备用美术 |
| `wall_lantern.png` | 无 | 壁灯备用美术 |

缩略图是按统一风格生成的概念插画，**不是现有 3D 模型的精确渲染**。首批四种可作为目录候选；之后模型外观定稿时，可替换为相同光照 / 镜头的模型渲染。其余五种不要因为有图片就加进真实可摆放目录，尤其壁挂、地毯的规则目前不具备。

图标保留原始 RGBA 像素。显示时完整等比适应卡片内框并留约 10% 内边距；地毯原图比较满，必须避免贴边。不要把所有缩略图强制裁成同一个 alpha 包围盒后铺满，细长壁灯会显得过大。

## 给 Godot 的图片装配约定

1. 所有 PNG 有真实 alpha；精确尺寸与 `atlas_region_xywh` 见 [manifest.json](manifest.json)。后者为 alpha > 4 的范围加 8 像素余量，坐标为 `x, y, width, height`，可用于 AtlasTexture。运行文件仍为原图，未实际裁切。
2. 可拉伸背景在 AtlasTexture 可视范围内再做 StyleBoxTexture / NinePatchRect。角部叶纹、按钮端帽和圆角应留在固定边距；具体九宫格像素边距由接入者在目标尺寸下校准。独立树叶、家具图标等比。
3. 参考布局为左侧目录、顶部模式标题、下方操作条、场景附近操作提示。建议 1280×800 左栏约 320–360 像素，家具格两列；1920×1200 根据 UI 缩放设置整体放大。参数集中在 `.tres`，不散写在脚本中。
4. 家具缩略图与文字保持独立：上部物体预览，下部本地化名称；长英文允许两行。面板背景、叶片、选中框 `mouse_filter = IGNORE`，真实按钮承接输入。
5. 只对侧栏、按钮区域阻挡鼠标。全屏装饰框不能吞掉场景点击；当前 `app/shop_decoration.gd` 通过悬停控件判断是否允许摆放。
6. 基础配色参考：深底 `#0a211b`，暖象牙文字 `#f2e3b9`，次级文字 `#b2b394`，古铜 `#b69a62`，选中浅叶绿 `#d7e998`。颜色属于表现配置。
7. 字体复用 `ui_typography.tres` / Noto Serif SC。所有玩家可见文案用已有或新增翻译 key，键位标签从真实 InputMap 获取。

## 现有功能必须如实呈现

- 实际家具目录只有四种；三个分类的空态或暂不开放状态要清楚。不要把旧 `foliage_preview.json` 样例当权威目录。
- 当前没有家具库存、装修花费、金币余额、撤销历史或布局持久保存。本轮皮肤不要显示参考图的“拥有 2 / 1,280”作为真实数据。
- `cancel_requested` = 取消当前预览；“撤销”不是同一功能。
- R 当前进入 / 退出装修，旋转由按钮触发；不可直接照图写“R 旋转”。
- 真正入口是 `presentation/decorating/decorating_panel.gd`；不要只改 `foliage_ui.gd` 中的旧样例页。

完整静态审计见 [reports/integration_audit.md](reports/integration_audit.md)。

## 制作与验证记录

PNG 使用**内置 image_gen**逐个生成；最终提示词和生成源路径保存在 `generation/*_prompts.json`。参考图为用户提供，本次未使用商店下载素材。SVG 为本项目绘制的简单操作图标。没有从参考图截取带字 UI，未使用代码抠图或重绘生成图片。

`generation/build_package.py` 只读 PNG 检查 alpha / 尺寸、对比源与运行副本 SHA-256，并生成美术清单与网页；不编辑图片像素。检查结果见 `reports/asset_validation.json`。Godot 导入、实际尺寸、双语、点击、旋转 / 取消 / 移除 / 完成和鼠标穿透测试需由接入任务执行并记录。

自动浏览器打开本地 HTML 时被 URL 安全策略阻止，因此网页尚未完成浏览器截图 / 点击验收。本轮未绕过限制；图片逐张检查、文件清单与相对链接静态检查可独立完成。最终以代码任务的 Godot 实机截图为准。
