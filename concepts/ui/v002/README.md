# UI 风格对照稿 v002

状态：生成的讨论用概念图。A 为 [v001 深绿古铜](../v001/README.md)，本轮新增 B、C 两种风格。视觉设定尚未确认，也未实现成 Godot UI。

| 界面 | B 浅色炼金手记 | C 深色秘术玻璃 |
|---|---|---|
| 经营 HUD | [B_hud](B_hud.png) | [C_hud](C_hud.png) |
| 背包 | [B_inventory](B_inventory.png) | [C_inventory](C_inventory.png) |
| 订单 | [B_orders](B_orders.png) | [C_orders](C_orders.png) |
| 装修 | [B_decoration](B_decoration.png) | [C_decoration](C_decoration.png) |
| 交互组件 | [B_components](B_components.png) | [C_components](C_components.png) |

## 对比目的

- **A 深绿古铜**：与店铺木材和绿植呼应，氛围厚重。
- **B 浅色炼金手记**：羊皮纸、胡桃木、铜件、植物线描；订单和背包更像手帐。
- **C 深色秘术玻璃**：烟灰玻璃、细银线、少量青蓝与琥珀点缀；场景露出更多，操作层级较轻。

## 观察与边界

- B 的背包和订单板块较大，文字在亮背景上清楚，但会挡住更多店铺。B 的经营 HUD 也偏厚重。
- C 的 HUD 和装修界面给场景更多空间，物品详情文字则要在最终缩放测试中确认可读性。
- 图片生成器添加了各自额外的菜单、世界观文字、奖励、时间、金币和快捷键；这些只是视觉占位，不能直接当成产品决定。
- 订单仍以“可选 0 或 1 张、可自由出发”为共同交互目标；正式文案与输入映射需按项目契约实现。
- 所有正式界面文字应通过本地化 key 动态渲染，图中文字不可直接烘焙进 UI。
- 本轮使用内置 image_gen 工具，每张图片独立生成，参考实际店铺渲染。完整提示词见 [prompts.json](prompts.json)。

建议选**一套作为基础**，再从另一套借用具体组件；例如 C 的轻 HUD 配合 B 的订单卡，但需先统一边框、字体和按钮状态。

