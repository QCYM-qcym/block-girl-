# FOUNDATION-3B Softlock Analysis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. NOT EXECUTED；等待用户后续授权。

**Goal:** 在3A统一图上区分可达Goal、确定Softlock、证据不足，并独立分类Reset恢复能力。

**Architecture:** 只消费Explorer已发现的图节点，从所有Goal沿reverse邻接遍历。完整UNFILTERED图的差集才是softlock；不调用新的玩法搜索、不生成Reset边。

**Tech Stack:** 现有Godot/GDScript RefCounted、SceneTree测试、PowerShell。

**Spec:** `docs/superpowers/specs/2026-09-16-foundation-solver-quality-contracts.md` §6–7、13–15、22–24、28–32。

## Global Constraints

- FROZEN DESIGN / NOT IMPLEMENTED；当前不执行、不commit/push/merge/创建worktree。
- 基线feat/foundation-core、4dda1fdce9c562427ab7541f1ee21266a3b8214a；执行前按新授权确认集成依赖。
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

- [ ] RED：手工算法图S→A→G、S→T，T是无出边sink；T无路到Goal。Key字段使用正式合法状态key，测试期望集合由fixture literal给出，不从待测reverse复制。增加两个Goal、所有节点可Goal、全图无Goal三类；环使用两个不同状态T↔U，不添加被正式图排除的无变化自环。

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

- [ ] GREEN：先粗检封闭结构/descriptor/预算；在记录容量内调用3A Graph.validate，再按下列有限reverse流程。输出key数组排序，见证沿已存predecessor，无新玩法探索。

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

- [ ] GREEN验证：无Goal完整图全部softlock并声明initial无解；Goal终止节点不在softlock；重复reverse边/错key/断predecessor由Graph.validate拒绝，返回ERROR而非继续修图。

## Task 2: 不完整性、预算与Reset

**Files:** softlock_analyzer.gd、test_softlock_analyzer.gd、softlock_fixtures.gd。

**Interfaces:** 消费graph.complete/stop_reason、Records.initial_state；产出UNKNOWN与nullable计数，不改变Graph。

- [ ] RED：上述图标为BUDGET partial，必须INCOMPLETE且softlock_states/count=null；FirstGoal partial也相同。FILTERED图、stop_reason ERROR、版本错返回ERROR。自定义初态图不含spawn时reset_recoverable_count=null。

```gdscript
var r := Softlocks.analyze(level, partial_graph, budget)
assert(r.status == 1)
assert(r.softlock_states == null and r.softlock_count == null)
assert(r.reset_classification == 2)
assert(r.reset_recoverable_count == null)
assert(r.goal_reachable_states.has(goal_key)) # 已证明的正向事实可以保留
```

- [ ] RED：图记录数超max_nodes或max_edges时返回INCOMPLETE，检查计数0、Goal正向集合空；invalid budget返回ERROR。受控clock让graph验证后或reverse中超时，不准COMPLETE。验证错误与超时同时出现时ERROR优先。
- [ ] GREEN：容量是接纳的不同图记录数；验证/reverse复用不重复计数。验证与遍历墙钟均纳入；Graph.validate不可硬中断，不宣称硬实时。完整验证后计nodes.size/edges.size。Reset只通过正式spawn key在同图的可达性证据分类；完整图spawn存在但不能Goal→NOT_RECOVERABLE_BY_RESET。
- [ ] GREEN验证：没有softlock但spawn不可判时count=0、分类UNKNOWN；partial未知节点从不进入softlock；输入Graph深比较不变。

## Task 3: 真实3A交接与回归

**Files:** test_softlock_integration.gd、softlock_fixtures.gd、run_validation.ps1、专属report、本plan。

**Interfaces:** 只通过真实Explorer FULL_GRAPH获得完整图；不得把单元手工complete字典作为最终证明。

- [ ] RED：真实Baker→Validator→Explorer分别生成可解无死局、小局部死局、完整无解、被搜索预算中止四fixture，写死每个fixture预期status与至少一个具名状态字段/见证路径；若3A不可用，记录DEPENDENCY_PENDING，不伪造PASS。
- [ ] GREEN：接真实Graph.validate和Explorer，前述四类结果与手算期望一致；所有softlock prefix在原图逐边可达，Reset从未出现在edges中。Baker/Validator的invalid fixture不能继续搜索。
- [ ] 编写wrapper：`-Godot/-EvidenceName`，stage60秒，后台Hidden，自有进程清理，checks>0与PASS/exit0/error扫描；新证据目录`.godot/foundation-3b/<EvidenceName>/`，保留HEAD/hash/stdout/stderr/输入budget与真实图来源，不覆盖旧证据。
- [ ] 执行验收命令；检查禁止文件未变并写报告，区分单元double与最终真实链。

```powershell
$godotExe = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
$projectRoot = 'E:/godot/若叶睦/方块少女-若叶睦'
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
