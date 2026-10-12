extends Resource
## 模型动作约定（只是命名映射，不含战斗数值）。
## 替换模型时：新模型带同名动作即可直接接入；名字不同就在这里改映射。
## 缺失的动作会退回 idle，不会报错，所以可以先接模型、后补动作。
@export_group("基础动作")
@export var idle: StringName = &"idle"
@export var move: StringName = &"run"
## move 动作按 1 倍速播放时对应的移动速度（米/秒）；实际播放速度随角色速度缩放。
@export var move_reference_speed := 6.0
@export var hit: StringName = &"hit"
@export var death: StringName = &"death"
@export var dodge: StringName = &"dodge"
## 蓄力时循环播放（没有就留空）
@export var charge: StringName = &""
@export_group("攻击动作")
## 技能 ID 或表现键 → 动作名。例：{"slash.1": "attack_1"}
@export var attacks: Dictionary = {}
## 找不到映射时依次轮换使用的动作（敌人常用）
@export var attack_fallback: Array[StringName] = []
## 动作名 → Vector2(前摇结束, 判定结束)，单位秒，指动画文件内部的时间。
## 游戏把自己的 前摇/判定/收招 时长分别映射到这三段，所以调数值不需要重做动画。
@export var attack_cuts: Dictionary = {}
@export_group("敌人行为状态")
## AI 状态名 → 动作名。windup / recovery 按进度播放，其余循环播放。
@export var states: Dictionary = {}
@export_group("过渡")
@export var blend_sec := 0.1
## 进入攻击动作的过渡要短，出手才干脆
@export var attack_blend_sec := 0.04
