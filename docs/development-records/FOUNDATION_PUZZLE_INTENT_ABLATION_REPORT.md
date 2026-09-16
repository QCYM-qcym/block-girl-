# FOUNDATION-3C — PuzzleIntent + Mechanic Ablation

FOUNDATION_PUZZLE_INTENT_ABLATION_PASS

CONTRACT_MISMATCH: NONE

Date: 2026-09-16

Workspace: E:/godot/worktrees/block-girl-foundation-intent

Branch: feat/foundation-puzzle-intent-ablation

Start/end HEAD: 69590f91e32c72103f885b32bb29e57eee36a0c3

## PuzzleIntent

实现独立的 puzzleintent.v1 sidecar，精确八字段：intent_version、intent_id、level_hash、rule_version、required_mechanics、optional_mechanics、expected_milestones、forbidden_bypasses。没有扩展 LevelDefinition、PuzzleState 或 build_info。

intent_id、milestone_id、bypass_id 使用正式小写 StringName ID；hash/rule 必须匹配 Level。required/optional 为合法、唯一、升序的 MechanicTag 集合且互不重叠。forbidden 集合非空、唯一、升序；不同 bypass_id 可以声明同一个集合，求解去重但报告保留全部声明。里程碑保持作者顺序，禁止额外 DSL/未知字段。

谓词仅 AT_FACE(face_id)、IN_LAYER(layer)、FACE_LIGHT(light_state)、MECHANIC_USED(mechanic)、GOAL。引用、枚举与封闭分支字段均验证。类型错误使用冻结 AnalysisIssue ABI；3C 没有重新定义 3A AnalysisCode 枚举。

## MechanicTag

| Tag | 值 | 分类依据 |
|---|---:|---|
| MOVE | 0 | 成功的 MOVE 原子边。 |
| WORLD_SHIFT | 1 | 成功 Shift。 |
| SURFACE_ROTATE | 2 | Surface 实际旋转。 |
| INNER_ROTATE | 3 | Inner 实际旋转。 |
| FACE_TRANSITION | 4 | 直接、TRIGGER 或 ENTER 的实际 FaceTransition。 |
| LOCAL_GROUP_ROTATE | 5 | 绑定组实际改变姿态；不是 ActionKind 的数值别名。 |
| CELESTIAL_CHANGE | 6 | 绑定动作实际改变 slot。 |
| MECHANISM_TRIGGER | 7 | USE wrapper、直接绑定动作或 MOVE 触发的 ENTER。 |

唯一分类器消费正式八字段 PuzzleTransitionResult。MOVE 通过正式 Connectivity.query_move 找中间入场面，再用 Effects.enter_effects 找绑定机制，不能只看最终玩家面。真实 MOVE→ENTER→FaceTransition 的测试先到踏板 TOP，再离开到 FRONT，仍得到 [MOVE, FACE_TRANSITION, MECHANISM_TRIGGER]。

MOVE+ENTER 设置当前 slot 得到 [MOVE, MECHANISM_TRIGGER]，没有 CELESTIAL_CHANGE。整个动作 APPLIED 且无变化时返回空集合。REJECTED、ERROR、未知字段、changed 矛盾、不相符的 global_kind、无关状态变化，以及组未改变却声称只改变玩家姿态等不一致结果明确失败。没有复制 roll、Mapping、光照或任何搜索算法。

## Ablation 与 Bypass

公共 analyze 只接受完整 UNFILTERED SearchPolicy、空 callback；baseline 必须 SOLVED 才开始消融。baseline 无解为 BASELINE_UNSOLVABLE；预算不足为 INCOMPLETE；ERROR 保留原诊断。

对 required/optional 单 tag 与 forbidden 集合去重调度。每次使用同一个正式 Solver、原 Level/初态、独立相同 SearchBudget，仅替换 filter_descriptor 与纯删边 callback。禁用 tag 命中时删除整个成功原子边，不产生去掉 ENTER 的另一种 MOVE，也不修改 next_state。

SOLVED 消融见证先调用正式 validate_semantics，再逐步分类确认没有被禁用的 tag。只有 required 单机制或 forbidden 集合被绕过才产生 4000/MECHANIC_BYPASS。optional 可被禁用仍通关只说明 essential=false，不是错误。

PROVEN_UNSOLVABLE 必须具有完整、EXHAUSTED、同 Level/初态/policy 的正式图；essential=true 只作用于整个禁用集合。3C 不重新构图或证明遗漏边，完整性来源于刚调用的正式 3A Explorer。

BUDGET_EXCEEDED 始终 essential=null、bypass_detected=null、status=INCOMPLETE；附带 trace 也不改变这个结论。ERROR 同样不给二值结论；聚合 ERROR 优先 INCOMPLETE。COMPLETE 表示本次分析完成，不表示所有设计要求或所有解均通过。

## Milestones 与 advisory

每条质量见证先调用 3A validate_semantics。采样0为初态，后续采样使用已验证 transition 的提交状态与当步 tag。required 子序列按作者顺序贪心、非递减匹配；同一步 MOVE+ENTER 可同时满足多个谓词。optional 独立记录最早位置，不推进 required 游标。MECHANIC_USED 只在当步成立，不成为永久事实。

FACE_LIGHT 使用正式 Derived.light，查询错误不能当 SHADOW；GOAL 使用正式 GoalEvaluator。缺少 required 顺序产生 TRACE_BYPASS/4001；TRACE_MATCH 只说明这条 witness 满足。所有结果保留 scope=SINGLE_TRACE，不证明所有解或所有最短解的教学顺序。

真实最短见证未使用的 mechanism_id 只生成 4002/UNUSED_MECHANISM、WARNING、RETURNED_SHORTEST_TRACE。预算截断或非最短声明的测试见证使用 DISCOVERED_WITNESS。required/optional 潜在 tag、observed_used=false 与原 trace 作为 advisory 元数据保留；不把一次未使用升级成关卡错误。

## Dependency status

开始时 3A 尚未提供实现，先完成显式 tests-only Solver 结果表及注册 fixture 的语义校验替身，早期结果为 PROVISIONAL。替身没有 BFS、探索器、StateGraph build 或通用 Trace 校验算法；其一节点图仅为明确声明的结果表值 fixture，不是实际关卡的可达性证据。

最终 3A 已报告 FOUNDATION_STATE_EXPLORER_BFS_PASS；本轮已接入真正实现并通过完整验收。来源 E:/godot/worktrees/block-girl-foundation-solver/foundation/solver，3A HEAD 为 69590f91e32c72103f885b32bb29e57eee36a0c3，实际未提交实现由逐文件 SHA-256 识别。

wrapper 的显式 -SolverSourceRoot 在本 Work ignored 验收项目下建立 tests-only 目录 junction，读取正式7个脚本及 UID。没有复制3A production算法，没有修改另一个 worktree，也没有 merge。来源14个文件在运行前后 hash 一致。主生产接口无替身 fallback；缺少正式依赖时明确返回依赖错误。不带正式依赖的独立验收仍只能输出 PROVISIONAL。

正式接口消费 Solver.solve、SearchRecords.default_policy、Trace.validate_semantics；最终正向证明与伪造 trace 负例都经过真实3A。测试观察 adapter 只记录正式调用的 policy/budget/status/metrics/graph.complete/stop_reason 与 trace，不改变返回值。

## 真实五组结果

每组均经真实 Baker 与 Validator VALID。策略 BFS/FIRST_SHORTEST、UNFILTERED baseline；普通预算 states=10000、edges=100000、depth=-1、runtime_ms=0、action_evaluations=200000。验证预算4096构型/100000检查。每个子 search 使用独立预算。

| Fixture | Baseline SOLVED 长度 | 禁用 tag | 消融结果 | essential / bypass | baseline / ablated evaluations |
|---|---:|---|---|---|---|
| required_shift | 1 | WORLD_SHIFT | PROVEN_UNSOLVABLE | true / false | 5 / 28 |
| shift_bypass | 1 | WORLD_SHIFT | SOLVED | false / true | 1 / 1 |
| required_enter_celestial | 3 | CELESTIAL_CHANGE | PROVEN_UNSOLVABLE | true / false | 15 / 5 |
| multiple_celestial_entries | 2 | CELESTIAL_CHANGE | PROVEN_UNSOLVABLE | true / false | 19 / 7 |
| optional_mechanism | 1 | CELESTIAL_CHANGE | SOLVED | false / false | 1 / 1 |

所有上述 SOLVED 图均 complete=false / FIRST_GOAL；上述无解消融图均 complete=true / EXHAUSTED。结论只针对当前 fail-safe Kernel 和明确过滤策略。

required_enter_celestial 的人工路线为 MOVE 到未映射踏板 → MOVE 返回原面 → SHIFT。Validator 曾拒绝“踏板同时作为 Shift 目标”的初始 fixture；只修正本 Work 的测试关卡，没有改 Validator 或规则。

额外真实预算案例：required_shift，max_action_evaluations=6。baseline 在5次动作评估后 SOLVED，消融 run 返回 BUDGET_EXCEEDED；essential 与 bypass_detected 均 null。每组另有 max_states=1 的基线预算不足检查。

五组均验证真实 Solver 重复运行产生相同首条 trace。伪造 trace 保持结构、完整状态键和末态 Goal 有效，但把首动作换成不可达 MOVE；正式 Trace.validate 接受结构，正式语义检查及 Milestones 明确返回 ERROR、findings=[]。另有真实 missing required milestone 4001、optional 不报错，以及未用 console 仅 WARNING 的检查。

## Tests / evidence

Godot 4.7.2.stable.steam.ed1daf0bf。

| 最终 suite | Assertion checks | 依赖范围 |
|---|---:|---|
| IntentValidation | 845 | 正式 sidecar schema，含未知/缺失字段、类型、版本、引用、集合反例。 |
| MechanicClassifier | 66 | 正式 Kernel/Connectivity/Effects，覆盖8类及复合入口。 |
| Ablation unit | 50 | tests-only 结果表，验证状态分支、去重、预算、错误、禁用tag见证、原子filter。 |
| Milestone unit | 10 | 注册fixture gate + 正式分类/Derived/Goal；测试顺序、optional、伪造、光照失败。 |
| Real integration | 81 | 真正 Baker/Validator/3A Solver/Trace，五组正负证明。 |
| 合计 | 1052 | 断言检查数，不冒充1052个独立测试函数。 |

最终所有阶段 exit=0，stderr 为空，明确 PASS。wrapper 另以“exit0 + 阶段PASS + 故意 stderr FAIL”验证会拒绝，不会误发最终 PASS。每阶段隐藏进程、60秒超时；只结束自己的超时进程，证据不覆盖。

TDD RED 证据：schema-red、classifier-red、milestone-red、ablation-red。审查补充 ablation-proof-red（不能把 graph=null 的结果当完整无解证明）、classifier-consistency-red（无组变化的伪造机关结果），修复后全套通过。子代理因用量限制中断，之后的实现与代码复查由主执行者完成；未宣称完成独立全分支审查。

最终证据根：`.godot/foundation-3c/intent_final_03/`。包含 results.json、source_manifest.json、5组完整诊断记录、required_shift_ablated_budget.txt、summary.json。逐次 policy_descriptor、budget、完整 metrics、图完整性、trace与语义调用记录在对应 fixture 文件。早期替身验收保留在 intent_wrapper_first；不作为最终正式质量证明。

实际命令（在指定 Work C worktree）：

```powershell
& './tests/foundation/quality/intent/run_validation.ps1' -EvidenceName intent_final_03 -SolverSourceRoot 'E:/godot/worktrees/block-girl-foundation-solver'
& './tests/foundation/full_integration/run_validation.ps1' -Headless -EvidenceName intent_final_regression
& './tests/foundation/run_validation.ps1' -EvidenceName intent_final_foundation
```

既有回归全部通过：FOUNDATION-2 full integration 77；Orientation 77965、DATA 733、StateKey 546、Spatial 1533、Celestial 132、第一波 Integration 105。未修改这些既有测试。

## Files / git diff

生产仅 foundation/quality/intent/{intent_types,intent_validation,mechanic_classifier,ablation_analyzer,milestone_analyzer}.gd 及 UID。

测试仅 tests/foundation/quality/intent/{intent_fixtures,solver_contract_double,test_intent_validation,test_mechanic_classifier,test_ablation_analyzer,test_milestone_analyzer,test_intent_integration}.gd 及 UID、run_validation.ps1。

文档仅本报告与本 Work plan。完整含未跟踪文件的 patch：`.godot/foundation-3c/intent_final_03/work-c.diff`，统计在 work-c.stat.txt。共26个新增文件和1个本 Work plan修改。

公共Spec、LevelDefinition、PuzzleState、Solver、其它Owner production/tests、project.godot、主工作区均未修改。没有新增BFS、Softlock、Runtime Parity、Editor或P-02。未commit/push/merge；保留分支和worktree，停止于交付。
