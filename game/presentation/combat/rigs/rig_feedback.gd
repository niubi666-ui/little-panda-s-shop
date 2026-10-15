extends Resource
## 骨骼角色的表现手感（rigged_actor_visual.gd 读取）：转身、受击闪白/抖动、尸体消散、前摇泛光。
## 与模型无关，换模型时不用动；同类角色共用一份（见同目录 rig_feedback_*.tres）。
@export_group("转身")
## 主角：移动时身体朝移动方向，出招时转向瞄准方向
@export var face_movement: bool
## 转身的阻尼（越大越快）
@export var turn_sharpness: float
## 平面速度超过这个值（米/秒）才按移动方向转身
@export var face_min_speed: float
@export_group("受击表现")
## 受击闪白时长（没有 HitFeedback 的一方，例如玩家；0 表示不闪）
@export var own_flash_sec: float
@export var flash_color: Color
## 受击时模型抖动幅度（米）、时长、抖动角速度（弧度/秒）
@export var hit_shake_m: float
@export var hit_shake_sec: float
@export var hit_shake_speed: float
@export_group("死亡")
## 倒地后停留多久开始消散；消散用时。消散结束后由 ActorView 隐藏。
@export var corpse_hold_sec: float
@export var corpse_fade_sec: float
## 倒地后一直保留、不消散（主角用；需同时在表现配置里打开 retain_corpse）
@export var keep_corpse: bool
@export_group("预警")
## 前摇时身体泛光的强度（随前摇进度增强；0 为不泛光）
@export var telegraph_glow: float
@export var telegraph_color: Color
