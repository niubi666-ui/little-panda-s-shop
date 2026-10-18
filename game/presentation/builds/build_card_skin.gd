extends Resource
## All card layout and typography are presentation data.
@export var canvas_size: Vector2
@export var card_size: Vector2
@export var cards_top: float
@export var card_gap: float
@export var outer_margin: float
@export var heading_rect: Rect2
@export var subtitle_rect: Rect2
@export var error_rect: Rect2
@export var title_rect: Rect2
@export var binding_rect: Rect2
@export var operation_rect: Rect2
@export var headline_rect: Rect2
@export var description_rect: Rect2
@export var choose_rect: Rect2
@export var ornament_rect: Rect2
@export var surface_inset: float
@export var surface_bottom: float
@export var art_bottom: float
@export var fade_rect: Rect2
@export var body_color: Color
@export var overlay_color: Color
@export var overlay_z_index: int
@export var text_color: Color
@export var muted_color: Color
@export var gold_color: Color
@export var ornament_opacity: float
@export var title_font_size: int
@export var title_min_font_size: int
@export var binding_font_size: int
@export var operation_font_size: int
@export var headline_font_size: int
@export var headline_min_font_size: int
@export var description_font_size: int
@export var choose_font_size: int
@export var rarity_font_size: int
@export var small_label_min_font_size: int
@export var heading_font_size: int
@export var subtitle_font_size: int
@export var fade_texture: Texture2D
@export var ornament_texture: Texture2D
@export var button_texture: Texture2D
@export var button_texture_margin: float
@export var hover_brightness: float


@export_group("Screen")
## 卡牌区（canvas_size）最多占屏幕高度的比例：留出四周让玩家看到场景
@export var screen_height_fraction: float
## 背景：模糊程度（屏幕贴图的 mip 级）、压暗颜色（alpha 为压暗强度）、四角暗角
@export var backdrop_shader: Shader
@export var backdrop_blur_lod: float
@export var backdrop_tint: Color
@export var backdrop_vignette: float

@export_group("Open")
@export var open_sec: float            # 背景变暗、标题落下
@export var heading_drop: float        # 标题从上方落下的距离（画布像素）
@export var deal_delay_sec: float      # 第一张卡开始飞入的时间
@export var deal_stagger_sec: float    # 每张卡之间的间隔
@export var deal_sec: float            # 每张卡飞入用时
@export var deal_rise: float           # 卡从下方多远处升起
@export var deal_scale: float          # 飞入起始缩放
@export var deal_tilt_deg: float       # 飞入起始倾斜（左右两张向外）
## 弹出后这段时间内不接受选择：防止战斗中连点攻击误选
@export var input_lock_sec: float

@export_group("Focus")
@export var hover_speed: float         # 悬停变化的快慢（越大越快）
@export var hover_lift: float          # 选中的卡上浮（画布像素）
@export var hover_scale: float         # 选中的卡放大比例
@export var dim_scale: float           # 其他卡缩小比例
@export var dim_darken: float          # 其他卡压暗比例
@export var glow_size: float           # 卡背后光晕（稀有度颜色）向外扩散的宽度
@export var glow_rect: Rect2            # 光晕底板（相对卡）：必须整个藏在卡框后面，光晕只从它四周向外扩
@export var glow_idle: float           # 平时的光晕强度
@export var glow_focus: float          # 选中时的光晕强度
@export var glow_pulse: float          # 选中时光晕呼吸幅度
@export var glow_pulse_speed: float
@export var press_squash: float        # 按下时缩小比例

@export_group("Pick")
@export var pick_sec: float            # 选中的卡：放大、闪白、上升消失
@export var pick_punch: float
@export var pick_flash: float          # 闪白亮度（1 = 不闪）
@export var pick_rise: float
@export var discard_sec: float         # 没选的卡下沉淡出
@export var discard_drop: float
@export var close_sec: float           # 背景恢复
@export var burst_amount: int          # 选中瞬间迸出的光点
@export var burst_lifetime: float
@export var burst_speed: Vector2       # 最小、最大初速度
@export var burst_gravity: float
@export var burst_size: Vector2        # 最小、最大尺寸
@export var burst_texture: Texture2D

@export_group("Hints")
@export var hotkey_rect: Rect2         # 卡下方的数字键提示（相对卡）
@export var hotkey_font_size: int
@export var tooltip_width: float
