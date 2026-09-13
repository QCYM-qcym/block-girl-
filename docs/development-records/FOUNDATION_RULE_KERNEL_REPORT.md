# FOUNDATION-2A — Puzzle Rule Kernel Provisional Report

```text
FOUNDATION_RULE_KERNEL_PROVISIONAL_PASS
BLOCKER: WAITING_FOR_2B_SAFETY_INTEGRATION
CONTRACT_MISMATCH: NONE
```

日期：2026-09-13。当前仅是用户授权的 provisional 验收，不是最终真实 Safety 联调结果。

## 工作区与合同

- 实际工作树：`E:/godot/worktrees/block-girl-foundation-rule-kernel`
- 实际分支：`feat/foundation-rule-kernel`
- 开始/结束 HEAD：`b7fd6ae9cfa1961a4ca52bb977d66e87903fcec5`
- 执行合同：`foundation.execution.v1`；公共 API 修订：`foundation.contract.v1.1`
- 数据标签继续使用 `foundation.contract.v1`、`cube24.v1`、`foundation.rules.v1`；StateKey 使用 `statekey.v1`
- 引擎：`Godot Engine v4.7.2.stable.steam.ed1daf0bf`

已读取正式架构 Spec、Core Contract、Puzzle Rule Kernel Contract 与本 Work 计划。没有改变公共字段、枚举、坐标、Face 法线、Frame 手性、组合顺序、19 字段 LevelDefinition 或六字段 PuzzleState。

需求中的 ROTATE_LOCAL_GROUP 使用合同唯一名称 `LOCAL_GROUP_ROTATE=6`，未新增别名或第九动作。预检怀疑的组 allowed_rotation_deltas 字段经当前合同与 DATA 实现核对确实存在，没有产生合同偏差。

## 文件

新增 8 个纯 `RefCounted` 逻辑脚本及对应 UID：

| 文件 | 职责 |
|---|---|
| `foundation/rules/rule_types.gd` | TransitionStatus；仅新增四个 2000..2003 拒绝码 |
| `foundation/rules/rule_records.gd` | 封闭结果、Context/ticket 工厂、输入边界、深复制、诊断规范排序 |
| `foundation/rules/puzzle_rule_kernel.gd` | evaluate_action、complete_global 与原子动作事务 |
| `foundation/rules/derived_state_resolver.gd` | 正式 Snapshot/Validation/Mapping/Lighting 调用与失败短路 |
| `foundation/rules/connectivity_resolver.gd` | 同层共面精确邻接，提升为 int64 后比较 |
| `foundation/rules/transition_permission.gd` | Busy ticket 重放、完整状态交换性与并发 Safety 调用 |
| `foundation/rules/mechanism_effects.gd` | 首版 profile、ENTER/USE 授权、确定顺序收集单效果 |
| `foundation/rules/goal_evaluator.gd` | shape/空间/Safety 后只读 GoalResult |

新增测试文件：`tests/foundation/rules/kernel_fixture.gd`、`safety_double.gd`、`test_rule_kernel.gd`、`test_busy_transition.gd`，均含对应 UID；另有同目录 `run_validation.ps1`。

文档仅更新本 Work 的 `docs/superpowers/plans/2026-09-13-foundation-rule-kernel.md`，并新增本报告。总计 27 个文件：26 个新增、1 个修改。无全局 class_name，无运行场景、输入、相机、动画、音频、渲染或 Safety 算法副本。

## 原子入口与 Transition 结果

正式 `evaluate_action(level,state,action,context)` 返回八字段 PuzzleTransitionResult：status、previous_state、next_state、action、changed、rejection_code、issues、global_kind。

- APPLIED：返回完整候选六字段状态；不修改调用者；只有完整新旧状态不同才 changed=true。
- REJECTED：next_state=null、changed=false、global_kind=NONE；使用合同 canonical rejection_code。
- ERROR：next_state=null、rejection_code=0，至少一条 ERROR issue；1105 始终是 ERROR，保留原始下层诊断内容。

按 DATA shape/context → 当前空间/Safety → Busy/授权 → 动作查询 → 私有候选 → 安全/光照 → 下一态验证的顺序短路。查询失败不会继续将 null/部分 Snapshot 传给 Lighting。输出的 previous_state、next_state、action、issue 集合分别深复制。

自动测试在每次主套件动作前后比较 `var_to_bytes([level,state,action,context])` 和正式 StateKey；APPLIED、REJECTED、ERROR 均保持输入不变。修改返回副本不影响输入。晚期 Slot/ENTER 效果错误丢弃整个 MOVE 候选，没有 player 已提交、Slot 尚未提交的半态。

## 八类动作

| 动作 | 已实现行为与单元证据 |
|---|---|
| MOVE | 使用源 Frame 的 FaceAxis 查正式快照；唯一同层共面 walkable 邻接；边缘拒绝，不自动绕同 Cube 边。Math.quarter_turn/compose 更新姿态；正反和四次连续 roll 验证 |
| SHIFT_WORLD | 正式 collect→resolve；SAME 保持姿态，OPPOSITE 使用完整 Frame reframe；明暗和独立 entry/exit 限制 |
| ROTATE_SURFACE | 检查允许增量/端态，左乘对应 World；承载玩家更新 pose，本地 Location 身份保持 |
| ROTATE_INNER | 相同事务路径；玩家在另一个 World 时保持 player 全量不变 |
| USE_FACE_TRANSITION | 同 Cube 不同 walkable Face 的显式非空 step 通道，校验每步法线及 entry/exit；多步与逆路径验证，位移/扫掠委托正式 Safety |
| TRIGGER_MECHANISM | 只解析当前 Face 的 USE 单一效果，然后走统一动作事务；远程与错误 trigger 拒绝 |
| LOCAL_GROUP_ROTATE | 精确授权、allowed_states/deltas 与完整有向边；父 World 下增量左乘组，玩家按 W×delta×inverse(W) 跟随；golden W=2、delta=22 得 Shared delta=9 |
| MOVE_CELESTIAL | 委托正式 SET/NEXT/PREVIOUS/TOGGLE 与 Slot 图；只写 celestial.slot_id；SET 当前 Slot changed=false，不开 ticket |

每个动作均覆盖 APPLIED 和合法 REJECTED；非法 shape/reference、业务 profile、溢出、下层错误另走 ERROR。当前这些动作的 Safety 判断使用测试替身，不能据此声称连续轨迹已获得真实几何安全证明。

## Shift、OPPOSITE 与 Derived

Surface→Inner 必须唯一映射、source exit 未阻止、target entry 未阻止且源 SHADOW；Inner→Surface 不要求 Shadow。NONE 为 REJECTED1400；AMBIGUOUS 和 ERROR 保持下层 issues 并 ERROR，均不继续光照。

固定 OPPOSITE goldens：Frame 3→2、pose0 得1；Frame 3→17、pose0 得19。未固定半圈轴或回正。真正的 sealed 多目标 fixture 先由正式 Snapshot Validation 以1201拒绝；独立 AMBIGUOUS 用正式 Mapping.resolve_mapping 生成包装，再以 test-only seam 检验 Kernel 分支，不声称该集合是合法未封闭关卡。

Derived 调用正式 Geometry.snapshot 与 SpatialValidation，再用正式 Mapping 和 LogicalLighting。没有调用邻模块私有 helper，也未复制 AnchorOverlap、FaceCompatibility、候选解析或光照算法。光照按 Face ID 排序查询，成功结果和错误诊断均不因声明数组置乱改变。Anchor、Frame、Lighting、Safety、Busy/context 全部不持久化、不写入 StateKey。

## Busy 与完成事务

ExecutionContext 仅含 global_transition_state、ticket、local_moves。ticket 仅保存 level_hash、原 base_state 和 accepted_action。begin_global 只封闭校验并深复制，不提交状态，不反向 preload Kernel；ticket 消费时仍重新计算原授权。

local_moves 是已提交普通 MOVE 的重放记录，没有 queue/deferred/pending。每次重放必须精确重建当前正式 StateKey，篡改 hash/原动作/trace/state 明确 ERROR。

Busy 时七类全局动作在 MOVING、TRANSITION 均立即拒绝1500。局部 MOVE 须满足两序完整 StateKey 相等，并调用 Safety.validate_concurrent_motion；串行安全不能代替组合扫掠。跨运动载体、进入 ENTER、进入或离开 Goal 均保守拒绝1504；普通无邻接仍是2000。测试包含 Celestial、承载 World、承载 Group 期间连续两步 MOVE 正例及完整 completion，最新玩家位置不会被启动时副本覆盖，也不要求走回 console 再授权。

MOVE+ENTER 是一次原子复合动作，不能开启延迟 global ticket；本地 roll 落定时由未来 Runtime 整体提交。complete_global 返回完整下一态，不要求 Runtime 逐字段合并。Reset/generation/旧视觉 callback 属后续 Runtime 验收，本 Work 没有实现。

## Mechanism 与 Goal

只接受合同首版 ENTER/USE、固定单状态机关、三种允许效果。直接组/天体动作必须逐字段等于绑定机制 action，知道 mechanism_id 不构成任意授权。多个 ENTER 全局效果 ERROR1501，任一效果 REJECTED/ERROR 都回滚外层 MOVE。站立不会自行再次 ENTER，非全局状态/flags 完整保留，无动态门/flag/FSM 扩展。

Goal 在 shape、空间和 Safety 成功后只比较正式 face_id 与 required_flags。未达成返回 ok=true/is_goal=false；坏输入、Safety 包装或安全结果返回 ok=false/is_goal=null，绝不改变任何状态。

## 测试与证据

全部证据位于本工作树忽略目录 `.godot/`，没有写到其它 Work。

| 最终测试 | 断言数 | 结果/目录 |
|---|---:|---|
| 主 Kernel 套件 | 717 | exit0、failures=[]；`.godot/foundation-2a-validation/kernel_provisional_final/` |
| Busy 套件 | 116 | exit0、failures=[]；同目录 |
| 独立 Query helper | 37 | exit0、failures=0；`.godot/foundation-2a-evidence/final-metadata/helpers.*.log` |
| 第一波既有完整回归 | 81,014 | 6 个实际新运行进程通过；`.godot/foundation-1-validation/kernel_provisional_regression/` |

本次两套正式规则测试共 **833** 项；37 项 helper 证据单列，81,014 是本次重新运行的原有回归数量，不计作新写的 Kernel 测试。最终所有成功进程 stderr 为空。

TDD 与修复证据均未覆盖旧失败文件：

- `.godot/foundation-2a-evidence/initial-red/`、`expanded-red/`：明确缺 Kernel 实现，退出1。
- `.godot/foundation-2a-evidence/busy-red/`：明确缺 Busy permission，退出1。
- `.godot/foundation-2a-query-evidence/`：三 helper 的 RED/37项 GREEN。
- `.godot/foundation-2a-validation/kernel_diagnostic_red/`：诊断 ID/tuple 排序反例。
- `kernel_safety_wrapper_red/`：SAFE 携1105被错误放行的反例。
- `kernel_order_red/`：光照错误受 Face 顺序影响的反例。
- `kernel_warning_overflow_red/`：1105 WARNING 归一化后缺 ERROR级诊断的反例。
- `kernel_unit_01` 至 `kernel_unit_07`：解析/fixture 修正及各轮 GREEN；最终结果以 `kernel_provisional_final` 为准。

Safety 包装校验覆盖缺字段、未知状态、额外字段、ERROR空诊断、SAFE带issue、1105严重性不符；并发专用坏包装测试只注入 concurrent 查询，未被 validate_state 提前拦截。原始下层诊断保持，必要时追加本层 ERROR 说明。独立审查两轮指出的问题均有检错测试与修复复审，无残留发现。

可复现命令（从本工作树运行，EvidenceName 使用新名字避免覆盖证据）：

```powershell
& './tests/foundation/rules/run_validation.ps1' -EvidenceName another_provisional_run -UnitDouble
& './tests/foundation/run_validation.ps1' -EvidenceName another_foundation_regression
```

## 真实 Safety 阻塞与 test-only 边界

当前没有 `foundation/validation/safety_queries.gd`。生产 Kernel/Goal 静态 preload 正式路径，没有动态兜底或本地 Safety 算法。

单元 wrapper 在忽略证据目录复制本 Work 的规则脚本，只重定向依赖到明确 test-only 的 Safety double 和 query seam；原生产文件不修改。query seam 默认仍委托真实 Derived，只在指定错误用例返回受控包装。正式模式不会创建或使用这些替换路径；缺真实 Safety 时立即失败并保留 `.godot/foundation-2a-validation/kernel_real_gate/dependency.txt`。

待 2B 返回正式通过且由用户 commit/push、接入真实接口后，才能运行不带 `-UnitDouble` 的两套测试以及第一波回归，处理可能出现的真实 swept-volume/profile 集成问题。当前不对真实扫掠结果、2B 联合安全或 Runtime 可玩性作通过声明。

## Git diff 与停止状态

仅本报告文件表所列允许文件发生变化；公共合同、第一波生产/测试、2B/2C/2D、P-01、project.godot 均未改。没有跨工作树复制生产文件。

完整 Git diff（包含未跟踪新文件）与状态保存为 `.godot/foundation-2a-evidence/final-metadata/kernel-worktree.diff.txt`、`git-status.txt`。普通 git diff 只显示已跟踪计划，不把未跟踪新文件遗漏成“无改动”。已核对允许路径与新增文件空白；未 stage、commit、push、merge 或 rebase。

当前停止于用户授权的 provisional 边界，唯一未解除的集成阻塞是正式 2B Safety。
