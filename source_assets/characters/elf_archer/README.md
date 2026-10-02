# 精灵弓箭手：头身组合 v001

- 编辑文件：`blender/jingling_assembled_v001.blend`。
- 原始备份：`original/jingling_source.blend`；用户原始 jingling.blend 未修改。
- 调整头身缩放、前后位置和颈部高度；去除头部素材多余肩胸、身体断颈，将下缘收进披风。
- 保留原 UV 与两张打包的 4096×4096 贴图。全身高度约 1.70 m；头身保持独立网格，共同父级 ElfArcher_Assembly。
- 预览：`previews/assembled_front.png`、`assembled_three_quarter.png`、`assembled_side.png`、`assembled_back.png`。
- 本版为静态外观组合：领口采用遮挡搭接，未焊接为连续拓扑，未绑定骨骼。动画制作前需针对颈部转动、头发和披风做权重及穿插检查。
- `scripts/assemble.py` 可从备份重建；只操作自身后台 Blender 进程。
