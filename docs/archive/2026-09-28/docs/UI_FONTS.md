# UI 字体：更换入口

## 日后只改这一个资源

`game/presentation/foliage/ui_typography.tres`

Godot文件系统中双击它，可以在检查器中修改：

| 字段 | 作用 | 当前值 |
|---|---|---|
| font_file | 共用字体文件（标题、正文、按钮均由它生成） | NotoSerifSC-VF.ttf |
| body_weight | 正文字重 | 500 |
| button_weight | 按钮字重 | 650 |
| heading_weight | 标题字重 | 750 |
| body_size | 正文字号 | 19 |
| button_size | 按钮字号 | 19 |
| title_size | 主标题字号 | 29 |
| detail_title_size | 物品详情/委托标题字号 | 22 |
| muted_size | 辅助说明字号 | 16 |
| catalog_size | 家具格子文字字号 | 16 |

要换整套字体：把新`.ttf`/`.otf`放入`game/assets/fonts/`，导入后拖到这个资源的`font_file`，重新运行游戏。无需逐个修改页面或编辑业务代码。可变字体的`wght`轴负责字重；替换成不支持该轴的静态字体时，各角色会使用该文件本身的字重。

`foliage_theme_factory.gd`在启动时将此配置应用到主题，main把同一个Theme注入HUD/菜单和家具交互弹窗。`build_foliage_ui.py`只生成图形主题，不生成或覆盖字体配置。字体调整不需要重新运行美术生成工具。目前不做游戏运行中的字体热加载，修改后重新运行即可。

## 与参考图的关系

foliage_v001是AI生成概念图，生成记录没有指定可识别的字库文件，因此**无法证明任何现成字体与图中字形逐字一致**。本版按参考图中的宋体衬线、横细竖粗及较重标题/按钮方向，采用Noto Serif SC可变字体近似还原；不宣称找到了概念图原字体。将来拿到准确字库时，通过上面的同一入口替换。

字体随项目保存，不再依赖目标电脑安装宋体。中英文均由同一字库提供。参考图中的暖白、金色与深色文字仍由图形Theme负责。

## 来源与许可记录

- 来源：[Google Fonts / Noto Serif SC](https://github.com/google/fonts/tree/main/ofl/notoserifsc)
- 下载日期：2026-09-26。
- 未修改字体二进制；项目内文件名：`game/assets/fonts/NotoSerifSC-VF.ttf`。
- SHA-256：`050080D9255A86808F2945BFFAC582B31EF32BC36411CE29563B4961670C66F9`。
- 上游OFL文本一并保存为`game/assets/fonts/OFL-NotoSerifSC.txt`，发布时保留。

## 验证

`game/tests/ui_typography.gd`检查全部中英文翻译字符及UI符号在字体内的覆盖情况。`game/tests/foliage_ui.gd`检查真实界面中的双语排版和点击，截图归档到`docs/previews/typography_*.png`。改大字号后应重新运行界面检查，确认按钮和侧栏没有溢出。
