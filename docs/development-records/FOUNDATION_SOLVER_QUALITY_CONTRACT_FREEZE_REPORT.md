---
title: FOUNDATION Solver Quality Contract Freeze Report
date: 2026-09-16
design_status: FROZEN DESIGN
implementation_status: NOT IMPLEMENTED
review_status: AWAITING USER REVIEW
analysis_contract: foundation.analysis.v1
---

# FOUNDATION-3.0 — Solver & Quality Contract Freeze Report

**FOUNDATION_SOLVER_QUALITY_CONTRACT_FREEZE_PASS**

**CONTRACT_MISMATCH: NONE**

本PASS仅表示本轮文档、源码接口对照、所有权与交付范围检查通过。新Solver、Softlock、Intent/Ablation、Parity均为 **FROZEN DESIGN / NOT IMPLEMENTED**；没有运行新的Godot/Solver测试，没有提前启动四Work。

## 1. Branch / HEAD与读取依据

主仓库：`E:/godot/若叶睦/方块少女-若叶睦`。开始和完成检查均为分支`feat/foundation-core`、HEAD `4dda1fdce9c562427ab7541f1ee21266a3b8214a`，正好等于用户给定基线，不需后代替代证明。开始工作区干净；完成时只有本轮六份未跟踪Markdown，原tracked文件和index无变化。

读取依据：

- `docs/superpowers/specs/2026-09-13-foundation-spatial-puzzle-architecture-design.md`
- `docs/superpowers/specs/2026-09-13-foundation-core-contracts.md`
- `docs/superpowers/specs/2026-09-13-foundation-puzzle-rule-kernel-contracts.md`
- `docs/development-records/FOUNDATION_INTEGRATION_REPORT.md`
- `docs/development-records/FOUNDATION_2_INTEGRATION_REPORT.md`

并核对当前foundation八个production目录的真实代码（共28份.gd）：

| 目录 | 核查内容 / 对本轮的约束 |
|---|---|
| orientation | cube24与真实离散旋转，Solver不得重写姿态公式 |
| contracts | Level/State/Action封闭字段、StateKey完整字符串、initial_state |
| spatial | 几何/Mapping与1105错误，不能由搜索器自行挑映射 |
| celestial | 正式CelestialSlot/Lighting，里程碑只复用正式查询 |
| validation | StaticValidator三状态与计数预算、Safety fail-safe |
| rules | 8字段transition、八动作、IDLE context、Goal、MOVE+ENTER复合效果 |
| level | Baker/Codec真实hash与Validator前置，不接受自称合法的Level |
| runtime | Session只装载spawn、local/global完成接口、token/generation与Presenter真实返回值 |

FOUNDATION-2报告中的FOUNDATION_RULE_RUNTIME_PASS与91,219条执行断言是历史验收证据，本轮没有把该数字当作新运行结果。旧core/架构与第一波代码相对既有读取基线未变；第二波新生产接口已据当前代码复核。

## 2. Solver Status

固定SOLVED=0、PROVEN_UNSOLVABLE=1、BUDGET_EXCEEDED=2、ERROR=3。只有定义策略下完整闭包且没有Goal才可PROVEN_UNSOLVABLE；FIRST_SHORTEST找到Goal不代表全图完整。FULL_GRAPH预算耗尽即使保留Goal见证也必须BUDGET_EXCEEDED。

## 3. SearchBudget

固定max_states、max_edges、max_depth、max_runtime_ms、max_action_evaluations，默认10000/100000/-1/0/200000。-1深度无限，0墙钟关闭；其余有效范围见Spec。限制前检查、图原子插入，恰满但无额外工作可正常结束。深度上限不能静默裁剪，拒绝动作也计attempt预算。墙钟覆盖前置验证但不能中断单次纯函数；ERROR不被超时掩盖。

## 4. StateGraph contract

唯一stategraph.v1：完整key→状态节点、边数组、forward/reverse、first predecessor、BFS depth、Goal/expanded、complete/stop_reason。节点身份只能是正式statekey.v1，边下标只是引用。Goal终止、保留平行语义动作边、不记录无变化自环。

PolicyDescriptor固定strategy/mode/validation_options/filter_descriptor，是SearchPolicy去掉Callable的深复制投影。Graph/Trace保存同一结构。完整性只信本进程正式Explorer来源，结构验证不能替手填complete证明未遗漏边；首版不导入外部图。

## 5. StateExplorer

静态ActionGenerator候选→正式Kernel.evaluate_action+idle_context→APPLIED.changed结果→正式Key/Goal→纯filter→预算检查→原子入图。REJECTED计数；ERROR终止。只有一处BFS，BFSSolver薄调用Explorer；不写Shift/Rotation/Lighting规则。StaticValidator非VALID时不建图；Safety拒绝沿Kernel结果处理。

## 6. SolutionTrace

3A拥有solutiontrace.v1、predecessor生成、结构校验及`validate_semantics`。trace含初态/key、有序semantic action、每步完整expected_state/key/global_kind、Goal key和步数；不含键鼠/帧。语义校验逐步调用正式Kernel验证可达性，返回真实transitions供3C复用；正确key与Goal末态本身不能证明路径合法。3D仍需真实Session验证提交，不能以纯Kernel检查替代。

## 7. Softlock definition

完整UNFILTERED图内，Softlock=ReachableFromInitial−CanReachAnyGoal，后者从所有Goal沿reverse求得。完整无Goal意味着初态无解且所有已达状态为softlock。图不完整或分析预算不足时INCOMPLETE、softlock_states/count=null，保留正向证据与unknown，不做虚假负结论。图记录容量在调用整图验证前检查，墙钟包含校验和reverse。

## 8. Reset policy

Reset永不进入主ActionGenerator/Graph/SolutionTrace。可否Reset恢复是单独分类，不删除softlock身份。spawn不在自定义初态图或图不完整时UNKNOWN；确定完整spawn可Goal时才有RECOVERABLE_BY_RESET及精确恢复数。

## 9. PuzzleIntent

独立puzzleintent.v1 sidecar，含版本、ID、Level hash/rule、required/optional机制、ordered milestones、forbidden禁用集合。required/optional互斥，禁止任意DSL/UI文案表达式；不扩展原LevelDefinition或PuzzleState。报告保留完整intent，避免相同Level的不同设计意图混淆。

## 10. MechanicTag

唯一3C分类：MOVE、WORLD_SHIFT、SURFACE_ROTATE、INNER_ROTATE、FACE_TRANSITION、LOCAL_GROUP_ROTATE、CELESTIAL_CHANGE、MECHANISM_TRIGGER。分类成功动作的完整实际效果，覆盖direct/TRIGGER/ENTER入口。MOVE+ENTER FaceTransition需正式Connectivity解析中间入场Face，再读正式Effects；不能假设result有events字段或只看最终位置。

## 11. Ablation result与质量范围

只接受UNFILTERED输入policy；正常baseline SOLVED后，每个禁用集合调用同一3A Solver。回调只删除真实成功边，不改Level、next_state或ENTER内部效果。SOLVED表示该集合非必要；仅违反required/forbidden才MECHANIC_BYPASS。完整无解表示集合整体必要，不能推到每个成员；预算耗尽essential/bypass=null、INCOMPLETE。

硬见证先做正式语义校验并复查禁用tag。Milestone首版仅SINGLE_TRACE：required按非递减采样索引匹配，optional独立，不阻断required；TRACE_MATCH不证明所有解。UNUSED_MECHANISM只对返回见证WARNING。所有解教学顺序证明与最短解数量明确延期。

## 12. RuntimeParity

3D async replay直接送semantic action到真实Session.request_action，逐步等一次committed+IDLE，比较完整statekey.v1及expected_state。按transition_started.is_global选择finish接口；复合MOVE仍local。首版只支持spawn初态，不直接赋session.state。

MATCH/DIVERGED/ERROR/INCOMPLETE四状态固定；第一次错key/拒绝/commit数异常定位divergence_step，超时不伪装MATCH。LOGICAL_SESSION与GRAPHICAL都走真实KernelPort/Safety；图形模式用正式Presenter自然Tween完成，截图辅助。Reset旧token负例独立于trace。

## 13. Search metrics与延期

统一explored_states、visited_states、generated_edges、duplicate_states、goal_states、max_depth_reached、solution_length、action_evaluations/rejected/no_op/filtered计数、Safety不确定拒绝数及elapsed_ms。指标不参与规则。shortest_solution_count=null、shortest_solution_count_complete=false，明确未实现全部最短解计数。

延期：A*/SAT/SMT、自动关卡生成、Difficulty AI、Monte Carlo、启发式设计、完整Heatmap/Editor UI、所有最短解计数、严格milestone全路径乘积分析、Graph/Trace磁盘交换、非spawn Runtime恢复、搜索并行性能与时间窗玩法。无P-02、Blender或P-01迁移。

## 14. 四Owner所有权

| Work | production唯一范围 | tests唯一范围 | 清单中production / tests数量 |
|---|---|---|---|
| 3A | foundation/solver/ | tests/foundation/solver/ | 7 / 6 |
| 3B | foundation/quality/softlock/ | tests/foundation/quality/softlock/ | 2 / 5 |
| 3C | foundation/quality/intent/ | tests/foundation/quality/intent/ | 5 / 8 |
| 3D | foundation/parity/ | tests/foundation/parity/ | 2 / 7 |

这是未来计划清单，共16份production、26份tests/scene/wrapper，**当前均未创建**；自动比较四清单无重叠。各自.gd.uid归原Owner；仅可更新自身plan和专属report，不共享修改Spec/旧wrapper。3B/C/D允许明确tests-only fixture/adapter并发开发，但禁止复制3A算法，最终PASS必须真实集成。

## 15. 实际新增仓库文档

本轮精确六份：

1. [合同Spec](../superpowers/specs/2026-09-16-foundation-solver-quality-contracts.md)
2. [3A StateExplorer/BFS计划](../superpowers/plans/2026-09-16-foundation-state-explorer-bfs.md)
3. [3B Softlock计划](../superpowers/plans/2026-09-16-foundation-softlock-analysis.md)
4. [3C Intent/Ablation计划](../superpowers/plans/2026-09-16-foundation-puzzle-intent-ablation.md)
5. [3D Runtime Parity计划](../superpowers/plans/2026-09-16-foundation-runtime-parity.md)
6. 本报告`docs/development-records/FOUNDATION_SOLVER_QUALITY_CONTRACT_FREEZE_REPORT.md`

四计划各含Goal、Architecture、精确文件、consumed/produced签名、RED/GREEN代码示例和步骤、具体验收命令、禁止文件、PASS与CONTRACT_MISMATCH停止规则。命令已经核对现有Godot路径及旧full_integration wrapper接口；新测试路径是拟实现交付，不声称现在存在或已运行。

## 16. Obsidian实际同步

根目录`E:/obsdian/青澄的水泥房/方块娘/若叶睦`，新增：

- `测试与验证/自动状态空间与BFS求解器.md`
- `测试与验证/Softlock与Reverse Reachability.md`
- `测试与验证/PuzzleIntent与Mechanic Ablation.md`
- `测试与验证/SolutionTrace与Runtime Parity.md`
- `技术心得/为什么搜索预算耗尽不等于无解.md`
- `可复用方法论/用机制消融验证关卡设计意图.md`
- `开发日志/2026-09-16-FOUNDATION-3.0求解器质量合同冻结.md`

仅追加更新`00-索引/00-MOC-核心玩法架构.md`。其原4134字节逐字节前缀保持一致；原SHA256为`D037FD58DAABFE1F8487857E9DD447FE4FED95A861ACDA02B12FEE4CB3C33F51`。七篇笔记均有双链、标签、FROZEN DESIGN/NOT IMPLEMENTED；双链目标存在且不重名。历史阶段文字保留，新追加段明确FOUNDATION-2已实施而第三波尚未开始。

## 17. 十五项自检与实际验证

| # | 要求 | 结果 / 依据 |
|---|---|---|
| 1 | Solver无第二套玩法 | PASS；Spec §2/4/5，3A只转正式Kernel |
| 2 | Next State只来自Kernel | PASS；成功transition→完整状态入图，filter只能删边 |
| 3 | statekey.v1唯一身份 | PASS；Spec §6，Graph/Trace/Parity共用 |
| 4 | Reset不入主Solver | PASS；候选八类，无Reset |
| 5 | Budget不等于无解 | PASS；五原因/边界/完整性状态独立 |
| 6 | Softlock定义独立于Reset | PASS；先差集再恢复分类 |
| 7 | partial图不伪判Softlock | PASS；INCOMPLETE/null/unknown |
| 8 | Ablation不实现Solver | PASS；3C callback+唯一3A solve，无BFS |
| 9 | Parity不模拟键盘 | PASS；Session.request_action semantic输入 |
| 10 | Parity使用statekey.v1 | PASS；逐次commit完整key比较 |
| 11 | invalid Level不进Solver | PASS；hash+StaticValidator VALID门槛 |
| 12 | Safety不被绕过 | PASS；沿Kernel fail-safe、保留1601/1105 |
| 13 | 四Owner无重叠 | PASS；自动提取42条production/tests清单，无重复路径 |
| 14 | double不复制3A算法 | PASS；明确tests-only响应/值fixture、真实依赖最终门槛 |
| 15 | 未开始Solver production | PASS；仅六份新Markdown、原tracked/index无diff |

实际执行的是文档/静态源码检查：分支与HEAD、Git范围、四计划必需章节与禁用占位扫描、精确文件清单交集、Obsidian双链/标签/状态、MOC原始字节保护、Markdown格式与链接。没有运行新的Godot测试、没有新Runtime PASS；四计划内所有执行checkbox保持未勾选。

独立只读评审最初发现PolicyDescriptor未封闭、Milestone见证未证明相邻动作可达；已分别补齐唯一策略投影、Trace.validate_semantics与伪造trace负例。另将Softlock测试无变化自环改为sink/两状态环。最终复核无剩余阻塞，仅为合同/接口review，不是实现验收。

## 18. CONTRACT_MISMATCH

**NONE**。当前production无需改变即可满足冻结设计。真实Session只支持spawn的限制已明确收窄3D首版能力，未凭空增加恢复API；真实MOVE+ENTER没有events字段的限制已由正式查询复用处理。以上为合同已解决的适配边界，不是未处理缺口。

未来Work若发现expected/actual API或字段冲突，必须停止受影响步骤并报告Owner/path，不越界改公共合同或其它Work文件。依赖未交付用DEPENDENCY_PENDING，不冒充真实集成PASS。

## 19. Git diff与非实现证据

`git diff --name-only`、`git diff --cached --name-only`为空；`git diff --check`通过；HEAD未移动。`git ls-files --others --exclude-standard`列出本报告和上列Spec/四计划，共六份Markdown。因为它们尚未跟踪，普通`git diff --stat`为空不表示没有文档交付。

foundation原28份.gd保持现状；未创建四路production/tests目录或修改任何旧代码、tests、P-01、project.godot、资产。知识库在仓库外，七新一追加单独核验。没有git add/commit/push/merge、没有创建worktree，没有启动3A/3B/3C/3D。只读review不是四路实施启动。

## 20. 是否可以启动四路并发

**合同与计划具备后续并发条件，当前执行状态仍为等待用户review。** 用户后续授权后，3A直接依赖FOUNDATION-2，3B/C/D按冻结Graph/Solver/Trace接口先开发；3A未集成时限定tests-only double，最终全部必须接真实链。3A不反向preload3C，只消费固定纯过滤Callable，文件Owner无冲突。

本轮到此停止，不自动启动实施。
