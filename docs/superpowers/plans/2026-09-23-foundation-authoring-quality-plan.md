# FOUNDATION-4 4C Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task after explicit execution approval. Steps use checkbox (`- [ ]`) syntax. 本轮仅编制计划；后续拟采用四Owner独立worktree，具体启动仍须用户授权，不自动派生实现任务。

**Goal:** 以正式关卡和绑定Intent执行真实质量分析，向4D返回未篡改的状态与证据。

**Architecture:** 编排器从正式Spawn调用Explorer并把其原始活图直接交Softlock；Ablation独立调用正式API，所选原图trace另查语义与里程碑。取消只在公开调用前后检查；没有worker、BFS或顶层PASS判断。

**Tech Stack:** Godot/GDScript、PowerShell、现有FOUNDATION公开接口；不增加第三方运行依赖。工程声明4.7特性，实际engine能力须在I0核验并绑定，不能把声明当运行验证。

**Spec:** [Design Spec](../specs/2026-09-22-foundation-authoring-editor-design.md)，SHA-256 `A4D9CD7CCFDE8E4FDB0EEA72746505B995361850E623BEF7952D49849EC9A13F`；[Tool Contracts](../specs/2026-09-22-foundation-authoring-tool-contracts.md)，SHA-256 `C31A03E807A2BF9268D32AA00FA18BCD93C77BAD4C53ED00A8D349FED8462A6B`。仅消费这两个已批准内容版本。

**Approval:** [独立批准记录](../../development-records/FOUNDATION_4_SPEC_APPROVAL_RECORD.md)。Spec旧front matter保持原字节，不再以其待审标记否认本次哈希批准。

**Date:** 2026-09-23 · **PLAN_DOCUMENTED** · **AWAITING_USER_REVIEW** · **IMPLEMENTATION_NOT_STARTED**。

## Global Constraints

- 唯一Reader/Baker/Codec、Kernel/Safety、Solver/Softlock/Intent/Trace与Session/Presenter/Replayer；不调用私有测试seam绕过正式验证，不产生第二算法。
- 4A定义作者/source_map；4D定义wire、快照/任务/报告及唯一状态视图；4C只编排质量；4B独占插件入口。跨Owner共享数据及已批准数值以[集成计划公共约束](2026-09-23-foundation-authoring-integration-plan.md)为单一计划登记，不复制出另一套协议。
- 两个World单位变换；玩法实例覆盖报错停链；六面不缺失/不重复；未知字段/版本失败。原始Transform交Reader，不提前量化。
- ANALYZE_CURRENT允许未保存但不签发整关PASS；ACCEPT_SAVED保存同轮闭包；失败不回退旧产物。完整验收固定UNFILTERED/FULL_GRAPH、零软锁、适用Intent、同一trace语义与GRAPHICAL MATCH。
- 取消立即撤销PASS资格；CANCELLING直到调用结束和自有资源释放确认；不强杀、不承诺有界回收。所有工具默认预算逐项沿合同§6，期限不等于硬终止。
- 源码/fixture入Git；生成日志、运行工程、导出和本任务可配置临时目录在E盘。无全局环境修改。tests-only double只能证明局部包装行为，真实链不得加载它。
- 本轮不创建实际.gd/.uid/.tscn/.tres/插件/测试；以下Create/Modify/Test均为将来实施任务。所有示例仅在Markdown内；全部Godot验收 **NOT_RUN**。
- 禁止写main、旧P-01及既有FOUNDATION生产模块；禁止写`E:/Study/方块娘项目/若叶睦/model/art_pilot_01`、`E:/Study/方块娘项目/若叶睦/photo`或运行Blender。白盒不等待美术，不引入旧像素尺寸约束。
- 不commit/push/merge/PR、不创建开发worktree。计划批准、执行方式授权、共同基线已提交是执行前置；任务REVIEW完成只形成可审阅差异，不自动提交。

## Review Focus

- FULL_GRAPH预算用尽但已有trace → C1保留BUDGET_EXCEEDED，不冒称完整图。
- Reset可恢复却仍是软锁 → C1断言softlock_count不扣减。
- 原图与Ablation baseline选到不同trace → C2单独核验原图所选trace。
- optional非空或空Intent混成跳过校验 → C2实测IntentValidation及子项适用性。
- 原算法SOLVED但safety_unproven_rejections>0 → C3保留值交D阻止完整PASS，不篡改Solver枚举。

## 禁止范围

不改foundation/solver/quality/rules/validation等旧生产API，不使用其私有注入seam；不改4A绑定/wire、4D任务/汇总、4B插件、project.godot、测试wrapper/MOC。不能接收调用方提供的Graph作为可信完整图，公开入口只接level和intent。

## 精确文件所有权

下列路径相对实施worktree根；同名`.gd.uid`逐项归同Owner，实施导入后纳入正式源依赖。未列文件不得顺手修改。表内tests/路径同时是本任务的Test文件；Create表示未来创建，后续任务对同Owner已创建文件的扩展仍由该Owner维护。

| 操作 | 文件 | 责任 / 创建任务 |
|---|---|---|
| Create | `tools/foundation/authoring_quality/quality_workflow.gd` | 4C-1：公开质量编排入口 |
| Create | `tools/foundation/authoring_quality/quality_workflow.gd.uid` | 4C-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_quality/quality_stage_records.gd` | 4C-1：保留原返回并生成D定义StageRecord值 |
| Create | `tools/foundation/authoring_quality/quality_stage_records.gd.uid` | 4C-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tools/foundation/authoring_quality/selected_trace_checks.gd` | 4C-2：同一原图trace的Spawn/语义/里程碑绑定 |
| Create | `tools/foundation/authoring_quality/selected_trace_checks.gd.uid` | 4C-2：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring_quality/test_quality_workflow.gd` | 4C-1：本Owner测试；boundary double只控制调用边界 |
| Create | `tests/foundation/authoring_quality/test_quality_workflow.gd.uid` | 4C-1：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring_quality/test_selected_trace.gd` | 4C-2：本Owner测试；boundary double只控制调用边界 |
| Create | `tests/foundation/authoring_quality/test_selected_trace.gd.uid` | 4C-2：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring_quality/test_quality_failures.gd` | 4C-3：本Owner测试；boundary double只控制调用边界 |
| Create | `tests/foundation/authoring_quality/test_quality_failures.gd.uid` | 4C-3：对应脚本持久UID，只在所属任务受控导入生成 |
| Create | `tests/foundation/authoring_quality/boundary_control_double.gd` | 4C-3：本Owner测试；boundary double只控制调用边界 |
| Create | `tests/foundation/authoring_quality/boundary_control_double.gd.uid` | 4C-3：对应脚本持久UID，只在所属任务受控导入生成 |

## 公开接口（新建）与已有API

| 新接口完整签名 | 返回及边界 |
|---|---|
| quality_workflow.gd `run_quality(level:Dictionary,bound_intent:Dictionary,policy:Dictionary,identity:Dictionary,boundary_control:RefCounted)->Dictionary` | QualityRunResult按公共记录表；输入是成功Bake后正式Codec可接受level和4A候选Intent，正式Intent校验仍必须实际调用；没有顶层verdict |
| quality_stage_records.gd `from_native(stage_id:String,native_result:Dictionary,inputs:Dictionary,policy:Dictionary,budget:Dictionary)->Dictionary` | D定义StageRecord值，COMPLETED/INCOMPLETE/ERROR与原枚举分开；缺结果用另一个`not_run(stage_id:String,reason:String,inputs:Dictionary)->Dictionary`，native_result=null |
| selected_trace_checks.gd `check_selected(level:Dictionary,intent:Dictionary,trace:Dictionary,initial:Dictionary)->Dictionary` | `{trace_validation:Dictionary,spawn_matches:bool,semantics:Dictionary或null,milestones:Dictionary或null,issues:Array[Dictionary]}`，semantics失败不编造transitions；所选trace保留原内容 |

已有正式接口：`Records.initial_state(level:Dictionary)->Dictionary`、`StateKey.build(level:Dictionary,state:Dictionary)->Dictionary`；`SearchRecords.default_policy(mode:int)->Dictionary`；`Explorer.explore(level:Dictionary,initial:Dictionary,policy:Dictionary,budget:Dictionary)->Dictionary`；`Softlock.analyze(level:Dictionary,graph:Dictionary,budget:Dictionary)->Dictionary`；`IntentValidation.validate(level:Dictionary,intent:Dictionary)->Dictionary`；`Ablation.analyze(level:Dictionary,initial:Dictionary,intent:Dictionary,policy:Dictionary,budget:Dictionary)->Dictionary`；`Trace.validate(level:Dictionary,trace:Dictionary)->Dictionary`、`Trace.validate_semantics(level:Dictionary,trace:Dictionary)->Dictionary`；`Milestones.analyze_trace(level:Dictionary,intent:Dictionary,trace:Dictionary)->Dictionary`。路径及原返回字段见批准Tool Contracts §2，预算逐项公共表，不传cancel/progress/skip_validation等不存在options。

BoundaryControl公开方法由D1创建：stop_requested/reason/checkpoint；D完整worker未就绪时可用C测试文件boundary_control_double.gd实现同三个方法，仅模拟边界取消，不替换Solver/Safety。它不进入Real交付加载清单。policy为D ExecutionPolicy值，C重建SearchPolicy时固定strategy=BFS，完整验收mode=1、UNFILTERED、空Callable；显式局部求解可mode=0，但结果不具完整验收资格。

编排核心（C1实现）：

```gdscript
var initial := Records.initial_state(level)
if not boundary_control.checkpoint("ORIGINAL_GRAPH"):
    return cancelled_before_search_result
var search_policy := SearchRecords.default_policy(policy.search_mode)
search_policy.validation_options = policy.bake_options.duplicate(true)
var original := Explorer.explore(level, initial, search_policy, policy.search_budget)
# 保留original完整原返回；check边界后，只有符合Softlock公开输入前提才继续。
var locks: Variant = null
if boundary_control.checkpoint("SOFTLOCK") and original.graph != null and original.status != SolverTypes.SolverStatus.ERROR:
    locks = Softlock.analyze(level, original.graph, policy.softlock_budget)
# 绝不序列化/复制重建graph再送此调用；Ablation不消费这个graph。
```

cancelled_before_search_result是本方法构造的QualityRunResult：selected_trace_ref=null、所需阶段NOT_RUN/CANCELLED、原结果null；不是旧Solver的假status。Softlock的实际INCOMPLETE要保留null结论。图为null或Solver.ERROR等不满足前提时只记NOT_RUN原因，不能用空图造零软锁。4D收到后唯一汇总。

测试输入可直接使用已有正式`tests/foundation/solver/solver_fixtures.gd::corridor(length:int=3)->Dictionary`及`tests/foundation/quality/intent/intent_fixtures.gd::scenario(name:String)->Dictionary`、`empty_intent(level:Dictionary)->Dictionary`。它们是正式Baker/fixture数据，用于C模块真实算法调用；最终I2必须改接4A新作者产物，不将旧fixture当新作者链成果。

### 4C-1 — 原图和同进程Softlock编排

**Files:** `tools/foundation/authoring_quality/quality_workflow.gd`, `tools/foundation/authoring_quality/quality_stage_records.gd`, `tests/foundation/authoring_quality/test_quality_workflow.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** 正式Explorer/Softlock/Records，D_PROTOCOL值合同和批准默认预算

**Interfaces — produces:** run_quality基础、StageRecord包装；不暴露graph输入端口

- [ ] **RED：** corridor完整可解、sink/cycle软锁、max_states=1预算耗尽、FIRST_SHORTEST局部用途分别断言；Softlock来自同一次Explorer返回，不允许磁盘图入参。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4C -Case 4C-1 -Mode Real -EvidenceName 4c_4c-1_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
const Fixtures = preload("res://tests/foundation/solver/solver_fixtures.gd")
var level: Dictionary = Fixtures.corridor(3)
var policy: Dictionary = RunRecords.default_execution_policy("ACCEPT_SAVED")
policy.search_budget.max_states = 1 # 显式本测试配置，仍记录policy_digest；不是修改默认。
var result := Workflow.run_quality(level, IntentFixtures.empty_intent(level), policy, identity, control)
var original_stage: Dictionary = {}
for stage in result.stages:
    if stage.stage_id == "ORIGINAL_GRAPH":
        original_stage = stage
check(not original_stage.is_empty(), "original graph stage exists")
if not original_stage.is_empty():
    check(original_stage.native_result.status == SolverTypes.SolverStatus.BUDGET_EXCEEDED, "preserve budget result")
check(not result.has("verdict"), "4C does not award PASS")
```

- [ ] **GREEN：** 按实际阶段集合有序记录（Intent校验阶段可能先于原图，因此实际测试按stage_id取，不依赖数组下标）；完整原图策略固定，保留安全未知计数、budget_reason与所有issues。Softlock不扣Reset可恢复数；不合法图前提不调用。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** 通过源码调用点和同进程对象传递测试证明活图来源，不能只Graph.validate磁盘记录；无自写BFS/完整性标志。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

### 4C-2 — 绑定Intent、消融与所选trace

**Files:** `tools/foundation/authoring_quality/selected_trace_checks.gd`, `tests/foundation/authoring_quality/test_selected_trace.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** 正式IntentValidation/Ablation/Milestones/Trace；4A绑定Intent在I2接入

**Interfaces — produces:** check_selected与完整QualityRunResult；C_QUALITY主交付

- [ ] **RED：** required_shift、shift_bypass、optional_mechanism、显式空及仅optional非空各有实际校验。构造多解使Ablation基线trace与原图trace可区分，所选Milestone仅核原图；非Spawn trace即使语义合法仍拒绝选用。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4C -Case 4C-2 -Mode Real -EvidenceName 4c_4c-2_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
var selected := TraceChecks.check_selected(level, bound_intent, original.solution_trace, Records.initial_state(level))
check(selected.spawn_matches and selected.semantics.ok, "selected trace starts at official spawn")
check(selected.milestones.scope == "SINGLE_TRACE", "single witness only")
check(bound_intent == before_intent, "constraints preserved")
check(quality.selected_trace_ref.trace == original.solution_trace, "no replacement by ablation witness")
```

- [ ] **GREEN：** 所有有效Intent包括空都实际validate；声明子项适用性从四集合判断，invalid/missing不是empty。Ablation公开analyze内部自行baseline，不传graph复用参数。独立选定原图trace调用TraceChecks；普通optional/UNUSED_MECHANISM警告原样保留，required/forbidden findings供D汇总。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** 零步Goal合法trace处理；不新增所有解教学证明；不更换trace以迎合里程碑；source Intent不改写。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

### 4C-3 — 不完整、安全未知和边界取消传播

**Files:** `tests/foundation/authoring_quality/test_quality_failures.gd`, `tests/foundation/authoring_quality/boundary_control_double.gd`（操作见文件表，包含相应UID）。

**Interfaces — consumes:** C1/C2真实链；D BoundaryControl；StageRecord原结果合同

**Interfaces — produces:** 故障/取消用例与C_QUALITY可交付证据

- [ ] **RED：** 调用前cancel没有正式结果；原调用结束后cancel保留该结果但不启动下一阶段；预算耗尽、ERROR、安全未知计数不变。包装单元可输入显式原结果值，不能伪称真实算法产生。
- [ ] **运行RED：** `pwsh -NoProfile -File tests/foundation/authoring_integration/run_module.ps1 -Module 4C -Case 4C-3 -Mode Unit -EvidenceName 4c_4c-3_01`。必须看到指定行为断言失败；首次入口尚未创建时先按I0登记入口，不能把无关依赖加载失败当作行为RED。保存失败参数/日志，不覆盖。

代表性断言片段（普通case位于I0 TestSuite派生脚本的`run()`；Editor case位于QA driver调用的`run(editor_plugin,tools_plugin)`，在该case定义同义的本地`check(bool,String)`并返回相同计数结果。片段为测试意图，前置动作/变量在对应RED步骤实现，不是独立可执行脚本）：

```gdscript
var actual_policy := SearchRecords.default_policy(SolverTypes.SearchMode.FULL_GRAPH)
var actual_budget: Dictionary = RunRecords.default_execution_policy("ACCEPT_SAVED").search_budget
var raw := Explorer.explore(level, Records.initial_state(level), actual_policy, actual_budget).duplicate(true)
# 保留完整返回shape；仅本Unit子case注入计数，不宣称真实探索产生该计数。
raw.metrics.safety_unproven_rejections = 1
var stage := StageRecords.from_native("ORIGINAL_GRAPH", raw, input_refs, actual_policy, actual_budget)
check(stage.native_result.metrics.safety_unproven_rejections == 1, "unknown safety retained")
check(stage.native_result.status == raw.status, "native status is not rewritten")
check(not stage.has("verdict"), "only 4D summarizes")
```

- [ ] **GREEN：** from_native单元使用完整真实返回记录的深拷贝再调整计数，以通过封闭schema；错误输入明确拒绝。boundary double只控制下一边界，不把取消Callable塞进旧分析器。真实D_JOBS接入测试另行通过，超时来自父4D，C保留实际结果。
- [ ] **运行GREEN：** 同一命令改用新的`-EvidenceName`后执行；预期退出0、实际checks>0、failures=[]、无脚本错误；证据标注mode、依赖提交/摘要与是否使用double。没有执行时保持NOT_RUN。
- [ ] **REVIEW：** 局部注入记录标UNIT_DOUBLE；另运行C1/C2 Real与I2，不拿伪造计数宣称算法安全未知真实覆盖；未返回阶段不能填COMPLETE或空结果。 记录文件差异和依赖交接，等待允许的Git收口流程；此步骤不自动commit。

## 验收与交接

现有命令（已存在，本轮NOT_RUN）：

```powershell
pwsh -NoProfile -File tests/foundation/solver/run_validation.ps1 -EvidenceName f4c_solver_01
pwsh -NoProfile -File tests/foundation/quality/softlock/run_validation.ps1 -EvidenceName f4c_softlock_01
pwsh -NoProfile -File tests/foundation/quality/intent/run_validation.ps1 -EvidenceName f4c_intent_01
```

完成条件：上述编排及真实算法用例保留所有原结果，4C无顶层PASS；C_QUALITY记录真实SHA给D6及Integration。C可在A/D完整UI未完成时做正式Level模块测试；D BoundaryControl接口缺失可做局部double，但I2真实来源接入前标DEPENDENCY_PENDING。不得为方便序列化在C实现另一wire或替D启动worker。
