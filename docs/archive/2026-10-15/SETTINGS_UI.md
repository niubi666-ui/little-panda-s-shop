# ESC 设置菜单 v002

2026-09-27：按 `source_assets/ui/settings/v002` 实作；不是将概念图铺在屏幕上。

## 当前功能

- 店铺 Esc／设置按钮、战斗 Esc 打开同一套菜单；深绿金边主框、羊皮纸、分类页签、叶饰和底部四个操作入口。
- 综合：中英文切换、真实 Master 音频总线滑杆、垂直同步。画面：垂直同步、帧率上限（不限制／30／60／120／144）。读取引擎当前值，概念图百分比不作为默认配置。
- 操作：从 InputMap 显示移动、攻击、闪避、交互键；重绑定和灵敏度为禁用占位。
- 音乐／音效分组、窗口模式／分辨率安全确认、画质预设、正式存读档均明确显示待接入。没有创建虚假存档槽或保存成功提示；保存和读取都进入同一个存档页。
- 返回或 Esc 关闭；退出先显示未保存进度提示，可取消或不保存退出。关闭按钮只有文字。
- 设置即时生效，当前不写磁盘，重启不保留。切换店铺时保留已选中英文。主音量操作真实 Master 总线；没有音频播放时不会凭空产生试听声音。
- 暂停整个 SceneTree，恢复进入菜单前的暂停状态。店铺原有家具弹窗／装修模式优先处理自身 Esc；战斗三选一可临时打开设置，返回后继续原来的选择。

## 模块与维护

- `app/pause_menu.gd`：场景持有的 CanvasLayer，负责暂停所有权、关闭、退出请求。无 Autoload、无业务存档写入。
- `app/settings_actions.gd`：窄设置适配器，操作 TranslationServer／AudioServer／DisplayServer／Engine。
- `presentation/settings/settings_panel.gd`：界面展示、页签、滑杆、占位、退出确认；接收设置适配器注入。
- `presentation/settings/settings_skin.tres`：纹理引用、Atlas裁切、配色、整体尺寸和帧率候选。
- 字体继续由 `presentation/foliage/ui_typography.tres` 单点配置，经共享 Theme 注入；中英文案在 `data/locales`，PO由内容工具生成。

素材 manifest 的非零 alpha 边界仍包含淡透明外边距。实机发现按钮被压扁，故运行资源使用接近不透明图案的裁切范围；源 PNG、源 manifest 均未改写。滑杆为底轨、填充、真实 HSlider 和独立叶片滑块。

## 验证

- `tests/settings_menu.gd`：主音量、帧率、双语四页截图、退出取消、Esc关闭、已有暂停状态恢复。
- `tests/settings_integration.gd`：真实店铺和森林战斗场景通过输入事件打开菜单；暂停期间角色位置／生命不变，关闭后移动恢复；三选一期间 Esc 打开、返回保留选择。
- `tools/content/build_shop_preview_content.py --check`：双语与生成 PO 一致。
- 实机图：`docs/previews/settings_shop.png`、`settings_battle.png`。1280×800 Forward+ 验证通过。

未实现：设置持久化、游戏保存／读取、音频分类与试听、显示模式确认倒计时、画质预设、键位重绑定。旧 Release 文件未覆盖；从当前 Godot 工程运行体验本版。
