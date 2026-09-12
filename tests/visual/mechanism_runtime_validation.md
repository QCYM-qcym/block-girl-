# PUZZLE_MECHANISM_PRODUCTION_REPORT

最终状态：**PUZZLE_MECHANISM_RUNTIME_ACCEPTANCE_PASS**

Godot Version: **4.7.2-stable (steam)** (ed1daf0bf001b61586d9930840f2f1394092c079)。真实 Windows 图形窗口、forward_plus / d3d12、NVIDIA GeForce RTX 5060 Ti。Godot 编辑器已打开本工程和测试场景；资源导入、运行与帧缓冲观察均已完成。最终证据为 run_03。

| Item | Result | 实际验证 |
|---|---|---|
| Pressure Plate | **PASS** | idle→真实 Area2D 进入 pressed→active→离开→解除 active 回 idle；按下 2px 高度差，角色在上方 |
| Door | **PASS** | closed→opening→open→closing→closed；点查询和 CharacterBody2D.test_move 证明 closed 阻挡、open 可通行；open 中央门扇已完全移除 |
| Moving Platform | **PASS** | idle/moving/arrived；两条等距轴及屏幕水平移动；整数坐标、支持碰撞、角色同步、来回精确停靠 |
| Rotator | **PASS** | A→90°离散过渡→B→A；支持多边形随端态改变，过渡禁用支持，重复输入被拒绝；Sprite 和 Camera 均不旋转 |
| Exit | **PASS** | locked 拒绝触发，ready 遇角色进入变 active，complete 动画结束进入 completed；无关卡跳转 |
| World Switch Device | **NOT_INCLUDED** | 本轮未实现实体装置或完整世界切换系统 |
| Surface/Inner Parity | **PASS** | 5 对 logical IDs，同 footprint / pivot / state orders / activation / collision 类型；物理行为两侧均验证 |
| Pixel Scaling | **PASS** | 全部 50 原生帧在 1x–4x 与实际 GPU 像素一致 |
| Draw Order | **PASS** | 压力板上、移动平台上、门前、门后共 8 个双世界摆位 |
| Interaction Test | **PASS** | 实际 Area2D、PhysicsPointQuery、CharacterBody2D passage、动画完成回调与平台平移 |

## Production / baseline

10 张透明生产 PNG、每世界 25 个原生帧、10 个可独立拖入的场景（每类 Surface 和 Inner 各一个）、10 个 SpriteFrames .tres、5 个局部脚本和一个共用视觉 helper。场景内嵌经过同一构建验证的 SpriteFrames，独立 .tres 同时提供；以后修改动画应通过构建器同步场景与独立资源。

所有逻辑机关 1×1 / 32×16，固定 frame 64×96、pivot=(32,48)、Sprite offset=0。沿用层高 8、固定左上光和既有色板密度。压力板局部按钮高差 2px，不改变建筑层高。门高 24px，本批只提供 NE/SW 通行方向；不把屏幕旋转冒充另一朝向。旋转台端态条形平台 16×8 局部单位，固定中心和旋转底座；过渡视觉扫掠可略过格边约 1 局部单位，此时支持禁用，不是扩展可走范围。

项目全局设置、已验收 Sprite / Tileset PNG、.tres 和 .tscn 共 **13** 个基线文件 SHA256 均不变（完整列表 delivery_verification.json）。没有改 project.godot 的 renderer、main scene 或全局参考分辨率。测试窗口 1280×960，content scaling disabled，整数节点倍率。

概念盘点在生产前完成。两张旧机关板为 NEEDS_REDRAW；新 imagegen 状态源保留于 sources/，其概念背景和不规则网格未进入生产文件。最终生产文件是精确原生像素几何重建的状态图集，Surface 使用灰白/灰绿，Inner 使用蓝灰、银色、紫灰与分段柱体。状态差异来自压下、门扇收拢、轨纹位置、条形朝向、空心/实心/完成几何，不单靠色相。

## Pixel quality / anchor / readability

| Scale | 实際比对像素 | 差异像素 | 最大 RGB 通道差 |
|---|---:|---:|---:|
|1x|307200|0|0|
|2x|1228800|0|0|
|3x|2764800|0|0|
|4x|4915200|0|0|

总计 **9,216,000** 像素，覆盖全部 50 帧及其透明边缘。Alpha 只有 0 和 255；Lossless compress/mode=0、mipmaps=false，实际载入图像无 mipmap。Nearest 在机关、角色和测试根节点显式设定。固定区域、固定 pivot、整数摆放，无状态空帧、无非预期位置或大小跳变。旋转/开门/完成时的轮廓变化是状态本身；底座保持同一位置。

每种动画在真实 AnimatedSprite2D 中播放并观察所有帧，38 个“机关/动画/世界”组合均覆盖预期帧序。静态 frame atlas 比对使用相同 Nearest 的原生区域；交互行为和动画另由真实可复用场景运行验证。1x 中的细小呼吸是克制装饰，不承载唯一状态信息；locked/ready/active/complete 仍有独立几何差异。此为技术美术可读性目检，未声称完成玩家可用性研究。

## Physics / movement / depth evidence

移动测试目标（相对起点原生屏幕坐标）：(32,16)、(-32,16)、(32,0)。前两者是两个等距地面轴，第三个是屏幕水平。每条路径往返；累计 210 个双世界移动采样，position 始终整数、角色相对平台偏移始终 (0,0)、Support 节点共享根坐标，实际支持点查询始终命中，结束严格等于目的地。非格点 (1,1) 被拒绝。测试中的角色跟随只由测试脚本订阅 translated(delta)，没有伪装成正式载客控制器。

Layer 1=门的阻挡，layer 2=平台支持面，layer 4=验收角色。这是等距俯视的支持语义，不是一个带重力的完整平台游戏物理系统。旋转中禁用 support/trigger 并锁定输入，B 完成后实际查询证明支持方向从 X 转 Z，再返回 A。该过渡不允许角色承载；正式谜题如何禁用操作由后续关卡逻辑决定。

压力板/出口等待的是实际 Area2D 状态和 overlap，设 30 physics-frame 超时；最终实际需要 2–3 帧。门中央闭合与开启分别进行了真实 test_move 通行测试。开门中碰撞保持阻挡，open 完成时解除；门柱永久阻挡保留。

每个遮挡摆位拍摄仅机关、仅角色、合成三张真实截图。8 个世界/摆位均有实际像素交叠；根据前后预期逐像素比较，遮挡误差全部 0。角色在地面机关/平台上时 z=1，门前后使用地面脚点 Y-sort。测试不是仅对照源图推测顺序。

## Issues

- **BLOCKER: 0**。
- **MAJOR: 0 未解决；M-001 已修复。** run_01 固定两帧后断言过早，Area2D 信号稍后到达。事件记录和截图证明根因是测试等待时机；改为有超时的实际状态/重叠等待。生产触发代码未改，run_03 全部通过。
- **MINOR: 0 未解决；M-004 已修复。** ready 目标的呼吸帧原本重复已有亮点，调整为两个侧向 1px 标记，底座不动；最终像素复验通过。
- **INFO: M-002/M-003。** 支持/阻挡层和源图重建决策见上；第一版门只提供固定通行朝向。保留未来明确实现的接口，没有世界、关卡或事件总线。

## Delivery / repeat

- 生产目录：E:/Study/方块娘项目/若叶睦/photo/production/mechanisms/。
- 工程资源：res://production/mechanisms/。
- 运行场景：res://tests/visual/mechanism_runtime_test.tscn（F6）。
- 复验入口：tests/visual/run_mechanism_validation.ps1 / MECHANISM_README.md。
- [最终引擎报告](E:/godot/若叶睦/方块少女-若叶睦/tests/visual/mechanism_evidence/run_03/engine_runtime_report.json)、[像素及遮挡报告](E:/godot/若叶睦/方块少女-若叶睦/tests/visual/mechanism_evidence/run_03/pixel_runtime_analysis.json)、[实机总览](E:/godot/若叶睦/方块少女-若叶睦/tests/visual/mechanism_evidence/run_03/runtime_contact.png)。最终 78 张 GPU 截图；stderr 为空。
- run_01 和 run_02 保留，run_02/reference 为呼吸完善前资源，run_03/reference 为最终资源快照。
- [Area2D 官方文档](https://docs.godotengine.org/en/stable/classes/class_area2d.html)、[AnimatableBody2D 官方文档](https://docs.godotengine.org/en/stable/classes/class_animatablebody2d.html)。本报告以已安装 Godot 的实际行为为准。

没有创建正式 PuzzleManager、WorldManager、LevelManager、存档、剧情、UI 产品资源、世界切换或正式关卡。下一阶段等待用户指令。

**PUZZLE_MECHANISM_RUNTIME_ACCEPTANCE_PASS**
