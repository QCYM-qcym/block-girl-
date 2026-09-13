# FOUNDATION-2A Puzzle Rule Kernel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This plan is NOT EXECUTED; execution requires the user's subsequent authorization.

**Goal:** 实现 Runtime 与未来Solver共用的纯原子规则核心，完整结果与可证明的busy局部移动。

**Architecture:** Kernel只编排第一波正式Math/DATA/Spatial/Celestial及2B共享几何安全查询。Runtime不写规则，Kernel不读取动画/输入。唯一纯入口同时完成合法性查询与完整下一态生成。

**Tech Stack:** Godot 4.7.2、GDScript RefCounted/static函数、SceneTree自动测试、PowerShell验收。

**Spec:** `docs/superpowers/specs/2026-09-13-foundation-puzzle-rule-kernel-contracts.md`，execution_contract=foundation.execution.v1；必须同时读core contracts与架构§33。

## Global Constraints

- FROZEN DESIGN / NOT IMPLEMENTED；本次FOUNDATION-2.0只交付计划，下面所有复选框保持未执行。
- 数据19字段、状态六字段、statekey.v1、cube24.v1、八动作及1105不改；正式动作名LOCAL_GROUP_ROTATE。
- 不修改第一波production/tests、其它Owner、公共Spec、旧P-01或project.godot；不commit/push/merge，除非后续用户另行明确授权。
- 2B Safety不是已存在的第一波API；可并行写测试double，真实集成必须等其正式实现。double只在本Work测试目录，不创建邻Owner占位文件。

## Exact files / Ownership

以下为2A唯一允许新增文件；每个.gd的对应.gd.uid同属2A。只可更新本plan进度及自己的report。

| 文件 | 职责 |
|---|---|
| foundation/rules/rule_types.gd | TransitionStatus及仅新增2000..2003拒绝码；不复制Types既有枚举 |
| foundation/rules/rule_records.gd | idle_context、begin_global及深复制封闭结果工厂 |
| foundation/rules/puzzle_rule_kernel.gd | evaluate_action、complete_global、动作事务编排 |
| foundation/rules/derived_state_resolver.gd | 成功快照/Mapping/Lighting编排及失败短路 |
| foundation/rules/connectivity_resolver.gd | 共面精确邻接，非Spatial变换副本 |
| foundation/rules/transition_permission.gd | busy准入、已接受事务与局部MOVE交换性证明 |
| foundation/rules/mechanism_effects.gd | ENTER/USE授权、单效果、无递归链 |
| foundation/rules/goal_evaluator.gd | 只读GoalResult |
| tests/foundation/rules/kernel_fixture.gd | 小型有授权机制/合法组边的真实数据fixture；不能照搬第一波shape fixture宣称业务有效 |
| tests/foundation/rules/safety_double.gd | 仅测试可控SAFE/UNSAFE/UNPROVEN/ERROR边界 |
| tests/foundation/rules/test_rule_kernel.gd | 八动作与原子/错误/Goal主套件 |
| tests/foundation/rules/test_busy_transition.gd | 延迟提交/两序等价/拒绝无队列套件 |
| tests/foundation/rules/run_validation.ps1 | 分进程测试、真实依赖标记、日志/退出码/超时 |
| docs/development-records/FOUNDATION_RULE_KERNEL_REPORT.md | 结果、缺口与实际证据 |

Prohibited files：foundation/{orientation,contracts,spatial,celestial,validation,level,runtime}/；tests/foundation原有所有文件与integration/；game/；prototype/；production/；tests/visual/；project.godot；其它三计划/report与所有Spec。

## Interfaces / Dependencies

- `Kernel.evaluate_action(level: Dictionary,state: Dictionary,action: Dictionary,context: Dictionary) -> Dictionary`，固定PuzzleTransitionResult八字段；`complete_global(level,state,context) -> Dictionary`同结果。
- `RuleRecords.idle_context() -> Dictionary`；`begin_global(level: Dictionary,result: Dictionary) -> Dictionary`，ContextResult。
- `Derived.snapshot(level,state)`、`shift_mapping(level,state)`、`light(level,state,face_id: StringName)`分别返回原正式Spatial/Mapping/Lighting结果。
- `Connectivity.query_move(level,state,face_axis: int) -> Dictionary`，ConnectivityResult；`Goal.is_goal(level,state) -> Dictionary`，GoalResult。
- `Safety.validate_state(level,state)`、`validate_motion(level,before,after,action)`、`validate_concurrent_motion(level,before,after_local,after_global,local_action,global_action)`来自2B的`foundation/validation/safety_queries.gd`；不得在production内用测试double兜底。
- 内部effects/permission helper不是第二套跨Work公共API，由Kernel调用；所有跨Work调用只使用Spec的签名，不让Runtime读取内部函数。

## Task 1：完整Result、只读Goal与失败原子性

Files：rule_types、rule_records、kernel、goal、kernel_fixture、test_rule_kernel。

- [ ] RED：写下列断言及坏level/state/action/context、UNKNOWN_FIELD、1105副本隔离反例；运行主测试确认因入口缺失或断言失败退出1，保存原失败。

```gdscript
var before := state.duplicate(true)
var action := Records.make_action(Types.PuzzleActionKind.MOVE, {"face_axis": 0})
var result := Kernel.evaluate_action(level, state, action, RuleRecords.idle_context())
check(state == before, "query preserves old state")
check(result.status == RuleTypes.TransitionStatus.REJECTED, "missing neighbor rejects")
check(result.next_state == null and not result.changed, "no partial state")
check(result.rejection_code == RuleTypes.ActionRejectionCode.MOVE_BLOCKED, "canonical rejection")
var goal_result := Goal.is_goal(level, state)
check(goal_result.ok and not goal_result.is_goal and state == before, "goal is read only")
```

- [ ] 最小实现：先串联DATA shape与封闭Result工厂；成功next_state=`state.duplicate(true)`后仅在私有candidate中变更；ERROR工厂固定next_state=null。Goal按face_id与required_flags，不新增完成字段。
- [ ] GREEN：有效/无效输入与修改输出后输入不变；初态与Goal真实Safety未接前标记为单元double结果，不能最终PASS。

## Task 2：MOVE、Shift及Derived真实链接

Files：derived、connectivity、kernel、fixture、test_rule_kernel。

- [ ] RED：fixture包含一对共面相邻Face、同Cube不同法线Face、另世界SAME/OPPOSITE重合、一个遮挡体；分别断言roll方向、边缘拒绝、亮面拒切/回切不要求阴影、source/target独立blocked。

```gdscript
var shifted := Kernel.evaluate_action(level, state, Records.make_action(1, {}), RuleRecords.idle_context())
check(shifted.status == RuleTypes.TransitionStatus.APPLIED, "shadow SAME shift")
check(shifted.next_state.player.orientation == state.player.orientation, "SAME keeps shared pose")
# OPPOSITE fixture source Frame=3,target Frame=17,pose=0:
check(opposite_result.next_state.player.orientation == 19, "full frame golden, not fixed half turn")
check(overflow_result.status == RuleTypes.TransitionStatus.ERROR, "1105 is ERROR")
check(overflow_result.next_state == null and light_call_count == 0, "no light call after failed snapshot")
```

- [ ] 最小实现：调用正式collect→resolve，NONE/UNIQUE/AMBIGUOUS/ERROR四分支；roll用Math.quarter_turn/compose，OPPOSITE用reframe；对target搜索只比较提升后的整数坐标。
- [ ] GREEN：固定3→2结果1和3→17结果19；四roll/正反恢复；抖乱数据不改结果；真实sealed多目标先ERROR1201，独立resolution AMBIGUOUS测试不能冒称合法多目标关卡。

## Task 3：旋转、显式换面与机关/Slot事务

Files：kernel、mechanism_effects、fixture、test_rule_kernel。

- [ ] RED：World承载/不承载、不同World下Group的W×delta×W逆、合法/非法组边、同Cube多step通道与逆路径；远程机关、伪造目标、ENTER重复站立、两个ENTER全局效果失败。

```gdscript
var rotated := Kernel.evaluate_action(level, state, Records.make_action(2, {"rotation_delta": 2}), RuleRecords.idle_context())
check(rotated.next_state.player.location == state.player.location, "carrier keeps local identity")
check(rotated.next_state.player.orientation == Orientation.compose(2, state.player.orientation), "carrier rotates pose")
check(rejected_group.next_state == null and state == before, "unsafe group has no half commit")
check(two_enter_effects.status == RuleTypes.TransitionStatus.ERROR, "no priority winner for multiple globals")
check(two_enter_effects.issues[0].code == Types.ValidationCode.MULTIPLE_GLOBAL_MUTATIONS, "1501")
```

- [ ] 最小实现：统一效果分派，授权按本Face、trigger与逐字段action等值；读取正式Slot结果；有向边/allowed域先验，再调用共享Safety；通道用source Cube局部steps与正式Math，禁止通过Frame重置pose。
- [ ] GREEN：SET当前Slot changed=false；NEXT/PREVIOUS/TOGGLE与无边1301；flags/mechanism_states保持全量不变；非法宽profile数据ERROR且不修改DATA使其通过。实际ENTER踏板MOVE+天体效果一次返回完整next_state，begin_global对此拒绝开ticket；local roll落定完整提交，不能分拆player/Slot。

## Task 4：Busy可交换MOVE与完成事务

Files：transition_permission、rule_records、kernel、test_busy_transition。

- [ ] RED：稳定A接受global后仍A；移动两步后完成B不丢最新player；承载World/Group MOVE含pose等价；goal/ENTER/跨载体不许可；Reset旧ticket由Runtime测试，Kernel测试坏context/trace。

```gdscript
var prepared := Kernel.evaluate_action(level, state, global_action, RuleRecords.idle_context())
var opened := RuleRecords.begin_global(level, prepared)
check(opened.ok and state.celestial.slot_id == &"a", "request is not commit")
var local_result := Kernel.evaluate_action(level, state, move_action, opened.context)
check(local_result.status == RuleTypes.TransitionStatus.APPLIED, "safe local move during busy")
var moved := local_result.next_state
opened.context.local_moves.append(move_action.duplicate(true))
var finished := Kernel.complete_global(level, moved, opened.context)
check(finished.next_state.player.location == moved.player.location, "celestial completion keeps latest player")
check(StateKey.build(level, finished.next_state).key == serial_key, "canonical atomic ordering")
```

- [ ] 最小实现：context记录已执行MOVE；核内重放原接受授权，按载体变换重映射轴；两种次序比较完整StateKey与安全，并调用共享并发扫掠查询；失败明确1504/ERROR；完成返回完整next_state，不让调用方merge字段。
- [ ] GREEN：所有global在MOVING和TRANSITION都拒绝且不留任何pending字段；goal/ENTER不被动画窗口悄悄跳过；completion不用重新站回console；无变化Slot不开ticket；不能证明的MOVE拒绝而普通安全路线仍可走。

## Task 5：真实2B Safety联调与验收

Files：两个test、run_validation、report与本plan。

- [ ] 在真实2B实现可用后，测试入口preload正式Safety；移除测试注入路径在真实模式的使用，保留double仅用于错误分支单测。记录依赖HEAD。
- [ ] 运行全套真实八动作与所有失败原子性、SAFE/UNSAFE/UNPROVEN/1105；接真实Math/Spatial/Celestial/StateKey，不复制邻模块文件。
- [ ] wrapper用隐藏进程、退出码+明确PASS+错误扫描+60秒超时，证据只写`.godot/`或ignored evidence的新目录。汇总实际断言数，不把历史81,014当本次新结果。
- [ ] 完成报告、ownership diff检查；需要改合同则返回CONTRACT_MISMATCH并停止，不自行升级。

## Acceptance command / PASS

后续实现完成才运行（在项目或隔离工作区根）：

```powershell
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/foundation/rules/test_rule_kernel.gd
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/foundation/rules/test_busy_transition.gd
& './tests/foundation/rules/run_validation.ps1' -EvidenceName rule_kernel_final
& './tests/foundation/run_validation.ps1' -EvidenceName rule_kernel_foundation_regression
```

两套件exit0且failures=[]、真实依赖齐备、既有FOUNDATION回归通过、无越权文件后，才可输出 **FOUNDATION_RULE_KERNEL_PASS**。缺真实Safety仅允许报告UNIT_TESTS_WITH_DOUBLE_PASS，不得输出上述最终token。本轮没有运行这些命令、没有创建这些生产文件。
