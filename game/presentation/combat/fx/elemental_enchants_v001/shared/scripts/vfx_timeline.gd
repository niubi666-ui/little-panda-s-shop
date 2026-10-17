extends Resource
## 特效分层的出场时间表：子节点名 → 延迟秒数（课程里 PlayParticleSystems 的做法）。

@export var delays: Dictionary = {}
@export var lifetime := 3.0         ## 整个特效多久后自动删除，0 = 不删
