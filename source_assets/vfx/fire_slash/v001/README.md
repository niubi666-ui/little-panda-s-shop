# 火焰刀光小样 v001

2026-09-26。状态：待用户评审的独立实机视觉小样，未确定正式元素分类或技能。

## 查看

- 视频：`previews/fire_slash.mp4`，1280×800、60 FPS、约 8 秒，前段普通训练场镜头，后段近景 0.35 倍慢放，无音频。
- 截图：`previews/candidate_a.png` 与 `previews/candidate_a_detail.png`。
- Godot 当前场景运行入口：`game/presentation/combat/demos/fire_slash_v001/showcase.tscn`。Space 重播，Tab 慢放，P 暂停，Esc 退出。

使用实际小熊猫模型、现有训练场和新制作的简洁长剑。武器已有尖剑刃、古铜护手、皮革握柄与剑首；骨骼攻击动画和握持仍为占位，浅色地面不是最终地牢环境。当前只评审弧面大小、配色、余烬和消散，不代表正式战斗效果质量已确定。

## 本次制作

- 使用 GPUTrail 记录完整剑身的扫动轨迹；跨度 1.6，覆盖临时剑的 1.1 长度并留出外缘火焰。
- 自行编写程序化火焰材质，金黄亮边、橙红半透明内层与流动噪声，不使用新生成图片，也没有取用 VFX-sketchbook 素材。
- 少量橙色余烬由粒子发射。
- `fire_effect.gd` 适配已有的效果接口，停止攻击时冻结轨迹并淡出；暂停冻结粒子、淡出与噪声时间。每次挥砍重启 GPU 拖尾。
- 表现参数位于 `fire_slash.tscn`、`flame.tres`，演示镜头及播放参数在 `settings.tres`；攻击阶段读取已有内容 Catalog，没有增加火焰伤害或修改玩法 JSON。
- 当前演示使用独立场景，不修改主场景、默认战斗效果或项目插件设置。

## 上游来源

GPUTrail by celyk：https://github.com/celyk/GPUTrail

审阅版本：`00a764775941c719847deeda8a31b4ebd8893895`，MIT。

`game/addons/gputrail_preview/` 保留上游脚本、着色器、默认资源与 LICENSE；仅用运行节点，不启用编辑器插件。`flame.gdshader` 的顶点轨迹部分改编自上游 `trail_draw_pass.gdshader`，fragment 火焰外观是本次新增。分发时保留上游版权与许可证。

## 验证和限制

Godot 4.7.2 Forward+ 实际加载并完成录制，普通与近景截图均捕获；`capture.log` 中 `failures=[]`，无运行错误。GPU 耗时来自录制环境，不能当作正式游戏帧率测量。

快速挥砍的弧面仍能看到采样分段，正式动作与材质后续可细化。当前仅制作一个简单小样，待用户选择后继续。
