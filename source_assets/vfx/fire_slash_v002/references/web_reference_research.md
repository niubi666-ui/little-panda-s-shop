# 火焰斩击网页调研：待实际播放核验

日期：2026-09-27。此文件只记录参考调研，不修改生产资源。

## 真实观看范围与阻塞

**本轮没有成功播放视频或观看GIF动画，也没有看到可用于逐帧判断的实际图片。不能把下面的候选写成“已观看并选定的动画主参考”。**

- Cua `getBrowser` 返回无可用浏览器；尝试创建IAB、Chrome标签页都返回 `Browser is not available`。
- web可读取作者原作页及文字描述，但YouTube嵌入页报无法执行JavaScript；直接GIF报 `Unsupported content-type: image/gif`。
- web对JPEG只返回链接，没有向本轮提供图像像素。图片搜索提供了文字描述，不能等同于我亲自看过图像或动画。
- 未下载任何远程媒体来绕过这些限制，未付费、未安装插件。

## 三个作者原作候选

### 1. De Andre Martin — Fire Sword Slash VFX

原作：[Fire Sword Slash VFX](https://goldmario100.artstation.com/projects/zDrmJm)

作者明确描述：剑上火焰跟随武器运动，移动后有留在后方溶解的火焰；另有命中效果；色彩目标由强烈亮黄过渡至红色，参考Smash Ultimate。

**可借鉴的制作方向，来自作者说明：**将刀刃跟随层、滞后消散层和命中爆发层分开；用有色火焰承担大面积，用更窄的黄白核心强调刃口。不能从文字证明其具体面积比例、速度曲线或“手感很好”。

状态：原作文字已读，动画未观看。建议优先由可播放环境核验。

### 2. Aashish Bharunt — Stylized Sword Slash

原作：[Stylized Sword Slash](https://aashishbharunt.artstation.com/projects/kQq2Qn)

更新版作者视频入口：[Stylized Slash VFX FIXED v_02](https://www.youtube-nocookie.com/embed/A48dJyYvwr0?feature=oembed&rel=0)

作者说明其重点是ribbon与mesh同步，修订了分层、鲜艳配色、扭曲层并加入音效。适合核验“主体弧面＋独立动势层”的组织方式。

**可借鉴的制作方向，属于由作者说明做出的推断：**不要让一张发光贴图承担全部信息；分别安排主弧面、速度线／火舌、扰动以及命中反馈。尚不能确认此片的颜色面积、精确时序或火焰饱满度。

状态：原作文字已读；嵌入页报JavaScript错误，动画未观看。

### 3. Jessica Reel — Sword Slashes VFX - Fire Version

原作：[Sword Slashes VFX - Fire Version](https://wraithnwhimsy.artstation.com/projects/3E91Bv)

作者视频入口：[Fire Sword Slash VFX View 4](https://www.youtube-nocookie.com/embed/vr6Nu29AY9g?feature=oembed&rel=0)

作者描述连续剑击最终接投射物，使用材质和Niagara，并同时放入动画序列和Sequencer。作者本人也表示时序仍可再打磨，因此它更适合做组合与镜头参考，不能直接认定是最终节奏标准。

**可借鉴的制作方向，来自作者说明：**近战拖影与收尾剑气应分别承担扫过和离体飞行，挂接武器时序后再评价。在未播放前不对其“攻击力度”作结论。

状态：原作文字已读，四个展示视频入口可定位，但动画未观看。

## 更有针对性的分层讨论线索

Lucie的原作：[Slash VFX](https://www.artstation.com/artwork/ea8PrX)。本轮ArtStation主页解析落在登录壳，没有成功读取完整作品。

[RealTimeVFX对比讨论](https://realtimevfx.com/t/wip-help-fire-slash-craving-for-tips/20818)有作者Sig的实践和MRvfx的反馈。讨论明确提出：先让强发光火焰出现，随后揭示形状接近的烟层；火与烟可能由两个相近网格错时衔接；使用侵蚀消散可比整体淡出更有形态变化。这是参与者的分析，不能当作Lucie本人确认的底层实现。

建议实际观看时优先核验这个关系：**宽而饱满的橙红火体先成形 → 局部亮核短促闪过 → 火舌向尾部撕裂 → 暗烟和少量余烬更迟离场。**不能从讨论文字给它编造毫秒时长或帧号。

## 对当前项目的制作提案（原创建议，不是参考片测量）

- 保持已认可的大幅160°弧面与现有主刀光尺寸；亮核只占局部窄带，避免全片黄白导致纹理与厚度消失。
- 主体用连续但不均匀的橙红火焰面保证饱满，火舌以数个大小不同的连通团块形成轮廓，再用少量细丝和余烬补充速度。
- 分别控制亮核、主火体、暗部／烟层的寿命与侵蚀，避免所有层一起等比例变透明。
- 保留发力瞬间的短促峰值，收招后用形状撕裂而非匀速长拖尾来消散。准确秒数要在真实小熊猫动作和当前攻击逻辑窗口下调，不能从未播放的网络作品推定。
- 对比时至少看：静帧轮廓是否饱满、正常速度是否能读到主形、慢放是否有层次衔接、在实际明亮训练场里是否仍保留橙红和暗部。

## 结论

已完成原作者链接与文字线索调研，**尚未满足“实际观看动画后确定主参考”的验收条件**。应由具备浏览器播放能力的环境继续观看这些原作，再决定唯一主参考；本文件不能用于声称已经复现某个已观看动画。
