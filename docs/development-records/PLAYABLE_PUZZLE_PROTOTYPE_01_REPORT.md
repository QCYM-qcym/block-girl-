# PLAYABLE_PUZZLE_PROTOTYPE_01_REPORT

**PLAYABLE_PUZZLE_PROTOTYPE_01_PASS**

日期：2026-09-12。Level：**P-01《另一个世界》**。

Branch：`feat/playable-puzzle-p01`。修改前实际运行 `git branch --show-current` 确认目标分支，`git status --short` 为空。基线 HEAD：`433289de9604dd07707e0ff5d41fb4326f2fd774`。最终仍在此分支，所有变更未提交；没有 commit、push、merge、rebase 或 remote 修改。

Godot Version：**4.7.2.stable.steam.ed1daf0bf**。自动运行环境：Windows / Forward+ / D3D12 / NVIDIA GeForce RTX 5060 Ti，真实图形窗口及 GPU 截图。系统键鼠验收通过 Godot 编辑器 F5 启动的新关卡完成，Debug Overlay 始终关闭。

Main Scene：`res://game/levels/mutsumi/p01_another_world.tscn`。实际 F5 已确认进入 P-01。测试结束按 R 留在 Surface / NORTH 起点，可由用户继续试玩。

## 验收结果

| 项目 | 结果 | 证据 / 实际行为 |
|---|---|---|
| 完整通关 | PASS | 图形自动 A/B 与系统键鼠 A/B 均完成；没有传送、Inspector 改状态或开发通关快捷键 |
| Hold Movement | PASS | 按下一次 W 保持，连续滚动；松开完成当前格。Plate、门、Exit 前持续输入结算正确 |
| Surface / Inner | PASS | Surface 第一断路阻挡；Inner 出现真实节点；桥上禁止切换至无地面的 Surface，显示短暂原因 |
| Four Perspectives | PASS | NORTH/EAST/SOUTH/WEST 四端态、环回、地图可见性和既有 172 项回归 |
| Q/E | PASS | E 与 Q 分别进入相邻视角；不改格坐标、世界或姿态 |
| Mouse Drag | PASS | 右拖正式通关，左拖四次循环，短拖回弹；一次手势只切一格视角 |
| Perspective Connection | PASS | 仅 INNER + EAST；同高、同入出方向、Anchor 距离 0；正常一格投影距离滚动并延迟提交逻辑目的地 |
| Pressure Plate | PASS | Surface 当前格占用即 pressed/open；Inner 不激活；不是 latch 或跨世界 Plate |
| Door | PASS | Plate 前方格间门；滚动期间 OPEN，落定到门后格才 CLOSED，无夹住或半格停止 |
| Exit | PASS | Surface 到达即自动完成，无额外按键 |
| Reset | PASS | 清除 cell、orientation、world、view、held input、转场、Link、Plate、Door、Exit、完成与三个提示本地状态 |
| Tutorial Hints | PASS | WASD → 第一断路 Space → 中间断路 Q/E+拖动；成功使用后淡出；点击/短拖回弹不消耗旋转提示 |
| View-relative Input | PASS | 系统键盘在 EAST 按 W 实际向屏幕右上移动；四向映射回归通过 |
| Regression | PASS | Sprite、Tileset、Mechanism、Perspective、四视角 bugfix 与旧 P01 全通过 |
| Softlock | PASS | 108 个可达位置/世界/视角状态全部有无需 Reset 的出口路线；断开 Link 只删除边，保留站立节点 |
| Visual Debt | 保留 | **CUBE_FACE_VISUAL_REWORK_REQUIRED**，本轮未重做 Sprite，不阻塞玩法验收 |

## 控制与解法

按住 WASD 或方向键连续逐格翻滚；松开后落定停止。Space 切换世界。Q/E 左右切换 90° 视角；鼠标左键水平拖动至少 60 个游戏窗口像素也可切换，左右各一档。R 随时 Reset。F3 显示/隐藏开发状态，默认隐藏。

在等距地图上 W、D、S、A 分别对应屏幕右上、右下、左下、左上，旋转后保持这一屏幕方向约定。

确定性解法（数字是完整移动格数，可以按住到边界）：

1. 初始 Surface/NORTH，W × 3 到第一断路。
2. Space 进入 Inner，W × 2 经过桥到转角；D × 3 到中间平台末端。
3. E 一次，或鼠标右拖一次，进入 EAST。两个道路端点对齐。
4. W × 1 正常滚过连接，抵达最终平台。
5. Space 回 Surface，保留 EAST。W × 2 踩到压力板，门开启。
6. W × 1 穿门，门在身后关闭；W × 1 到出口，自动显示「关卡完成」。R 可重玩。

两条自动路线最终均为 `(13,0), Surface, EAST`，朝向 `(1,0,0)|(0,0,-1)|(0,1,0)`，13 次完整滚动，Door closed、Puzzle complete。目标首次体验约 2–5 分钟；熟悉解法后可明显更快。**本轮没有招募新玩家做无引导计时，因此尚不能声称 2–5 分钟或趣味性已被用户研究验证。**

## 实际新增 / 修改文件

项目根目录：`E:/godot/若叶睦/方块少女-若叶睦/`。

| 文件 | 类型 | 用途 |
|---|---|---|
| `game/levels/mutsumi/p01_another_world.tscn` | 新增 | 独立正式 Gameplay 场景 |
| `game/levels/mutsumi/p01_another_world.gd` | 新增 | 装配公共能力、最小 HUD、完成和 Reset；不复制移动/旋转算法 |
| `game/levels/mutsumi/p01_state.gd` | 新增 | 继承已验证 Connectivity，配置地图、世界占格、门边、Plate/Exit 状态 |
| `game/levels/mutsumi/p01_board.gd` | 新增 | 复用生产 Tile atlas、Plate/Door/Exit 场景与角色表现；整数缩放、排序 |
| `game/levels/mutsumi/p01_hints.gd` | 新增 | 仅本关三个提示的触发和淡出，无通用教程框架 |
| `game/player/grid_input.gd` | 新增 | 可复用输入接线，直接调用既有 Movement/Perspective，沿用原 phase/busy 仲裁 |
| `game/player/sprite_presentation.gd` | 新增 | 已验收 SpriteFrames 的表现适配；由逻辑进度选翻滚帧，动画不提交游戏状态 |
| `prototype/perspective/connectivity.gd` | 修改 | 增加默认 can_stand 接口，原技术地图两世界支持不变 |
| `prototype/perspective/grid_movement.gd` | 修改 | Shift 前检查 can_stand；落定发 committed，先结算机关再尝试下一 held move |
| `project.godot` | 修改 | 唯一配置修改：main_scene 指向新 P-01 |
| `tests/gameplay/test_p01_state.gd` | 新增 | 31 项状态检查与 108 状态可解性搜索 |
| `tests/gameplay/test_p01_runtime.gd` | 新增 | 167 项真实渲染/输入检查、双路线和截图 |
| `tests/gameplay/run_p01_validation.ps1` | 新增 | 可重复运行 P01 状态、图形测试和可选全部回归，保护历史证据 |
| `docs/design/p01-another-world.md` | 新增 | 四区关卡设计、时序和资产边界 |
| `docs/superpowers/plans/2026-09-12-playable-puzzle-p01.md` | 新增 | 实施前创建并跟踪完成的真实路径计划 |
| `docs/development-records/PLAYABLE_PUZZLE_PROTOTYPE_01_REPORT.md` | 新增 | 本报告 |

Godot 为 6 个新增 gameplay `.gd` 与 2 个测试 `.gd` 生成对应 `.gd.uid`，一并保留。新增运行证据位于 `tests/gameplay/evidence/p01_*`，详细路径见下。没有新增、生成或重做 PNG 生产资产。

旧 `prototype/puzzle_01.tscn` 是早期 gameplay draft，现作为 regression fixture 完整保留；其旧状态、输入、画面测试均重新通过。没有将 `tests/visual` 或 Perspective Tech Test 改造成关卡，也没有删除测试场景。

## 复用与责任边界

实际先检查了 Sprite manifest / runtime report、Tileset production/runtime report、Mechanism production/runtime report、四视角修复设计和报告、现有脚本、旧 P01 与测试入口。复用公共 `cube_orientation.gd`、`perspective_controller.gd`、`perspective_anchor.gd`、`perspective_link.gd`、`connectivity.gd` 和 `grid_movement.gd`，没有新建第二套旋转状态或朝向系统。

角色使用 `production/sprites/{mutsumi,mortis}_sprite_frames.tres`，地面使用已验收 Surface/Inner `FLOOR_01` atlas region。机关实例化已验收 Surface Plate/Door/Exit 场景，Inner 以淡化轮廓暗示其属于另一世界。格图负责通行与逻辑占用；关卡实例的 Area 触发和物理碰撞层停用，避免混入第二种碰撞裁决。资源测试场景仍保留原 Area2D/物理验证行为。

顺序为：合法 edge 授权 → 完整 90° roll → cell 和 CubeOrientation 一起提交 → committed → Plate/Door/Exit 结算 → 下一 held move。门的视觉 opening/open/closing 只响应逻辑；在已授权穿门的滚动开始后保证门扇已完全敞开，不依赖某一动画帧来判通行。

## 自动验证与红绿证据

最终 P01 证据：[p01_final_01](E:/godot/若叶睦/方块少女-若叶睦/tests/gameplay/evidence/p01_final_01/runtime_report.json)。31 项状态检查、108/108 可解；**167 项图形运行检查，failures=[]**，Windows / Forward+。两个最终 stderr 均为空，runner exit 0。25 张 GPU 截图覆盖双路线及 1280×900、900×700 的全部四个视角。

覆盖：初始状态、两次实际 held 直路移动、第一断路、桥上 Shift 拒绝反馈、第二断路、连接中途与落定、旋转锁、Shift 保姿态、Plate/Door 开闭与穿越、Exit/complete 输入锁、Reset 中断 roll/Shift/rotate/drag、四 View 地图范围、Q 左循环、鼠标左循环、短拖回弹、F3、焦点丢失清理。

- `p01_red`：先运行测试确认缺失 state / 正式 scene 时 exit 1，再实现。
- `p01_runtime_01`：首次图形装配发现 GDScript 类型推导错误，修复明确 Vector2 类型；失败日志保留。
- `p01_runtime_02`：首次两条图形通关 155 项 PASS。
- `p01_runtime_03`：调整默认 3 倍整数缩放后 155 项 PASS。
- `p01_hint_red`：独立审查指出单击回弹会消耗旋转提示；新增测试实际得到两条对应失败，其它 165 项通过。
- `p01_final_01`：只把 current 真正改变视为成功旋转后，167 项全部 PASS；独立复查没有其它重要问题。

既有基线新一轮证据：[p01_regression_01](E:/godot/若叶睦/方块少女-若叶睦/tests/gameplay/evidence/p01_regression_01/runtime_report.json)。未削弱或改写任何原测试。

| 回归套件 | 本轮新结果 |
|---|---|
| Perspective pure logic | 66 checks；24 orientations；PASS |
| 四视角 / Inner bugfix | 172 checks；PASS |
| 原 Perspective Runtime | 54 checks；PASS |
| 旧 P01 state | 50 checks；94/94 states solvable；PASS |
| 旧 P01 input | PASS |
| 旧 P01 Runtime | 3452 checks；PASS（逐帧采样数量可能随帧时变化） |
| Sprite Runtime | ENGINE_RUN_PASS；60 captures；0 failures |
| Tileset Runtime | ENGINE_CHECKS_PASS；107 captures；0 failures |
| Mechanism Runtime | ENGINE_CHECKS_PASS；78 captures；0 failures |

所有回归 stderr 为空。原 Tileset harness 会重存样板，仍通过既有 runner 在执行前后保留其精确字节。最终受保护的 production、tests/visual、旧 P01、原 Perspective 测试与场景 `git diff` 全为空；[integrity.json](E:/godot/若叶睦/方块少女-若叶睦/tests/gameplay/evidence/p01_final_01/integrity.json) 记录。样板 SHA256 仍为 `AA4CCBBE859FEA4084CAB6DBD7A2987F5E702A448D00829A3048B3A244744BB1`。

复跑：在项目目录运行 `tests/gameplay/run_p01_validation.ps1 -EvidenceName <新的证据目录名> -IncludeRegressions`。默认不覆盖已存在证据目录。状态测试 headless，图形套件必须真实 Windows 渲染，不能用 headless 冒充运行验收。

## 系统键鼠验收与体验观察

[manual_validation.json](E:/godot/若叶睦/方块少女-若叶睦/tests/gameplay/evidence/p01_manual/manual_validation.json) 和同目录 16 张系统截图记录 F5、A 键盘路线、B 鼠标路线与最终 Reset。每次操作后观察实际窗口；两个完整通关都没有开启 F3。系统 API 使用普通按下/松开，真正的持续按住体验由自动图形测试发一个 press 后保持验证，二者证据不混称。

| 玩家验收重点 | 本次实际观察与边界 |
|---|---|
| 知道去哪 | 起点只有一条路，中间只有一个转角；全图能看到下一段和发光出口，没有无意义支路 |
| 第一次断路 | 一格地面缺失清楚；移动被挡。Reset 后的 B 路线实际看到 Space 在断路处出现 |
| Space 是否过早 | 起点只有 WASD，成功移动后消失；未在出发前提示 Space |
| 世界差异 | 同格换肤与地板色板切换，缺失的一格桥真实出现，且可滚过 |
| 第二断路 | 相隔更远的两个平台，Inner 已有桥却仍不能通过；到端点才出现 Q/E+拖动 |
| 尝试旋转 | 极简提示清楚；键盘 E 与真实右拖分别成功使道路对齐 |
| EAST 对齐 | 中间与最终平台形成连续一格间距的地面，未发生错位或跳屏 |
| 穿越像走路 | 玩家只滚动一格可见距离，到达新逻辑平台，没有瞬移 |
| Plate → Door | 人工在 Plate 停下时看到门扇打开；跨过后在身后关闭，随后可继续前进 |
| Exit | 菱形发光标记可辨，进入即出现完成文字和 R 重玩 |

这是实施者的功能与可读性验收，不是盲测新玩家，也不等同于“谜题已经好玩”的结论。没有观察到明显卡顿；未做帧时间统计或性能 benchmark。

## 已知限制

1. **CUBE_FACE_VISUAL_REWORK_REQUIRED**：现有正式 Sprite 在落定帧复位可见脸，不能完整表现逻辑保持的单物理面朝向。本关按授权保留正式美术，朝向逻辑正确；未伪称美术已解决。
2. Perspective 沿用已经接受的分平台 2D 重构：最终平台在 EAST 显示偏移 (-5,0)，真实网格不移动。它不是单刚性 3D 相机投影证明，未来 3D 需要独立验证。
3. Door 生产资源只有一个对角通行轴，其它视角水平镜像适配，光照也会镜像。旋转过程中固定贴图仍是 2D 表现，无新方向资产生产。
4. Surface/EAST 虽能看到对齐道路，该 Link 按本关 INNER-only 规则不可回穿；站立地面保留，继续到出口不受影响。
5. Godot 嵌入式游戏窗口失去焦点后，可能需要先点击游戏画面再用键盘。人工验收已实际恢复焦点；独立运行窗口无需编辑器输入转发。嵌入面板可能再次缩放画面，最清晰的原生最近邻效果见独立窗口整数倍率截图。
6. 没有音频、正式菜单、存档或下一关；这是本轮明确范围，不是未完成任务。首次玩家用时与乐趣仍待用户试玩反馈。

本阶段结束。P-01《另一个世界》已经成为可由用户本人实际试玩的完整谜题原型。未开始 P-02/P-03、音频、Live2D、Sprite Rework、主菜单、存档或章节系统。
