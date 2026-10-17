太刀动作库 / NODACHI ANIMATION LIBRARY

最新工程：nodachi_character_animation_library.blend
空格播放 / 暂停。右上角“场景”下拉选择：
00_Overview — 常用动作总览：待机 / 步行 / 跑步 / 冲刺 / 转身 / 攻击 (18 段)
01_Attacks_Attack01_Attack05 — Attack01 和 Attack05 原有攻击 (11 段)
02_Idle_and_Stance — 待机与战斗姿态切换 (4 段)
03_Walk_Normal — 普通姿态多方向步行 (30 段)
04_Walk_Combat — 战斗姿态多方向步行 (30 段)
05_Walk_Block — 格挡姿态多方向步行 (24 段)
06_Walk_Transitions — 步行姿态切换 (2 段)
07_Run_Normal_and_Sprint — 普通跑步与冲刺 (45 段)
08_Run_Combat_and_Sprint — 战斗跑步与冲刺 (45 段)
09_Run_Transitions — 跑步姿态切换 (2 段)
10_Turn_Normal — 普通姿态原地转身 (4 段)
11_Turn_Combat — 战斗姿态原地转身 (4 段)
12_Turn_Block — 格挡姿态原地转身 (4 段)

共 204 个独立角色 Actions：194 个待机/移动/转身源动作 + 10 个攻击动作。
本轮导出 194 FBX；其中战斗待机复用已有 Action，因此实际新增 193 Actions。
统一以 60 FPS 保持源时长播放，循环动作在分类预览中重复两次。
普通/战斗待机各展示前 3 秒；完整 10 秒源 Action 仍保留。
IP = 动作包的原地移动版本；RM 版本和 additive 瞄准偏移未重复导入。
所有场景共享人形网格、骨架数据与太刀网格，动画独立编排。
使用动作包自带 Manny 人形；尚未重定向到游戏主角或接入 Godot。
预览的动作切换是分段展示，不是游戏动画状态机。
清单：reports/animation_library_manifest.csv
