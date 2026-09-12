# SPRITE_RUNTIME_VALIDATION

Final Status: **SPRITE_RUNTIME_ACCEPTANCE_PASS**

Godot Version: **4.7.2-stable (steam)** (ed1daf0bf001b61586d9930840f2f1394092c079)

Renderer: **Forward Plus / D3D12**；DisplayServer: **Windows**；GPU: **NVIDIA GeForce RTX 5060 Ti**。测试为真实图形窗口，非 headless 渲染。编辑器已实际打开项目、导入资源；headless 仅用于导入和脚本预检。

## Project and scope

工程：`E:/godot/若叶睦/方块少女-若叶睦/project.godot`。原项目已存在，无主场景和既有测试目录。新增 `production/sprites/` 与隔离的 `tests/visual/`。`project.godot` 的 SHA256 与本轮开始时相同，未改 renderer、全局过滤、参考分辨率或 main scene。未创建正式控制器、关卡、Tileset，未提交或 push。

## Import

**PASS**。两张 PNG 在引擎中载入为 144×264；`compress/mode=0`（Lossless）、`mipmaps/generate=false`，实际 Texture Image 也不含 mipmap。AtlasTexture 区域全部 24×24、filter_clip=true；SpriteFrames 的帧数、帧序、FPS、loop 和 duration 与 manifest 相符。

项目默认纹理过滤为 Linear（ProjectSettings 值 1 / Viewport 默认值 1）；角色示例、测试根节点和 AnimatedSprite2D 均显式设置 CanvasItem.TEXTURE_FILTER_NEAREST。不同枚举的值不能直接混淆。未为本轮修改全局默认项。

## Mutsumi / Mortis animation playback

| Animation | Mutsumi | Mortis | 实际渲染到的零基帧 | manifest 时长/秒 |
|---|---|---|---|---:|
| idle | PASS | PASS | 0 | 1.000 |
| subtle_idle | PASS | PASS | 0,1,2,3,4,5 | 4.000 |
| roll_left | PASS | PASS | 0,1,2,3,4,5 | 0.333 |
| roll_right | PASS | PASS | 0,1,2,3,4,5 | 0.333 |
| roll_forward | PASS | PASS | 0,1,2,3,4,5 | 0.333 |
| roll_backward | PASS | PASS | 0,1,2,3,4,5 | 0.333 |
| interaction | PASS | PASS | 0,1,2,3,4,5 | 0.600 |
| world_switch_start | PASS | PASS | 0,1,2 | 0.250 |
| world_switch_midpoint | PASS | PASS | 0,1,2 | 0.250 |
| world_switch | PASS | PASS | 0,1,2,3,4,5 | 0.500 |
| puzzle_complete | PASS | PASS | 0,1,2,3,4,5 | 0.600 |
| shadow | PASS | PASS | 0 | 循环静态帧 |

非循环动画均实际触发 animation_finished；两状态每次完成信号的记录差值约 2 微秒，同一渲染帧。翻滚实测约 0.3495–0.3497 秒，0.3333 秒理论时长与回调检测之间约一帧差异（60 FPS）；在检查容差内，无需修改 FPS。所有倍率面板的 frame 每次读取均一致。

## Pixel Scaling

| Scale | Result | 实际像素采样数 | RGB 最大差异 |
|---|---|---:|---:|
| 1x | PASS | 57456 | 0 |
| 2x | PASS | 229824 | 0 |
| 3x | PASS | 517104 | 0 |
| 4x | PASS | 919296 | 0 |

总计 **1,723,680** 个 GPU 渲染像素与 PNG 最近邻期望值逐像素一致：无模糊、抗锯齿、bleeding 或非整数像素抖动。采样涵盖角色及透明边缘，避开标签和底部标尺；不是对文本抗锯齿作判断。实际窗口 1280×720，canvas/final transform 为单位变换；1x–4x 完全由整数节点倍率实现。8x 只用来观察细节，不替代要求的倍率。未添加 480×270 分辨率系统。

## Anchor / footprint / world switch

- Anchor Consistency: **PASS**。全部 cell 24×24；centered=true，offset=(0,-9)，纹理 (12,21) 对齐节点原点；实际底边保持同一标尺位置，无动画切换瞬移。
- Mutsumi/Mortis Footprint Parity: **PASS**。对应格同 Alpha 轮廓，固定 16×16 静止体型、同基线、同播放阶段。此项验收的是资产占格，未声称已验证正式关卡碰撞逻辑。
- World Switch: **PASS**。Mutsumi→Mortis 和 Mortis→Mutsumi 同时实际播放，完成后更换为对方 SpriteFrames 的 idle；交接前后角色区域差异 **0 像素**，无空白帧或尺寸跳变。
- Shadow: **PASS**。真实显示并播放；开启阴影与关闭阴影之间有 1128 个屏幕像素发生变化，证明阴影不是未显示的空测试；相隔 0.3 秒两次截图差异 0，位置和强度稳定。

## Issues

- BLOCKER: **0**。
- MAJOR: **0 未解决；1 已修复（R-001）**。首轮实际运行发现部分翻滚格缺失可见表面。GPU 与 PNG 完全一致后定位到 PNG 生成器观察方向错误。先记录 `runtime_issues.md` 和原图备份，再将可见面剔除/排序方向从 (1,2,1) 改为与原投影匹配的 (1,2/3,1)。每皮肤仅 12 个翻滚格改变，非翻滚格全部逐像素不变；色板、锚点、画布、角度序列和动画 FPS 不变。回归测试从 FAIL 变 PASS，真实 run_02 复验通过。
- MINOR: **1（R-003）**。互动和完成在 1x 下反馈轻微；动画有效且可区分，但建议未来正式交互阶段结合音效确认反馈强度。本轮保留既定风格，不扩展 UI/特效。
- INFO: **R-002**。新建角色节点时需保持显式 Nearest，避免继承项目 Linear 默认项。

## PNG change audit

| 文件 | 修改前 SHA256 | 修改后 SHA256 |
|---|---|---|
| mutsumi_cube_sheet.png | c7b7fd84e1411a8be8109dc8cab26b50a597bdc7e4ec2f55db6db1809c5547e6 | 403a9510f1984bb69d87ceff66710c67b6efaeb894a7a00cb1bed7fdb800b1be |
| mortis_cube_sheet.png | bea21ec0e5d9cc712c1a86dce0add18c303fedecf7998bf1d2adc175eac110d4 | 308aed6f83fb7d18c280a7647bccb1891c33731a88e04f1dc6ea1833e258c420 |

原图备份：`E:\godot\若叶睦\sprite_production_work\runtime_validation/before_png_fix/`。受影响严重缺口格为 (row,col)=(2,3),(3,2),(4,2),(5,3)，每皮肤一样；其他改变的翻滚格为同根因修复涉及的面交界像素。旧版缺口格凸包内缺失 10 像素；修复后所有翻滚格为 0。修正版已同步到原生产目录及工程，预览和静态哈希报告同步更新。

## Fresh verification evidence

- [修复后引擎报告](E:\godot\若叶睦\方块少女-若叶睦\tests\visual\evidence\run_02/engine_runtime_report.json)
- [修复后逐像素验收](E:\godot\若叶睦\方块少女-若叶睦\tests\visual\evidence\run_02/pixel_runtime_analysis.json)
- [四方向真实运行帧](E:\godot\若叶睦\方块少女-若叶睦\tests\visual\evidence\run_02/runtime_rolls_contact.png)
- [状态动画真实运行帧](E:\godot\若叶睦\方块少女-若叶睦\tests\visual\evidence\run_02/runtime_states_contact.png)
- [1x–4x 与阴影截图](E:\godot\若叶睦\方块少女-若叶睦\tests\visual\evidence\run_02/shadow_idle_a.png)
- [切换交接前](E:\godot\若叶睦\方块少女-若叶睦\tests\visual\evidence\run_02/world_switch_handoff_before.png)、[切换交接后](E:\godot\若叶睦\方块少女-若叶睦\tests\visual\evidence\run_02/world_switch_handoff_after.png)
- 修复前对照：`E:/godot/若叶睦/方块少女-若叶睦/tests/visual/evidence/run_01/`；每轮的 reference/ 保存当时实际测试的 PNG/SpriteFrames。
- 引擎日志：`E:\godot\若叶睦\sprite_production_work\runtime_validation/run_02_stdout.log`、`run_02_stderr.log`；stderr 为空。

## Re-run

在 Godot 打开 `res://tests/visual/sprite_runtime_test.tscn`，按 F6；按键与自动运行方法见同目录 README.md / run_sprite_validation.ps1。测试场景不设为项目主场景。

官方设置与截图依据：[图像导入](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)、[Viewport 帧缓冲读取](https://docs.godotengine.org/en/stable/classes/class_viewport.html)。

Sprite Runtime 验收完成，可以进入下一阶段 Tileset 生产与验证。
