古树圣庭 v004 · 自然环境微风评审
================================
制作日期：2026-10-02

打开 previews/index.html 查看实际视频与入口。
Blender 完整场景：blender/grand_forest_sanctuary_v004_breeze.blend
Godot 独立样例：项目根目录“启动环境微风预览.cmd”

本轮实现
--------
1. 793 个圣树叶团模块做根梢加权弯曲，树干、粗根保持稳定。
2. 6,944 个花草部件使用23份原型，组织为552组共享形变实例批次。
   蕨类的叶轴与叶片、铃花的茎叶与花铃使用相同整株尺度和摆动相位。
   根部权重为0，越靠近叶梢/花梢越容易摆动。
3. 主摇摆、较慢阵风、小幅局部颤动叠加；地面斑驳树影的辅助几何轻微漂移。
4. 地面苔藓、碎落叶、建筑与碰撞相关的原始几何保持原样。
5. Godot GPU Shader 独立样例使用真实蕨类、铃花与树冠资产。
   时间由预览宿主控制，空格暂停；不是每帧CPU重建模型。

Blender 使用
------------
打开v004文件，空格播放时间线。动画参考时长10秒，可延长结束帧连续播放。
选择“BREEZE_controls”空物体，在自定义属性中修改strength：0静止、1自然微风。
可用相机：Camera_Panorama、Camera_Gameplay、Camera_Breeze_Flowers、Camera_Breeze_Canopy。
密集花草的原始对象保留但隐藏；WIND_animated_flora_batches提供动态绘制。
WIND_INTERNAL_shared_sources 是共享原型来源，隐藏但供节点读取。
不要同时显示原始花草和动态批次，否则会重复绘制。

Blender自然风参数在 scripts/breeze_profile.json 中，修改后运行build_breeze.py重新生成派生版本。
几何节点主要用于美术预览；Godot运行时使用独立顶点Shader，二者没有自动互相导出关系。

Godot 使用
----------
入口：game/presentation/environment_wind_v001/breeze_preview.tscn
风动参数：该目录natural_breeze.tres；GPU程序：breeze.gdshader。
空格暂停/继续；1/2/3切换微弱/自然/较强；Tab切换对象；滚轮缩放；右键拖动旋转；Esc退出。
这是独立的材质与动作评审场景，未替换正式战斗房间，没有修改玩法或存档。

画面与性能边界
--------------
花草近景视频采用实际Cycles渲染。树冠/全景动态评审视频采用EEVEE，
间接光、透光与Cycles有差异；保存的Blender主文件仍保留原Cycles灯光与材质。
Godot样例将Blender程序叶色/噪声/透光混合简化为PBR代表色，保留树冠贴图、法线、UV和裁切；
该样例的摄影棚灯光不等于完整庭院光影。
Blender花草批次按8种局部方向、3组相位复用形变；Godot样例采用连续空间/实例相位。
本轮未验证完整庭院在Godot中的帧率，不把几何共享或小样运行通过当作全场景性能结论。
短片末尾回到开头有时间跳转；它们是实际时间段的展示，不是无缝循环动画。

验证记录
--------
reports/breeze_validation.json：710份原网格的几何/UV/材质槽、10,000个原对象位置、
26盏原灯光均通过对照；根部固定，树冠跨帧实际变形且三角面不变；原v003文件哈希不变。
reports/sample_export.json：样例GLB与导出限制。源材质名末尾_Alpha会触发Godot透明导入提示，
已改名CutoutMaterial；实际导入MASK裁切阈值0.42，图集法线强度0.72。
game/presentation/environment_wind_v001/README.txt记录Godot解析/素材/材质/暂停专项检查。
GPU录制日志和视频位于reports/godot_gpu_capture*.log及previews/breeze_gpu.mp4。

原始v003文件保留，既有Blender窗口未操作。没有生成Release。
