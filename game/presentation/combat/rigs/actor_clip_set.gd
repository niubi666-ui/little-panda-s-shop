extends Resource
## 模型动作约定（只是命名映射和播放参数，不含战斗数值）。所有字段都在 *_clips.tres 里显式赋值。
## 替换模型时：新模型带同名动作即可直接接入；名字不同就在这里改映射。
## 模型里缺失的动作会退回 idle，所以可以先接模型、后补动作；但映射里列出的攻击动作必须配切点。
@export_group("基础动作")
@export var idle: StringName
@export var move: StringName
## move 动作按 1 倍速播放时对应的移动速度（米/秒）；实际播放速度随角色速度缩放。
@export var move_reference_speed: float
## 平面速度低于这个值（米/秒）播 idle
@export var move_min_speed: float
## move 动作播放倍速的上下限
@export var move_rate_min: float
@export var move_rate_max: float
@export var hit: StringName
@export var death: StringName
@export var dodge: StringName
## 蓄力时循环播放（没有就留空）
@export var charge: StringName
@export_group("攻击动作")
## 技能 ID 或表现键 → 动作名。例：{"slash.1": "attack_1"}
@export var attacks: Dictionary
## 找不到映射时依次轮换使用的动作（敌人常用）
@export var attack_fallback: Array[StringName]
## 动作名 → Vector2(前摇结束, 判定结束)，单位秒，指动画文件内部的时间。
## 游戏把自己的 前摇/判定/收招 时长分别映射到这三段，所以调数值不需要重做动画。
@export var attack_cuts: Dictionary
## 动作名 → Vector4(前摇缓出指数, 挥砍占判定段比例, 挥砍缓出指数, 收招停顿比例)：出刀“快—狠—停”的节奏。
## - 前摇缓出指数 > 1：很快拧到蓄力姿势，然后在顶点“憋住”；1 为匀速。
## - 挥砍占判定段比例：动画在判定段的前这一部分就挥完（0.35 ≈ 判定 0.1 秒里的头 2 帧），剩下时间停在挥到底的姿势。
## - 挥砍缓出指数 > 1：起刀最快、到底减速，像甩出去；1 为匀速。
## - 收招停顿比例：收招段开头保持挥到底的姿势这么久（占收招时长的比例），再收回。
## 只改动画播放方式，不改判定时间。每个有切点的攻击动作都要写；匀速播放写 Vector4(1, 1, 1, 0)。
@export var attack_shapes: Dictionary
@export_group("敌人行为状态")
## AI 状态名 → 动作名。windup / recovery 按进度播放，其余循环播放。
@export var states: Dictionary
@export_group("过渡")
@export var blend_sec: float
## 进入攻击动作的过渡要短，出手才干脆
@export var attack_blend_sec: float
## 受击、闪避这类反应动作的过渡
@export var react_blend_sec: float

## 映射里出现的每个攻击动作都要有切点。返回缺失项，空数组表示完整。
func missing_cuts() -> Array[StringName]:
	var missing: Array[StringName] = []
	var clips: Array = attacks.values() + attack_fallback
	for clip in clips:
		if not attack_cuts.has(StringName(clip)) and not missing.has(StringName(clip)): missing.append(StringName(clip))
	for clip in attack_cuts:
		if not attack_shapes.has(StringName(clip)) and not missing.has(StringName(clip)): missing.append(StringName(clip))
	return missing
