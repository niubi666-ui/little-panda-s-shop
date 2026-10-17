太刀动作：UE → Blender 导出验证 v001

最新：已补齐待机、移动和转身动作（2026-10-16）
最新工程：blender/nodachi_character_animation_library.blend
共 204 个独立角色动作：194 个待机/移动/转身源动作 + 10 个原有攻击动作。
本轮 194 个 FBX 全部导出；复用已有战斗待机，新增 193 个 Action。
普通/战斗多方向走跑、起步/循环/停步、冲刺、姿态切换、格挡步行、90/180 度转身均已按类别整理。
打开默认 00_Overview 常用动作总览，约 39 秒；右上角场景下拉可切换 13 个预览场景，空格播放暂停。
原 Attack01、Attack05 在 01_Attacks_Attack01_Attack05 场景中完整保留。
完整清单：reports/animation_library_manifest.csv；使用说明：ANIMATION_LIBRARY_README.txt。
新导出的源 FBX：fbx/locomotion/，按类别分文件夹，只有骨架动画，不重复携带人形网格。
原地移动采用动作包原生 IP 版本；源时长统一到 60 FPS，循环重复仅用于预览。
13 个场景共享同一份身体、武器网格和骨架数据。验证了静止骨架匹配、实际蒙皮运动及 NLA 绑定。
仍使用动作包自带 Manny 人形，尚未重定向到游戏主角，尚未接入 Godot。

以下为之前的两次导出记录：

新增 Attack05：
最新合集工程：blender/nodachi_animation_review_attack01_and_05.blend
保留 Attack01 的 6 段预览，并追加 Attack05 四段攻击和完整连击，共 11 段。
Attack05：830–975、994–1159、1178–1318、1337–1507；完整连击 1526–1826（5 秒）。
新增 FBX 位于 fbx/attack05/；完整连击视频为 previews/nodachi_attack05_full_combo.mp4。
原工程仍保留，用于对比。新增动作已验证静止骨架匹配与实际网格运动，保持源速度和位移。

来源工程：D:/UE5 test/Test58/Test58.uproject
来源内容：/Game/Nodachi/Animations/Sequence
导出方式：UE 5.8.3 Python AssetExportTask / FBX 2018；启用渲染器的独立 commandlet。
武器挂点：通过正在运行的 UE 官方 MCP 查询 Nodachi_Weapon_RSocket，父骨骼 Nodachi_Weapon_R，局部变换为单位矩阵。

blender/nodachi_animation_review_v001.blend
打开后按空格播放/暂停。默认完整播放范围 1–811，60 FPS。
底部 NLA 轨道含 6 段，各动作同时独立保存在 Actions 中。

帧范围         内容                       源时长
1–121          战斗待机（展示前 2 秒）    完整 Action 保留 10 秒
140–250        连击第 1 段                1.833333 秒
269–359        连击第 2 段                1.5 秒
378–468        连击第 3 段                1.5 秒
487–592        连击第 4 段                1.75 秒
611–811        完整四连击                 3.333333 秒

原始 FBX：fbx/。动画 FBX 各自包含预览模型、骨架和动画；另有独立参考人形及太刀。
视频：previews/nodachi_full_combo.mp4（完整连击，60 FPS，轻量预览材质）。
静帧：previews/idle_front.png（Blender 实际渲染）。
检查记录：reports/ue_export.json、blender_review.json、weapon_socket.json、live_playback.json。
可复现脚本：scripts/。导出脚本不保存或修改 UE 原始动画资产。

验证结果：6 个动作成功导入；骨架静止姿势一致；实际网格随动画变形；太刀跟随专用武器骨骼；已在可见 Blender 窗口播放。
待机源文件为 24 FPS，攻击源文件为 60 FPS，已按原时长转换为统一 60 FPS。
源动画含空间位移，评审相机只跟随角色 XY，未把动作强行改为原地。
NLA 的短停顿和切换仅用于逐段评审，不代表游戏中的连招过渡。

范围说明：本次使用动作包自带 Manny 人形。预览材质为简化材质，未完整转换 UE 材质。
尚未重定向到 ShopGame 主角，尚未接入 Godot。下一步需完成主角骨架重定向、握刀适配、根位移处理，再导出 GLB 并配置游戏动画资源。
