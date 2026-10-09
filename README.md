# 小熊猫的小店 / Little Panda's Shop

Godot 4 单人动作肉鸽与店铺经营原型。当前实现状态见 [docs/HANDOFF.md](docs/HANDOFF.md)，开发先读 [AGENTS.md](AGENTS.md) 和 [PROJECT_CONTRACT.md](PROJECT_CONTRACT.md)。

## 换一台 Windows 电脑运行

1. 安装 Git 与 **Git LFS**。本项目的模型、Blender 源文件、贴图、字体等使用 LFS，网页 Download ZIP 不能替代已验证的 Git + LFS 拉取方式。
2. 拉取完整资源：

   ```powershell
   git lfs install
   git clone https://github.com/niubi666-ui/little-panda-s-shop.git
   cd little-panda-s-shop
   git lfs pull
   git lfs fsck
   ```

3. 使用当前验证版本 **Godot 4.7.2 stable 标准版**打开 `game/project.godot`，等待首次资源导入完成。项目使用 Forward+，需要支持它的显卡与驱动。
4. 按 F5 从店铺开始，F6 进入战斗训练。训练工具可以刷新精英游侠；开场三选一完成后再操作训练按钮。

当前战斗操作：左键三连击、右键重斩、Q 剑气（瞬发，基础冷却 1 秒）、Shift 闪避。三个攻击动作同时可用，剑气不需要先抽到解锁卡；当前 Build 配置为 schema v6。

已有克隆的电脑更新时，在没有未提交修改的情况下执行 `git pull --ff-only`，随后执行 `git lfs pull` 和 `git lfs fsck`。若本机有未提交工作，先保存或提交，再合并更新；不要用强制重置覆盖自己的修改。

**工程可以放在任意目录，不需要 E 盘。** 主程序只读取项目内资源；第一次导入可能需要几分钟，`.godot/` 缓存无需从旧电脑搬过来。仅运行游戏不需要安装 Blender、Python 或 MCP。

## 使用根目录启动脚本

脚本统一通过 `tools/launch_godot.ps1` 找到引擎，依次读取：

- 环境变量 `GODOT_BIN`；
- `tools/local_config.json` 的 `godot_executable`（可复制同目录 example 文件后填写实际路径）；
- PATH 中的 `godot` / `godot4`；
- 旧开发机的安装位置（兼容现有电脑）。

`tools/local_config.json` 被忽略，不会把新电脑设置覆盖到别人的电脑。也可以始终在 Godot 编辑器里启动对应场景。

## 继续开发

- **代码与内容**：Godot 标准版即可。内容校验使用 Python 3.11+，独立安装依赖：

  ```powershell
  python -m venv builds/content_venv
  ./builds/content_venv/Scripts/python.exe -m pip install -r tools/content/requirements.txt
  ./builds/content_venv/Scripts/python.exe tools/content/build_shop_preview_content.py --check
  ```

- **美术**：源文件在 `source_assets/`，当前使用 Blender 5.2.1 LTS。原图/贴图随仓库或 Blender 打包保存。Auto-Rig Pro 等本机工具、Godot/Blender 安装包不入库；需要重新装到新机器。
- **AI/MCP**：连接配置、登录与凭证是电脑环境设置，不由 Git 同步，需要在新电脑重新配置；游戏运行本身不依赖 MCP。
- **旧制作/验证工具**：部分历史导出脚本和截图输出仍写有旧机路径，运行前检查相关脚本。常规 Godot 开发和主场景不依赖这些路径。图片/录像制作工具还可能需要 Pillow、NumPy、imageio-ffmpeg；它们不是游戏运行依赖。
- 不同步 `builds/`、`.godot/`、虚拟环境、日志、旧 Release 和自动备份。此前电脑上的临时训练/装修状态及 `user://` 设置也不属于仓库。

## Git 约定

仓库保存代码与必要美术源文件，二进制素材使用 Git LFS。提交前核对 `git status`；提交后用普通 `git push` 同时上传 Git 提交及对应 LFS 对象。没有用户新授权时，Agent 不自动提交、推送或制作 Release。详见 [版本管理](docs/LOCAL_GIT.md)。
