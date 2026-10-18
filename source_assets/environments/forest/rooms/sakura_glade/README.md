# 樱花林空地（sakura_glade）

第一区的战斗场景，也是训练场现在用的场景（原来的“童话森林第二版”，2026-10-18 改名整理）。

- `sakura_glade.blend`：
  - `Terrain`：地面 `Ground`（材质 ArenaGround，与 Godot 地面着色器同一套公式，所以 Cycles 渲染图就是游戏画面的对照目标）、水面 `Brook`
  - `Layout`：4035 个素材实例，全部链接自 `../../kit/forest_kit.blend`
  - `Lighting`：太阳、光束灯、提灯、雾、镜头；`Motes`：空气里的光尘（只在 Cycles 里）
  - 场景自定义属性 `forest_room`：场地常数（play_half、water_z、stream_half、bridge_x），导出时写进 layout.json
- 这个场景最初是脚本生成的（`../../lookdev/build_game_arena_v2.py`），现在以这个 .blend 为准，直接在里面改摆放即可，不用再跑生成脚本。

游戏里：`game/presentation/rooms/forest/sakura_glade/`。游戏里额外做的调整（不在 Blender 文件里）：
桥隐藏、草的疏密（`density_keep`）、水面抬高 0.25 米、活动范围、落樱花瓣，都在 `room.tscn` 里。
