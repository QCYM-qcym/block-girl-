# P01 POLISH FOUNDATION REPORT

Date: 2026-09-13 (Asia/Shanghai)

Branch: `feat/playable-puzzle-p01`

HEAD before / after: `433289de9604dd07707e0ff5d41fb4326f2fd774`

Godot Version: `4.7.2.stable.steam.ed1daf0bf`，Windows，Forward+ / D3D12，NVIDIA GeForce RTX 5060 Ti。

Final Status: P01_POLISH_FOUNDATION_PASS

## 本轮结果

P-01 增加 12 个基础 SFX、两条环境循环、约 0.4 秒的局部像素世界过渡、轻微旋转与连接端点反馈、三个情境键位图，以及约 1.8 秒的完成演出。复用现有正式角色、地面和机关资源。谜题、移动、24 态姿态、输入控制器、四视角与机关状态逻辑未改写。

音频全部是本项目程序化生成的 TEMP 基础素材，非正式 BGM。音频 PASS 指已验证触发、PCM 输出、音量余量与通关解耦，不代表 Codex 完成了主观听音评价。耐听性与最终混音需要用户本人反馈。

| 项目 | 结果 | 证据与边界 |
|---|---|---|
| Roll SFX | PASS | 连续持键运行触发 Roll/Land；固定单 cue 单声部；实际最多 3 个 SFX 同时播放 |
| World Shift SFX | PASS | 双向关联 motif 实际触发；世界状态不依赖音频 |
| World Shift FX | PASS | 局部离散像素溶解与重现；0.25 秒原锁定 + 0.15 秒表现尾段 |
| Perspective Rotate Feedback | PASS | Q/E 与系统鼠标长拖均吸附；短拖回弹；沿用 60 px 阈值、0.4 秒吸附 |
| Perspective Link Feedback | PASS | 1 px 端点轻反馈和低音量 cue；无答案文字；主要 FX 关闭后仍可通关 |
| Pressure Plate Feedback | PASS | 原下降动画、短边缘反馈与声音；踏上后门立即响应 |
| Door Feedback | PASS | 原开关动画与状态提交；缺少开门音频仍能通过门 |
| Exit Feedback | PASS | Inner Locked、Surface Ready、抵达后 Complete；原出口激活动画保留 |
| Tutorial WASD | PASS | 开始淡入，小键帽；首次移动后淡出；Reset 重现 |
| Tutorial Shift | PASS | 第一断路才出现 Space 键位图；成功切换淡出 |
| Tutorial Rotate | PASS | 中间平台才出现 Q/E 与鼠标水平图标；成功旋转淡出 |
| Puzzle Complete | PASS | 原玩法立即锁定；短暂停顿、环境降音、压暗、标题与 R 提示；1.8 秒完成 |
| Ambience | PASS | 两条 8 秒周期循环、约 0.4 秒世界交叉淡化；完成时降低 14 dB；TEMP |
| Muted Playthrough | PASS | 系统键盘 M 关闭 Master，从起点 13 步完整通关，声音始终关闭 |
| Q/E Playthrough | PASS | 系统键盘路线 A，13 步，F3 全程关闭 |
| Mouse Playthrough | PASS | 系统拖动路线 B，短拖回弹、长拖 EAST，13 步，F3 全程关闭 |
| Regression | PASS | 全部旧核心与正式角色 GPU 回归通过，详见下表记录 |
| External Audio License Audit | NOT_APPLICABLE | 没有外部音频；14 个自制文件的来源、作者、CC0-1.0、可再分发记录齐全 |
| First-time User Test | REQUIRED | TUTORIAL_FIRST_USER_VALIDATION_REQUIRED |

## 自动验证

- `tests/gameplay/test_p01_polish.gd`：最终 `runtime_03`，74 项检查，0 失败。键盘、鼠标、Master 静音、音频与主要 FX 关闭、缺失 Door Open 音频五条完整路线具有相同最终格、姿态、世界、视角及 13 次移动。
- 覆盖 Shift 输入锁、Rotate 输入锁、完成后 Move/Shift/Rotate 锁定、Reset 清理完成与 Shader 状态、教程标志、实际 12 条 cue 触发、固定音效通道、缺失音频不影响 Door、FX 关闭不影响 Link。
- AudioEffectCapture 从实际 Godot Master 混音读取 5,310,464 个声道样本，峰值 `0.08846753`，RMS `0.00595769`；最大 3 个活跃 SFX。实际混音片段保存在 `tests/gameplay/evidence/p01_polish/runtime_03/actual_mix.wav`。这不证明用户扬声器状态或主观听感。
- `test_p01_polish_pixels.gd`：48 项检查，0 失败。两世界正式角色与地面，1/2/3/4 倍、原态与溶解态，在实际 GPU 渲染中检查同一原生像素块颜色一致、未溶解像素保持源颜色、溶解只去除部分像素。最终 stderr 为空。
- 连续按住 W 使用 Godot Input 的一次 press、延后 release 验证；系统键鼠人工路线采用实际按键和鼠标操作，没有把逐格点按冒充物理持键测试。
- RED 记录保留；首次接线运行暴露一个动态边界变量缺少显式 Rect2 类型，修复后 runtime_02/03 通过。像素短测试曾在退出前未留足音频线程释放时间，增加测试退出等待后消除 4 个播放实例的警告。游戏逻辑未因此改动。

## 旧系统回归记录

`run_p01_validation.ps1 -EvidenceName polish_p01 -IncludeRegressions` 已完整执行通过：P-01 状态 31 项 / 108 个可达状态全部可解，P-01 Runtime 167 项；Perspective Logic 66 项 / 24 态，定向缺陷回归 172 项，Perspective Runtime 54 项；旧 Puzzle 状态 50 项 / 94 个状态全部可解，输入回归通过，旧 Runtime 3452 项；Sprite 60 张、Tileset 107 张、Mechanism 78 张运行截图，全部无失败。对应各阶段 stdout / stderr 与 JSON 保存在 `polish_p01/`、`polish_p01_regression/`。

正式 Orientation Sprite 静态资源检查 857 项通过；Cube Orientation 可视化 632 项、正式 Orientation Sprite GPU Runtime 1780 项全部通过，stderr 为空。后两项证据位于 `p01_polish/cube_regression/`、`p01_polish/orientation_regression/` 及对应 stdout / stderr。

对实施前快照中的 209 个已有文件逐个比较 SHA-256，唯一变化为预期的 P-01 装配脚本。旧 tests/visual、生产角色/地面/机关、共享 movement/orientation/view 与 P-01 状态文件保持原字节。旧 Tileset 测试会重存样例，沿用既有运行包装器保存并恢复该样例的原始字节；未修改旧测试。证据：`p01_polish/protected_files.json`。

## 系统键鼠人工验收详情

实际运行正式 P-01 场景，以 `p01_polish_manual.gd` 被动记录状态和截图。记录器不注入输入、不写玩法状态。输入由 Windows Computer Use 发送到 Godot 窗口；所有操作后检查窗口。

| 路线 | 实际操作 | 完成截图 |
|---|---|---|
| A | WASD、Space、E、机关、Exit | `tests/gameplay/evidence/p01_polish/manual/state_044.png` |
| B | WASD、Space、短拖回弹、长拖 EAST、机关、Exit | `tests/gameplay/evidence/p01_polish/manual/state_088.png` |
| C | 起点 M 静音，WASD、Space、E、机关、Exit | `tests/gameplay/evidence/p01_polish/manual/state_133.png` |

三次均抵达 `(13,0)` / Surface / EAST，持久姿态 `(1,0,0)|(0,0,-1)|(0,1,0)`，13 次移动，完成演出时间 1.8 秒，F3 全程关闭。被动轨迹和汇总为 `manual/trace.json`、`manual/playthrough_summary.json`。人工验收日志无脚本错误。

观察：世界变化短促、没有长时间等待；键盘与鼠标最终吸附节奏一致；短拖回弹正常；连接高光没有弹文字或路径答案；三个教程图标在地图下方，未挡道路；压力板占用立即开门，穿过后关闭；出口形状和激活状态可辨；完成演出在停顿后淡入并提供 R。静音时这些视觉信息仍存在。

未声称完成“第一次玩家、不看解法”的测试。验收者知道解法；记录用时含工具观察与暂停，不能用作新手 2–5 分钟体验的证据。

## 文件范围

已有文件修改仅：

- `game/levels/mutsumi/p01_another_world.gd`：装配五个表现模块、更新静音状态提示；不承载新的谜题逻辑。
- `docs/design/p01-another-world.md`：同步正式 Orientation Sprite 基线、声音、FX、教程与完成演出。

本轮新增：

- `game/polish/p01_audio.gd`、`p01_feedback.gd`、`p01_polish.gd`、`p01_tutorial_view.gd`、`p01_completion_view.gd`、`pixel_dissolve.gdshader` 及 Godot UID。
- `default_bus_layout.tres`：Master / SFX / Ambience。
- `production/audio/p01/TEMP_roll.wav`、`TEMP_land.wav`、`TEMP_shift_inner.wav`、`TEMP_shift_surface.wav`、`TEMP_rotate.wav`、`TEMP_link_on.wav`、`TEMP_link_off.wav`、`TEMP_plate.wav`、`TEMP_door_open.wav`、`TEMP_door_close.wav`、`TEMP_exit_ready.wav`、`TEMP_complete.wav`、`TEMP_amb_surface.wav`、`TEMP_amb_inner.wav`，对应 `.import` 和 `manifest.json`。
- `production/ui/p01/tutorial_keys.png` 与 `.import`。
- `tests/gameplay/build_p01_polish_assets.py`、`test_p01_polish.gd`、`test_p01_polish_pixels.gd`、`p01_polish_manual.gd` 及 Godot UID。
- `docs/audio/AUDIO_ASSET_MANIFEST.md`、`docs/audio/SOUND_DIRECTION.md`、`docs/art/POLISH_DIRECTION.md`、`docs/design/P01_POLISH_FOUNDATION_SPEC.md`、`docs/superpowers/plans/2026-09-12-p01-polish-foundation.md`、本报告。
- 本轮证据目录：`tests/gameplay/evidence/p01_polish/`、`polish_p01/`、`polish_p01_regression/`。

已有工作区包含此前阶段的未提交成果。本轮没有 reset/restore/clean，也没有 commit/push/merge/rebase 或修改 remote。最终报告的文件范围按本轮快照比较，不能把整个 Git 未提交列表当成本轮新增。

## 操作与原解法

WASD：按住连续逐格翻滚；Space：保持格坐标、物理姿态与视角切换世界；Q/E 或鼠标水平拖动：旋转 90°；R：随时重置；M：Master 静音；F3：姿态信息；F4：主要局部 FX 调试开关。

原解法不变：出生 W×3 → Space → W×2 → D×3 → E（或右拖）→ W 跨连接 → Space → W×2 踩板开门 → W×2 抵达 Exit。

## Known Issues / 验证边界

1. TUTORIAL_FIRST_USER_VALIDATION_REQUIRED；首次玩家是否理解、是否在 2–5 分钟完成需要用户本人试玩。
2. 音频是合法自制 TEMP 基础音效和环境循环。是否耐听、是否过轻、不同设备上的音量平衡待用户听音反馈；未完成主观声音质量验收。
3. 为保持既有玩法锁定规则，Shift 在 0.25 秒提交后即可继续操作，重现尾段还持续约 0.15 秒；此短尾段只影响可见程度，不写位置或姿态。
4. 原有门另一投影轴使用水平镜像，光照方向限制沿用已验收资产。本轮没有重做资源。

## 提交建议（未执行）

标题：`feat: 完善 P-01 视觉与音频反馈`

说明：为 P-01《另一个世界》补充基础音效、世界切换效果、视角旋转反馈、透视连接反馈、教程提示与关卡完成演出，在不改变谜题核心逻辑的前提下提升完整游玩体验。

完成后停止本阶段，等待用户试玩；不开始 P-02、Live2D、正式 BGM 或其它系统。
