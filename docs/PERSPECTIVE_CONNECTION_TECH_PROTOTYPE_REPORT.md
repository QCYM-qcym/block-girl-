# PERSPECTIVE_CONNECTION_TECH_PROTOTYPE_REPORT

## BUGFIX ROUND 1 — fresh acceptance

**PERSPECTIVE_CONNECTION_TECH_PROTOTYPE_PASS**  
Date: 2026-09-12  
Godot Version: **4.7.2.stable.steam.ed1daf0bf**  
Runtime: Windows / Forward+ / D3D12 / NVIDIA GeForce RTX 5060 Ti  
Project: `E:/godot/若叶睦/方块少女-若叶睦`

本轮重新打开之前的验收，按用户人工反馈修复两个缺陷。此前的“两视角 + Surface-only”PASS 不沿用；本报告结果来自本轮新测试和 A–G 系统键鼠实操。当前窗口保留在 **Inner / EAST / Anchor A (4,2)**，按 W 可再次穿越，按 R 可重新开始。

| Acceptance | Fresh result |
|---|---|
| FOUR VIEW SYSTEM | PASS |
| INNER WORLD PERSPECTIVE TRAVERSAL | PASS |
| Q/E | PASS |
| MOUSE DRAG | PASS |
| VIEW-RELATIVE MOVEMENT | PASS |
| CUBE ORIENTATION PRESERVATION | PASS |
| ROTATION LOCK | PASS |
| REGRESSION | PASS |

## BUG 1 ROOT CAUSE

实际启动旧实现，E 四次得到 1→0→1→0，Q 和左右拖动也只遍历两个视角。四次“回到初始”本身不能证明四视角成立，所以新测试同时要求每一步准确和四种视角全部出现。

根因是旧控制器 `posmod(current+step,2)`、鼠标 `1-current`、仅两项的平台投影配置，以及显示层同样假设两个视角。原来的 rotate_grid 只区分 NORTH 与另一个 90° 状态，未实现 SOUTH/WEST。不是浮点角度偶发漂移。

## BUG 1 FIX

- 定义 NORTH=0、EAST=1、SOUTH=2、WEST=3。E/right drag 为 +1 modulo 4；Q/left drag 为 -1 modulo 4。
- 两种输入继续走同一 `request_rotate_left/right`；一次拖动最多一步。水平位移 ≥60 窗口像素且大于垂直位移才提交，否则回弹。
- 单独保存本次旋转的正负 step，视觉角度使用 `(current + step * progress) * PI/2`。WEST→NORTH 和 NORTH→WEST 分别沿 +90°/-90° 过渡，避免按索引差值走 270°。
- 四种离散网格变换为 `(x,z)`、`(z,-x)`、`(-x,-z)`、`(-z,x)`；吸附后使用整数索引，未累计 gameplay 浮点角度。补齐四种布局与视口居中，像素纹理没有任意角度旋转。
- CubeOrientation、GridPosition、WorldState 不受 Rotate 修改。旋转中仍锁定移动、Shift、穿越及第二次 Rotate；吸附后重算连接。

## BUG 1 VERIFICATION

先运行 `test_perspective_bugfix.gd` 得到实际 RED，再单独运行 `--case=rotation` 得到 **57 checks / failures=[] / exit 0**。证据：`tests/gameplay/evidence/bugfix1_rotation_green/`。其中包括 E/Q/左右拖动四步循环、每步状态、姿态保留、屏幕方向映射和 1000 次逻辑旋转。

最终扩展测试进一步覆盖实际 16 种 WASD 输入、正负边界半程角度、特别长的拖动、四个 View 的旋转锁与拓扑提交，以及 1280×900 / 1000×720 全视角布局。A–D 键鼠实操也逐步观察通过。

## BUG 2 ROOT CAUSE

最小复现：启动 → Space 切 Inner → D 四格 → W 两格到 (4,2) → E 到旧 View B（现 EAST）→ W。修改前 **3/3 次稳定复现**。

| Data-flow layer | 修改前实际记录 | 结论 |
|---|---|---|
| Visual / controller | Inner、view=1、rotation_busy=false | 已吸附到视觉连接视角 |
| Anchor IDs / node | A_east @(4,2), B_west @(10,2) | 正确的 authored pair |
| Projection | A/B screen 均为 (962,262)，distance=0 | 画面与 gameplay 投影没有偏差 |
| Allowed perspectives | [1] | 该视角允许；扩展后 EAST 仍为 1 |
| World restriction | allowed_world_states=[0]，当前 world=1 | **首次被拒绝的层：wrong world** |
| Direction / elevation | entry=exit=East；端点相对方向正确；高度均 0 | 都符合条件 |
| Link state | enabled=true，active=false | 被世界配置阻止，不是“active=true 但图未更新” |
| Graph edge | absent | 按 inactive 正确拒绝加入可查询边 |
| Player neighbor query | [(4,1),(4,3),(3,2)]；请求世界 East，返回 (4,2) | 未获得 B 目的节点 |
| Roll / commit | phase=idle，无跨边滚动，无 B 提交 | 上游没有合法目的地 |
| Node identity / cache | 两世界共用固定节点；recalc revision 随 Shift/snap 递增 | 无不同世界节点 ID 冲突；无玩家邻居缓存；排除 stale cache |

根因是**表现层在两个世界使用相同的连接布局，但这个测试场景的 authored Link 只允许 Surface**。前次验收曾把 Inner 无法通过当作配置预期，未满足人工试玩要求的画面/通行一致性。

完整逐层记录位于 `tests/gameplay/evidence/bugfix1_red/bugfix_report.json`，含世界、视角、玩家格、完整姿态、端点 screen 坐标、限制列表、方向/高度、active、graph edge、邻居列表、请求目标、动作状态与版本号。

## BUG 2 FIX

在 connectivity.gd 创建该场景的候选 Link 后，明确设置 **allowed_world_states=[0,1]**。该连接在 **Surface / Inner 的 EAST** 均允许，其余三个视角均不允许。没有绕过世界/视角/投影/方向/高度校验，没有强行把 Link 设为 active，也没有重写 Graph 或 Player。

F3 在原有层中增加 Allowed World、Allowed View、Direction Match、Elevation Match、Graph Edge、Player Can Traverse、Traversal blocker/target 和 neighbors。实际投影位置/距离随显示更新；旋转期间 Link reason 标为 committed，Graph Edge 显示 ABSENT，Traversal 明确显示 rotation lock。玩家不在 Anchor、正在 roll/shift 时也显示原因。F3 仍可整体隐藏。

## BUG 2 VERIFICATION

单独执行 `--case=inner`，得到 **39 checks / failures=[] / exit 0**。证据：`tests/gameplay/evidence/bugfix1_inner_green/`。三次均完成 Inner A→B 的正常滚动，并验证断开后 B 可站立、返回被阻止、往返 Shift 保持状态。配置回归同时验证 Surface-only、Inner-only、两世界均允许，active 与 graph edge 完全一致。

最终 fresh trace：Inner/EAST、distance=0、allowed_world_states=[0,1]、active=true、graph_edge_present=true，A 的邻居包含 (10,2)，W 返回 B。滚动中逻辑节点仍为 A，落定后提交 B，姿态更新一次。最终视口居中后 A/B screen 均为 (890,419)，这是整体显示居中的坐标变化，不是投影容差放宽。

## 四视角输入映射

当前等距网格 W 为屏幕右上、D 右下、S 左下、A 左上。每格实际 screen 位移分别为原生 (16,-8)、(16,8)、(-16,8)、(-16,-8)，再乘整数显示倍率。

| View | W / Up | D / Right | S / Down | A / Left |
|---|---|---|---|---|
| NORTH | world N | world E | world S | world W |
| EAST | world E | world S | world W | world N |
| SOUTH | world S | world W | world N | world E |
| WEST | world W | world N | world E | world S |

Space 是 World Shift 的按键；Shift 是玩法名称。Q/E 每次 90°；左键水平拖动 ≥60 px 触发一步；R Reset；F3 Debug。project.godot 未改 InputMap/主场景，技术场景通过已有 `_input` 路径读取这些按键。

## Fresh automated regression

| Suite | 本轮结果 | Evidence |
|---|---|---|
| 初始缺陷 RED | 84 checks，预期 exit 1，稳定复现两缺陷 | bugfix1_red |
| Bug 1 独立 GREEN | 57 checks，0 failures，exit 0 | bugfix1_rotation_green |
| Bug 2 独立 GREEN | 39 checks，0 failures，exit 0 | bugfix1_inner_green |
| 最终扩展缺陷测试 | **172 checks，0 failures，exit 0** | bugfix1_extended_final |
| 原逻辑回归 | **66 checks**，24 orientations，0 failures | bugfix1_full_01/logic.stdout.log |
| 原技术运行回归 | **54 checks**，0 failures，12 GPU captures | bugfix1_full_01/runtime_report.json |
| Sprite Runtime | 60 GPU captures，0 failures | bugfix1_full_01/sprite |
| Tileset Runtime | 107 GPU captures，0 failures | bugfix1_full_01/tileset |
| Mechanism Runtime | 78 GPU captures，0 failures | bugfix1_full_01/mechanism |
| 旧 P-01 | 50 state checks；94/94 可达状态可解；input PASS；**3452 runtime checks**，0 failures | bugfix1_full_01/puzzle01 |

证据均在 `tests/gameplay/evidence/`。图形运行报告明确记录 Windows、forward_plus、d3d12，不以 headless 冒充运行。旧 P-01 的逐帧断言数随采样帧数变化，本轮如实报告 3452。所有 full_01 阶段 stderr 均空，最终扩展测试 stderr 也为空。

原 66/54 检查没有删减；只对被新规格替代的预期作定向适配：旧 wrong-world 用例显式配置 Surface-only，恢复后仍为双世界；旧 NORTH 左拖预期改为 WEST。其余 held/release、24 姿态、四向滚动、面部隐藏、Shift、双向穿越、焦点丢失、Reset、窗口和资源覆盖保留。

复跑命令（PowerShell，项目目录）：

```powershell
./tests/gameplay/run_validation.ps1 -EvidenceName new_name -IncludeRegressions
```

该脚本会运行新旧全部测试；可通过 `-Godot` 指定引擎路径。不得复用已有证据目录名。原 Tileset harness 会重新保存样板，现有 wrapper 的 try/finally 字节保护仍保留，本轮样板哈希与基线一致。

## A–G 系统键鼠实操

在新启动的独立 TECH 窗口使用系统键盘/鼠标操作，并逐步观察画面；不是仅调用控制器方法。系统操作由 computer-use 执行，未声称用户本人已确认。

| Case | 观察结果 |
|---|---|
| A | E×4：NORTH→EAST→SOUTH→WEST→NORTH，PASS |
| B | Q×4：NORTH→WEST→SOUTH→EAST→NORTH，PASS |
| C | 右拖×4：完整顺向四视角循环，PASS |
| D | 左拖×4：完整逆向四视角循环，PASS |
| E | Inner 在 EAST，ACTIVE / PRESENT / YES；W 实际由 (4,2) 滚入 (10,2)，PASS |
| F | B 上 Q 回 NORTH，INACTIVE / ABSENT；A 键无法沿原边返回，B 节点保留，PASS |
| G | 在 B/NORTH 上 Space 两次，位置 (10,2)、姿态 X(0,-1,0)/Y(-1,0,0)/Z(0,0,-1)、视角 NORTH 都保留，PASS |

实操证据：`tests/gameplay/evidence/bugfix1_manual/`，10 张截图以及 manual_validation.json。最后 E 回 EAST、S 反向返回 A，窗口停在 Inner/EAST/(4,2)，W 可立即重试。原来错误版本的运行进程已关闭，Godot 编辑器未关闭。

## Actual file changes

| Modified | Responsibility |
|---|---|
| prototype/perspective/perspective_controller.gd | 四视角、符号步长、拖动、精确投影 |
| prototype/perspective/cube_visual.gd | 读取控制器的有符号观察角度 |
| prototype/perspective/connectivity.gd | 该 authored pair 明确允许两个世界 |
| prototype/perspective/grid_movement.gd | 更新过时的 Surface/View B 反馈文案 |
| prototype/perspective/debug_overlay.gd | 逐层连接与玩家可通行原因 |
| tests/gameplay/perspective_connection_tech_test.gd | 四视角画面居中、Debug 尺寸、状态反馈 |
| tests/gameplay/test_perspective_logic.gd | 原 66 项中显式配置受限世界用例 |
| tests/gameplay/test_perspective_runtime.gd | 原 54 项定向适配四视角与世界配置 |
| tests/gameplay/run_validation.ps1 | 纳入新 bugfix 图形测试 |
| docs/perspective_connection_design.md | 四视角与双世界连接的当前基线 |
| docs/PERSPECTIVE_CONNECTION_TECH_PROTOTYPE_REPORT.md | 本轮报告，替代旧 PASS 结论 |

新增：tests/gameplay/test_perspective_bugfix.gd 及其 .uid；docs/superpowers/plans/2026-09-12-perspective-bugfix-round1.md；独立的 bugfix1_* evidence 目录。完整清单见 changed_files.json。

CubeOrientation、PerspectiveLink 校验逻辑、PerspectiveAnchor、生产资源、tests/visual 原测试及场景、旧 P-01、project.godot 均未修改。完整性基线包含 1790 个可读文件；另两个旧运行日志在基线时被进程占用，已明确排除，未把它们计作资源哈希通过。保护目录与非授权修改检查见 asset_integrity.json。

Git: **GIT_REPOSITORY_NOT_INITIALIZED**。未初始化或提交/上传。两个 BUG 分别留存 bug1.patch / bug2.patch 和独立 GREEN 记录，不伪造 Git commit。独立只读代码审查未发现需修复的实现问题；其后补齐的全视角锁/布局测试也通过。

## Issues and stop boundary

- BLOCKER：无。
- MAJOR（后续美术任务）：正式角色 Sprite 仍为 **CUBE_FACE_VISUAL_AUDIT_FAIL / VISUAL_ASSET_REWORK_REQUIRED**；当前临时单面 debug cube 保留真实姿态。本轮未重制资源。
- INFO：仍采用设计师指定的平台分区 2D 投影；不是单个刚性 3D 相机的几何证明。没有进入 3D 或扩大关卡范围。
- INFO：当前 Link 仅在 EAST 激活，其他三视角不可通行是明确配置。视角转动中 cached Link 可能仍为 ACTIVE，实际边和 Player readiness 为锁定，F3 会解释；吸附完成后重新检查可行性。

**PERSPECTIVE_CONNECTION_TECH_PROTOTYPE_PASS**。本轮修复到此停止，等待用户实际试玩确认。不开始 GitHub Baseline、Playable Puzzle Prototype 01、Sprite Rework 或正式关卡。