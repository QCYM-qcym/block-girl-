---
title: FOUNDATION-4 Tool Contracts
date: 2026-09-22
revised: 2026-09-23
revision_status: CONTRACT_REVIEW_READY
design_status: DESIGN DOCUMENTED
implementation_status: NOT IMPLEMENTED
review_status: AWAITING USER REVIEW
contract_freeze: HELD_FOR_REVIEW
source_baseline: bfcc6c004db232ca2f4ea4d409c98bda0dc6d165
---

# FOUNDATION-4.0 — Tool Contracts

## 1. 效力、类型与版本

这是正式工具合同审阅稿。§2 是本轮源码事实；§3–11 是本次集中修订的候选工具字段与协议，全部 NOT IMPLEMENTED，尚未获字段级冻结批准。不存在的 API 不作为可调用接口列出。见[Design Spec](2026-09-22-foundation-authoring-editor-design.md)和[审阅报告](../../development-records/FOUNDATION_4_DESIGN_CONSOLIDATION_REVIEW_REPORT.md)。

现有规范：[Core](2026-09-13-foundation-core-contracts.md)、[Kernel](2026-09-13-foundation-puzzle-rule-kernel-contracts.md)、[Solver/Quality](2026-09-16-foundation-solver-quality-contracts.md)。LevelDefinition 19 字段，PuzzleState 6 字段，statekey.v1 不变。正式内存 Dictionary 的键为 String、ID 为 StringName、枚举为 int、离散坐标为 Vector3i；不得把 JSON 解析得到的浮点或普通 String 直接送入要求精确类型的接口。

拟定工具版本：levelauthoring.v1、puzzleintentauthoring.v1、authoringsnapshot.v1、authoringsourcemap.v1、authoringrun.v1、levelacceptance.v1。它们不替换 foundation.contract.v1 / contract_revision v1.1 / foundation.rules.v1 / foundation.execution.v1 / foundation.analysis.v1 / cube24.v1，也不向正式记录增加字段。所有候选版本名须随本稿 review。2026-09-23 用户已批准 G1/G2 的方案方向：作者声明快照＋版本绑定受控工程、4D 唯一封闭交换层、Solver/Softlock 同进程且不跨进程恢复可信完整图；下文编码、捕获和装载细则以及 G3–G6 仍待批准。

## 2. 真实源码边界逐项对照

下表路径相对本设计工作树，行号以本轮基线为准。所有签名中的 level/state/initial/action/policy/budget/options/trace/graph/intent 为 Dictionary，除另注外返回 Dictionary。旧 Owner：DATA/MATH/SPATIAL/CELESTIAL；2A Kernel、2B Validator/Safety、2C Reader/Baker/Codec、2D Runtime；3A Solver、3B Softlock、3C Intent、3D Parity。新 4A–4D 不接管旧模块。

| 边界 / 调用方 → 提供方 | 当前真实文件与公开接口 | 输入、输出与失败语义 | 复用 / 工具适配 / 缺口 |
|---|---|---|---|
| 作者输入：4D → 4A → 2C | foundation/level/authoring_reader.gd:12 `read_scene(root: Node3D)` | 根 meta foundation_authoring（不含 content_hash）；直接 Cubes/Slots；返回 `{ok,authoring,issues}`，失败 authoring=null | Reader 可直接复用；新节点/Resource/World 展开适配尚不存在；G1/G3 |
| 正式 Bake：4D → 2C | foundation/level/level_baker.gd:10 `bake(authoring,options)` | 18 字段 authoring；options 恰为正整数 max_configurations/max_checks；`{ok,level,issues,validation}`；未获 VALID 则 level=null，validation 可 null | 直接复用；不调用私有 _bake_with_validator，不绕过正式验证 |
| canonical 交换：4D → 2C | foundation/level/level_codec.gd:35/43/54 `encode(level)`, `compute_content_hash(level)`, `decode(text:String)` | 分别 `{ok,text,issues}`、`{ok,content_hash,issues}`、`{ok,level,issues}`；失败空字符串/null；encode 核实 content_hash；decode 恢复类型 | 直接复用；只能处理 Level，不是 Intent/Trace/快照通用 codec；G2 |
| 状态与身份：4C/4D → DATA | foundation/contracts/contract_records.gd:22 `initial_state(level)`；state_key.gd:9 `build(level,state)` | initial_state 要求 level shape 预先合法，返回六字段；build 返回 `{ok,key,issues}`，失败 key="" | 从成功 Bake 构造 Spawn，完整 String key；不另 hash 状态 |
| Shape：4A/4C/4D → DATA | foundation/contracts/contract_validation.gd `validate_level_shape(level)`, `validate_state_shape(level,state)`, `validate_action_shape(level,action)` | 返回 Array[ValidationIssue]；字段、域、引用检查不证明可解 | 正式值记录边界直接复用；作者格式校验独属 4A，不能把作者 metadata 混入 Level |
| 静态：Baker/Solver/Replayer → 2B | foundation/validation/static_validator.gd:19 `validate(level,options)` | `{status,issues,configurations_checked,checks_performed}`；VALID/INVALID/INCOMPLETE；预算/安全未知不能成功 Bake | 复用各现有调用，不造 Editor 验证规则；记录各次真实预算 |
| Safety：Kernel/Session → 2B | foundation/validation/safety_queries.gd:13/17/51 `validate_state(level,state)`, `validate_motion(level,before,after,action)`, `validate_concurrent_motion(level,before,after_local,after_global,local_action,global_action)` | `{status,issues}`；SAFE/UNSAFE/UNPROVEN/ERROR；几何安全不等于动作权限 | 间接复用；4C/4D 保留 1601 与安全未知计数，不能另做扫掠 |
| 动作：Solver/Session → 2A | foundation/rules/puzzle_rule_kernel.gd:21/35 `evaluate_action(level,state,action,context)`, `complete_global(level,state,context)` | 八字段 status/previous_state/next_state/action/changed/rejection_code/issues/global_kind；APPLIED/REJECTED/ERROR，后两者 next_state=null | 原 Owner 执行；工具不做第二规则，不把 REJECTED 当关卡非法 |
| 连接/机关分类：正式3C → 2A | foundation/rules/connectivity_resolver.gd:11 `query_move(level,state,face_axis:int)`；mechanism_effects.gd:27/61 `authorize(level,state,action,trigger:StringName=&"USE")`, `enter_effects(level,source_face:StringName,target_face:StringName)` | query `{ok,target_location,direction,issues}`，成功也可无目标；authorize `{ok,effect,issues}`；enter_effects 返回 Array[Dictionary]，先满足 DATA/profile 前提 | 由既有机制分类器复用，不由4C重算 MOVE+ENTER 中间面或复制分类 |
| 派生展示：4D → SPATIAL/2A | foundation/spatial/surface_geometry.gd `face_id(cube_id:StringName,face:int)->StringName`, `make_face_nodes(cube_id)->Array[Dictionary]`, `snapshot(level,state)`；foundation/rules/derived_state_resolver.gd:12/24/39 `snapshot`, `shift_mapping`, `light(level,state,face_id:StringName)` | Geometry/Derived snapshot `{ok,value,issues}`；mapping 四态和 candidates/mapping/issues；light `{ok,light_state,reason,occluder_id,issues}`；失败不能当 SHADOW 或空成功 | 直接消费正式值；4D 提供唯一只读视图，4B 只装配；G4 |
| Solver：4C → 3A | foundation/solver/state_explorer.gd:18 `explore(level,initial,policy,budget)`；bfs_solver.gd:4 `solve(...)` | `{status,graph,solution_trace,metrics,budget_reason,issues,validation}`；SOLVED/PROVEN_UNSOLVABLE/BUDGET_EXCEEDED/ERROR | 同一探索器；完整验收指定 FULL_GRAPH/UNFILTERED；单解分析可 FIRST_SHORTEST；无取消 token / progress / skip_validation |
| 策略构造：4C → 3A | foundation/solver/search_records.gd:4/10 `default_policy(mode:int)`, `default_budget()` | policy 五字段含 Callable；budget 五字段；graph/trace 仅保存无 Callable 的四字段 descriptor | 使用公开工厂；跨进程只传描述，worker 重建正式 policy，不序列化 Callable；G2 |
| 图：4C → 3A | foundation/solver/state_graph.gd:9 `validate(level,graph)` | `{ok,issues}`；校验结构、完整 key、邻接、predecessor 和标志一致性；不证明调用来源或未漏边 | 原图同进程直传；磁盘载入 complete=true 不能作为可信活图 |
| 软锁：4C → 3B | foundation/quality/softlock/softlock_analyzer.gd:12 `analyze(level,graph,budget)` | budget={max_nodes,max_edges,max_runtime_ms}；COMPLETE/INCOMPLETE/ERROR，未完整 softlock_states/count=null；witnesses 为 GraphPath，不是通关 SolutionTrace | 直接复用；UNFILTERED，同进程原图；无取消 API；不减去 Reset 可恢复数量 |
| Intent 绑定：4D → 4A；校验4C → 3C | 新4A转换尚不存在；foundation/quality/intent/intent_validation.gd:7 `validate(level,intent)` | 正式恰八字段；intent_version/hash/rule 必须匹配；`{ok,issues}`，失败是 AnalysisIssue | 必须工具适配；作者→sidecar 转换只归4A；正式校验只归3C；G3 |
| 消融：4C → 3C | foundation/quality/intent/ablation_analyzer.gd:7 `analyze(level,initial,intent,policy,budget)` | `{status,intent,baseline,ablations,milestone_analysis,advisories,issues}`；COMPLETE/INCOMPLETE/ERROR/BASELINE_UNSOLVABLE；子项 essential/bypass_detected 可 null | 直接复用；内部自行 baseline/子求解，不接受现成 baseline/graph；COMPLETE 仍可能有硬 bypass |
| 所选里程碑：4C → 3C | foundation/quality/intent/milestone_analyzer.gd:9 `analyze_trace(level,intent,trace)` | `{status,scope,matched_milestones,missing_required,sample_indices,findings,issues}`；scope=SINGLE_TRACE；TRACE_MATCH/TRACE_BYPASS/INCOMPLETE/ERROR | 对所选原图 trace 调用；不能混用 Ablation 另一条 trace 的证据 |
| Trace：4C/4D → 3A | foundation/solver/solution_trace.gd:12/43/80 `from_graph(level,graph,goal_key:String)`, `validate(level,trace)`, `validate_semantics(level,trace)` | from_graph `{ok,trace,issues}`；validate `{ok,issues}`；semantics `{ok,transitions,issues}`，失败 transitions=[] | 默认选择原图 solution_trace；validate 仅结构不足以证明动作合法；没有导入导出接口，G2 |
| Session：正式3D → 2D | foundation/runtime/runtime_session.gd:38/64/101/119/134 `load_level(definition)`, `request_action(action)`, `finish_local(id:int,callback_generation:int)`, `finish_global(...)`, `reset()->void` | load `{ok,issues}`只从 Spawn；request 八字段；finish `{ignored,transition}`；committed/transition_started/feedback 信号 | 由现有 Replayer 独占动作调度；只读状态不能注入 Session；reset 不等于停止整个工具任务 |
| Presenter：4D只读服务/正式3D → 2D | foundation/runtime/prototype_presenter.gd:41/87/124/129 `sync_state(level,state)`, `animate_transition(level,result,duration:float)`, `clear_previews()->void`, `layer_offset(layer:int)->Vector3` | sync `{ok,issues}`；animate `{ok,issues,tween,preview}`（失败无成功载荷）；硬编码世界左右偏移 | GRAPHICAL 原样复用；Shared Space 预览需4D消费正式几何，不能直接套偏移；G4 |
| 整段回放：4D → 3D | foundation/parity/trace_replayer.gd:39 instance async `replay(level,trace,options)` | 必须在 SceneTree 内；options mode/max_steps/max_runtime_ms/step_timeout_ms；结果 status/trace_length/matched_steps/divergence_step/expected_statekey/actual_statekey/action/issues | 直接 await；GRAPHICAL=1；无公开 pause/step/cancel/restore；无图形宿主加载服务，4D 新增编排；G2/G5 |
| 捕获/取消/发布/定位：4B → 4D/4A | 当前无 FOUNDATION-4 快照捕获、任务管理、archive/source-map API；旧 tools/foundation/level/bake_level.gd 仅单场景磁盘 CLI | 不能把旧 CLI 或 Runtime Reset 写成完整工具服务 | 必须工具适配，见拟定合同；G1/G2/G3/G5/G6 |

### 2.1 关键限制补充

AuthoringReader 的 Cube metadata 恰为 cube_id/layer/group_id/occludes_light/tags；Faces 恰六条，每条 face/walkable/shift_exit_blocked/shift_entry_blocked/mechanism_ids。Slot 使用显式 slot_id。坐标/姿态量化与 make_face_nodes 都在 Reader 内；source map 不能依赖树顺序等于 canonical 数组顺序。

SearchPolicy={strategy,mode,validation_options,filter_descriptor,transition_filter}；strategy=&"BFS"；FULL_GRAPH=1/FIRST_SHORTEST=0。UNFILTERED descriptor={filter_id:&"UNFILTERED",filter_version:"1",disabled_mechanics:[]}，Callable 为空。SearchBudget={max_states>0,max_edges>=0,max_depth>=-1,max_runtime_ms>=0,max_action_evaluations>0}，0 runtime 禁用墙钟，-1 仅用于无限深度。默认 10000/100000/-1/0/200000 是源码默认，不自动成为用户批准的验收预算。

GraphNode={state_key,state,depth,is_goal,expanded,predecessor_edge}；Goal 终止。完整图不是所有解路径枚举。SolutionTrace={trace_version,level_hash,rule_version,policy_descriptor,initial_state,initial_statekey,steps,goal_statekey,total_actions,shortest}；step={index,action,expected_state,resulting_statekey,global_kind}，index 从1起，浏览初态为0。合法零步解不能拒绝。

SoftlockResult 保留 initial_key/reachable_states/goal_reachable_states/softlock_states/softlock_count/unknown_states/reset_classification/reset_recoverable_count/witnesses/metrics/issues/status。GraphPath={target_key,edge_ids}，不保证到 Goal，不送给只接受通关 trace 的 Replayer。

Ablation 子项={status,disabled_mechanics,baseline_status,ablated_status,essential,bypass_detected,findings,solution_trace_if_any,metrics,issues}；metrics 包含 baseline/ablated SearchMetrics。optional 消融仍是实际请求，不能省掉预算耗尽；UNUSED_MECHANISM 是警告。正式 MechanicTag 与 PuzzleActionKind 不是同一数值语义。

Replayer 内置 Validator 预算固定 4096/100000（trace_replayer.gd:79），不接受 validation_options；默认 replay options 为 mode=0,max_steps=10000,max_runtime_ms=0,step_timeout_ms=5000，完整验收须显式 mode=1。Session.load_level 本身只验 shape/初态安全，不替代完整 Validator/Codec；因此必须由成功 Bake 产物和正式 Replayer 路径进入。Replayer 返回首个差异，不公开全部实际逐步 PuzzleState；工具不能伪造“实测步骤列表”。

## 3. 拟定作者字段与旧 profile 映射（Owner 4A）

以下是可审阅的字段落点，不是已有 Resource 类。全部作者声明有独立版本、持久 authoring_id 和明确文档归属；显示名仅取 Node/Resource 标签，不进入规则身份。未知领域字段/版本、缺字段、重复 ID、无法解析引用、非法层级显式失败；引擎固有属性不算未知领域字段。

| 源声明 / 唯一写入位置（拟定） | 正式输入映射 | 只读、派生及拒绝条件 |
|---|---|---|
| Level root：authoring_version、authoring_id、level_id；schema/contract/orientation/rule 的显式 profile 元信息；cell_size、shift_compatibilities、flag_definitions、build_info；Surface/Inner/Intent 关联 | foundation_authoring 的关卡字段和 worlds/celestial 等组装 | 本次不改变正式版本；未知版本拒绝；build_info 不藏 Intent 或规则 |
| World root：layer、pivot2、initial_orientation、allowed_states、allowed_rotation_deltas、allowed_rotation_intents | worlds[] 恰两个正式记录 | layer 与装配角色一致；Node transform 必须 identity；pivot2 是整数配置，不从容器变换猜 |
| Cube：cube_id、occludes_light、tags、原始 local transform、六面配置 | foundation_cube + foundation_faces；layer 取唯一 World；group_id 取下述成员关系 | Reader 生成 center2/orientation/faces；不直接写派生 anchor；cube ID 整关唯一 |
| Face：face、walkable、shift_exit_blocked、shift_entry_blocked | Reader 六面配置；face 为0..5各一次 | 机制关联从 Mechanism 的 host_face 引用生成，只读反向列表；这一单一写入选择待审 G3 |
| RotatableGroup：group_id、cube_ids、pivot2、initial_orientation、allowed_states、allowed_rotation_deltas、edges | groups[]；成员列表生成 Cube.group_id | 成员唯一、同层、无嵌套；不能同时编辑两份独立归属，G3 |
| Slot：slot_id、原始位置；Level Celestial：slot_order、wrap、initial_slot_id、edges | Slots 节点与 template.celestial（slots=[]） | Reader 将 Slot 位置量化为 position2；两个世界共享一份 Celestial |
| Spawn：CubeID+FaceDirection、player orientation；Exit：CubeID+FaceDirection、required_flags | spawn.location 的 layer 解析 Cube；goal.face_id 由 Geometry.face_id | Marker transform 只作显示，不与面引用并列成为空间真相 |
| FaceTransition：transition_id、source/target 面引用、entry_axis、exit_axis、rotation_steps、required_flags | face_transitions[] 的正式同名字段及生成的 Face ID | 保留有序 rotation_steps；不扩展任意跨方块传送规则 |
| Mechanism 实例：mechanism_id、host_face 引用、trigger、priority、config 引用、target_bindings | mechanisms[] identity/face_id/trigger/priority/action；反向 face.mechanism_ids | 所在世界由 host Cube 解析；视觉摆放不改绑定；自有 action.mechanism_id=实例ID；原目标引用不因复制改变 |
| Mechanism Resource：kind、initial_state、allowed_states；按 kind 的可复用参数 rotation_delta 或 celestial_op | action.kind/参数、机制单状态字段 | kind 限既有三种；group_id/transition_id/target_slot_id/alternate_slot_id 放实例 target_bindings；未知/多余参数拒绝；G3 |
| Intent Resource：authoring_version、authoring_id、intent_id、required_mechanics、optional_mechanics、expected_milestones、forbidden_bypasses | §4 唯一绑定 | 不编辑 level_hash/rule_version；不存地图副本 |

适配器创建 plain Node3D 临时 root、Cubes、Slots，显式声明 template 的全部18字段；cubes/faces/slots 空集合交 Reader 填充。不实例化作者执行脚本，不复制原 Node 脚本或任意 metadata。释放责任归4A：成功/失败都释放该次临时树；不入活动 SceneTree。物化声明按 §5.2 保留 Transform3D 分量的精确位值，不提前量化。

上表新单一写入选择只映射正式正反索引，不更改正式 Level schema；缺少用户 review 时停止其字段冻结。旧平铺 fixture 继续原 Reader 入口，不迁移或覆盖。

### 3.1 复制与 Resource 专用化拟稿

复制单对象是一个撤销事务，结果记录新旧作者身份、新正式身份、保留目标引用列表和源文档。自有机制 action.mechanism_id 随新实例身份组装；group/face/slot/transition 的外部目标仍保留，不能用邻近对象重绑定。若保留引用造成不合法，显式报错而非修复。

删除操作先由4A解析本关已知引用影响，4B显示清单且默认取消；用户明确确认后，只删除所属源文档中的对象，保留其他声明的悬空引用供诊断，不静默解绑。撤销恢复被删对象的原authoring_id、正式ID与关联数据；跨文件引用未被删除，因此恢复后重新解析。无法确定影响范围时明确显示未解析依赖，不冒称“无引用”。

“专用副本”拟递归复制可变语义 Resource、其嵌套集合及可变子资源，以访问表保留副本内部的同一资源别名；不保留指向原可变语义资源的引用。只读表现资产可共享，但必须在预览清单列出。不以 `Resource.duplicate(true)` 作为复制完整性保证；候选实现由4A按下列封闭字段表显式复制。撤销恢复原引用，重做复用同一副本身份；保存文件是单独明确操作。

### 3.2 G3 本次具体建议：六面、资源白名单与撤销

Cube 持有恰六个内嵌 `FaceAuthoringResource`，按 face=0..5 定位，字段为 authoring_id、face、walkable、shift_exit_blocked、shift_entry_blocked；不增加永久 Face Node，不允许不同 Cube 共享可变 Face Resource。默认值只用于“创建新 Cube”操作，加载时缺面/多面/重复面失败，不替作者补齐。机关反向列表只由 host_face 生成，Cube.group_id 只由 RotatableGroup.cube_ids 生成。

可变语义 Resource 白名单为上述 Face、MechanismConfig、PuzzleIntentAuthoring、MilestoneAuthoring、BypassAuthoring。字段分别以 §3/§4 为准；Milestone 的 predicate 和 Bypass.disabled_mechanics 是封闭值集合，不是任意脚本 Resource。其它组、Slot、Spawn/Exit、引用与边均是所属作者节点的封闭值字段。任何额外 Resource 类型在语义字段中出现均 `UNSUPPORTED_RESOURCE_TYPE`，不能仅因继承 Resource 就递归接受。

专用化遍历此白名单，复制全部可变字段、嵌套 Array/Dictionary、外部及内嵌语义子资源；访问表保留副本内部别名，检测并拒绝语义循环，分配新的工具 authoring_id。正式外部目标 ID 不变。纯展示资产不在语义 profile 中，继续共享且列于摘要；不复制 Script、Node、Callable。预检全部成功才进入一次 UndoRedo 事务，失败不留下部分副本。新副本先内嵌保存于所属文档，另存外部 `.tres` 是独立显式操作。

4B 使用所属场景根作为 `EditorUndoRedoManager.create_action(..., custom_context, ..., mark_unsaved=true)` 的上下文；提交包含对象/引用和ID表，撤销/重做不得重新分配 ID。当前首版不承诺跨场景原子撤销。官方文档明确深复制的资源范围及例外，故此处选择字段白名单复制；UndoRedo 的自定义上下文用于选择文档历史。[Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html)、[EditorUndoRedoManager](https://docs.godotengine.org/en/stable/classes/class_editorundoredomanager.html)。这些是 API 文档核验，不是本机运行验证。

## 4. Intent 唯一绑定（4A 转换，4C 正式校验）

拟定输入：`{run_id,snapshot_id,authoring_intent,bake_result}`；输出工具包装：`{ok,bound_intent:null|Dictionary,source_intent_digest,issues}`。这是合同描述，当前无同名可调用函数。前提是本轮 bake_result.ok=true、level 非null且真实 validation=VALID；无法证实同轮来源拒绝绑定。

正式输出仅八字段：intent_version="puzzleintent.v1"、intent_id、level_hash=level.content_hash、rule_version=level.rule_version、required_mechanics、optional_mechanics、expected_milestones、forbidden_bypasses。工具 run_id/authoring_id/digest 不混入。绑定只做声明映射；4C 调 IntentValidation.validate 后方可作为有效 sidecar 发布。失败候选可作诊断，但标无效。

Milestone 保留 `{milestone_id,required,predicate}`；正式 PredicateKind=AT_FACE/IN_LAYER/FACE_LIGHT/MECHANIC_USED/GOAL。AT_FACE 的作者 face_ref 转为唯一 face_id；其它分别只含 layer/light_state/mechanic 或无额外 payload。FACE_LIGHT 指样本玩家所在面，不擅自增加任意 target face。Bypass={bypass_id,disabled_mechanics}。标签集合拒绝重复/非法后可规范升序，不改变里程碑顺序，不自动补约束。

显式空判断必须在有效作者 profile 上执行且四声明集合全空；missing/invalid 不进入空判断。空仍生成并正式校验绑定 Intent。报告保留原作者身份、有效 sidecar 摘要、每个约束适用性和固定限定文案。缺失 Intent 的阶段是 NOT_RUN/MISSING_INPUT，整体不可完整通过。

## 5. G1/G2 集中修订：输入、受控工程与唯一交换层

方向已获批准；本节具体协议推荐整体采纳，当前仍 HELD_FOR_REVIEW。4A负责声明投影，4D负责捕获事务、封包、交换、执行身份与工程装载。

| InputSnapshot 字段 | 候选类型与语义 |
|---|---|
| snapshot_version / snapshot_id | authoringsnapshot.v1 / 不透明单次身份；不是 level_hash |
| level_ref | {level_authoring_id,level_id,root_source_uri} |
| input_mode / captured_at / capture_generation | ANALYZE_CURRENT 或 ACCEPT_SAVED；时间和代次为执行元数据 |
| dependencies | 按 source_uri 排序；条目 {source_uri,resource_uid或null,kind,origin,content_digest,snapshot_ref,declared_version,authoring_ids} |
| authoring_payload_ref | 4A封闭声明值、原始变换、显式目标和 resource_table；没有 Node/Callable/对象地址 |
| source_fingerprint | 下述 source-manifest 的规范 wire 字节 SHA-256，不以 mtime 替代 |
| execution_policy / policy_digest | 阶段、实际正式策略/预算、图形选项、任务期限；策略的独立规范摘要 |
| versions / execution_digest | 工具/合同版本、engine version信息和可执行文件SHA-256、模块/配置闭包清单及其摘要；HEAD仅作来源说明 |
| integrity | 附件 relative_path / byte_length / sha256 清单；input.ready 为最后发布的封包标记 |

### 5.1 G1 捕获与装载协议

1. **先确定文档归属。** Level 显式关联恰两个独立 World 文档和一个 Intent。建议首版玩法编辑只落在独立 World 源文档：Level 中的 World 是单位变换实例，不允许通过 Editable Children、继承场景或实例覆盖改变玩法属性。纯显示显隐/选中状态不进入声明；同一 World 多实例、玩法覆盖或无法判定覆盖来源返回 `UNSUPPORTED_AUTHORING_OVERRIDE`。这是本次新增待审限制，不是历史批准事实；未保存分析仍保留。
2. **选择当前数据。** 4B 提供 `EditorInterface.get_open_scene_roots()` 的引用集合，4D 主线程捕获期间调用4A只读投影；相关独立 World 已打开时，唯一使用该源文档缓冲，不用 Level 实例中的旧内容覆盖它。没打开的文档读取本次已冻结文件字节对应的 PackedScene/SceneState；不实例化其作者脚本。作者类只能来自版本清单中4A白名单，缺省声明值来自版本化profile，不靠运行未知脚本补值。新建未保存文档用 `editor://<editor_instance_id>/<document_id>` 加显式关联，可分析；ACCEPT_SAVED 必须先获得持久源路径。
3. **共享资源消歧。** 从所有相关打开文档的声明引用遍历白名单资源，按外部资源路径或内嵌所属文档＋authoring_id建立 resource_table；无路径对象按稳定authoring_id登记。一个资源身份出现多个内容版本返回 `RESOURCE_VERSION_CONFLICT`，不选最近使用版本。外部共享资源的未保存值纳入 EDITOR_BUFFER，重复引用指向同一表项。闭包外对象、未声明资源和缺失引用停止捕获。
4. **保存入口。** ACCEPT_SAVED 先列出相关文档/资源，作者明确保存后重新检查。首版建议采用保存清单＋重新检查，不实现伪造的“相关文件一键全存”。`save_scene()` 只针对当前场景，不调用 `save_all_scenes()` 以免保存无关场景；独立 Resource 须明确保存。对相关打开对象做当前投影与新读磁盘投影比较，任一不一致/未保存/未能证明一致均 `SAVE_REQUIRED`，不启动。相同内容但保存状态不可确认时同样保守停止。
5. **一致捕获。** 4D 获取单槽、限制4B编辑入口，主线程同步拷贝值期间不 await；记录关卡/文档集合、编辑代次、资源引用与所有磁盘字节摘要。封包期间可继续写独立副本，但最终在主线程重新投影并核对上述信息和磁盘摘要；任何变化为 `CAPTURE_CHANGED`，丢弃未封口包、释放锁，不自动重试或回退旧磁盘。文件外部变更无法被编辑器锁阻止，所以两次比对不可省。成功以最终核对时刻为捕获边界，之后的变更只令报告过期。
6. **封包与隔离工程。** 4D 在 E 盘该 run 目录创建 `input/` 和 `execution/project/`。input 保留原磁盘源字节（仅溯源）以及当前声明 wire；未保存数据的执行真相是声明包，不把旧 `.tscn` 冒充当前输入。execution 仅物化版本清单中的正式 FOUNDATION 模块、必要受控4A/4C/4D宿主、白盒表现资源和最小 `project.godot`，保持它们的 `res://` 相对路径。关闭主项目 autoload/editor plugins，不复制整项目、美术目录或P-01展示场景。项目设置、导入缓存和本任务可配置 TEMP/TMP/用户数据均绑定 E 盘，不改全局环境。
7. **依赖/UID 与启动。** 清单覆盖脚本的静态依赖及显式列出的动态依赖；缺项为 `DEPENDENCY_PENDING`，禁止回活动项目找补。优先沿现有 `res://` 引用；确有 uid 引用则连同对应资源及 `.uid` 来源建立本工程映射，UID无法唯一对应manifest路径即 `EXECUTION_DEPENDENCY_INVALID`。作者声明中的UID仅作定位，不用于加载玩法或实例化任意源场景。worker 启动后先比对自身engine/version、模块和配置摘要，再读 input.ready；不匹配为 `EXECUTION_VERSION_MISMATCH`。导入和验证只在独立工程内进行，未完整核验不得进入正式链。

输入链只有一条：声明包 → 4A临时plain Node3D旧profile → 正式Reader/Baker → 正式Codec canonical → Records.initial_state → 4C原图及质量。Solver返回的原图直接交同进程Softlock。图形宿主随后从同一input身份、同一execution工程读取canonical和trace，正式解码/校验后创建现有Replayer Node并 `await replay(...,mode=GRAPHICAL)`。所有失败均保留来源与阶段；无成功Bake不得用历史canonical继续。

API依据：EditorInterface公开已打开场景根和保存方法；SceneState可只读查看场景导出/覆盖数据而无需实例化。[EditorInterface](https://docs.godotengine.org/en/stable/classes/class_editorinterface.html)、[SceneState](https://docs.godotengine.org/en/stable/classes/class_scenestate.html)。本机 `project.godot` 声明4.7特性，不能据此推定实际引擎版本或全部API可用；实施前能力检查与保存/覆盖检测用例必须真实运行，缺能力停为 `DEPENDENCY_PENDING`，不降低捕获保证。

### 5.2 G2 字节与类型合同：foundationtoolwire.v1（4D唯一实现）

Level产物始终使用正式 LevelCodec 的文本与content_hash。其它交换载荷采用**封闭、带类型的数组树**，外层为 `["foundationtoolwire.v1","<record_kind>",<tagged_value>]`。不接受JSON对象、JSON数字token或任意Object反序列化，不调用 `JSON.to_native(...,true)`、`str_to_var` 或 eval。允许的record_kind限 authoring、snapshot、source_map、intent、trace、state_inspection、graph_archive、quality_result、stage_result、report、worker_message、manifest、policy。graph_archive保留正式返回图的历史数据，仅由只读查看入口消费；不提供还原可信活图或交给Softlock的接口。

| 内存类型 | 唯一候选 wire 表达 |
|---|---|
| null / bool | `["null"]` / `["bool",true或false]` |
| String / StringName | `["string","值"]` / `["name","值"]`；二者不互换 |
| int / enum | `["int","十进制"]`，域为有符号64位，格式 `0` 或 `-?[1-9][0-9]*`；枚举再按所属正式schema校验，不按名字猜值 |
| float | `["f64","16位小写十六进制"]`，按IEEE754 binary64高字节在前；拒绝NaN/Inf，保留负零 |
| Vector3i | `["v3i","x","y","z"]`，各分量同十进制规范且须满足Vector3i分量范围 |
| Vector3 | `["v3",f64x,f64y,f64z]`，分量均为上述完整f64标签值 |
| Basis / Transform3D | `["basis",v3x,v3y,v3z]`（列向量） / `["transform3d",basis,v3origin]`，不量化，不重建欧拉角 |
| Array | `["array",[tagged_value,...]]`，保序；元素精确类型由所属schema恢复 |
| Dictionary | `["dict",[[tagged_key,tagged_value],...]]`；键限String/StringName/int且受记录schema约束 |

字典条目按键的canonical编码UTF-8字节升序；拒绝未排序、重复编码以及恢复后相等的键（包括同字面String/StringName碰撞），不覆盖先值。资源表是作者schema中的普通值记录和显式ref，不增加Resource标签；不允许值树循环。正式封闭记录的字段集合以§2对应合同为准，4A只维护authoring/source_map的字段schema，4D统一执行编码；不能各Owner写自己的JSON转换。类型标签不授权任意字段，未知字段/版本/标签/长度均拒绝。

canonical字节是UTF-8，无BOM、无空白、无末尾换行。字符串只将双引号和反斜线转义为 `\"`、`\\`，U+0000..001F统一小写 `\u00xx`；其余有效Unicode标量原样UTF-8，不做Unicode正规化，不转义斜线。拒绝非法UTF-8/孤立代理项。解析后按此规则重编码，逐字节相同才接受，因此宽松JSON解析器接受的尾逗号/替代转义不能通过。整数先检查词法和范围再转换；浮点按位恢复，并检查当前引擎分量精度能无损往返，否则 `WIRE_PRECISION_UNSUPPORTED`。所有新wire文件摘要为SHA-256小写hex；不改变正式Level哈希/StateKey。

source-manifest={authoring_payload_digest,dependencies,source_locations}；dependencies的执行内容digest覆盖选定声明，另记录冻结磁盘字节digest；source_locations覆盖文档URI、authoring_id、捕获时节点路径/标签。source_fingerprint=该manifest的wire摘要，排除run_id、时间、编辑代次、窗口/相机状态和机器缓存绝对路径。policy_digest及execution_digest独立绑定RunIdentity。uri统一项目内 `res://` 加 `/`，资源外部位置需显式登记，拒绝路径穿越及大小写歧义；包附件路径必须是包根内相对路径，不接受symlink/junction逃逸。内存对象地址不参与任何持久摘要。

source-manifest内的dependencies是InputSnapshot.dependencies的稳定投影，仅含source_uri、resource_uid、kind、origin、content_digest、disk_digest或null、declared_version、排序后的authoring_ids，不包含snapshot_ref；附件以摘要命名的包内相对路径定位。由此相同来源/内容不会因run目录或snapshot_id改变而得到不同源摘要。编辑代次单独决定“撤销后也须重新验收”的保守当前性，不能拿相同摘要跳过这一政策。

读取顺序：已知文件大小/资源限额 → 完成标记 → 清单及附件字节摘要 → UTF-8与canonical语法 → 标签/域/封闭schema → 实际正式校验。Intent调用IntentValidation；trace调用结构及语义验证并绑定本关Spawn；state_inspection绑定canonical与完整StateKey并通过state shape；Level只由LevelCodec.decode。任何失败停止当前输入，不发布有效产物。收到同一trace的hash不等于真实回放MATCH。

数值与语法选择源于Godot JSON会把数值按浮点处理且解析并非严格JSON；不能直接stringify正式Dictionary就认定精确往返。[JSON](https://docs.godotengine.org/en/stable/classes/class_json.html)。上述新wire仅是待批准合同，本轮没有codec实现或往返测试。

## 6. G5 集中修订：任务、取消、IPC与预算

RunIdentity={editor_instance_id,run_id,generation,level_ref,snapshot_id,source_fingerprint,policy_digest,execution_digest,versions}。run_id为新UUID，generation在本编辑器实例内单调；跨重启生成新editor_instance_id。4D服务持有唯一重任务槽，4B只是调用方；启动时忙则 `BUSY`，不入队。

建议生命周期：CAPTURING → RUNNING → FINALIZING → COMPLETED；取消时进入 CANCELLING，确认释放后才 CANCELLED；异常经清理后 FAILED。COMPLETED不是PASS。headless和graphical宿主顺序执行并共享同一槽，不能在headless还持有活图作业时并行启动另一个重任务。

**首版选择合作式取消，不新增旧Solver/Replayer取消API，也不承诺强杀时限。** 4D写入绑定完整run身份的cancel闩锁，立即撤销PASS资格和后续阶段调度；worker在每个正式调用前后检查它。同步求解/质量调用及整段Replayer正在执行时允许返回，UI保持“正在取消，等待当前检查释放”。只保留已经完整写出的正式结果；中断/崩溃无返回时native_result=null。首版不以PID数字执行kill，不按进程名关闭其它Godot，更不碰美术进程。

IPC选择该run目录内的封闭wire文件：每方向一写者、单调sequence的不可覆盖消息文件，先写同目录临时文件、close并核验后rename；接收方忽略临时文件。WorkerMessage={protocol_version,identity,sequence,kind,stage_id,payload_ref_or_inline}，kind限 HELLO/STAGE_STARTED/STAGE_RESULT/HEARTBEAT/EXIT/ERROR；父侧指令限 CANCEL/LEASE。消费者核对完整身份、次序、schema和摘要；过期、重复或跳号先报协议问题，不覆盖当前结果。消息不是远程函数调用。STAGE_RESULT先附件后消息，EXIT是清理声明，仍须父进程观察该次启动的子进程退出。

4D用 `OS.create_process` 启动当前已绑定引擎，保留创建返回的子PID与run握手身份，仅作存活观察。资源释放条件是子进程确认退出、文件关闭、回调解除、4D预览节点释放全部成立；不知道是否退出即保留槽和清理中状态，不假装成功。4B卸载先取消并注销UI回调，4D清理服务挂于编辑器根、独立于插件控件直到释放；重新启用插件接回同一服务，不能再开第二槽。编辑器退出时子进程可能仍存在，宿主检查父租约：候选每1秒续租、30秒未更新即在下一可检查边界退出且不得发布PASS。租约只是停链保障，不能中断正在进行的同步调用；若调用永久不返回，自动清理不能宣称完成。这是明确接受的首版限制。

官方 `OS.create_process` 创建独立进程，父进程退出不会自动带走它；`is_process_running`用于所创建子进程的观察。因此不能把插件卸载或取消按钮当作退出确认。[OS](https://docs.godotengine.org/en/stable/classes/class_os.html)。实施时须实测卸载、重启、崩溃和租约失效；本轮未启动任何Godot进程。

预算必须在启动前展示、冻结并记录。候选默认：Baker及SearchPolicy.validation_options为4096/100000；SearchBudget为max_states=10000、max_edges=100000、max_depth=-1、max_runtime_ms=30000、max_action_evaluations=200000；Softlock为max_nodes=10000、max_edges=100000、max_runtime_ms=30000；Replayer为GRAPHICAL、max_steps=10000、max_runtime_ms=60000、step_timeout_ms=5000，其内部静态预算仍固定4096/100000。Ablation沿正式内部baseline/子搜索使用明确传入的同一搜索预算，分别保留实测结果，不能把每次预算冒称整个阶段预算。

候选工具阶段期限为300000ms，wire单附件上限128MiB、值树深度64；超限明确拒绝，未来调整必须进入policy_digest。期限由父4D观察，超时封锁发布并请求停链，等待正式调用返回后才释放；这是调度期限而非硬终止承诺。超时记录工具 `TIMEOUT`、completion=ERROR，正式native_result如已返回仍保留；不能改写成Solver BUDGET_EXCEEDED。用户先取消则保留cancelled原因；真实错误优先序依§7。UI只显示真实阶段/已知计数，不伪造内部百分比。

## 7. 拟定质量编排结果与通过汇总

4C 返回 QualityRunResult={run_identity,selected_trace_ref,stages,issues}，只包含实际正式返回与证据；4D 唯一汇总器判断验收门槛，4B不能重新判 PASS。具体函数名尚无代码。

执行范围：原图从正式 Spawn 使用 UNFILTERED/FULL_GRAPH；FIRST_SHORTEST 仅可用于显式局部分析或正式消融内部策略，不能替代完整原图。保留原图 solution_trace，即使预算耗尽有 trace 也不改 Solver 状态；这种见证经语义校验可浏览，但没有完整验收资格。所选 trace 初态须与 Records.initial_state / StateKey 匹配；Trace.validate_semantics 本身不强制 Spawn，工具不能漏掉此输入绑定。

原图与 Softlock 在同一 worker 直接传真实图；不重建“等价图”。Ablation 调正式 analyze，允许其内置独立 baseline/消融搜索，分别记录预算。所选原图 trace 另调用正式 Milestones.analyze_trace，防止内部 baseline 见证混用。不能为了让里程碑通过改选/改写作者意图；选择策略纳入报告。

内存StageRecord.native_result保留实际正式返回。落盘时其中graph单独写为graph_archive附件，存储记录以明确的附件引用替换该大字段，其余字段及原图内容不变；这是4D存储表达，不伪装为正式SolverResult入参。读档器只暴露归档图元数据与经state shape/StateKey复核的只读状态，不把此存储记录送入4C；即使complete=true也不重新签发Softlock证据。4C的Softlock调用只能持有本次explore直接返回的内存图。

### 7.1 StageRecord（拟定）

| 字段 | 定义 |
|---|---|
| stage_id、owner、module_ref | 工具阶段唯一名及真实模块来源/版本 |
| applicability | APPLICABLE / NOT_APPLICABLE；后者必须有实际无声明理由 |
| execution | NOT_RUN / RUNNING / COMPLETED / INCOMPLETE / ERROR / CANCELLED |
| reason | 稳定工具原因名和可读说明；缺依赖、取消、超时等不篡改上游码 |
| input_refs、actual_policy、actual_budget | 精确输入摘要；各正式调用实际预算，含 Replayer 固定静态预算 |
| native_result | 原样正式记录或null；未运行没有伪造 status |
| evidence_refs、warnings、started_at、finished_at | 实际证据/警告与执行时间 |

工具执行 COMPLETED 只表示已返回、检查执行完毕，native_result 可能是确定失败。正式 ERROR/INCOMPLETE 必须在工具阶段和顶层缺证据列表呈现；不适用不覆盖已运行的正式返回。Intent 作者校验、绑定、正式校验是分开的必需阶段；空约束仅影响消融/里程碑相应子项适用性。若实际调用了空 Intent 的 analyze 并返回 TRACE_MATCH，也保留其真实值和空范围，不能编造非空教学证明。

### 7.2 LevelAcceptanceReport（拟定，Owner 4D）

顶层字段：report_version、run_identity、entry_kind、inputs、versions、stages、evidence、summary、publication。inputs 保存 source_fingerprint、依赖清单、level_hash|null、作者 Intent 身份、绑定 Intent 摘要|null、selected_trace_digest|null、执行策略与预算。不存在的新产物填null，严禁填上一轮内容。evidence 每项={role,relative_path|null,digest,format_version,inline|null}；路径须在本包内，摘要核验后消费。

summary 分别保存 verdict=PASS/FAIL/UNDETERMINED、completion=COMPLETE/INCOMPLETE/ERROR/CANCELLED、hard_findings、missing_required_evidence、warnings、scope_notes、intent_empty。ANALYZE_CURRENT 只报告阶段证据，顶层验收 verdict 固定 UNDETERMINED，注明 NOT_AN_ACCEPTANCE_RUN；不能把局部全绿签发成整关 PASS。

确定反例存在且证据身份有效时 verdict=FAIL，即使其它阶段未完成；无反例但缺证据时 UNDETERMINED。只有完整验收全部适用门槛满足才 PASS。completion 错误优先次序沿工作笔记：ERROR > CANCELLED > INCOMPLETE > COMPLETE。取消后绝不 PASS。损坏/身份不匹配的记录不作为确定反例或通过证据，只报执行/读档错误。

安全未知处理：保留正式 Validator INCOMPLETE、issue 1601、各 SolverResult.metrics.safety_unproven_rejections；对原图及适用消融 baseline/子搜索的未知证据，完整验收禁止 PASS，不把 fail-safe 图中的正式 SOLVED/PROVEN_UNSOLVABLE 重写。正式模块的正负结论仍按原语义展示，同时追加“完整技术验收缺少安全证明”。Runtime Safety/回放错误同理。普通 UNUSED_MECHANISM/optional 警告不可临时升级或降级来追求通过。

currentness 是消费者对当前工作区计算的 CURRENT/STALE/UNKNOWN，另有 archive_integrity=VERIFIED/INVALID/UNVERIFIED；不是不可变报告永久字段。只有已核验、已完整发布、PASS+COMPLETE+CURRENT 的完整验收报告显示当前通过。源/Intent/策略变化立即 STALE，不能只看 level_hash。撤销到旧内容也要求显式重新验收；面板展开、选择、相机不触发规则失效。

显式空时 summary.scope_notes 和 UI/导出摘要同时保留“验收通过 · 未声明设计约束”及未证明事项；如果 STALE 则显示“历史快照：验收通过 · 未声明设计约束；当前已过期”，不维持当前绿灯。

## 8. 拟定来源映射、预览数据与 UI 边界

SourceMap（4A）={map_version,snapshot_id,source_fingerprint,level_hash|null,entries}。Entry={authoring_id,document_uri,node_path_at_capture|null,resource_uid|null,resource_subpath|null,local_face|null,entity_kind,entity_id|null,field,reader_path|null,canonical_path|null}。一条问题可关联多项；正式 ID 包括类型，避免不同类别同字面 ID 冲突。canonical_path 仅在正式排序/成功产物后填写，早期读取失败不能伪造。

ValidationIssue 六字段含 entity_ids；AnalysisIssue 六字段含 upstream、没有顶层 entity_ids；QualityFinding 包含 subject_ids/scope/trace/details。必须按实际类型分别解析；先正式实体/subject，再准确阶段路径和 upstream，不能假定所有错误都有同一字段。Reader 早期错误 path 可为 Cubes/节点名且 entity_ids=[]，用临时 profile→作者记录映射；映射不足显示整关问题。

点击当前对象前复核 snapshot/currentness 与 authoring_id；改名/重排仍能靠身份定位，但旧路径不得直接解释新数组。已过期报告可浏览其历史状态，不将其高亮宣称为当前有效结论。源对象不存在或多个匹配则返回未定位，不选最近对象。

StateInspectionRequest（4D拟定）={run_identity,level_ref,state_ref,state_key,origin,trace_step|null}，origin=SOFTLOCK_STATE/TRACE_EXPECTED；输出正式 Geometry.snapshot 的值/问题和来源，不输出可写 RuntimeSession。Graph state 与完整 StateKey 配对；Trace 显示前先验整条语义，初态0和步骤1..N可自由选取。4D 管独立显示节点生命周期，4B 管UI容器、选中面与文字；无第二份预览模型或任务管理器。

真实 ReplayRequest 只含同轮 canonical/trace/正式 options 与身份，通过4D重任务槽调用现有 Replayer；不能从浏览步骤N启动任意恢复。Presenter 的自然 Tween 和 Session 的 finish_local/global 由现有 Replayer管理，工具不按 global_kind自行选择提交路径。G4明确建议：4D唯一只读视图直接消费Geometry.snapshot/正式Math产生的构型，按正式cell_size与坐标换算在Shared Space绘制白盒，不施加原Presenter的左右偏移，不复制WGC/face frame/光照算法。显示失败原样返回issues并清除本次不完整图层，不画旧状态冒充成功。4B只提供视口宿主、相机、选面与文字。

真实GRAPHICAL验收保持原Replayer/Presenter及其±2.4显示布局，在UI标为“正式运行回放（分层展示）”；该布局不改变逻辑位置，不声称等同Shared Space叠加。最小白盒手动运行宿主同属4D：只加载本次正式Codec产物，输入转换为正式PuzzleAction交RuntimeSession，播放/提交沿既有Presenter与Session约定；Reset调用正式Session.reset。不绑定具体地图，不复制美术演示脚本。此运行宿主不是第二个状态预览服务，也不替代正式整段Replayer验收。采用此建议无需扩展2D Presenter API。

## 9. G6 精确归档路径与发布失败合同（待批准）

Git政策已批准；本次建议冻结缓存为**执行源项目根**的 `.godot/foundation-authoring/runs/<run_id>/`，项目根必须在E盘，run_id只允许UUID安全路径片段。不能误用嵌套worker工程自己的 `.godot` 作为报告根。后续实施计划负责加入精确忽略规则，正式fixture/作者场景正常入Git，本轮不改ignore。

候选默认永久导出根 `E:/godot/foundation-authoring-deliveries/<level_id>/<run_id>/`，导出时明确显示/选择目标，未授权不得覆盖既有目录；支持用户明确指定的其它E盘目录。`.godot`只是缓存，不自动当永久交付，也不自动删除历史run。换到非E盘项目时要求明确配置E盘运行根，不能悄悄写C盘。

每轮目录：`input/` 不可变声明/源字节；`execution/project/` 受控运行工程；`ipc/` 身份消息；`staging/` 未封口附件；`artifacts/` 阶段结果、canonical、Intent、trace、source_map和最终report；根 `manifest.wire` 是最后发布的完成标记。协议必须避免循环摘要：report引用证据摘要、publication=PUBLISHED及自身位置，但不包含自己的hash或manifest hash；manifest枚举所有正式附件（包括report）的长度与摘要。缓存内输入/工程内容另由input.ready绑定，临时IPC不算永久证据。

写入流程：新文件写入 → close → 重读长度/摘要 → 同目录rename到此前不存在的最终文件名 → 完整检查 → 最后发布manifest。消费者只有看到可验证manifest才接受“已发布”；半写文件、没有manifest的孤立report和正在写的stage都不成为完整PASS。这里保证逻辑可见性，不声称跨文件事务或断电持久性；任一读档都重新验证。跨卷导出在目标卷临时目录完成复制/校验，再发布目标完成标记，失败不得冒充成功包或覆盖源。

publication={state:NOT_STARTED|WRITING|PUBLISHED|FAILED,location|null,issues}。首次发布失败：保留各技术阶段native_result、`technical_gates_satisfied`诊断；顶层completion=ERROR，verdict=UNDETERMINED（已有可信硬反例则FAIL），publication=FAILED，绝不签发完整PASS。不能写盘时只展示内存失败及可确认的部分证据位置，不宣称失败报告已归档。失败或取消运行仍可按同一完整性协议发布真实的FAIL/UNDETERMINED报告；“发布完成”与“验收通过”分开。

已经发布的历史报告不可变：之后的导出失败返回独立ExportResult失败，原报告保持原值；读档失败返回read_error、archive_integrity=INVALID/UNVERIFIED，不能当作当前通过。stale只改变消费者当前性标记，不覆写历史报告。跨进程或历史包中的图条目一律只供只读展示，绝不恢复成可信完整图。

## 10. 集中待批准差异与停止线

| ID / Owner | 本次推荐的具体决定 | 相对此前记录的差异 / 失败边界 |
|---|---|---|
| G1 / 4A＋4D，4B提供编辑上下文 | §5.1独立World源优先；禁止玩法实例覆盖；当前值投影＋前后比对；保存清单；最小版本绑定工程 | 方向已批准，以上捕获/装载细则待批；冲突、变化、缺依赖均不回退磁盘 |
| G2 / 4D唯一wire；4A作者schema | §5.2封闭tagged array、十进制整数、浮点位值、规范UTF-8和SHA-256；正式LevelCodec保持独占 | 方向/活图同进程已批准；具体字节、类型、摘要与图形装载合同待批；损坏/未知类型停止 |
| G3 / 4A，4B事务UI | §3六个内嵌Face Resource、组成员/host_face单写；语义白名单复制、内部别名保留、外部目标不变 | 此前只是推荐，仍须批准字段/复制边界；不支持类型或循环不部分复制 |
| G4 / 4D服务，4B装配 | §8正式Geometry/Math只读Shared Space；原Presenter用于真实分层回放；4D通用白盒运行宿主 | 不改旧Presenter，不要求美术；只读浏览不标实测，不向Session注入状态 |
| G5 / 4D | §6文件IPC、单槽、合作取消/租约、资源退出确认、候选预算及限额；保留Replayer固定静态预算 | 新增明确“等待同步调用返回，不能保证强杀时限”的首版限制；超时不篡改模块状态 |
| G6 / 4D | §9 E盘项目缓存与默认永久目录；最后manifest发布；首次发布失败ERROR/UNDETERMINED，导出失败独立 | 精确路径和失败汇总此前未批准；不改变已批准Git策略、不覆盖历史 |

当前分类：`CONTRACT_REVIEW_READY`；`IMPLEMENTATION: NOT_STARTED`；`contract_freeze: HELD_FOR_REVIEW`。`CONTRACT_APPROVAL: PENDING`表示本稿尚待签字；`DEPENDENCY_PENDING`仅表示实际实现/运行所需模块、能力或已提交依赖未就绪；`CONTRACT_MISMATCH`只用于实际实现违背已冻结预期的证据。本轮未发现必须改既有生产API的冲突，不再用“工具方案待审”冒充CONTRACT_MISMATCH，也不宣称已通过接口运行验收。

批准本次Spec只进入状态B：形成四份Owner实施计划和一份集成计划并再次停审；只有计划批准、执行方式明确、共同基线已提交后才进入状态C。新API不因出现在文档中而存在，所有接口如下节所列均 NOT IMPLEMENTED。

## 11. 候选工具接口清单（review对象，不是现有API）

本表定义模块边界，精确文件与测试命令留给获批后的实施计划。普通结果统一 `{ok,value|null,issues}`；issues是工具诊断，内嵌上游issue不改码。所有输入record须通过本合同的封闭schema；不接受任意Dictionary穿透。服务返回的失败原因与§5–9一致。

| Owner / 接口候选 | 输入 → 输出 / 释放与失败责任 |
|---|---|
| 4A `project_document(source, document_context)` | 受支持编辑根或冻结SceneState＋文档身份 → AuthoringDocument值投影及资源引用表；调用限捕获主线程，返回无对象引用；无法判定覆盖则失败 |
| 4A `validate_authoring(payload)` | 已解析闭包 → 作者字段/身份/引用问题；不调用第二套空间规则 |
| 4A `bake_authoring(payload, bake_options, snapshot_identity)` | 值声明 → `{ok,level,issues,validation,source_map}`；内部唯一临时旧profile、正式Reader/Baker；所有出口释放临时树；失败level=null |
| 4A `bind_intent(authoring_intent, successful_bake, snapshot_identity)` | 同轮输入 → §4 bound_intent包装；未成功Bake或身份不符拒绝 |
| 4A `prepare_edit(operation, object_ref, context)` | 单对象复制/专用化/删除预检 → 无副作用edit proposal、身份/引用影响与撤销数据；4B才提交事务；失败不改变源 |
| 4D `capture(request, editor_context)` | 入口种类、level_ref、完整policy → sealed SnapshotRef；内部调用4A，不再转换作者字段；任一失败释放捕获锁 |
| 4D `encode_wire(kind, value)` / `decode_wire(kind, bytes)` | 精确值↔规范字节，统一验证schema/类型/版本；无对象反序列化；失败不返回可用半值 |
| 4D `start(request)` / `cancel(identity)` | start返回run_identity或BUSY；cancel幂等设置闩锁并返回当前生命周期，不把请求回执当资源已释放 |
| 4C `run_quality(level, bound_intent, policy, identity, boundary_control)` | 同进程正式输入 → QualityRunResult；boundary_control仅在正式调用前后检查stop，绝不传入旧Solver假options；原图直接进Softlock，不出进程 |
| 4D `inspect_state(request)` / `release_view(view_id)` | 已验证level+state+key → 单一只读视图句柄和诊断；失败清理新节点；不返回可写Session |
| 4D `replay_run(identity, canonical_ref, trace_ref, options)` | 通过唯一重任务服务的整段GRAPHICAL流程 → 正式Replayer结果/实际预算；不能恢复到浏览步骤 |
| 4D `publish(run_evidence)` / `export_archive(verified_manifest, destination)` | 唯一汇总/发布 → report引用或publication失败；导出 → 独立ExportResult；不更改已发布历史结论 |
| 4B插件 | 调上述服务、所属文档UndoRedo、渲染工具诊断和正式结果；不实现wire、worker、顶层verdict或另一状态视图 |

验收义务（后续实际运行，不是本轮结果）：未保存Level/World/共享Intent捕获及冲突、磁盘变化、未知依赖；整数边界/负零/变换精确往返/重复键和损坏附件拒绝；六面及别名深复制和Undo/Redo；预算不足/取消/卸载/迟到消息与退出确认；只读状态隔离；同轮canonical/trace真实GRAPHICAL；发布失败/导出失败/旧报告过期。首项纵向交付另见Design Spec §12，不能以协议测试替代真实作者→Runtime链。
