# FOUNDATION-3C PuzzleIntent + Mechanic Ablation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking. EXECUTED；用户2026-09-16已授权，已通过真实3A最终验收。未commit/push/merge。

**Goal:** 对设计者声明的required/optional机制和禁用集合给出可复现消融结果，并检查一条真实解的教学里程碑。

**Architecture:** PuzzleIntent是独立sidecar；MechanicClassifier唯一归类正式Kernel成功transition。Ablation提供纯删边callback给3A Solver，Milestone复用3A语义trace校验与正式Derived查询；本模块没有BFS。

**Tech Stack:** Godot/GDScript纯记录与Callable、SceneTree测试、PowerShell独立验收。

**Spec:** `docs/superpowers/specs/2026-09-16-foundation-solver-quality-contracts.md` §3、7、12、16–24、28–32。

## Global Constraints

- FROZEN DESIGN / IMPLEMENTED；本轮在用户指定worktree执行，不commit/push/merge。
- 基线feat/foundation-core / 4dda1fdce9c562427ab7541f1ee21266a3b8214a。不得变更LevelDefinition、PuzzleState、PuzzleAction、Kernel规则或状态身份。
- MechanicTag与ActionKind不同枚举；唯一分类位置为本Owner mechanic_classifier.gd，3A无反向依赖。
- 消融删除完整APPLIED.changed边，不能修改Level、只筛顶层kind或剥离ENTER后保留MOVE。
- baseline正常SOLVED是分析必要性前提；任何预算耗尽都不能给essential/bypass的布尔定论。
- 里程碑首版只验证SINGLE_TRACE；不能宣称全部解遵循顺序。shortest_solution_count明确延期。

## Exact files / Owner 3C

| 文件 | 职责 |
|---|---|
| foundation/quality/intent/intent_types.gd | MechanicTag/PredicateKind/AblationStatus/MilestoneStatus/QualityCode唯一枚举 |
| foundation/quality/intent/intent_validation.gd | sidecar封闭schema、引用与版本校验 |
| foundation/quality/intent/mechanic_classifier.gd | 正式成功transition到tags/机制IDs |
| foundation/quality/intent/ablation_analyzer.gd | baseline、私有filter构造、Solver调用与结果聚合 |
| foundation/quality/intent/milestone_analyzer.gd | 真实trace采样、required子序列、optional建议 |
| tests/foundation/quality/intent/intent_fixtures.gd | 真实Baker/Kernel关卡与具名期望 |
| tests/foundation/quality/intent/solver_contract_double.gd | 独立Solver结果表与调用记录，无搜索算法 |
| tests/foundation/quality/intent/test_intent_validation.gd | schema与版本负例 |
| tests/foundation/quality/intent/test_mechanic_classifier.gd | 八种taxonomy、多入口与ENTER实际效果 |
| tests/foundation/quality/intent/test_ablation_analyzer.gd | baseline/消融状态与required/optional区别 |
| tests/foundation/quality/intent/test_milestone_analyzer.gd | 语义可信、顺序与SINGLE_TRACE |
| tests/foundation/quality/intent/test_intent_integration.gd | 真实3A消融与见证复查 |
| tests/foundation/quality/intent/run_validation.ps1 | 独立证据wrapper |
| docs/development-records/FOUNDATION_PUZZLE_INTENT_ABLATION_REPORT.md | intent、每次search、见证scope |
| docs/superpowers/plans/2026-09-16-foundation-puzzle-intent-ablation.md | 本plan勾选 |

对应新增.gd.uid归3C。**Prohibited files:** foundation/solver/、foundation/quality/softlock/、foundation/parity/、全部既有production/tests、其它Owner目录/plan/report、公共Spec、P-01、prototype/、project.godot、tests/visual/及资产。没有共享“quality BFS”文件授权。

## Interfaces consumed / produced

消费3A `Solver.solve(level,initial,policy,budget)`、`SearchRecords.default_policy(mode)`、`Trace.validate_semantics(level,trace)->{ok,transitions,issues}`。消费真实 `Connectivity.query_move(level,state,face_axis)`、`Effects.enter_effects(level,source_face,target_face)`、`Derived.light(level,state,face_id)`、`Goal.is_goal(level,state)`。Effects只用于追溯成功动作，不自判合法性。

产出static接口：

```gdscript
IntentValidation.validate(level: Dictionary, intent: Dictionary) -> Dictionary # {ok,issues}
Mechanics.classify_transition(level: Dictionary, result: Dictionary) -> Dictionary # {ok,tags,mechanism_ids,issues}
Ablation.analyze(level: Dictionary, initial: Dictionary, intent: Dictionary, policy: Dictionary, budget: Dictionary) -> Dictionary # IntentAnalysisResult
Milestones.analyze_trace(level: Dictionary, intent: Dictionary, trace: Dictionary) -> Dictionary # MilestoneAnalysisResult
```

Ablation内私有callback只按Spec §7返回`{ok,allow,issues}`，不增加公共make_policy API。analyze只接受UNFILTERED输入policy；baseline使用其mode/验证选项，消融深复制后替换filter descriptor/Callable，各次SearchBudget独立。IntentValidation错误为ERROR，不调用Solver。3A未集成时允许tests-only Solver adapter，公开production无自动double fallback。

## Task 1: Sidecar与taxonomy

**Files:** intent_types.gd、intent_validation.gd、intent_fixtures.gd、test_intent_validation.gd。

**Interfaces:** 消费Level/hash及3A AnalysisIssue；产出封闭PuzzleIntent验证。

- [x] RED：有效sidecar通过；required/optional重叠、未知tag、无序/重复集合、空forbidden集合、重复milestone ID、错level_hash/rule_version、错误谓词引用、额外DSL字符串字段均失败。

```gdscript
var intent := fixture_intent.duplicate(true)
intent.required_mechanics = [1, 6] # WORLD_SHIFT, CELESTIAL_CHANGE
intent.optional_mechanics = [4] # FACE_TRANSITION
assert(IntentValidation.validate(level, intent).ok)
intent.optional_mechanics.append(1)
assert(not IntentValidation.validate(level, intent).ok)
```

- [x] GREEN：按Spec §16/20封闭字段验证；ID、引用和枚举值读取正式合同；只验证sidecar，不把字段塞入Level。QualityFinding codes4000/4001/4002与AnalysisCode3000段严格分开。
- [x] GREEN验证：required/optional空数组合法，forbidden可单tag或多tag；milestone顺序保留，不能排序掩盖教学顺序。

## Task 2: 唯一实际效果分类器

**Files:** mechanic_classifier.gd、test_mechanic_classifier.gd、intent_fixtures.gd。

**Interfaces:** 消费真实8字段PuzzleTransitionResult及正式Connectivity/Effects；产出排序去重tags/机制IDs。

- [x] RED：用真实Kernel结果覆盖MOVE、SHIFT、两个WorldRotate、FaceTransition、TRIGGER/direct组/天体。MOVE→ENTER天体必须同时出现MOVE/CELESTIAL_CHANGE/MECHANISM_TRIGGER；相同slot的ENTER只出现MOVE/MECHANISM_TRIGGER；全动作无变化返回空集合。

```gdscript
var r := Kernel.evaluate_action(level, initial, move_onto_enter, RuleRecords.idle_context())
assert(r.status == 0 and r.changed)
var c := Mechanics.classify_transition(level, r)
assert(c.ok)
assert(c.tags == [0, 6, 7])
assert(c.mechanism_ids == [&"enter_plate"])
```

- [x] RED：ENTER绑定FaceTransition，最终Face不同于入场Face，仍识别入场机制与FACE_TRANSITION；REJECTED/ERROR/inconsistent输入不返回空成功。该负例防止仅查看最终player.location。
- [x] GREEN：MOVE先复用Connectivity.query_move(level,previous_state,action.face_axis)取得中间目标，再用Effects.enter_effects；其它入口沿机制绑定定义和真实前后字段差异取tag。分类不调用自制roll/lighting/mapping，不使用并不存在的events字段。
- [x] GREEN验证：wrapper/direct别名tag相同、平行动作仍不同；发生实际slot变化才CELESTIAL_CHANGE；所有输出深复制且输入不变。

## Task 3: Baseline与原子删边消融

**Files:** ablation_analyzer.gd、solver_contract_double.gd、test_ablation_analyzer.gd。

**Interfaces:** 消费Solver唯一入口与classifier；产出Spec §19 AblationResult/IntentAnalysisResult。

- [x] RED：结果表double按传入descriptor返回既定SolverResult并记录calls；baseline无解/预算/错误时不启动消融。required禁用仍SOLVED报MECHANIC_BYPASS，optional仍SOLVED只essential=false，集合无解只能断言集合整体essential。

```gdscript
# 真正运行前先用结果表double控制两次求解：baseline SOLVED，禁用SHIFT仍SOLVED。
var r := Ablation.analyze(level, initial, required_shift_intent, policy, budget)
assert(r.ablations[0].essential == false)
assert(r.ablations[0].bypass_detected == true)
assert(r.ablations[0].findings[0].code == 4000)
# 单独case让消融budget耗尽，即使附带见证也不能输出布尔定论。
assert(incomplete_result.ablations[0].essential == null)
assert(incomplete_result.ablations[0].bypass_detected == null)
```

- [x] GREEN：先完整baseline；对required/optional单tag及forbidden集合去重调度，报告仍关联全部声明。闭包callback调用classifier，tags相交返回allow=false；错误返回ok=false，由3A FILTER_ERROR终止。

```text
filter(level,result):
  classification = Mechanics.classify_transition(level,result)
  if !classification.ok: return {ok:false,allow:false,issues:classification.issues}
  overlap = any classification.tags member in disabled_mechanics
  return {ok:true,allow:!overlap,issues:[]}
```

- [x] RED/GREEN：检查MOVE+ENTER整条边被删除，没有生成“移动完成但机关未触发”的新状态；Kernel ERROR先于filter；disabled集合必须非空升序。输入policy若不是UNFILTERED返回ERROR/INVALID_SEARCH_POLICY，不能把消融结果当baseline。
- [x] GREEN验证：每个SOLVED见证先Trace.validate_semantics且分类确认未用禁用tag，才生成硬finding；虚假double trace只测编排，不计真实质量证据。聚合ERROR优先INCOMPLETE；COMPLETE仅代表分析跑完，不代表设计无缺陷。

## Task 4: 里程碑与未使用advisory

**Files:** milestone_analyzer.gd、test_milestone_analyzer.gd、intent_fixtures.gd；ablation_analyzer.gd聚合advisories。

**Interfaces:** 消费Trace.validate_semantics返回真实transitions、唯一classifier、正式Derived/Goal；产出SINGLE_TRACE结果。

- [x] RED：正式两步Goal trace缺required SHIFT→TRACE_BYPASS/4001；同项optional不产生硬错误；required顺序反转、optional缺失夹在required之间、初态满足AT_FACE、同一步同时满足MOVE+ENTER两个谓词都要有literal sample_indices。
- [x] RED：所有StateKey/末Goal正确但一步动作不可达的伪造trace返回ERROR且findings=[]；光照查询失败不能当SHADOW命中。

```gdscript
var checked := Milestones.analyze_trace(level, intent, forged_trace)
assert(checked.status == 3)
assert(checked.findings.is_empty())
var valid := Milestones.analyze_trace(level, intent, solved_trace)
assert(valid.scope == "SINGLE_TRACE")
```

- [x] GREEN：先语义验证；采样初态0与每步1..N，required子序列贪心非递减匹配，optional各自找最早命中。MECHANIC_USED只看当步，GOAL使用正式Evaluator。未匹配索引null，required缺失才生成4001。
- [x] GREEN：对返回最短见证未出现的mechanism_id仅4002/WARNING，scope RETURNED_SHORTEST_TRACE；预算附带见证scope DISCOVERED_WITNESS。不推断所有解或所有最短解未使用，不实现乘积图/BFS。

## Task 5: 真实3A消融与独立验收

**Files:** test_intent_integration.gd、intent_fixtures.gd、run_validation.ps1、专属report、本plan。

- [x] RED：真实Baker关卡准备“必须SHIFT”“存在无需SHIFT的绕过”“必须ENTER天体”“同天体direct/TRIGGER/ENTER多入口”“可选机关”五组。人工列出预期通关动作与禁止集合；基线都由真实Solver获得SOLVED，不能用double报告最终结论。
- [x] GREEN：真实Solver反复求解，必需机制消融PROVEN_UNSOLVABLE；绕过例SOLVED且语义校验通过；三入口天体均受同一tag过滤；极小预算INCOMPLETE。对真实返回trace做milestone检查，明确只有SINGLE_TRACE证明。
- [x] 编写wrapper支持`-Godot/-EvidenceName`，stage60秒、Hidden、仅清理自身进程；证据`.godot/foundation-3c/<EvidenceName>/`不覆盖，保存HEAD/hash、每次policy/budget/metrics、intent副本、trace与错误。exit0/checks>0/PASS且无错误才通过。
- [x] 执行命令，检查写入白名单，完成报告后停止review。

```powershell
$godotExe = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
$projectRoot = 'E:/godot/若叶睦/方块少女-若叶睦'
Set-Location -LiteralPath $projectRoot
& $godotExe --headless --path $projectRoot --script res://tests/foundation/quality/intent/test_intent_validation.gd
& $godotExe --headless --path $projectRoot --script res://tests/foundation/quality/intent/test_mechanic_classifier.gd
& $godotExe --headless --path $projectRoot --script res://tests/foundation/quality/intent/test_ablation_analyzer.gd
& $godotExe --headless --path $projectRoot --script res://tests/foundation/quality/intent/test_milestone_analyzer.gd
& $godotExe --headless --path $projectRoot --script res://tests/foundation/quality/intent/test_intent_integration.gd
& ./tests/foundation/quality/intent/run_validation.ps1 -Godot $godotExe -EvidenceName ('accept_3c_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
& ./tests/foundation/full_integration/run_validation.ps1 -Godot $godotExe -Headless -EvidenceName ('regress_3c_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
git diff --check
git status --short
```

**PASS token:** `FOUNDATION_PUZZLE_INTENT_ABLATION_PASS`；真实3A与所有负例通过、CONTRACT_MISMATCH: NONE。模块PASS不是所有关卡意图PASS。

**CONTRACT_MISMATCH stop rule:** 字段、tag映射、Callable接口、ENTER profile或真实API与Spec不一致时停止依赖工作，列expected/actual/path/Owner；不能改Kernel、3A或共享合同自行修正。3A缺席可测试double编排但必须标DEPENDENCY_PENDING，不输出真实PASS。

## Execution record — 2026-09-16

用户指定工作区 E:/godot/worktrees/block-girl-foundation-intent、分支 feat/foundation-puzzle-intent-ablation；实际基线为 69590f91e32c72103f885b32bb29e57eee36a0c3。上文历史命令中的主工作区路径未用于执行本轮写入。

开始3A未就绪，先tests-only结果表测试；最终3A正式实现完成，通过ignored项目中的只读junction接入，无源码复制、跨worktree修改或merge。完整执行命令：

```powershell
& './tests/foundation/quality/intent/run_validation.ps1' -EvidenceName intent_final_03 -SolverSourceRoot 'E:/godot/worktrees/block-girl-foundation-solver'
& './tests/foundation/full_integration/run_validation.ps1' -Headless -EvidenceName intent_final_regression
& './tests/foundation/run_validation.ps1' -EvidenceName intent_final_foundation
```

最终五套1052项断言、真实五组消融、真实伪造trace拒绝、子消融预算null结论均通过；既有完整集成77项与第一波六套回归通过。全部新代码位于精确3C白名单。详见 docs/development-records/FOUNDATION_PUZZLE_INTENT_ABLATION_REPORT.md 和 .godot/foundation-3c/intent_final_03/。

FOUNDATION_PUZZLE_INTENT_ABLATION_PASS
CONTRACT_MISMATCH: NONE
