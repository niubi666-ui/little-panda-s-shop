extends Resource
## 战斗音效配置（combat_audio.gd 读取）。事件名 → AudioCue；按技能/角色选择事件的映射也在这里。
## 想换声音：替换对应 AudioCue 里的 wav；想调音量/音高：改 AudioCue 的参数。
const Cue = preload("res://presentation/audio/audio_cue.gd")

## 事件名 → AudioCue
@export var cues: Dictionary
## 技能出手（cue 帧）的挥砍声：技能 ID → 事件名；没列出的用 default_swing_cue
@export var swing_cues: Dictionary
@export var default_swing_cue: StringName
## 玩家打中敌人：技能 ID → 事件名；没列出的用 default_hit_cue
@export var hit_cues: Dictionary
@export var default_hit_cue: StringName
## 打在未破防的霸体上（替代普通命中声）、霸体被打破
@export var armor_hit_cue: StringName
@export var guard_break_cue: StringName
## 元素：挂上元素（元素 ID → 事件名）、感电放电、反应（反应 ID → 事件名）
@export var element_cues: Dictionary
@export var discharge_cue: StringName
@export var reaction_cues: Dictionary
## 敌人前摇提示：角色 ID → 事件名；没列出的不出声
@export var windup_cues: Dictionary
@export_group("播放")
## 同时能响的音效数量
@export var voices: int
## 左右声道随画面位置偏移的程度（0 为不偏移）
@export var panning_strength: float
@export var bus: StringName
