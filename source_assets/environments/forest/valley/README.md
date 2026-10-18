# 樱花溪流山谷（只做 Blender，不进游戏）

上午阳光明媚的樱花溪谷：清澈见底的溪水从上游的小瀑布流下来，两岸樱花盛开、野花和高草茂盛，花瓣在空中飘落、落在地上和水面上，溪边石头上停着山雀，花丛间有蝴蝶。

打开 `sakura_stream.blend` 就能看。默认停在第 300 帧；有本地缓存时花瓣已经满天飘，从第 1 帧播放能看到花瓣一片片落下来。
花瓣下落的本地缓存位于旁边的 `blendcache_sakura_stream/`，可重新烘焙，因此不提交 Git。换电脑拉取后，选中 `Environment/PetalEmitter`，在粒子系统的缓存面板将范围设为 1–900，重新 Bake；若面板仍显示旧缓存已烘焙，先 Free Bake 再 Bake。完成后回到第 300 帧即可恢复预览。也可以从第 1 帧连续播放到目标帧进行临时模拟；下面的 `render` 命令会逐帧推进到目标帧。此 Blender 预览缓存不影响 Godot 游戏运行。

## 文件

| 文件 | 是什么 |
| --- | --- |
| `sakura_stream.blend` | 场景本体（Cycles）。素材是链接的，见下文 |
| `blendcache_sakura_stream/` | 花瓣飘落的本地粒子缓存，不入 Git，换电脑重新烘焙 |
| `build_stream.py` | 搭场景的脚本，可重跑（随机数固定，结果不变）；也能直接出图 |
| `downloads/valley_downloads.blend` | 这个场景从 BlenderKit 下载的素材：主樱树 Sakura Tree、Grass Medium 草丛、苔藓石群、林间石、山雀 |
| `renders/` | 四个镜头的成图 |

素材来源：高精度原件链接自 `../lookdev/fairy_forest.blend`（开花樱树、森林树、蕨、各色野花、扫描石头、毒蝇伞、蝴蝶），
岩壁和地面材质来自 `../kit/forest_kit.blend`。这几个文件要保持相对位置不变，否则 .blend 里会找不到素材。

## 场景里有什么

- **地形**：脚本生成的山谷（约 120 × 175 米），溪流蜿蜒穿过谷底，两岸宽窄各自起伏；上游一道约 2.8 米高的瀑布，下游一道小跌水。
- **水**：真实的水——完全透射、折射率 1.333，水体内部按深度吸收成青绿色（浅处清澈见底、深处发青），顺水流方向拉长的细波纹；
  跌水和瀑布下面按网格上的 `foam` 属性混进白沫。瀑布是三股水帘从岩石之间落下，底下有水雾。
- **光**：物理天空（Nishita）+ 上午约 40° 高的暖色太阳，从西边斜照进山谷；很淡的全局薄雾和贴水面的晨雾；合成里一层很淡的柔光。
  天空亮度（世界的 Background Strength）在 0.1 左右最合适，调高画面会发灰。
- **植物**：两岸十几棵樱树（BlenderKit 主樱树 + 样板间的开花樱树），山坡上的森林，几何节点铺的草（`Scatter/Grass`），蕨、灌木、成片的单色野花。
- **花瓣**：飘落的花瓣是粒子（`Environment/PetalEmitter`，风 `Wind` + 湍流 `Turbulence` 吹着打旋）；地上和水面上的花瓣是几何节点散布（`Scatter/GroundPetals`、`Scatter/WaterPetals`）。
- **鸟**：几只山雀停在溪边石头和倒木上（`Layout` 里名字带 `A_tit` 的），近景镜头前那只叫 `bird_near`。

## 镜头

| 相机 | 看什么 |
| --- | --- |
| `Cam_Hero` | 站在溪中顺流往上游看：樱花夹岸、溪水倒影、远处的瀑布（默认相机） |
| `Cam_Bank` | 蹲在溪边的近景：浅水、苔藓石、野花、山雀 |
| `Cam_Falls` | 瀑布潭 |
| `Cam_Wide` | 从下游高处俯看整个山谷 |

## 出图

```powershell
# 在 source_assets/environments/forest/ 下
& 'E:\blender\blender.exe' --background valley/sakura_stream.blend --python valley/build_stream.py -- render Cam_Hero,Cam_Bank 1920 160 valley/renders
# 重搭场景（改了脚本后）
& 'E:\blender\blender.exe' --background --factory-startup --python valley/build_stream.py
```

在 Blender 里直接按 F12 渲染当前相机也可以（第 300 帧、Cycles、GPU）。1920 × 1080、160 采样一张约 3 分钟（RTX 4060）。

## 想调的话

脚本开头的常数：溪流走向 `xc`、宽度 `halfw`、水位 `wl`（瀑布位置 `FALL_Y`、跌水 `RAPIDS_Y`）、太阳方向 `SUN_DIR`。
摆放在 `build_layout` 里（樱树、石头、野花、鸟的位置）；草和花瓣的疏密在 `build` 里的 `scatter(...)` 调用；花瓣数量和下落速度在 `build_petal_fall`。

“鸟语”只做了画面里的鸟，没有声音。
