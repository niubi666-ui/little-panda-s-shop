# 美术资源目录与交付规则

本目录保存可编辑源资产和制作记录。概念图继续位于根目录 `concepts/`；验收后的运行资源放入 `game/assets/`。工程边界以 `../PROJECT_CONTRACT.md` 为准。

## 当前目录

```text
source_assets/
  characters/
    red_panda/
      original/tripo_v001/   Tripo原始FBX及配套.fbm贴图目录
      blender/              可编辑.blend源工程
      textures/             后续编辑过的贴图源文件
      exports/              待验收的GLB等候选导出
      previews/             动作/模型截图与预览视频
      reports/              检查结果与资产记录
  environments/
    shop/                   主店、小院与扩建建筑源文件
    dungeon/                按主题进一步划分的房间/模块源文件
  props/                    家具、商品、武器、装饰等独立物件
  materials/                可复用材质与纹理源文件
  ui/                       界面与图标源文件；已选树叶风格参考见 ui/reference/foliage_v001/
  vfx/                      战斗及环境特效源文件
```

新的角色或重要资产按需采用 original、blender、textures、exports、previews、reports 子目录，不一次创建所有空资产目录。环境模块用稳定英文名称，独立交互物件不合并进整栋建筑网格。

## 命名与版本

- 路径采用英文小写和下划线，例如 `characters/red_panda`。这是资产ID，不决定玩家给主角起的名字。
- 原始下载文件保留供应方名称及配套文件夹结构，放入 `original/<来源>_v001/`；后续下载使用新版本目录，不覆盖旧版本。
- Blender工作文件采用 `<资产>_<来源或用途>_v001.blend`；诊断文件带 `review`，不要当成验收版本。
- 原始文件不直接改写；修改在.blend和派生贴图中进行。来源、日期、参考图、商用授权凭据及处理记录随资产保存，授权信息缺失时如实标记待补充。
- 打包贴图或使用可解析的相对路径，避免只在某台机器能打开；版本间记录骨架、动作名和材质变化。

## 从源资产到游戏

1. 原始素材归档至 original。
2. 在 blender/ 中检查/修整网格、骨架、权重和动作。
3. 在 previews/ 与 reports/ 保存可复核的检查结果。
4. 候选导出放在 exports/，通过蒙皮、材质、动画及Godot导入验证后，再交付到 `game/assets/characters/red_panda/` 等对应位置。
5. .tscn场景组装与.tres表现映射遵守代码架构；碰撞和命中规则不能由导入网格自动替代。玩法参数仍来自规定的JSON配置。

已建立Godot工程与首个店铺实机预览，见 [店铺接入说明](../docs/SHOP_PREVIEW.md)。面数、贴图尺寸、动作数量和角色世界尺寸随实机测试调整，不把某次Tripo导入值当成项目标准。

## 本次归档

- `little_pandas/` 为用户原始投递目录，内容已复制到 `characters/red_panda/original/tripo_v001/`，投递目录保留。
- 当前检查结果见 [主角检查报告](characters/red_panda/reports/tripo_v001_review.md)。此版本存在明显动画变形，尚未通过美术验收。
- 新增五动作来源已归档至 `characters/red_panda/original/tripo_v002/`。最新工作版本为 [绑定修订v002](characters/red_panda/reports/rig_v002_review.md)：新增尾骨、修复尾巴与手部权重；v001报告保留为历史检查记录。
