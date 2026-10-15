extends Resource
## 一个音效事件：从 streams 里随机挑一条播放，音量与音高带一点随机，避免机械重复。
@export var streams: Array[AudioStream]
@export var volume_db: float
@export var pitch_min: float
@export var pitch_max: float
## 同一事件两次播放的最短间隔（秒）：多弹同时命中时不叠成噪音
@export var min_interval_sec: float
