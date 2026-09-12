# TILESET_PRODUCTION_REPORT

最终状态：**TILESET_RUNTIME_ACCEPTANCE_PASS**

Godot Version: **4.7.2-stable (steam)** (ed1daf0bf001b61586d9930840f2f1394092c079)。真实 Windows 图形窗口 / forward_plus / d3d12 / NVIDIA GeForce RTX 5060 Ti。编辑器已实际打开项目和测试场景；自动化测试实际运行，使用 GPU Viewport framebuffer 截图，非 headless 渲染。

| 验收项 | 结果 |
|---|---|
| Surface Tiles | **65 structural + 6 decoration = 71** |
| Inner Tiles | **65 structural + 6 decoration = 71** |
| Required families | **20 / 20**；15 个方向族各 NE/SE/SW/NW，5 个非方向族 |
| Surface/Inner Pairing | **PASS**，71 对；逐项核对占格、原点、高度、方向、通行及碰撞多边形 |
| 32×16 Grid | **PASS**，Godot isometric / DIAMOND_DOWN，实际坐标验证 |
| Tile Seam | **PASS**，5 连续地面、楼梯接高台、两向墙角，四倍率均无意外缺口 |
| Character Scale | **PASS**，16×16 可见角色体位于 32×16 格内，24×24 Sprite region / offset=(0,-9) 保持原基线 |
| Draw Order | **PASS**，墙前/后、高台前/后、高台上、楼梯、桥面，两世界共 14 个摆位 |
| Runtime Test | **PASS**，最终 run_03，107 张真实截图，引擎 failures=[] |
| Basic collision | **PASS**，12 次实际 PhysicsPointQuery；墙/柱阻挡、地面无阻挡、拱门中间通行且柱脚阻挡 |
| Editable sample | **PASS**，重新加载保存的 .tscn，10 个 TileMapLayer，两侧每层 cells / logical IDs / transforms 一致 |

## Pixel Scaling

| Scale | Result | 实际比对像素 | RGB 差异像素 | 最大通道差 |
|---|---|---:|---:|---:|
|1x|PASS|872448|0|0|
|2x|PASS|3489792|0|0|
|3x|PASS|7852032|0|0|
|4x|PASS|13959168|0|0|

合计 **26,173,440** 像素；每倍率覆盖全部 142 个原生 Tile（含透明周边）。PNG Alpha 只含 0/255，四张 atlas 均无半透明像素；Lossless compress/mode=0，mipmaps/generate=false，载入图像无 mipmap。CanvasItem 显式 Nearest。所有区域严格整数缩放，无 blur、AA、bleeding。样板概览为 3x；完整验收另有 1x–4x，不以概览替代四档测试。

## Geometry / joins / sorting

64×96 atlas region、pivot=(32,48)、texture_origin=(0,0)。层高 8px、低墙 8px、高墙 24px、柱/拱 32px、悬崖向下 24px。大纹理格只容纳垂直结构，逻辑 footprint 仍 1×1 / 32×16。

Godot 原始 map_to_local(0,0)=(16,8)，(1,0)=(32,16)，(0,1)=(0,16)。样板 layer.position=(-16,-8) 归一化中心。角色脚点使用 layer.position + map_to_local(cell) - elevation，而不是假设 Godot 原始首格在零点。完整规则见 TILESET_SPEC.md。

五连地面实际覆盖 1280 原生像素，与独立投影矩形数学覆盖一致；missing=0、extra=0、overlap=0、colorErrors=0。地面无透明缝、黑线、1px 重叠或错位。楼梯和墙体允许正常的三维投影遮挡（侧面互相覆盖），不把它误报为地面重叠；对照 atlas 轮廓并实机目检，高低连接与墙角无意外缺口。Inner 墙面有明确设计的 1px 分段和银色连接，保持同阻挡多边形。

每个遮挡摆位分别拍仅环境、仅角色、合成画面；所有摆位存在真实像素交叠，前/后预期合成误差均 0。地面同层用 Y-sort；角色站到高台、楼梯、桥面时使用明确上层 z stratum。这是资源摆放合同，本轮没有实现自动高度切换或角色控制器。

## Art / modular contract

Surface 灰白石材、灰绿侧面、低饱和青色嵌饰、稀疏独立植物。Inner 有分段墙/柱/拱体、银色嵌片、切入裂纹、紫灰植物及不同石纹，不是单一 hue shift。可通行桥落脚面保持连续；BRIDGE_BROKEN 是双方都不可通行的独立 GAP 逻辑模块。未来世界专属道路必须替换 logical tile（EMPTY/GAP 与 PATH），不得暗中反转同 ID collision。

现有概念板盘点和重新绘制决策保存于 source_inventory.md。两张新 imagegen 材质源保存于 sources/，只供生产溯源；经过有限色板采样和原生像素几何投影生成可切分透明 atlas。原始概念背景、文字与伪透明格没有进入生产 PNG。装饰独立 source_id=1，结构 source_id=0；预览与生产文件分开。

## Issues

- **BLOCKER: 0 未解决；T-001 已修复。** 初始 64×64 存储格裁掉悬崖/支撑，改为 64×96，全部 alpha bounds 现在具有外部透明余量；逻辑格和角色不变。
- **MAJOR: 0 未解决；T-003 / T-004 已修复。** 首轮测试首格坐标偏差和概览右侧裁切，已通过实际坐标归一化及 3x 概览修正。run_03 完整复验通过。
- **MINOR: 0 未解决；T-005 已修复。** 三种藤/边缘植物现在有不同长度、分枝和基部轮廓，维持独立 overlay。
- **INFO: T-002。** 项目默认 Linear，新增节点继续显式 Nearest。小装饰在 1x 只占数个像素，是稀疏环境点缀，不承载交互提示。

问题在修改前已记录于 tileset_production_work/issues.md，副本 tileset_issues.md。

## Scope and audit

project.godot 及两张已验收 Sprite PNG 的 SHA256 均与任务开始时一致。Renderer、参考分辨率、main scene、Sprite 动画与玩法代码未修改。项目仍未建立新的全局参考分辨率；测试窗口为 1280×960，content scaling disabled，整数节点倍率。未创建正式关卡、PuzzleMechanism、世界切换系统、UI 产品资源、Live2D 或角色控制器。

## Outputs / repeat

- 生产：E:/Study/方块娘项目/若叶睦/photo/production/tilesets/
- 工程：res://production/tilesets/，两份真实 TileSet .tres + 四张透明 PNG + MD/JSON manifest。
- 运行测试：res://tests/visual/tileset_runtime_test.tscn（F6）。
- 可编辑样板：res://tests/visual/tileset_paired_sample.tscn。
- 重跑说明：tests/visual/TILESET_README.md / run_tileset_validation.ps1。
- 最终 [引擎报告](E:/godot/若叶睦/方块少女-若叶睦/tests/visual/tileset_evidence/run_03/engine_runtime_report.json)、[像素报告](E:/godot/若叶睦/方块少女-若叶睦/tests/visual/tileset_evidence/run_03/pixel_runtime_analysis.json)、[实机样板](E:/godot/若叶睦/方块少女-若叶睦/tests/visual/tileset_evidence/run_03/paired_environment_final.png)、[拼接总览](E:/godot/若叶睦/方块少女-若叶睦/tests/visual/tileset_evidence/run_03/runtime_contact.png)。
- 前两轮证据保留；run_02/reference 保存装饰完善前资源，run_03/reference 保存最终实际验收资源。日志 stderr 均为空。
- [TileSetAtlasSource](https://docs.godotengine.org/en/stable/classes/class_tilesetatlassource.html)、[TileData](https://docs.godotengine.org/en/stable/classes/class_tiledata.html)、[TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html) 为 API 依据；以已安装版本实际执行结果为准。

**TILESET_RUNTIME_ACCEPTANCE_PASS**
