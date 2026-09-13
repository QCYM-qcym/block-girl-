# CUBE_SPRITE_ORIENTATION_REWORK_REPORT

2026-09-12 · `feat/playable-puzzle-p01`

最终状态：**CUBE_SPRITE_ORIENTATION_REWORK_PASS**。

正式若叶睦与 Mortis 像素资源已接入 P-01 和独立正式 Sprite 场景，完成真实 Godot 图形运行及系统键鼠目检。本次通过对象是新 PNG 图集，不是将 X 方块通过结果替代正式角色验收。

## 结果

| 项目 | 结果 |
| --- | --- |
| Logical Orientations | 24，沿用已有 CubeOrientation |
| Unique Visual States | 每皮肤13个稳定外观；两皮肤26个 |
| Mutsumi | PASS |
| Mortis | PASS |
| Single Physical Face | PASS |
| Persistent Orientation | PASS |
| Perspective Mapping | PASS |
| World Shift Mapping | PASS |
| Continuous Roll | PASS，单次持续Input按下至少5格 |
| Debug Cube Parity | PASS |
| P-01 Regression | PASS |
| Old Sprite | DEPRECATED（正式P-01用途）；原旧资源测试仍保留引用 |

## 资源设计与尺寸

固定六个物理面，只有 `FACE_FRONT=local+Z=CHARACTER_FACE` 有角色脸，其余五面共用无方向、无脸的发色材质。可见脸的三种位置各含四种面内旋转，共12个外观；隐藏脸的12个逻辑姿态合并成1个无脸外观，因此每皮肤13种。四个 Perspective 通过相机相对姿态复用同一表，不制作四套。

正式资源使用24×24画布、pivot=(12,21)、静止外接框(4,5)至(19,20)，保持旧正式角色16×16比例；没有改成32×32。两皮肤每一对应帧 alpha 完全一致。Mutsumi 使用低饱和灰绿、浅灰绿小脸；Mortis 使用银灰、冷灰绿、深蓝灰边和少量紫色标记。没有多面复制脸、四肢或装备。

90°roll为起点、22.5°、45°、67.5°、终点，共5采样、3中间帧。相机90°旋转采用9采样，包含7中间帧，支持正反向、环绕及鼠标回弹。两皮肤共享映射、几何和节奏。先生成稳定态并通过74项检查，再生成过渡；按成对RGBA及物理脸mask精确去重后，**每皮肤178帧**（含13个稳定外观），图集384×288，共两张。

完整规格：[CUBE_SPRITE_PRESENTATION_SPEC](../design/CUBE_SPRITE_PRESENTATION_SPEC.md)。逐条192个稳定映射、面定义、region、pivot、visibility、roll目标与世界皮肤见生产清单。图集全部真实RGBA、alpha仅0/255，Lossless、Nearest、无mipmap；标签/背景只存在于preview。

## 正式生产目录

源生产：`E:/Study/方块娘项目/若叶睦/photo/production/sprites/v2_orientation/`。

Godot副本：`res://production/sprites/v2_orientation/`。

- `mutsumi/face_front.png`、`face_unmarked.png`、`orientation_atlas.png`。
- `mortis/face_front.png`、`face_unmarked.png`、`orientation_atlas.png`。
- `shared/orientation_sprite_manifest.json`：完整只读映射、区域、色板、面mask计数。
- `shared/character_face_mask.png`、`stable_validation_pass.json`、`generation_notes.md`。
- `orientation_sprite_manifest.md`：192行可读稳定映射表。
- `spec/CUBE_SPRITE_PRESENTATION_SPEC.md`。
- `preview/stable_orientations.png`、`north_roll_cycle.gif`；源目录另保留两张 `preview/imagegen_drafts/` 原稿。

imagegen仅生成物理正面原稿；原稿是DRAFT，未直接标为GODOT_READY。已执行像素网格、尺寸、固定眼口像素、透明度、色板、pivot和frame alignment清理。完整提示词与处理过程在 `shared/generation_notes.md`。

## 代码与实际改动范围

新增 Player 表现：`game/player/orientation_sprite_presenter.gd`。复用原X Presenter 的固定身份/调试接口，读取现有 mover.orientation、view 和 phase；常数次lookup选择region，不维护另一份可变逻辑Orientation，也不在P-01里写Sprite Mapping。

新增测试与生产工具：

- `tests/gameplay/export_sprite_orientations.gd`：调用已有CubeOrientation导出24态及相机置换。
- `tests/gameplay/build_orientation_sprites.py`：原稿清理、2D投影、图集去重与preview。
- `tests/gameplay/test_orientation_sprite_assets.py`：离线资源合同。
- `tests/gameplay/test_orientation_sprite_runtime.gd`：实际GPU图形验证。
- `tests/gameplay/orientation_sprite_visual_test.tscn/.gd`：继承原fixture的正式模式，正式角色和X使用同一mover/view。
- 对应 Godot `.uid`，规格、计划、本报告和本轮evidence。

本轮仅修改两个既有文件：`game/levels/mutsumi/p01_board.gd` 的Player引用，以及 `p01_another_world.gd` 去除临时X美术提示、保留F3入口。旧X实现/测试、Movement、Perspective、World/Puzzle状态、地图、机关、Tileset及旧Sprite PNG都未改。相对本轮开始176个文件哈希快照，174个保持一致。

## 自动及实际Godot验证

环境：Godot4.7.2.stable.steam.ed1daf0bf / Windows / Forward+ / D3D12 / RTX5060Ti。

| 验证 | 实际结果 |
| --- | --- |
| 稳定资源 | 74 checks PASS；精确13外观/皮肤 |
| 完整资源 | 857 checks PASS；二值alpha、共享轮廓、画布/基线、roll/camera端点、视角置换 |
| 正式Sprite GPU Runtime | 1780 checks，failures=[] |
| 原单面X Runtime | 632 checks，failures=[] |
| 新P-01状态 | 31 checks；108/108可达状态可解 |
| 新P-01 Runtime | 167 checks；正常键盘与鼠标视角两条路线均从头到Exit/Complete，再Reset |
| 原Perspective回归 | logic66 / bugfix172 / runtime54，均通过 |
| 旧Puzzle回归 | state50、94/94状态可解，input PASS，runtime3452通过 |
| 旧Sprite/Tileset/Mechanism | 分别60/107/78次运行捕获通过 |

正式GPU测试对24姿态×4视角×2皮肤的192种稳定组合逐项检查物理面及X一致性，并将选中24×24region在8倍Nearest下的全幅实际屏幕像素与PNG逐像素比对。另在NORTH/Surface受控枚举24态×4方向×5采样，检查全部roll端点与过渡帧像素；这不是“每种视角下全部动态过渡均已穷举”的声明。动态视角通过四次Q、鼠标输入和共享映射审查验证。

连续roll使用一次Input press保持至至少五次commit，每次新步起始姿态等于前步目标。面部停留10.1秒保持；TOP换世界保姿态。实际P-01路线包含连续移动、World Shift、Perspective Rotate/Link、Pressure Plate、Door、Exit、Complete与Reset，没有用传送玩家代替正常路线。

证据：`tests/gameplay/evidence/sprite_rework/runtime_02/`、同级运行日志、`debug_cube_regression/`；P-01为 `sprite_rework_p01/`，旧回归为 `sprite_rework_p01_regression/`。

首轮 `runtime_01` 有96个过渡终点断言失败：测试错误写入了getter派生属性moving/fraction，并未驱动真实采样。改为暂停fixture tick后设置phase/elapsed，原生产逻辑不变；`runtime_02` 全部1780项通过。首轮证据保留。只读审查发现同一测试问题，已关闭；未发现其他重要/严重实现问题。新通过运行及各回归stderr为空。

## 系统键鼠目检

使用独立正式Sprite窗口，左侧正式角色，右侧X基准，默认1200×820。截图与JSON位于 `sprite_rework/manual/`。

| Case | 结果 |
| --- | --- |
| A NORTH W×4 | PASS：SOUTH→TOP→NORTH隐藏→BOTTOM隐藏→SOUTH，正式脸与X同面 |
| B W×1等待 | PASS：等待23.181秒，仍TOP、IDLE、Moves1 |
| C W×1后Q×4 | PASS：NORTH→WEST→SOUTH→EAST→NORTH，逻辑姿态和坐标不变，正式顶面纹理面内方向随观察改变 |
| D TOP按Space | PASS：Mortis仍TOP，与Mutsumi同物理位置和轮廓 |
| E按住W至少5格 | 自动持续Input事件PASS；系统工具只支持tap，未冒充物理长按人工结果 |
| F W D S A | PASS：脸随混合轴旋转，终点TOP，始终与X物理面一致 |
| 鼠标拖动 | PASS：转至WEST，物理姿态保持 |

## 试玩、已知边界与停止点

- 正式模式：打开 `res://tests/gameplay/orientation_sprite_visual_test.tscn` 后 F6。
- 原X模式：`res://tests/gameplay/cube_orientation_visual_test.tscn` 原样保留。
- F5仍运行P-01，已接入正式角色。
- WASD连续滚动，Q/E或水平拖动转视角，Space切世界，R重置，F3调试。

当前小尺寸脸细节刻意克制；在顶面投影时可读像素更少。动画是离散像素采样，不是平滑3D网格；X连续投影和正式采样在两个采样之间可略有进度差，落定与下一步起点一致。独立窗口默认尺寸完成目检，未宣称任意缩放/DPI均已穷举。正式美术风格后续以用户试玩反馈为准。

旧Sheet仍供历史资源测试使用，但正式游戏角色已弃用其固定idle/roll方案；没有删除或覆盖旧文件。没有改Gameplay或进入P-02、Audio、Live2D、菜单或存档阶段。HEAD保持 `433289de9604dd07707e0ff5d41fb4326f2fd774`，未commit/push/merge/rebase或改remote。

本轮在 **CUBE_SPRITE_ORIENTATION_REWORK_PASS** 停止，等待用户试玩正式角色。
