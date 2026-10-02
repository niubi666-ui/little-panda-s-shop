# 火焰刀光 v002 生命周期回归

测试入口：`game/tests/fire_slash_v002.gd`。

实际执行 Godot 4.7.2 `--headless --fixed-fps 60`，共98个断言，最终 `failures=[]`。机器结果见 `runtime_validation.json`，日志见 `runtime_headless.log`。

覆盖以下实际接口与对象：

- 身体火焰与热刃独立材质实例，共享相同拖尾几何。
- 全部四层CPUParticles：Particles、FlamePlumes、LongSparks、SmokeWisps。
- 活动期间暂停冻结各层 `speed_scale`、拖尾位置／年龄、两个shader动画相位、闪光时钟、光强和光位置。
- 暂停期间修改播放速率不会恢复任何粒子；继续后所有粒子使用设定速率。
- 取消停在最后剑姿，不生成回拉弧线，停止所有新粒子，并保留已生成尾迹自然消散。
- 尾迹及热刃清空、灯光归零隐藏、各层停止发射，并等待最长原生粒子寿命。
- 两次挥砍有独立stroke ID，不出现连接两次攻击的三角形；旧拖尾保持世界位置。
- clear立即清理所有表现层。
- 切换释放旧粒子、top-level热刃与光源；暂停切回不会恢复旧stroke。
- 不同实例的body和热刃材质互不干扰。
- 通过真实HealthRuntime死亡取消能力，各层停止新发射；死后暂停及继续正确冻结／恢复尾效时钟。

## 本次发现并修正的问题

首次运行暴露6项死后暂停失败：ActorView在死亡／隐藏分支提前返回，残留刀光及光源时钟继续运行，四层粒子仍以1倍速更新。主整合任务已把 `set_time_running(delta > 0)` 移至死亡提前返回之前。此回归没有放宽断言，修复后98项全部通过。

这是生命周期和对象状态验证，不等于通过无头渲染观察每个原生粒子位置。实际Forward+截图和视频另由capture入口验证，末尾 `tail_cleared.png` 用于目视检查自然消散。
