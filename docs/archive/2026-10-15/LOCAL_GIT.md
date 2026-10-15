# 版本管理与换机同步

- 当前工作目录为 `E:/ShopGame`，新电脑可以使用任意目录。用户已授权本次迁移至 `https://github.com/niubi666-ui/little-panda-s-shop`，远端分支为 `main`；本地保留原 `master` 分支并跟踪 `origin/main`。未来仍只有用户明确要求时才提交、上传或修改远端。
- 入库：Godot 代码、场景、配置、测试、运行资源，内容/美术工具，源 `.blend`、纹理与烘焙输入，概念图、静态验收图和项目文档。源资产较大是正常现象，不把不可替代的美术源文件当缓存排除。
- Godot 的 `.uid`、资源旁的 `.import` 设置和运行用 PO 保留；`game/.godot/` 可由编辑器重新生成。
- 忽略：`builds/`（含构建包、本机虚拟环境、验证输出）、缓存、日志、临时文件、Blender 自动/明确备份、过程录像/原始预览帧、本机 Blender 工具拷贝及教程。文件仍留在本机。
- `little_pandas/` 是 `source_assets/characters/red_panda/original/tripo_v002/` 的重复投递；小熊猫 `exports/*.glb` 是可重新导出的副本，源文件与 `game/assets/` 下的运行版本均入库。
- `source_assets/**/*.import` 是复制到素材目录的 Godot 导入元数据；使用 `game/` 中的正式版本，素材目录副本忽略。
- 不整体忽略 `source_assets/`、`exports/` 或 `reports/`：其中包含 UI 成品、必要高模输入和生成脚本使用的元数据。
- 具体规则以根目录 `.gitignore` 为准。模型、Blender源文件、纹理、字体等二进制素材由 `.gitattributes` 指定使用 Git LFS；新电脑必须安装 LFS 并拉取真实对象。只修改忽略规则不会删除本地文件。

日常只读检查：`git status --short`、`git diff`、`git log --oneline -5`。提交前检查暂存范围；代码、配置与对应文档保持一致。不要把日志或 Release 包强制加入仓库。

换机步骤与引擎启动路径配置见根目录 [README](../README.md)。重新打开工程使用 `game/project.godot`；Python 校验依赖见 `tools/content/requirements.txt`，可在被忽略的 `builds/content_venv/` 中重建。部分旧素材生成/截图工具中的绝对路径仍需按机器调整；不等于主程序运行依赖旧电脑。

迁移前原历史备份放在旧电脑的 `builds/git-migration-backup/`，不会上传。历史 LFS 转换仅在本次迁移时执行；日常开发不用再次迁移或强制推送。不要通过清空 `.git/lfs/` 来节省空间，先确认对应对象已上传。
