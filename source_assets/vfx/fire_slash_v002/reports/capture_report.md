# 火焰斩击 v002：最终实机捕获

## 文件

- `previews/fire_combat_v002.mp4`：1280×800、60 FPS、720帧、12.000秒，4,171,972字节。
- `previews/fire_combat_v002.avi`：Godot Movie Maker原始录制。
- `previews/normal_endpoint.png`：正常速度单次斩击。
- `previews/slow_endpoint.png`：0.4倍速近景末端。
- `previews/combo_endpoint.png`：三连击第三段末端。
- `previews/range_hit.png`、`range_endpoint.png`：实际扣血帧与范围命中末端。
- `previews/tail_cleared.png`：11.9秒时尾效已消失。

路径均相对于 `source_assets/vfx/fire_slash_v002/`。机器结果为 `reports/capture_result.json`；录像／转码日志为 `capture_run.log`、`capture_encode.log`。

## 实际运行结果

使用当前Forward+训练场、小熊猫、长剑、地面、灯光、HUD以及真实能力时间线。通过测试面板既有按钮信号选择 `fire_slash_v002`，选中态显示正确，主要动作未被面板遮挡。

总计6次真实施放：正常单斩，0.4倍速单斩，按实际定义顺序执行 `slash.1 → slash.2 → slash.3`，最后以 `slash.1` 命中2.3499999米处目标。该次判定半径2.5米，造成16点实际伤害，斥候HP由46降至30。所有攻击扇形均为160°，空挥阶段没有伤害。

为了比较效果而暂停敌人AI决策，Actor、AbilityRunner、MeleeResolver、受击反馈及HP状态保持真实运行。主角身体仍使用项目现有占位动作，**本录像没有接入正式骨骼挥剑**。

`capture_result.json failures=[]`。Godot与Blender编码退出码均为0，最终录像720帧与转码一致，未裁剪、未变速处理、未插入概念图。

## 最终视觉核对

已查看最终慢速、三连末段、真实命中及消散帧：白热刃贴合火焰体外沿，橙红火腹向内翻卷；火焰团块尺寸与密度降低后，没有前一版成排巨大图标式团块。火星、长火丝与少量半透明焰舌分层，最终11.9秒截图没有遗留刀光、持续发射、烟或照明光斑。

制作迭代期间发现径向UV翻转导致额外热刃与主体分离。主整合任务为此新效果使用专属body shader，修正径向映射；已有其他刀光不受该修正影响。最终录像是在该修正后重新录制。

## 生命周期回归

`game/tests/fire_slash_v002.gd` 对最终runtime运行98项断言，`failures=[]`。结果见 `runtime_validation.json`、`runtime_validation.md`。涵盖四层粒子与双材质／光源暂停、取消、消散、stroke隔离、切换释放、材质隔离和真实死亡后的暂停恢复。
