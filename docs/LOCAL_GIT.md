# 本地版本管理

- 仓库根目录为 `E:/ShopGame`。当前仅使用本地 Git，无远端；初始化后，只有用户明确要求时才提交。添加远端或上传也须用户明确要求。
- 入库：Godot 代码、场景、配置、测试、运行资源，内容/美术工具，源 `.blend`、纹理与烘焙输入，概念图、静态验收图和项目文档。源资产较大是正常现象，不把不可替代的美术源文件当缓存排除。
- Godot 的 `.uid`、资源旁的 `.import` 设置和运行用 PO 保留；`game/.godot/` 可由编辑器重新生成。
- 忽略：`builds/`（含构建包、本机虚拟环境、验证输出）、缓存、日志、临时文件、Blender 自动/明确备份、过程录像/原始预览帧、本机 Blender 工具拷贝及教程。文件仍留在本机。
- `little_pandas/` 是 `source_assets/characters/red_panda/original/tripo_v002/` 的重复投递；小熊猫 `exports/*.glb` 是可重新导出的副本，源文件与 `game/assets/` 下的运行版本均入库。
- `source_assets/**/*.import` 是复制到素材目录的 Godot 导入元数据；使用 `game/` 中的正式版本，素材目录副本忽略。
- 不整体忽略 `source_assets/`、`exports/` 或 `reports/`：其中包含 UI 成品、必要高模输入和生成脚本使用的元数据。
- 具体规则以根目录 `.gitignore` 为准。二进制素材直接存入本地 Git，未启用 Git LFS。只修改忽略规则不会删除本地文件。

日常只读检查：`git status --short`、`git diff`、`git log --oneline -5`。提交前检查暂存范围；代码、配置与对应文档保持一致。不要把日志或 Release 包强制加入仓库。

重新打开工程使用 `game/project.godot`；Python 校验依赖见 `tools/content/requirements.txt`，可在被忽略的 `builds/content_venv/` 中重建。已有素材生成工具中的本机绝对路径仍须按机器调整；本次 Git 初始化不代表它们已全部改为可移植路径。
