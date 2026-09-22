---
title: FOUNDATION-4 Authoring / Editor Design Spec
date: 2026-09-22
revised: 2026-09-23
revision_status: CONTRACT_REVIEW_READY
design_status: DESIGN DOCUMENTED
implementation_status: NOT IMPLEMENTED
review_status: AWAITING USER REVIEW
contract_freeze: HELD_FOR_REVIEW
source_baseline: bfcc6c004db232ca2f4ea4d409c98bda0dc6d165
---

# FOUNDATION-4.0 — Authoring / Editor Design Spec

## 1. 文档效力与依据

本文把已经批准的设计方向整理成正式审阅稿，不授权实施，不创建 4A/4B/4C/4D Work，不进入 P-02。FOUNDATION-4 工具尚未实现；FOUNDATION-1/2/3 的既有模块不能因此被标成未实现。

依据优先级：2026-09-23 GAME DEVELOPMENT — FOUNDATION-4 用户说明 → 2026-09-22 归并任务说明 → [工作笔记](../../development-records/FOUNDATION_4_AUTHORING_DESIGN_WORKING_NOTES.md)中最新明确批准记录 → 正式 Core / execution / analysis 合同及实际源码。历史候选、推荐语和“待批准”尾句不构成新的批准。逐条冲突及源码证据见[审阅报告](../../development-records/FOUNDATION_4_DESIGN_CONSOLIDATION_REVIEW_REPORT.md)。

[Tool Contracts](2026-09-22-foundation-authoring-tool-contracts.md)中“现有”代表本轮读到的生产接口；“拟定”代表供本次 review 的工具合同，不代表代码已经存在或用户已批准字段细节。本次已集中修订 G1–G6，状态 CONTRACT_REVIEW_READY / IMPLEMENTATION: NOT_STARTED，仍待正式Spec review，不签发合同冻结。G1/G2方案方向已获本次用户明确批准，具体捕获/编码/装载细则及G3–G6仍为提案；集中差异见Tool Contracts §10。

## 2. 制作流程与唯一真相

Hybrid Authoring：Scene 编辑空间，Resource 保存语义与可复用配置。唯一正式 Baker 产生 canonical LevelDefinition；Runtime、Validator、Solver 使用正式数据与接口。PuzzleState 独立保存可变态，PuzzleIntent 是独立 sidecar，不进入 LevelDefinition 或 build_info。编辑工具不执行第二套玩法规则，不复制 Baker、Solver、光照、映射、安全或绑定算法。

作者打开 Level 主场景，分别编辑 Surface / Inner 子场景，在 Inspector 配置六面、机制和 Intent。分析当前编辑状态可在未保存时给出局部证据；完整验收先由作者明确保存本关依赖，再捕获快照，执行 Bake、正式验证、完整搜索、软锁、Intent、Trace 语义与真实图形回放。Bake 已内置 StaticValidator，只在 VALID 时输出 level；界面不能制造绕过验证的中间产物。

地图源和依赖进入 Git；生成产物独立保存、日常忽略、交付时成套导出。保存不要求 commit/push。具体缓存路径仍属待确认建议，见 §11；本轮不修改 .gitignore。

## 3. 关卡组织与坐标

| 作者对象 | 已批准职责 |
|---|---|
| Level 主场景 | 装配恰好一个 Surface 和一个 Inner；关卡级配置、Spawn / Exit、共享 Celestial、Intent 引用 |
| 两个独立 World 子场景 | 各自组织 Cube、统一 MechanismAuthoringNode、FaceTransition、RotatableGroup；子场景局部检查不能签发整关通过 |
| Cube 作者节点 | 一个空间对象和稳定 Cube ID；六面是内部稳定数据，不默认增加六个永久 Face 节点 |
| MechanismAuthoringNode | 空间实例与显式关卡绑定，关联可复用机制 Resource；执行仍归 Kernel |
| Intent Resource | 作者声明必需机制、可选机制、里程碑、禁止绕过条件；不维护每次 Bake 的 hash |

两世界共享 Level 局部 Shared Space。Level 根可按 Reader 约束作有限刚体放置；World 实例根和组织容器单位变换，禁止 top_level、任意中间变换、同 World 多实例装配。Cube / Slot 原始变换交给 Reader，不自动吸附以掩盖非法数据。组旋转以正式 pivot / 初始状态表达，不用父 Node 旋转替代。

现有 Reader 仅支持直接 Cubes / Slots 容器。已批准共享适配路径：新作者声明 → 短生命周期、脱离 SceneTree 的纯 Node3D 旧 profile → 正式 Reader → 正式 Baker。适配器只展开结构、映射声明与记录来源，不复制作者脚本，不保存临时场景，不量化或推导玩法。Editor 与 headless 共用这个 4A 入口。

## 4. 六面与机制编辑

三维视口点选面联动 Inspector，Inspector 六面选择保留备用入口。Face 身份由 Cube 正式 ID 与本地 FaceDirection 决定；世界旋转不重命名本地面。walkable、shift_exit_blocked、shift_entry_blocked 和机制关联映射现有字段；layer 属于 Cube。FaceAnchor、U/V/normal、Mapping、逻辑光照只从正式模块派生，不可手改。

统一机关节点通过 Resource 参数与实例目标绑定形成正式 MechanismDefinition。首版只组合既有 ENTER / USE、MOVE_CELESTIAL、LOCAL_GROUP_ROTATE、USE_FACE_TRANSITION 能力和固定单状态机制 profile；不新增门、动态 flag 或每关执行脚本。可复用参数与实例目标的单一写入位置见工具合同；尚未批准的字段拆分明确为拟定。

4B 只有一个插件入口，使用 Dock、Inspector 和已有三维视口。基础反馈包括 Cube 边界/局部面、Spawn/Exit、世界标签与显隐、显式关系线、组成员/pivot、Celestial Slot 和问题高亮；图标及文字配合颜色。声明关系标为未验证；状态相关光照/连接只针对所显示的正式 Level + PuzzleState。不实现高级热力图、状态网络或新地图编辑器。

## 5. 身份、复制、引用、删除与共享资源

正式 ID 沿 Core：StringName，`[a-z][a-z0-9_]*`，同类同一关卡唯一，Cube 跨两世界唯一；Face 用官方 `face_id` 生成。工作笔记已批准的 authoring_id 是持久、不透明 UUID，仅用于工具来源定位，整关装配内唯一，不进入 canonical 或 StateKey；这不是新增运行时身份体系。显示名、路径、instance_id、Resource UID 都不能替代正式身份。

改名、移动、旋转保持对象身份。显式更改正式 ID 是规则编辑，必须检查引用，首版不自动跨文件重命名。

工具复制限单对象：分配新 authoring_id 及合法、无冲突的正式身份；复制机关默认保留原目标引用并明确显示，不猜新目标。记录自有 mechanism_id 与指向其他对象的目标引用必须区分。整组智能克隆、自动引用重映射延期。原生复制、外部编辑、多实例造成重复 ID 时诊断，Bake 不静默改号。

删除被引用对象前展示影响，默认取消；作者明确确认后允许删除，保留可诊断的失效引用。不能静默解绑或寻找邻近替代物。Undo 恢复对象、原身份和关系，Redo 复用同一组已分配 ID。编辑操作进入所属文档的撤销历史，一次拖动一次事务；跨文件批量编辑延期，保存/作业/导出不冒充源编辑撤销。

Resource 明确标识共享/专用，提供“创建专用副本后修改”。副本须覆盖全部可变语义子资源及嵌套 Array/Dictionary，保留内部别名关系，不能外层复制后继续误共享可变数据。外部纯展示资产是否继续共享必须在操作摘要中列出；具体资源类型白名单与复制算法属待审合同。首版不做全项目依赖管理器，仅处理本关依赖闭包。

## 6. Intent 绑定与证明范围

4A 独占保义绑定转换：同一快照的作者 Intent + 同轮成功 Bake 的 content_hash / rule_version → 正式八字段 puzzleintent.v1 候选。4C 调用 IntentValidation 与质量分析；4D 编排、汇总、归档；4B 展示。不增加、删除或放宽作者约束，不回写源 Resource，不使用旧关卡冒充本次成功。

作者格式独立版本化。未知版本、缺失必填字段、解析/加载失败必须报错，不静默迁移。正式标签集合唯一且升序；里程碑保持作者顺序；重复或非法条目不能靠去重/删除修复。作者 AT_FACE 引用使用 CubeID + 本地面，经官方接口转换。

缺少 Intent 不等于空：可以单独 Bake，但不能完成完整验收。显式空要求有效作者格式、必填配置齐全，且 required_mechanics、optional_mechanics、expected_milestones、forbidden_bypasses **全部为空**。仍实际执行作者校验、绑定和正式 Intent 校验。只有没有声明的约束子项才可“不适用”，不能把整个 Intent 阶段跳过。

其他门槛全部满足且当前性正确时，必须显示：**“验收通过 · 未声明设计约束”**，并注明“未证明特定机制必要性、禁止绕过条件或教学里程碑”。仅 optional 或 milestone 非空也不是空 Intent。未执行、不完整、错误和不适用分别表达。

里程碑始终 SINGLE_TRACE。所选原图最短 trace 的 TRACE_MATCH 只证明这条见证，不能表示所有解/所有最短解均满足教学顺序。Ablation 内部 baseline 的 trace 不能未经核对替代所选 trace。

## 7. 两个入口与快照

| 入口 | 输入政策 | 范围与结果用途 |
|---|---|---|
| 分析当前编辑状态 | 允许未保存；捕获当前 Level、相关独立 World、Resource、Intent 和分析配置的统一快照 | 明示实际检查、预算、未执行项；即便局部全绿也不签发完整验收 |
| 完整验收 | 本关相关场景/Resource 先保存；列出保存范围，由明确操作保存，不静默保存无关场景 | 获得一致快照后运行完整适用流程；保存不是 Git 提交 |

两入口均明确点击触发，共用作者适配、快照格式、Baker 和正式分析接口；不是两条玩法实现链。拖动或保存只做轻量字段/引用/profile 检查与过期标记，不自动完整搜索。

捕获期间短暂限制相关编辑；成功后解除限制，允许继续编辑。后台只读自己的不可变快照，不读取变化中的活动对象。捕获遇到缺失依赖、不同文档版本冲突或不能复制的声明则失败并停止启动；不从磁盘旧版本补洞。不能把 `duplicate(true)` 或三个 tscn 的文件复制直接当作完整快照协议。

本次 G1 明确推荐：玩法属性只在独立World源文档编辑，拒绝Level实例内玩法覆盖/继承叠加；相关打开文档的未保存声明优先，资源同身份多版本冲突则失败；保存入口用相关保存清单和磁盘/缓冲一致性复核。4D封包前后比较投影、编辑代次和磁盘摘要，worker只读封闭声明与版本绑定的最小工程。此新增覆盖限制和具体协议仍待批准，详见Tool Contracts §5；不取消未保存分析最终范围。

## 8. 后台任务、取消与生命周期

沿工作笔记批准的独立 Godot 作业进程方案：无界面进程负责适配/Bake/求解/质量，原图和 Softlock 留在同进程；独立可见图形验证进程加载同轮 canonical + trace，调用正式 GRAPHICAL Replayer。无图形能力只能给部分报告。

每个 Godot 编辑器实例首版仅一个重任务，包括求解、质量、完整验收、真实回放。完整验收各阶段占同一任务槽，不自动排队。轻量检查、看报告和浏览已有步骤可继续。每次任务绑定 run_id、generation、关卡身份、输入快照与执行策略。

任务至少区分运行中、正在取消、已取消。请求取消先封锁后续阶段和整轮 PASS 发布，再处理工具自己拥有的 worker / 图形进程；不能按进程名干预用户其它 Godot 窗口。无法立即中断的正式同步调用允许返回后停链；确认进程退出、回调断开和预览资源释放前不释放任务槽。

取消保留已完成、身份匹配的证据，不伪造未返回的正式结果。外部看门狗超时、正式预算不足、用户取消、崩溃各自记录。既有 API 不公开搜索中途进度，界面只显示真实阶段和已知指标。

切换关卡隔离发布上下文，旧任务不得更新新关卡；关闭插件先撤销发布资格并清理所拥有的任务/预览。迟到消息只有在 editor instance、run_id、generation、关卡、快照全部匹配时才能更新当前展示，否则仅保留为历史或丢弃无效消息。本次G5建议选合作式取消＋文件IPC＋父租约，不按PID强杀；工具期限只触发停链，不能保证中断同步调用。必须显示等待释放，未确认前不开放下一槽。默认预算、限额、卸载与租约边界见工具合同§6，均待review。

## 9. 报告、定位、只读构型与真实验证

任务生命周期、检查结论、当前适用性是不同维度。历史 PASS 在作者数据、相关资源、Intent 或分析配置变化后仍保留历史结论，但显示 STALE；依赖一致性未知显示 UNKNOWN。选择、展开面板、观察相机不改变规则身份。作者显示名变化可能不改 level_hash，却影响来源定位，仍按保守策略使旧映射/报告过期。Undo 也不自动恢复当前 PASS；首版不优化部分免重跑。

正式问题保留原 code、severity、path、entity_ids / subject_ids / upstream；4A 生成 source map，4B 定位与高亮，4D 归档。实体 ID 优先；索引路径只在其准确的 Reader 或 canonical 排序阶段解释。无法唯一匹配时显示整关/未定位问题，不猜方块。历史图层不能伪装成当前诊断。

软锁 GraphNode 与解法 initial_state / expected_state 共用 4D 的独立只读状态视图；4B 负责容器和选择。展示“分析状态”或“解法预期状态”，绑定 level_hash 和完整 StateKey，不写作者 Transform，不赋值 RuntimeSession.state。

解法可选任意步骤、上一/下一步、查看前后差异，显示前对整条 trace 执行正式 validate_semantics。浏览成功不能显示 Parity MATCH。真实验证另行从 Spawn 调用完整异步 GRAPHICAL replay，经过正式 Session、Kernel、Safety、Presenter，自然动画回调和单次提交比对。首版没有动画暂停单步、倒放、时间轴拖动、任意 Runtime 状态恢复。

现有 prototype_presenter.gd 带 Surface/Inner 的 ±2.4 视觉偏移。它能被正式 Replayer 复用，但不能直接当作 Shared Space 编辑器叠加视图。拟由唯一 4D 状态视图消费正式 Geometry.snapshot 派生值，4B 不再写一套状态展示服务；这一技术落点尚待 review，不修改旧 Presenter。

## 10. 完整验收门槛

| 必需证据 | 通过条件与限制 |
|---|---|
| 输入与 Bake | 一致、保存过的本关快照；本次正式 Baker 成功，validation=VALID；无历史回退 |
| 结构与安全 | 正式有效；安全无法判断不能降级为普通警告或“不适用” |
| 原关卡 Solver | 从 Records.initial_state 出发；UNFILTERED / FULL_GRAPH；SOLVED 且 graph.complete=true；只找到单条解不够 |
| Softlock | 本轮同进程正式未过滤活图；COMPLETE 且 softlock_count=0；Reset 可恢复不抵消软锁 |
| Intent | 有效作者输入、同轮绑定、正式校验；全部适用请求完成，无 required/forbidden 硬问题；普通 optional / UNUSED_MECHANISM 警告保留 |
| 所选 Trace | 记录原图返回见证及其身份；正式语义通过；required milestone 在同一 trace 为 TRACE_MATCH；SINGLE_TRACE |
| Runtime | 同一 trace 从 Spawn 正式 GRAPHICAL replay，MATCH；无图形/预算不足/取消不能替代 |
| 结果适用性 | 历史证据与当前源关系准确；只有已核验完整 PASS 且 CURRENT 才显示当前关卡通过 |

所有正式枚举原样保留。工具汇总不以 COMPLETE 等同质量 PASS，不以没有 finding 等同通过。预算不足、未执行、错误与未知不能转为无解/零软锁/必要性证明。安全 1601 / safety_unproven_rejections 必须显式阻止完整 PASS；这比仅满足“当前 fail-safe Kernel 图闭合”更严格，工具只增加门槛，不改变 Solver 的正式结果。

初态已 Goal 的合法零步解照常执行适用门槛。Ablation 内部仍进行自身正式 baseline / 子搜索，不提供假的 skip_validation 或复用图参数。现有 Replayer 内置静态预算 4096/100000，不接受自定义 validation_options；实际限制必须展示并归档，不能承诺提高前段预算就一定能通过图形阶段。

自动技术验收不证明可读性、趣味性或新手理解，真人体验另记。

## 11. 归档与交付

每轮独立输入、临时写入和证据集合；正式报告只有附件完整写入并校验后发布。取消/故障保留部分记录，不覆盖上一份完整归档。归档保留源快照身份、canonical、绑定 Intent、trace、策略/预算、工具/合同版本、实际阶段状态、警告和 source map。

工作笔记 DECISION-009 的Git政策已批准。本次G6明确建议缓存使用E盘执行源项目的 `.godot/foundation-authoring/runs/<run_id>/`，永久导出默认 `E:/godot/foundation-authoring-deliveries/<level_id>/<run_id>/` 并允许明确选择其它E盘目录；不覆盖已有包。精确路径仍待本次review。缓存不能当永久交付存储。

归档写入失败不能显示“完整验收已归档通过”；计算阶段证据保留，发布状态单独显示失败。本次建议首次发布失败为ERROR/UNDETERMINED（有硬反例则FAIL），保留技术门槛证据；已有报告的后续导出失败单独记录，不改历史结论。最后manifest及全部摘要校验构成发布边界，详见工具合同§9，待review。

## 12. 唯一 Owner 与首版终点

| Owner | 唯一职责 |
|---|---|
| 4A 作者数据 | 作者组件/profile、稳定身份与引用、共享适配、唯一 Intent 绑定、来源映射 |
| 4B 编辑器 | 唯一插件入口、面板/Inspector、视口标记与选择、提示与 UndoRedo、交互装配 |
| 4C 质量编排 | 调用正式求解、Softlock、Intent/Ablation、所选 trace 语义与里程碑；返回规范原结果，不复制算法 |
| 4D 验收与预览 | 快照、唯一重任务/取消服务、唯一报告汇总/归档、只读状态展示生命周期、真实回放入口 |

4A不拥有wire、任务管理或插件；4B不拥有Solver、验收汇总或第二预览；4C不拥有worker或顶层PASS；4D不重做作者转换或几何/玩法。已有 rules、Baker、Solver、Runtime 等保持原 Owner。建议技术目录仅作后续落点，不是任务分派。旧 API 如确需修改，先提交证据、影响与最小修订建议，停止受影响合同冻结。

### 12.1 获批实施后的第一项可运行交付

先交付 Level主场景＋独立Surface/Inner＋稳定Cube与六面＋Spawn/Exit＋正式最小天体/机制＋有效Intent（含显式空测试），经唯一4A适配→真实Reader/Baker→正式Codec→RuntimeSession/Kernel/Presenter，在可重复运行的白盒入口形成整条链。运行宿主唯一归4D，不为每张fixture编写玩法脚本；4B可以先提供最小操作入口，不能用大量空面板替代链路。

必须展示同一作者场景的一处真实配置修改→新Bake→canonical对应变化→Runtime确实装载该产物，记录源快照/level_hash；不能另造容易通过的LevelDefinition。行为覆盖MOVE、一种合法世界旋转、满足条件的World Shift、Goal、Reset，可分多个最小fixture。作者有效性、动作权限、几何安全、真实执行分别核验；失败不放宽Safety。

4.1先打通已保存作者数据至正式数据并接真实白盒Runtime；4.2六面/Inspector/身份引用/撤销诊断；4.3正式质量与步骤浏览；4.4未保存分析、完整快照、取消、回放和归档；4.5三地图完整流程及历史回归。先用已保存输入只是交付顺序，未保存分析仍必须完成。

白盒可替换，不重新施加旧像素尺寸或美术工程一格一单位约束；正式cell_size为准。旧P-01不迁移，不读美术半成品为正式依赖，不调用Blender、不写美术/参考图片目录。图形验收安排独占窗口，不终止其它Work进程；未运行明确NOT_RUN。白盒通过不是美术验收，也不是整个FOUNDATION-4完成。

### 12.2 最终范围与审批推进

FOUNDATION-4 最终以三张小型验证地图收口：A 验证基础制作和显式空 Intent；B 组合既有机制与实际约束；C 故意错误→定位→修正→旧结果过期→重验，同时覆盖撤销、保存重开和取消。不为地图写专属玩法脚本。这些不是 P-02；完成制作流程和既有回归后才进入 P-02。

验证分层包括作者序列化、编辑器/撤销、确定性 Bake、来源定位、质量状态、预览隔离、任务与归档全流程、既有工程回归。日常单关不跑全部历史测试；模块开发/总集成运行对应回归。本轮全部是设计验收要求，未创建地图或测试，未执行 Godot。

延期：整组智能克隆、自动引用重映射、全项目资源依赖管理器、高级热力图、所有解教学证明、AI 关卡生成、难度 AI、图编辑器、运行动画单步与任意状态恢复。本次Spec/合同批准后仅进入状态B：四份Owner计划＋一份集成计划审阅。计划批准、执行方式明确、共同基线已提交后才进入状态C，创建/核验独立工作树并实施。未跟踪文档不构成共同基线；commit/push/merge/PR仍须用户单独授权。
