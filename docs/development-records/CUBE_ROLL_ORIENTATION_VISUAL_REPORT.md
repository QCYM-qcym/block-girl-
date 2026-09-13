# CUBE_ROLL_ORIENTATION_VISUAL_REPORT

2026-09-12 · 分支 `feat/playable-puzzle-p01`

最终状态：**CUBE_ROLL_LOGIC_PASS_SPRITE_REWORK_REQUIRED**。

本轮完成用户允许的 A（Presenter 修复）+ B（临时单面 X 方块）。独立验收场景与 P-01 均已使用真实持久姿态的 2D 表现。正式 Mutsumi/Mortis Sprite 未重制，不能标为最终美术通过。

## 根因及状态

ROOT CAUSE: GridMovement 每格正确提交 CubeOrientation，但旧 sprite_presentation 没有读取姿态选图，只按移动方向播放四段固定 roll；结束后固定选择 subtle_idle。两世界旧 Sprite 的三种中间姿态共 6/6 次都选回与初始相同的 idle 像素，导致“每格正脸 reset”。换视角也没有重新解释物理面。

完整十项追踪见 [CUBE_ORIENTATION_VISUAL_AUDIT](CUBE_ORIENTATION_VISUAL_AUDIT.md)。原资源结论：**SPRITE_RESOURCE_INSUFFICIENT_FOR_TRUE_CUBE_ORIENTATION**。

| 项目 | 结果 |
| --- | --- |
| Existing Sprite Sufficiency | INSUFFICIENT |
| Logical CubeOrientation | PASS |
| Persistent Visual Orientation | PASS（临时 2D Presenter） |
| Single Physical Face | PASS（唯一 local +Z 面绘 X） |
| Four-step Roll Cycle | PASS |
| Continuous Hold Roll | PASS（图形运行持续 Input 事件） |
| Perspective Preservation | PASS |
| World Shift Preservation | PASS |
| Face Visibility | PASS |
| P-01 Regression | PASS |
| Final Sprite | REWORK_REQUIRED |

## 实现

CubeOrientation 保持唯一真实状态。Presenter 从它和 movement.direction/fraction 派生当前过渡矩阵，再应用相机变换；不保存第二套可变 visual_orientation。滚动终点等于已提交逻辑姿态，下一步从该姿态开始。

固定 `FACE_ID = physical_face_front / local +Z`。只在该物理面绘 X，其他五面无标记。North 四步的面法线为 SOUTH → TOP → NORTH → BOTTOM → SOUTH；NORTH 视角可见性为 YES → YES → NO → NO → YES。East 滚动时初始 +Z 面法线可保持 SOUTH，但图案在面内旋转；完整三轴姿态仍改变。

使用已有 Node2D 面投影和背面剔除。Space 仅切换测试色板，Q/E 与鼠标拖动仅改变观察方向。P-01 正常界面注明临时测试方块，F3 显示姿态、固定面 ID、世界方向、可见性、滚动进度和起止矩阵。

## 本轮实际文件变更

仅修改以下三个已有文件（相对于本轮开始快照）：

- `prototype/perspective/cube_visual.gd`：提取可覆盖的 draw_face_marker，原技术场景默认绘脸行为保持。
- `game/levels/mutsumi/p01_board.gd`：Player Presentation 引用切换至新 Presenter。
- `game/levels/mutsumi/p01_another_world.gd`：临时美术说明及 F3 字段。

新增：

- `game/player/cube_visual_presenter.gd` 及 Godot `.uid`。
- `tests/gameplay/cube_orientation_visual_test.tscn`、同名 `.gd` 及 `.uid`。
- `tests/gameplay/test_cube_visual.gd` 及 `.uid`。
- `tests/gameplay/audit_cube_orientation_visual.gd` 及 `.uid`，保留旧 Presenter 的失败复现。
- `docs/development-records/CUBE_ORIENTATION_VISUAL_AUDIT.md`。
- `docs/design/cube-orientation-presentation-spec.md`。
- `docs/superpowers/plans/2026-09-12-cube-orientation-visual-fix.md`。
- 本报告与下述 evidence 目录。

之前 P-01 阶段的未提交文件继续保留，不能把当前整个 git status 当成本轮变更清单。

## 自动验证

真实 Godot 4.7.2.stable.steam.ed1daf0bf，Windows / Forward+ / D3D12 / NVIDIA RTX 5060 Ti。

| 套件 | 本轮结果 | 证据（tests/gameplay/evidence/ 下） |
| --- | --- | --- |
| 旧表现复现 | 预期失败，6/6 中间姿态选回固定 idle | cube_visual_audit_02/audit.json，10 张截图 |
| 新 Presenter 缺失时的测试 | 预期失败 | cube_presenter_red/ |
| 新单面表现图形测试 | 632 checks，failures=[] | cube_visual_final_01/runtime_report.json，15 张截图 |
| P-01 状态 | 31 checks，108/108 可达状态可解 | cube_p01_regression/state.stdout.log |
| P-01 正常图形运行 | 167 checks，failures=[]；键盘与鼠标视角两条通关路线 | cube_p01_regression/ |
| Perspective | logic 66、bugfix 172、runtime 54，均通过 | cube_p01_regression_regression/ |
| 旧 Puzzle Prototype 回归 | state 50，94/94 状态可解；input PASS；runtime 3452 | 同上 |
| Sprite / Tileset / Mechanism | PASS；分别 60 / 107 / 78 次捕获，failures=[] | 同上各资源子目录 |

632 项包含 N×4、E×4、N+S、E+W；两世界四步方向序列；落定矩阵与逻辑一致；5.1 秒姿态保持；Q/Space 保持；单次 press 后持续保持并跨越多格；第二步起点等于第一步终点；24 姿态 × 4 视角 × 2 皮肤共 192 组合逐项比对矩阵、可见性和实际 GPU 图像中的金色 X 像素；鼠标旋转及 F3。

P-01 167 项重新覆盖 Hold、World Shift、Perspective Connection、Pressure Plate、Door、Exit、Complete、Reset，正常路线通关，没有通过传送玩家代替解谜。

首轮旧表现复现 `cube_visual_audit/` 因未等待输入队列分发，四次请求仅结算两步；该实验保留但不作为四步证据。修正后的 `cube_visual_audit_02/` 已核对完整两世界四步序列。新通过套件、P-01、旧回归及人工窗口的 stderr 均为空。

重跑新图形测试（项目根目录，使用新的 evidence 名避免覆盖）：

```powershell
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . --script res://tests/gameplay/test_cube_visual.gd -- --evidence-dir=res://tests/gameplay/evidence/cube_visual_rerun
& ./tests/gameplay/run_p01_validation.ps1 -EvidenceName cube_p01_rerun -IncludeRegressions
```

## 系统键鼠人工验收

独立窗口 `Cube Orientation Visual Test · 单面滚动验收`，默认 1200×820。通过系统键盘和鼠标操作；截图在 `cube_visual_manual/`。

| Case | 实际操作与观察 | 结果 |
| --- | --- | --- |
| A | R → NORTH，逐次 W×4。X 侧面 → 顶面 → 背面隐藏 → 底面隐藏 → 原侧面；F3 Moves 0→4 | PASS，A_00 至 A_04 |
| B | R → W，停止 17.16 秒；仍为 TOP、Moves 1、IDLE | PASS，B_top_after_17_seconds.jpg |
| C | 在上述 TOP 状态按 Q；视角 NORTH→WEST，姿态、格坐标和步数不变，旋转过程只改变观察投影 | PASS，C_west_preserves_top.jpg |
| D | 在同一 TOP 状态按 Space；Surface→Inner，测试颜色改变，TOP/姿态/格坐标不变 | PASS，D_inner_preserves_top.jpg |
| 鼠标 | TOP / Inner 状态水平拖动，视角 WEST→SOUTH，物理姿态保持 | PASS，mouse_south_preserves_top.jpg |
| E | 系统工具只能发送 tap，未冒充物理长按人工结果；以真实图形运行中单次 Input press 持续保持、多格衔接断言验证 | 自动 PASS，632 项套件 |

## 试玩与限制

独立场景：`res://tests/gameplay/cube_orientation_visual_test.tscn`，可在 Godot 打开后 F6。大方块固定屏幕位置便于对比，逻辑格仍移动；F3 默认显示。F5 主场景仍为 P-01，不改项目入口。

- 按住 WASD：逐格连续滚动；Q/E 或鼠标水平拖动：四视角旋转。
- Space：Surface/Inner；R：Reset；F3：调试信息。
- 独立场景有测试支撑网格，两世界均可站立；P-01 仍使用原地图与切换限制。

已知限制：当前是单面 X 技术替身，不是正式角色脸。X 有旋转对称性，不能只靠截图区分全部面内方向；自动测试另核对完整姿态矩阵。临时投影采用整数像素，过渡具有像素阶梯感。人工布局验证在默认窗口尺寸进行。

正式资源规划见 [Presentation Spec](../design/cube-orientation-presentation-spec.md)：定义完整24态、条件性视觉等价类、两皮肤静态映射、6帧90°过渡和连续相机角度缺口。资源数量须结合最终六面材质确认；本轮没有开始生产图集。

## 范围与停止点

本轮开始快照的 142 个受检文件中，139 个保持哈希一致，只有上述三个表现相关文件改变。Movement、CubeOrientation、输入、关卡状态、地图和 production 资源保持。`tests/visual` 无 git diff；其 tileset_paired_sample.tscn 的 SHA256 保持 `AA4CCBBE859FEA4084CAB6DBD7A2987F5E702A448D00829A3048B3A244744BB1`。

只读代码审查未发现重要或严重问题。HEAD 保持 `433289de9604dd07707e0ff5d41fb4326f2fd774`，无 commit、push、merge 或 remote 修改。

本阶段在 **CUBE_ROLL_LOGIC_PASS_SPRITE_REWORK_REQUIRED** 停止，等待用户试玩后决定定向 Pixel Sprite 重制或后续 3D Cube + Pixel Rendering 研究。
