# PLAYABLE_PUZZLE_PROTOTYPE_01_PASS

2026-09-12 · P-01「另一个世界」

已在现有工程 **E:/godot/若叶睦/方块少女-若叶睦** 实现并实际通关。独立场景为 `res://prototype/puzzle_01.tscn`。`project.godot` 的 main_scene 已指向它；现有编辑器已接受外部配置更新，通过“运行项目”（F5 对应入口）实际启动，移动、Reset 正常。交付时窗口保留在起点。

## 启动与控制

在 Godot 打开上述工程，按 **F5** 运行项目。也可打开 `res://prototype/puzzle_01.tscn` 后按 F6。旧资源测试场景仍保留；在旧场景按 F6 仍会运行资源测试。

| 输入 | 行为 |
|---|---|
| W / ↑ | 右上 NE，逻辑 -Z |
| D / → | 右下 SE，逻辑 +X |
| S / ↓ | 左下 SW，逻辑 +Z |
| A / ← | 左上 NW，逻辑 -X |
| 空格 | Surface / Inner 同坐标切换 |
| R | 随时恢复起点、角色、踏板、门、出口及计数 |
| H | 逐级显示提示 |

每按一次移动一格，播放已验收的对应方向翻滚，结束后提交格坐标；长按系统重复事件忽略。移动/切换/互动中忽略其他玩法输入，R 始终可用。目标世界缺地面或门仍阻挡时禁止切换，并显示红色中文说明。

## 关卡解法

先在断路前切到 Inner，沿新路抵达左上压力板。压力板压下并完成互动后保持点亮，Surface 的门开始开启；离开踏板不会关门。原路回到中央分叉，沿右下通道走到尽头，在共有地面回 Surface，再沿右上通道穿门抵达出口。

从 Reset 起点的精确路线（每次翻滚结束再按下一次）：

1. **D×5 → W×1 → 空格**。
2. **W×5 → A×4 → W×2**，踩到压力板并等待点亮。
3. **S×2 → D×4 → S×3 → D×4 → 空格**。
4. **W×5**，穿过门，到达 Exit，出现 **PUZZLE COMPLETE**。
5. **R** 重新开始。

该路线共 **35 次移动、2 次世界切换**。门的通行轴严格沿已验收 NE/SW 朝向，开启动画结束前保持逻辑阻挡。出口必须在 Surface、门已打开、玩家落定后才能完成。完成后禁用移动与切换，Reset 保持可用。

## 实际新增与修改文件

以下路径均以工程根 `E:/godot/若叶睦/方块少女-若叶睦/` 为前缀。

| 文件 | 用途 |
|---|---|
| `prototype/puzzle_01.tscn` | 新增独立可玩入口 |
| `prototype/puzzle_01.gd` | 本关协调、最小中文 HUD、反馈与 Reset |
| `prototype/puzzle_state.gd` | 本关地图、单玩家世界/位置、动作阶段、机关与完成状态 |
| `prototype/player.tscn` | 玩家 Body / Shadow 节点 |
| `prototype/player.gd` | 输入、原资产翻滚/切换/互动/完成动画、像素取整移动 |
| `prototype/board.gd` | 已验收 TileSet 与机关场景装配、世界显隐、坐标及深度 |
| `tests/prototype/test_state.gd` | 规则与地图穷举测试 |
| `tests/prototype/test_input.gd` | 逻辑键码兼容回归测试 |
| `tests/prototype/test_runtime.gd` | 实际引擎按键驱动、动画/Reset/通关与 GPU 截图 |
| `tests/prototype/run_validation.ps1` | 一键复验，带超时、退出码、错误日志检查 |
| `tests/prototype/evidence/.gdignore` | 截图/日志不作为游戏资产导入 |
| `docs/prototype_01_design.md` | 设计及资产接入约定 |
| `docs/prototype_01_plan.md` | 已完成的实施计划 |
| `docs/prototype_01_issues.md` | 问题根因、回归修正与限制 |
| `docs/PLAYABLE_PUZZLE_PROTOTYPE_01.md` | 本报告 |
| **`project.godot`** | **唯一修改的原有文件；仅更改 main_scene** |

Godot 为上述 7 个 GDScript 自动生成了相应 `.gd.uid`。新增验收数据在 `tests/prototype/evidence/run_01/`、`final_20260912/`、`manual/`、`development/`。完整机器清单见 `changed_files.json`。

未创建任何新角色图、地块图或机关图。直接加载原 `production/sprites` SpriteFrames、两套 TileSet，以及原 PressurePlateInner / Door / ExitGoal 场景。原机关实例在本关由逻辑到达驱动，关闭其 Area2D 自动监听，避免在翻滚半途中提前触发；原场景与脚本没有修改。

未引入 Moving Platform、Rotating Structure、Live2D、其他角色、正式关卡框架、Autoload、存档或 UI 大系统。

## 自动验收结果

最终复验：`tests/prototype/evidence/final_20260912/`。

| 检查 | 实际结果 |
|---|---|
| 引擎 | Godot **4.7.2 stable Steam**，Windows 图形窗口 |
| 渲染 | **Forward Plus / D3D12 / NVIDIA GeForce RTX 5060 Ti** |
| 导入 | 退出码 0，stderr 空 |
| 状态测试 | **50 项检查通过** |
| 穷举可达状态 | **94 / 94 可继续通关**，无需依赖 Reset 脱困 |
| 按键兼容回归 | 先复现失败，再修正通过，实际提交一格移动 |
| 图形 Runtime | **3,452 次断言，0 失败**；含逐帧像素坐标检查，不等于 3,452 个独立测试用例 |
| 动画 | 两角色四向翻滚、双向切换均观察到完整 6 帧；完成动画亦完整 6 帧 |
| 机关 | idle→pressed→active，closed→opening→open，locked→ready→active→complete→completed |
| 输入边界 | 缺地面、门关闭/开启中、非法切换、系统重复键与动作重叠均覆盖 |
| Reset | 翻滚中、切换中、踏板互动中、门开启中、出口完成中、通关后全部通过 |
| 窗口 | 1280×800、960×640、1600×1000 截图已检查，棋盘整数倍率 |
| 图像 | 12 张不同 GPU 截图，包含起点、翻滚、两世界、拒绝反馈、踏板、门、完成、Reset 与缩放 |
| 日志 | import / state / input / runtime 四阶段 stderr 全空，最终脚本退出码 0 |

本轮自动验收用时约 56.7 秒，包含多次重置和重复路线，**不能作为首次玩家完成时长**。

复验命令（每次使用新的 EvidenceName）：

```powershell
& 'E:/godot/若叶睦/方块少女-若叶睦/tests/prototype/run_validation.ps1' -EvidenceName 'review_01'
```

## 手动路径与独立审查

通过 Windows Computer Use 向普通游戏窗口发送实际系统按键，非直接改游戏状态：确认方向键与 WASD、同格切换、非法切换提示、压力板点亮、门开启，完成 35 步/2 切换通关，再按 R 恢复全部初始状态。实机画面在 `tests/prototype/evidence/manual/`。

现有编辑器起初仍缓存旧 main_scene，已点击“从磁盘重新加载”，停止旧资源运行窗口并从编辑器“运行项目”入口启动 P-01。编辑器启动后的移动和 R 亦实测正常。

独立只读代码审查：无 Critical / Important 问题。唯一 Minor 是首次验收未等待玩家庆祝动画播完；已补齐等待及六帧断言，复审确认解决。

按键诊断曾发现 Windows 自动操作事件的逻辑 D/Right 正确，但物理键码为 Tab；控制器已补充仅在物理控制键无法识别时使用逻辑键码。原始失败与成功证据保留。动画接续同时参考 [Godot AnimatedSprite2D 官方文档](https://docs.godotengine.org/en/stable/classes/class_animatedsprite2d.html)，最终判断基于本机实跑。

## 资产与旧测试完整性

开工前建立 **970 个原有文件 SHA256 基线**。结束时 **969 个完全不变**；唯一差异是 `project.godot` 的 main_scene。其中 **88 个 production 文件、877 个 tests/visual 文件全部哈希一致**。没有改动或重建已验收资产、原测试场景及验收证据。

## 已知问题与验证边界

无已知阻止游玩或通关的问题。

- **2–5 分钟是首次发现玩法的设计目标，尚未经过陌生玩家盲测校准。** 熟悉上述解法后可明显更快；不以延迟或强制等待凑时长。
- 暂无音效，提示依靠原资产动画与简短中文 HUD。每次按键走一格，未实现长按连续移动。
- 只验收了当前 Windows/Godot/显卡环境，没有声称已测试其他平台或发布导出包。

**最终状态：PLAYABLE_PUZZLE_PROTOTYPE_01_PASS**
