# FOUNDATION-3B Softlock Analysis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking. 已按后续用户授权执行；真实3A集成与最终验收完成，详见专属report。

**Goal:** 在3A统一图上区分可达Goal、确定Softlock、证据不足，并独立分类Reset恢复能力。

**Architecture:** 只消费Explorer已发现的图节点，从所有Goal沿reverse邻接遍历。完整UNFILTERED图的差集才是softlock；不调用新的玩法搜索、不生成Reset边。

**Tech Stack:** 现有Godot/GDScript RefCounted、SceneTree测试、PowerShell。

**Spec:** `docs/superpowers/specs/2026-09-16-foundation-solver-quality-contracts.md` §6–7、13–15、22–24、28–32。

## Global Constraints

- FROZEN DESIGN；本轮用户授权接入正式3A提交并在最终PASS后commit/push自己的3B分支。不创建其它worktree，不merge foundation-core/main，不创建PR。
- 实际工作区feat/foundation-softlock-analysis，来自FOUNDATION-3基线69590f91e32c72103f885b32bb29e57eee36a0c3；已通过fast-forward接入正式3A提交f34dd271adabcc4b724eb55b5fff1cb35f532e59。
- 只接收本进程真实Explorer产出且未经变更的Graph；手工Graph只作tests-only算法fixture。
- statekey.v1为唯一身份；Graph格式及其验证归3A。UNFILTERED判断使用完整PolicyDescriptor.filter_descriptor。
- graph.complete=false或reverse未完成：softlock_states/count=null，不能把unknown标成softlock。
- 不为Reset消除softlock；同关卡spawn不在自定义初态图时Reset分类UNKNOWN。

## Exact files / Owner 3B

| 文件 | 职责 |
|---|---|
| foundation/quality/softlock/softlock_types.gd | SoftlockStatus、ResetClassification唯一枚举、私有结果构造 |
| foundation/quality/softlock/softlock_analyzer.gd | 图准入、reverse、差集、Reset分类 |
| tests/foundation/quality/softlock/softlock_fixtures.gd | 单元Graph与真实Baker关卡输入 |
| tests/foundation/quality/softlock/graph_contract_double.gd | 3A未集成时的窄校验响应；无Explorer实现 |
| tests/foundation/quality/softlock/test_softlock_analyzer.gd | 集合、预算、Reset、错误负例 |
| tests/foundation/quality/softlock/test_softlock_integration.gd | 真实3A FULL_GRAPH到Softlock |
| tests/foundation/quality/softlock/run_validation.ps1 | 独立验收wrapper |
| docs/development-records/FOUNDATION_SOFTLOCK_ANALYSIS_REPORT.md | 证据范围与结果 |
| docs/superpowers/plans/2026-09-16-foundation-softlock-analysis.md | 本plan勾选 |

对应新增.gd.uid归3B。**Prohibited files:** foundation/solver/、foundation/quality/intent/、foundation/parity/、所有已存在foundation/与tests逻辑、其它Owner tests/plan/report、Spec、prototype/、P-01、project.godot、tests/visual/及资产。不能用目录所有权追加新公共Graph helper。

## Interfaces consumed / produced

消费 `Graph.validate(level,graph)->{ok,issues}`、`Records.initial_state(level)`、`Key.build(level,state)`；最终集成消费 `Explorer.explore(level,initial,SearchRecords.default_policy(FULL_GRAPH),budget)`。Graph有nodes/edges/forward/reverse/first predecessor，不能另造编号图。

产出static `Softlocks.analyze(level: Dictionary,graph: Dictionary,budget: Dictionary)->Dictionary`，固定SoftlockAnalysisResult：status、initial_key、reachable_states、goal_reachable_states、softlock_states/count、unknown_states、reset_classification、reset_recoverable_count、witnesses、metrics、issues。AnalysisBudget精确max_nodes/max_edges/max_runtime_ms，默认10000/100000/0；枚举及nullable语义沿Spec §15。witnesses为GraphPath数组，不能称SolutionTrace。

## Task 1: 完整图的reverse与证据路径

**Files:** softlock_types.gd、softlock_analyzer.gd、softlock_fixtures.gd、graph_contract_double.gd、test_softlock_analyzer.gd。

**Interfaces:** 消费Graph封闭记录；产出analyze完整结果。3A缺席时只用显式私有校验double，公开生产API不能自动fallback。

- [x] RED：手工算法图S→A→G、S→T，T是无出边sink；T无路到Goal。Key字段使用正式合法状态key，测试期望集合由fixture literal给出，不从待测reverse复制。增加两个Goal、所有节点可Goal、全图无Goal三类；环使用两个不同状态T↔U，不添加被正式图排除的无变化自环。

```gdscript
var r := Softlocks.analyze(level, graph, {"max_nodes": 10000, "max_edges": 100000, "max_runtime_ms": 0})
assert(r.status == 0)
assert(r.softlock_states == [trap_key])
assert(r.softlock_count == 1)
assert(r.unknown_states.is_empty())
assert(r.witnesses[0].target_key == trap_key)
# fixture的spawn就是S且可到G；Reset恢复不删除T的softlock身份。
assert(r.reset_recoverable_count == 1)
```

- [x] GREEN：先粗检封闭结构/descriptor/预算；在记录容量内调用3A Graph.validate，再按下列有限reverse流程。输出key数组排序，见证沿已存predecessor，无新玩法探索。

```text
goals = all graph.nodes where is_goal
can_reach_goal = goals; stack = goals
while stack nonempty:
  pop node; for edge_index in graph.reverse[node]:
    source = graph.edges[edge_index].from_key
    unseen source => add to can_reach_goal and stack
if graph.complete and traversal_finished:
  softlock = all graph.nodes - can_reach_goal
else:
  softlock = null; unknown = known nodes - proven can_reach_goal
```

- [x] GREEN验证：无Goal完整图全部softlock并声明initial无解；Goal终止节点不在softlock；重复reverse边/错key/断predecessor由Graph.validate拒绝，返回ERROR而非继续修图。

## Task 2: 不完整性、预算与Reset

**Files:** softlock_analyzer.gd、test_softlock_analyzer.gd、softlock_fixtures.gd。

**Interfaces:** 消费graph.complete/stop_reason、Records.initial_state；产出UNKNOWN与nullable计数，不改变Graph。

- [x] RED：上述图标为BUDGET partial，必须INCOMPLETE且softlock_states/count=null；FirstGoal partial也相同。FILTERED图、stop_reason ERROR、版本错返回ERROR。自定义初态图不含spawn时reset_recoverable_count=null。

```gdscript
var r := Softlocks.analyze(level, partial_graph, budget)
assert(r.status == 1)
assert(r.softlock_states == null and r.softlock_count == null)
assert(r.reset_classification == 2)
assert(r.reset_recoverable_count == null)
assert(r.goal_reachable_states.has(goal_key)) # 已证明的正向事实可以保留
```

- [x] RED：图记录数超max_nodes或max_edges时返回INCOMPLETE，检查计数0、Goal正向集合空；invalid budget返回ERROR。受控clock让graph验证后或reverse中超时，不准COMPLETE。验证错误与超时同时出现时ERROR优先。
- [x] GREEN：容量是接纳的不同图记录数；验证/reverse复用不重复计数。验证与遍历墙钟均纳入；Graph.validate不可硬中断，不宣称硬实时。完整验证后计nodes.size/edges.size。Reset只通过正式spawn key在同图的可达性证据分类；完整图spawn存在但不能Goal→NOT_RECOVERABLE_BY_RESET。
- [x] GREEN验证：没有softlock但spawn不可判时count=0、分类UNKNOWN；partial未知节点从不进入softlock；输入Graph深比较不变。

## Task 3: 真实3A交接与回归

**Files:** test_softlock_integration.gd、softlock_fixtures.gd、run_validation.ps1、专属report、本plan。

**Interfaces:** 只通过真实Explorer FULL_GRAPH获得完整图；不得把单元手工complete字典作为最终证明。

- [x] 真实集成测试：真实Baker→Validator→Explorer分别生成可解无死局、小局部死局、完整无解、被搜索预算中止四fixture，写死每个fixture预期status与至少一个具名状态字段/见证路径；若3A不可用，记录DEPENDENCY_PENDING，不伪造PASS。
- [x] GREEN：接真实Graph.validate和Explorer，前述四类结果与手算期望一致；所有softlock prefix在原图逐边可达，Reset从未出现在edges中。Baker/Validator的invalid fixture不能继续搜索。
- [x] 编写wrapper：`-Godot/-EvidenceName`，stage60秒，后台Hidden，自有进程清理，checks>0与PASS/exit0/error扫描；新证据目录`.godot/foundation-3b/<EvidenceName>/`，保留HEAD/hash/stdout/stderr/输入budget与真实图来源，不覆盖旧证据。
- [x] 执行provisional验收命令；检查禁止文件未变并写报告，区分单元double与最终真实链。

```powershell
$godotExe = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
$projectRoot = 'E:/godot/worktrees/block-girl-foundation-softlock'
Set-Location -LiteralPath $projectRoot
& $godotExe --headless --path $projectRoot --script res://tests/foundation/quality/softlock/test_softlock_analyzer.gd
& $godotExe --headless --path $projectRoot --script res://tests/foundation/quality/softlock/test_softlock_integration.gd
& ./tests/foundation/quality/softlock/run_validation.ps1 -Godot $godotExe -EvidenceName ('accept_3b_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
& ./tests/foundation/full_integration/run_validation.ps1 -Godot $godotExe -Headless -EvidenceName ('regress_3b_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
git diff --check
git status --short
```

**PASS token:** `FOUNDATION_SOFTLOCK_ANALYSIS_PASS`。必须真实3A完整/不完整图均验收，报告精确proof scope、reset分类、预算及unknown；不能只凭double通过。

**CONTRACT_MISMATCH stop rule:** 发现Graph字段/PolicyDescriptor/状态身份/API与Spec不符，停止相应集成，列expected/actual/path/Owner；不复制Graph/Explorer、不修改3A或旧production。依赖未交付仅DEPENDENCY_PENDING，等待交接后才做真实PASS。


## 2026-09-16 historical provisional evidence

- Task 1–2：算法、预算、Reset、排序、不可变性及两轮review修复完成；116 unit checks，0 failures。
- Task 3：真实Baker/Validator三输入与拒绝输入、依赖门禁共5 checks通过；真实3A四类Graph链未运行，前两项保持未勾选。此处不将tests-only图当Explorer产出。
- 3B wrapper：121 checks，exit0、stderr空，证据`.godot/foundation-3b/report_timeout_green/`。
- 既有FOUNDATION-2 headless全链回归：77 checks通过，证据`.godot/foundation-2-full/regress_3b_20260916/`。
- 结果：FOUNDATION_SOFTLOCK_ANALYSIS_PROVISIONAL_PASS；DEPENDENCY_PENDING: REAL_3A_STATEGRAPH；CONTRACT_MISMATCH: NONE。
- 只在当前worktree写3B清单文件。公共合同、其它Owner、P-01未改，未commit/push/merge。完整报告见`docs/development-records/FOUNDATION_SOFTLOCK_ANALYSIS_REPORT.md`。


## 2026-09-16 real 3A final acceptance

- [x] 读取正式3A接口，以`git merge --ff-only f34dd271adabcc4b724eb55b5fff1cb35f532e59`集成；无冲突、未手工复制、未修改3A。
- [x] 真实Baker/Validator→Explorer/BFSSolver→StateGraph→公开Analyzer：非平凡可解走廊、Sink、双状态环、多个Goal、全图无解、预算partial、自定义初态spawn缺失、初态Goal均覆盖。
- [x] Reset不进入ActionGenerator或Graph边；partial保留reachable/Goal/unknown证据，softlock字段保持null。
- [x] 重新验证115 unit +117 real integration =232 checks；正式3A162、FOUNDATION-2回归77、FOUNDATION-1回归81014，均exit0/0 failures。
- [x] 独立review后对齐初态Goal的EXHAUSTED测试fixture；真实FIRST_SHORTEST初态Goal验证通过。生产算法保持本轮接入前字节不变。
- [x] 证据`.godot/foundation-3b/real3a_acceptance/`含8个真实Graph案例、完整analysis、policy、budget及依赖hash。
- [x] 更新专属report；结果FOUNDATION_SOFTLOCK_ANALYSIS_PASS，CONTRACT_MISMATCH: NONE，DEPENDENCY_STATUS: REAL_3A_INTEGRATED。
- 最终commit/push按本轮用户明确授权执行，状态在最终交付消息报告；不PR、不merge main/core、不删除worktree。
