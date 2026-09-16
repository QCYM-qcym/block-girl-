# FOUNDATION-3A StateExplorer + BFS Solver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking. NOT EXECUTED；等待用户后续授权。

**Goal:** 通过唯一Kernel构建canonical有向状态图，返回一条最少semantic actions的解或准确的无解/预算/错误结论。

**Architecture:** ActionGenerator只枚举静态域；StateExplorer拥有唯一FIFO BFS、Graph与predecessor。BFSSolver是薄入口，SolutionTrace负责重建、结构校验及正式Kernel逐步语义校验。质量与Runtime通过冻结记录消费，不进入3A。

**Tech Stack:** 现有Godot/GDScript RefCounted与SceneTree测试；PowerShell独立证据wrapper。

**Spec:** `docs/superpowers/specs/2026-09-16-foundation-solver-quality-contracts.md` §1–13、22–24、28–32，foundation.analysis.v1。

## Global Constraints

- FROZEN DESIGN / NOT IMPLEMENTED；本轮仅写计划，没有执行下列步骤。
- baseline为4dda1fdce9c562427ab7541f1ee21266a3b8214a，feat/foundation-core。未来执行前确认授权分支、基线或已证明后代及工作区归属，不能覆盖并发修改。
- Kernel是唯一next_state来源；StateKey.build是唯一身份，GoalEvaluator是唯一Goal判定；Reset不入图。
- public API不允许skip_validation、double fallback或更改Level；Safety REJECTED保留，ERROR立即传播。
- 所有封闭记录/枚举/默认值以Spec为准；PolicyDescriptor是SearchPolicy去掉Callable的四字段投影。
- 本计划没有commit/push/merge/worktree操作；集成由用户另行授权。

## Exact files / Owner 3A

下列路径构成完整写入白名单；新增.gd的对应.uid也归3A，不能扩大目录授权。

| 文件 | 职责 |
|---|---|
| foundation/solver/solver_types.gd | SolverStatus/SearchMode/BudgetReason/GraphStopReason/AnalysisCode唯一枚举 |
| foundation/solver/search_records.gd | 默认policy/budget、内部封闭结果构造 |
| foundation/solver/action_generator.gd | 静态候选排序与同payload去重 |
| foundation/solver/state_graph.gd | 唯一Graph结构检查 |
| foundation/solver/state_explorer.gd | preflight、唯一BFS、预算与图原子插入 |
| foundation/solver/bfs_solver.gd | solve薄调用 |
| foundation/solver/solution_trace.gd | predecessor重建、结构与语义校验 |
| tests/foundation/solver/solver_fixtures.gd | 真实Baker关卡、literal期望及纯拓扑fixture |
| tests/foundation/solver/explorer_double.gd | tests-only受控Kernel/clock响应，不包含玩法公式 |
| tests/foundation/solver/test_action_generator.gd | 静态域、排序、无动态剪枝 |
| tests/foundation/solver/test_state_explorer.gd | BFS、预算、错误、真实链 |
| tests/foundation/solver/test_solution_trace.gd | 图/trace不变量与伪造路径负例 |
| tests/foundation/solver/run_validation.ps1 | 模块测试与证据保存，不修改旧wrapper |
| docs/development-records/FOUNDATION_STATE_EXPLORER_BFS_REPORT.md | 实际结果、范围与依赖来源 |
| docs/superpowers/plans/2026-09-16-foundation-state-explorer-bfs.md | 仅本计划执行勾选/记录 |

**Prohibited files:** 全部现有foundation生产文件；foundation/quality/、foundation/parity/；所有现有tests与其它Owner新增文件；project.godot、P-01、prototype/、tests/visual/、资产、其它Spec/plan/report、Obsidian。不得新建solver_shift/rotate/lighting/mapping等第二规则文件。

## Interfaces consumed / produced

读取既有正式 `Kernel.evaluate_action(level,state,action,RuleRecords.idle_context())`、`Goal.is_goal(level,state)`、`Key.build(level,state)`、`Codec.encode(level)`、`Validator.validate(level,{max_configurations,max_checks})`、`Records.initial_state(level)`。测试真实fixture通过 `Baker.bake(authoring,options)`，不得捏造content_hash。

产出以下static签名，Dictionary全部严格按Spec：

```gdscript
Actions.generate(level: Dictionary, state: Dictionary) -> Dictionary # ActionGenerationResult
Explorer.explore(level: Dictionary, initial: Dictionary, policy: Dictionary, budget: Dictionary) -> Dictionary # SolverResult
Solver.solve(level: Dictionary, initial: Dictionary, policy: Dictionary, budget: Dictionary) -> Dictionary # 同一结果
SearchRecords.default_policy(mode: int) -> Dictionary
SearchRecords.default_budget() -> Dictionary
Graph.validate(level: Dictionary, graph: Dictionary) -> Dictionary # {ok,issues}
Trace.from_graph(level: Dictionary, graph: Dictionary, goal_key: String) -> Dictionary # {ok,trace,issues}
Trace.validate(level: Dictionary, trace: Dictionary) -> Dictionary # {ok,issues}
Trace.validate_semantics(level: Dictionary, trace: Dictionary) -> Dictionary # {ok,transitions,issues}
```

3B/3C/3D读取此schema，不写3A文件。通用transition_filter是Spec §7的Callable；3A绝不preload quality/intent。算法测试可使用私有依赖注入入口，但公开solve始终绑定真实依赖。

## Task 1: 静态候选与记录

**Files:** solver_types.gd、search_records.gd、action_generator.gd；solver_fixtures.gd、test_action_generator.gd（完整路径见白名单）。

**Interfaces:** 消费DATA动作字段和静态Level；产出Actions.generate/default_policy/default_budget及唯一类型。

- [x] RED：在fixture中声明USE组旋转、USE天体、ENTER天体、FaceTransition、两World旋转域。断言下列候选规则；运行单文件并记录缺入口/断言失败。

```gdscript
var generated := Actions.generate(level, initial)
assert(generated.ok)
assert(generated.actions.filter(func(a): return a.kind == 0).size() == 4)
assert(generated.actions.any(func(a): return a.kind == 1))
assert(not generated.actions.any(func(a): return a.kind == 5 and a.mechanism_id == &"enter_plate"))
# 同一fixture把玩家移到不同合法稳定Face，候选仍等于原静态全集。
assert(Actions.generate(level, another_valid_state).actions == generated.actions)
```

- [x] GREEN：实现DATA shape检查；按Spec §4逐种枚举、深复制、明确字段元组排序；只去重同payload，保留TRIGGER和direct别名。默认预算精确10000/100000/-1/0/200000，validator默认4096/100000。
- [x] GREEN验证：单文件通过，倒序插入Level各数组后候选序不变；无Mapping/Lighting/Safety调用；非法静态数据返回issues而非修复。

## Task 2: BFS、Graph与预算闭包

**Files:** state_graph.gd、state_explorer.gd、bfs_solver.gd；explorer_double.gd、solver_fixtures.gd、test_state_explorer.gd。

**Interfaces:** 消费Task 1与正式Kernel/Key/Goal/Validator；产出唯一StateGraph、SolverResult、SearchMetrics。

- [x] RED：tests-only拓扑给S→A→G（2步）、S→B→C→G（3步）及环A→S，第二个2步Goal路线允许同长多解。断言首次trace长度2、非Goal只展开一次、平行边均保存、完整图反向索引一致。另用真实Baker产生至少一条固定两步最短解，期望来自人工列出的合法动作与终点字段。

```gdscript
var policy := SearchRecords.default_policy(1) # FULL_GRAPH
var result := Solver.solve(level, Records.initial_state(level), policy, SearchRecords.default_budget())
assert(result.status == 0)
assert(result.graph.complete)
assert(result.solution_trace.total_actions == 2)
assert(result.metrics.shortest_solution_count == null)
assert(not result.metrics.shortest_solution_count_complete)
assert(Graph.validate(level, result.graph).ok)
```

- [x] RED：分别触发MAX_STATES/EDGES/DEPTH/RUNTIME_MS/ACTION_EVALUATIONS；增加“恰满但穷尽”“depth边指向旧节点”“FULL_GRAPH已找到Goal后超预算”。初态Goal+max_edges=0应SOLVED/零步/闭包；无Goal完整环应PROVEN_UNSOLVABLE。Kernel ERROR/1105不能被拒绝、过滤器或超时掩盖；Safety 1601 REJECTED只计数。
- [x] GREEN：按如下执行顺序实现唯一探索器。所有容量检查在插入前，所有变更一次性完成。

```text
validate policy/budget → Codec.encode → StaticValidator VALID → initial DATA/Goal/Key
insert initial; enqueue if non-goal
while queue nonempty:
  for candidate in Actions.generate(current):
    check attempt/time budget; evaluate official Kernel with idle_context
    ERROR => stop; REJECTED/no-op => count and continue
    validate returned state/key/Goal; call optional pure edge filter
    disallowed => filtered count; continue
    check new-node depth/state and edge capacity; atomically insert graph records
    first new non-goal => enqueue; first Goal + FIRST_SHORTEST => finish
  mark current expanded only after all candidates
queue exhausted => complete; Goal exists ? SOLVED : PROVEN_UNSOLVABLE
```

- [x] GREEN验证：Graph.validate核对全部key/双向引用/首次predecessor/depth/expanded；callback错误FILTER_ERROR，拒绝/ERROR不能送callback；输入深复制保护。计数预算运行两次（禁墙钟）图与首解相同，只有elapsed_ms可不同。
- [x] RED/GREEN：invalid hash/invalid level/Validator INCOMPLETE均graph=null，不调用Kernel；Graph结构失败ERROR，未穷尽永不PROVEN_UNSOLVABLE。纯测试可注入计时器，真实公开调用不接受伪Validator证书。

## Task 3: Trace重建与语义可信边界

**Files:** solution_trace.gd、test_solution_trace.gd、solver_fixtures.gd。

**Interfaces:** 消费Task 2 Graph、正式Kernel/Goal/Key；产出from_graph、validate、validate_semantics。

- [x] RED：断链、循环predecessor、错depth、错hash、错step key、未知字段均失败；结构/key/Goal合法但某动作无法到达expected_state的伪造trace，validate可成功而validate_semantics必须失败。

```gdscript
var trace := solved.solution_trace.duplicate(true)
trace.steps[0].action = Records.make_action(1, {}) # fixture中该处Shift正式拒绝
assert(Trace.validate(level, trace).ok)
var checked := Trace.validate_semantics(level, trace)
assert(not checked.ok)
assert(checked.transitions.is_empty())
```

- [x] GREEN：沿first predecessor反向重建再反转；字段、版本与descriptor逐层深复制。语义校验从初态对每步调用正式Kernel，校验APPLIED.changed、完整状态/key/global_kind，成功返回一一对应8字段transitions，失败不返回半条证据。
- [x] GREEN验证：零步Goal；多Goal；MOVE+ENTER为一步；trace无Keyboard/Node/帧依赖。语义校验不能声称证明最短性或filter，3D不能用它替代真实Session。

## Task 4: 独立验收、回归与交接

**Files:** run_validation.ps1、专属report、本plan；不修改旧测试。

- [x] RED：wrapper要求每个测试exit0、checks>0、明确stage PASS、无SCRIPT ERROR/ERROR/FAIL；故意失败一次确认不能误报通过，保留失败日志。
- [x] GREEN：每stage 60秒进程上限，Start-Process后台用WindowStyle Hidden；超时仅终止自己启动的进程。证据位于项目`.godot/foundation-3a/<EvidenceName>/`，目录存在时拒绝覆盖；记录HEAD、依赖SHA256、参数、stdout/stderr、结果。不得输出到C盘。
- [x] 运行以下验收命令；wrapper必须支持`-Godot`与`-EvidenceName`。缺3A正式真实链或任何失败不可输出模块PASS。

```powershell
$godotExe = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
$projectRoot = 'E:/godot/若叶睦/方块少女-若叶睦'
Set-Location -LiteralPath $projectRoot
& $godotExe --headless --path $projectRoot --script res://tests/foundation/solver/test_action_generator.gd
& $godotExe --headless --path $projectRoot --script res://tests/foundation/solver/test_state_explorer.gd
& $godotExe --headless --path $projectRoot --script res://tests/foundation/solver/test_solution_trace.gd
& ./tests/foundation/solver/run_validation.ps1 -Godot $godotExe -EvidenceName ('accept_3a_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
& ./tests/foundation/full_integration/run_validation.ps1 -Godot $godotExe -Headless -EvidenceName ('regress_3a_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
git diff --check
git status --short
```

- [x] Report逐项列真实fixture的status/descriptor/complete/stop/budget/metrics/trace范围，区分double与真实集成；自检禁止文件无diff，提交用户review后停止。

**PASS token:** `FOUNDATION_STATE_EXPLORER_BFS_PASS`，仅真实依赖全部验收通过且CONTRACT_MISMATCH: NONE。它不是任意关卡有解保证。

**CONTRACT_MISMATCH stop rule:** 若当前API、记录字段或规则与冻结Spec不符，停止依赖步骤，报告精确path/expected/actual/受影响Owner；保留已完成测试，不修改旧production/Spec/他人文件来迁就。依赖尚未交付应标DEPENDENCY_PENDING，只能完成double阶段，不宣称真实PASS。

## Execution record — 2026-09-16

Executed on user-authorized worktree `E:/godot/worktrees/block-girl-foundation-solver`, branch `feat/foundation-state-explorer-bfs`, clean baseline `69590f91e32c72103f885b32bb29e57eee36a0c3`. Original plan baseline notes above are historical; no Spec was changed.

All four tasks completed. New module: three suites / 162 assertion checks. Existing FOUNDATION-2 full integration: 77 checks. Real two-step golden uses MOVE then SHIFT; a straight three-cube roll was independently observed to receive formal Safety UNPROVEN, retained as a negative fixture rather than bypassing Safety. RED/GREEN stages and intentional wrapper failure are preserved. Two independent-review findings were fixed and regression-tested; final focused review had no remaining concrete findings.

Final evidence: `.godot/foundation-3a/accept_3a_final_20260916/`; regression: `.godot/foundation-2-full/regress_3a_final_20260916/`. Detailed statuses/metrics/trace scopes and exact files are in `docs/development-records/FOUNDATION_STATE_EXPLORER_BFS_REPORT.md`.

FOUNDATION_STATE_EXPLORER_BFS_PASS
CONTRACT_MISMATCH: NONE

Stopped with changes unstaged; no commit/push/merge.

## Final closeout — 2026-09-16

User authorized final verification followed by commit and push of `feat/foundation-state-explorer-bfs` only. Baseline remains `69590f91e32c72103f885b32bb29e57eee36a0c3` before commit. No feature changes were made during closeout.

- [x] Reread contract, plan, report and all seven production scripts; duplicate-rule audit passed.
- [x] Fresh module validation: 162 checks, exit 0, 0 failures; `.godot/foundation-3a/closeout_3a_20260916_134544/`.
- [x] Fresh FOUNDATION-2 integration regression: 77 checks, exit 0, 0 failures; `.godot/foundation-2-full/closeout_regress_3a_20260916_134544/`.
- [x] Update final report with current evidence, scope and integration readiness. Commit only the 27 authorized files; evidence/cache remain excluded.

Commit title: `feat: add foundation state explorer and bfs solver`. The closeout authorization supersedes the previous keep-uncommitted handoff; no PR/merge/rebase/force push or main-worktree modification is included. Final commit hash, push confirmation and working-tree status are reported after the GitHub Desktop actions.
