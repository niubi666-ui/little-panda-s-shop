extends Resource
## 战斗反馈配置（presentation/combat/combat_juice.gd 读取）：受伤屏幕闪红、低血量脉动、
## 击杀爆点、闪避尘土、底部生命条。纯表现，删掉不影响判定。
@export_group("受伤与低血量")
## 屏幕四周压暗的材质（fx/hurt_vignette.gdshader）
@export var vignette_material: ShaderMaterial
## 受伤闪红从最亮退到 0 的时长
@export var hurt_fade_sec: float
## 低血量脉动：角速度（弧度/秒）、脉动最低点（0..1）、叠加到闪红上的权重
@export var low_pulse_speed: float
@export var low_pulse_floor: float
@export var low_vignette_weight: float
@export_group("击杀与闪避")
## 敌人死亡时在身上爆开的一次性粒子（CPUParticles3D 场景，参数在场景里调）
@export var kill_burst: PackedScene
@export var kill_burst_height_m: float
## 闪避起步时脚下的尘土（CPUParticles3D 场景）；喷射方向由代码按闪避反方向设置
@export var dodge_puff: PackedScene
@export var dodge_puff_height_m: float
## 尘土方向向上抬起的比例（0 为贴地平喷）
@export var dodge_puff_lift: float
@export_group("生命条")
@export var vitals: Resource
