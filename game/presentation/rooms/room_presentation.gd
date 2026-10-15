extends Resource
@export var placement_surface: Resource
@export var prop_visuals: Resource
## Scene-level room presentation. Future room selection injects this resource.
@export var template_id: StringName
@export var scene: PackedScene
@export var camera_offset: Vector3
@export var camera_target_offset: Vector3
## 透视镜头的垂直视角（度）。0 表示正交镜头。
## 透视时 camera_size 及其上下限不再是视野高度，而是缩放档位：
## 镜头距离 = camera_offset 的长度 × 当前档位 / camera_size。
@export var camera_fov: float
@export var camera_size: float
@export var camera_min_size: float
@export var camera_max_size: float
@export var camera_zoom_step: float
@export var camera_follow_bounds: Rect2
@export var temporal_antialiasing: bool
## 三维画面内部渲染高度的上限（像素）。0 表示不限制，始终按窗口分辨率渲染。
## 大于 0 时，窗口比它高就降分辨率渲染再放大（FSR 1），用来在高分屏全屏时保住帧率。
@export var render_height_limit: int
## 降分辨率渲染时的最低比例（0..1）：窗口再高也不低于这个比例
@export var render_min_scale: float
## 降分辨率渲染时的放大方式（Viewport.Scaling3DMode）。FSR 为 FSR 1（只在降分辨率时启用）；
## FSR2 自带时域抗锯齿，选它时始终启用，并关闭本房间的 MSAA（TAA 也应在上面关掉）。
@export var render_scaling_mode: Viewport.Scaling3DMode
