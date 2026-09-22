# FOUNDATION-4.0 — Authoring / Editor Working Notes

日期：2026-09-16。

阶段：ARCHITECTURE BRAINSTORMING。本文仅记录已批准决策、只读调研事实与待讨论事项，不是正式 Spec、Implementation Plan 或 Contract Freeze。

Core baseline：`bfcc6c004db232ca2f4ea4d409c98bda0dc6d165`。

设计分支：`docs/foundation-4-authoring-design`。

## DECISION-4.0-001 — HYBRID_AUTHORING_APPROVED

Status: APPROVED

Decision: Hybrid Scene + Resource authoring

用户在本轮补充要求中正式选择 C：HYBRID AUTHORING。后续设计以此为基线。

Scene responsibility: spatial authoring

- Cube。
- Face 的空间归属与可视化入口。
- Spawn / Exit。
- Mechanism 的空间实例。
- FaceTransition。
- RotatableGroup。
- Celestial 相关空间对象。

Resource responsibility: semantic/reusable authoring

- PuzzleIntent。
- 可复用机制配置。
- 非空间型配置。
- 后续适合跨关卡复用的数据；具体类型尚未批准。

Canonical runtime truth: LevelDefinition

Bridge: official Baker pipeline

批准原则：

> Scene 是作者编辑入口，Resource 是语义配置载体，canonical LevelDefinition 才是运行时与验证系统的唯一真相。

这里的 LevelDefinition 是唯一规则定义；既有 PuzzleState 仍是独立的可变谜题状态。PuzzleIntent 继续遵守 FOUNDATION-3 的独立 sidecar 合同，不写入 LevelDefinition 或 build_info。

Editor Tool 桥接 Scene / Resource 与正式 Baker，再编排 canonical LevelDefinition 的 Validator / Solver / Quality / Runtime Preview 调用。不得让 Runtime 直接读取 Authoring Node 作为 gameplay truth，不得让 Solver 依赖 Authoring Node，Validator 不依赖 Editor-only metadata。Resource 不复制一份 LevelDefinition；Editor 不另写玩法规则。

认可的目标工作流：打开 Level Authoring Scene → 3D 摆空间结构 → Inspector 配置 Face / Mechanism 参数 → 关联 PuzzleIntent Resource → Bake → Validate → Solve → Softlock / Intent / Ablation → Runtime Preview → Level Acceptance。

该流程是设计方向。当前正式 Baker 内部已经执行 StaticValidator，只有 VALID 才返回 level；后续 Bake / Validate 的界面阶段还需设计，不将上述按钮顺序解释为允许发布未验证产物。

## Face Authoring 的只读接口依据

- `foundation/spatial/surface_geometry.gd::make_face_nodes` 返回六个 Dictionary 记录，不是六个 Godot Node。canonical FaceNode 与 SceneTree Node 不要求一一对应。
- `face_id(cube_id, face)` 是唯一 Face ID 生成入口，格式为 `cube_id/FACE_SYMBOL`。面使用本地身份；旋转后不按 Shared Space normal 重命名。
- `face_frame` 提供本地 U/V/normal；`resolve_anchor` 根据已解析 Cube 自动派生 Anchor 与完整 Frame。它们不是可独立拖动的 Face 几何真相。
- `foundation/level/authoring_reader.gd::read_scene` 当前读取 Cube 节点上的六组 `foundation_faces` 数据，调用正式 `make_face_nodes` 后应用配置。该入口没有要求六个 Face 子节点，也没有现成的视口点面选择工具。
- 当前 Face 配置是 `walkable`、`shift_exit_blocked`、`shift_entry_blocked`、`mechanism_ids`；layer 属于 Cube。FaceTransition 通过独立定义引用 Face；`occludes_light` 属于 Cube，LIT/SHADOW 是正式 Lighting 派生结果。
- 因此用户列举的 enabled/playable/world/lighting 等概念不是本轮已批准的新字段；后续界面名称必须映射既有合同，不能复制 world 字段、删去六面身份或手填逻辑光照。
- canonical ValidationIssue 有 path / entity_ids，但部分 Reader 早期错误只有 authoring path、entity_ids 为空。具体的 selection / diagnostic mapping 桥接仍需后续批准，不能声称现成支持。

## DECISION-4.0-002 — FACE_AUTHORING_MODEL

Status: APPROVED

Decision: C. Hybrid Face Authoring

用户明确回复 C，批准一个 CubeAuthoringNode 持有六面 authoring data，默认不创建六个永久 Face SceneTree 子节点；通过 3D 视口点选具体 Face，再由 Inspector 展示该面的配置。Face 是具有稳定身份、可被选择的 authoring 子对象。

本次只讨论一个问题：一个 Cube 的六个 Face，主要怎样编辑？

| 候选 | 表示与编辑入口 | 主要取舍 |
|---|---|---|
| A. Inspector-first | 一个 Cube 场景节点，Inspector 内六组字段或 SubResource；无永久 Face 子节点 | 场景树简洁、工具实现较少；视口直接选面不够直观 |
| B. Face-as-Node | Cube 下显式六个 Face authoring 子节点，各自选择与 Inspector | 选面与错误定位直观；每 Cube 多六个节点，层级更繁杂 |
| C. Hybrid Face Authoring | 一个 Cube 节点持有六面数据；视口点选 Face 后 Inspector 显示对应配置 | 场景树简洁且可直接选面；需要额外选择工具与 Inspector 桥接 |

选择依据：现有六面记录和稳定 Face ID 可以支撑可选择的 authoring 子对象，不必将记录一比一变成 SceneTree 节点。具体字段或 SubResource 存储方案、选择工具接口、诊断桥接与 Gizmo 的完整 MVP 范围仍待后续设计；本决策不授权实现。

## DECISION-4.0-003 — WORLD_AUTHORING_ORGANIZATION

Status: APPROVED

Decision: C. 两个独立 World 子场景，由一个 Level 主场景装配

用户明确回复 C，批准分别编辑 Surface / Inner 子场景，再在 Level Authoring 主场景中组合。该决策选择了子场景组织，不代表两个独立关卡，也不批准两套 Baker 或运行时定义。

下一个问题只讨论 Surface / Inner 的场景组织方式：

| 候选 | 场景组织 | 主要取舍 |
|---|---|---|
| A. 同一 Level Scene、两个 World 子树 | SurfaceWorld / InnerWorld 分别组织本世界空间对象 | 归属清楚，可同时查看 Shared Space 中的两世界并分别隐藏或锁定 |
| B. 同一 Level Scene、一个共用容器 | 所有 Cube 混放，由 layer 属性区分 | 接近现有 Reader 的平铺结构；两世界对象较多时容易混淆 |
| C. 两个独立 World 子场景、一个 Level 主场景组合 | 分别编辑 Surface / Inner，再在主场景中装配 | 可独立维护或复用；跨世界对齐与引用管理更复杂 |

讨论时技术倾向 A；用户最终选择 C，以用户选择为后续设计基线。两世界仍共享同一 Shared Space，Cube ID 跨世界唯一，canonical WorldLayer 不变。场景层级不自行定义新的坐标变换规则。子场景实例变换、跨场景引用、保存与依赖失效的精确合同留到相应设计章节讨论。

已知适配边界：当前 AuthoringReader 要求根下的 Cubes / Slots 直接容器，不能宣称现有 Reader 已支持 C。后续需设计唯一 authoring 输入适配与正式 Reader / Baker 的衔接，不能复制量化、几何、编码或验证算法。本轮不修改这些入口。

## DECISION-4.0-004 — MECHANISM_AUTHORING_REPRESENTATION

Status: APPROVED

Decision: A. 统一 MechanismAuthoringNode

用户明确回复 A，批准使用统一 MechanismAuthoringNode 作为空间实例，关联可复用机制配置 Resource，在 Inspector 设置实例绑定。不同机制不要求独立的 authoring 节点类型；外观仍可区分，玩法执行由正式 Kernel 负责。

下一个问题只讨论 Mechanism 空间实例的 authoring 节点表示。已批准的语义配置 Resource 职责保持不变。

| 候选 | 编辑方式 | 主要取舍 |
|---|---|---|
| A. 统一 MechanismAuthoringNode | 放置统一节点，关联可复用机制配置 Resource，在 Inspector 配置实例绑定 | 入口统一、便于维护；需要清晰的类型标签与按配置展示字段 |
| B. 按机制类型分专用 Authoring Node | 从不同节点类型中选择，例如天体控制、局部组旋转、面转换装置；仍关联语义配置 Resource | 创建入口与 Inspector 更有针对性；需要维护多个节点类型及共同适配边界 |

选择依据：现有 MechanismDefinition 使用统一记录，正式机制能力是 ENTER / USE 触发配合 MOVE_CELESTIAL、LOCAL_GROUP_ROTATE 或 USE_FACE_TRANSITION；当前固定单状态 profile 不因此扩展为门、动态 flag 或任意机关脚本。节点形式与外观不是新玩法规则，最终映射现有记录并由正式 Kernel 执行。资源中可复用参数与关卡实例 ID / Face / 目标引用的具体拆分仍待后续设计。

## DECISION-4.0-005 — QUALITY_RESULT_PRESENTATION

Status: APPROVED

Decision: B. 报告 + 基础视口可视化

用户明确回复 B，批准保留完整面板报告，并在 3D 视口高亮关联 Cube / Face 或空间关系，帮助将分析结果对应到地图。

PuzzleIntent 采用独立 Resource 已在 DECISION-4.0-001 中获批，不重复提问。下一个问题只讨论首版 Solver / Quality 结果的整体呈现方式。

| 候选 | 呈现方式 | 主要取舍 |
|---|---|---|
| A. 报告为主 | 面板展示状态、指标、问题列表，并提供对应对象的选择定位 | 工具范围较小；空间关系主要由设计师结合场景理解 |
| B. 报告 + 基础视口可视化 | 保留完整报告，同时在 3D 视口高亮关联 Cube / Face 或空间关系 | 更容易对照空间理解结果；需额外可视化与结果状态同步 |

本决策不一次冻结全部可视化功能：具体 overlay 内容、Softlock 状态点选、SolutionTrace 逐步播放、Gizmo MVP 等仍需后续确认。高级热力图、完整图编辑器与所有解浏览保持原延期范围。

两种方案都必须保留正式状态、完整性与证据范围。BUDGET_EXCEEDED 不显示成无解，Softlock INCOMPLETE 不显示成零软锁，里程碑保持 SINGLE_TRACE 范围；不得用单一颜色或总体绿灯替代这些区别。空间可视化只能读取正式结果与派生接口，不形成第二套规则。

## DECISION-4.0-006 — SOFTLOCK_STATE_INSPECTION

Status: APPROVED

Decision: B. 只读状态预览

批准日期：2026-09-19。用户明确回复 B，批准点击已确认的软锁状态后，定位对应对象并展示发生软锁时的空间构型，标记玩家所在 Face，同时提供状态详情。

下一个问题只讨论点击一个已确认软锁状态后的查看体验。

| 候选 | 点击后的呈现 | 主要取舍 |
|---|---|---|
| A. 定位原场景对象 | 选中对应 Cube / Face，面板显示该状态的世界、姿态、组旋转、天体 Slot 等信息 | 工具较轻；作者需要自己结合数值理解发生软锁时的空间构型 |
| B. 只读状态预览 | 同时定位对象并展示该状态的空间构型，标记玩家所在 Face，提供状态详情 | 更容易理解旋转或换世界后的死局；需独立的只读状态展示 |

选择依据：StateGraph 的节点已有完整 PuzzleState；同一个 Face 在不同世界/组姿态、Slot 或玩家姿态下不必有同样结论，不能给原场景位置贴上无条件软锁标签。展示应绑定完整 StateKey、对应 level_hash 与有效分析结果。

B 的批准范围是只读检查，不把状态写回 authoring 场景，也不把它直接赋给 RuntimeSession。正式 Runtime 当前只从 Spawn 初始化；可操作的非 Spawn 状态恢复仍在既有延期边界内。后续设计必须消费正式 Spatial / Presenter 能力，区分状态快照展示与真实 Runtime 回放。Reset recoverability 仅作附加信息，不从 softlock 集合扣除；不完整分析中的 unknown 状态不能称为已确认软锁。

## DECISION-4.0-007 — SOLUTION_TRACE_PLAYBACK_UX

Status: APPROVED

Decision: C. 解法步骤浏览 + 真实整段验证

批准日期：2026-09-19。用户明确回复 C，批准将自由浏览解法步骤与真实 Runtime 整段验证分开。真实回放的暂停与单步控制留待后续评审。

下一个问题只讨论首版 Solver SolutionTrace 的回放控制。

| 候选 | 操作方式 | 主要取舍 |
|---|---|---|
| A. 整段自动回放 | 从 Spawn 自动播放到终点，提供停止、重新开始与结果报告 | 控制较简单；不便停在某一步检查 |
| B. 自动回放 + 逐步查看 | 保留整段播放，并可在动作完成后暂停、执行下一步、查看该步动作与状态差异 | 更适合检查机制与解法；需要回放控制与稳定边界的接口设计 |
| C. 解法步骤浏览 + 真实整段验证 | 在只读状态视图中自由选择步骤；独立按钮启动真实 Runtime 完整回放 | 查看前后步骤无需等待动画，可复用软锁状态视图；首版不提供真实动画回放的单步暂停 |

首次讨论技术倾向 B；2026-09-19 用户询问是否有更好的方案，随后根据真实接口提出 C，用户最终批准 C。所有方案消费正式 solutiontrace.v1，不生成 Editor-only 路径。A/B 的运行回放通过真实 RuntimeSession / Kernel / Presenter 执行。B 中暂停指在动作自然完成并提交后停止发送下一动作，不冻结半程 Tween 或修改动画时长；不包含倒放、任意时间轴拖动或中间状态直接恢复。

当前正式 Replayer 的公开入口是完整异步 replay(level, trace, options)，没有公开逐步控制 API。选择 B 只批准目标 UX，不表示现成支持；后续必须设计单一回放执行所有者及其适配边界，避免另写一套调度或绕过单次提交、IDLE、完整 StateKey 比较。人工暂停的交互会话与自动 Acceptance 的时间预算和完成状态应在后续合同中区分，未完成整段回放不能提前报告 MATCH。

C 的批准范围：

- “浏览解法”：步骤列表显示初态及每一步动作。点击任意步骤或上一/下一步，使用 Trace 已有的 initial_state / expected_state 展示只读空间快照与相邻状态变化。复用 DECISION-4.0-006 所需的状态视图，数据源分别为 GraphNode 和 Trace step；这不是运行中的 Session，也不执行反向动作。
- 显示前调用正式 Trace.validate_semantics 检查整条见证；绑定准确的 Level / Trace 身份。该检查成功只代表纯 Kernel 语义有效，界面明确标记为“解法预期状态”，不能称为 Runtime 实测或 Parity MATCH。
- “运行验证”：单独调用正式 Replayer 的 GRAPHICAL 模式，从 Spawn 完整运行同一 Trace，由真实 Session / Presenter 自然完成动作，并保留正式 ParityResult。结果关联同一输入；DIVERGED 的 divergence_step 可用于定位步骤列表中的预期快照，并展示公开结果提供的差异信息。不能假称当前接口公开全部实际逐步状态。
- 用户可直接查看第 N 步、再返回第 N-1 步，无需从头播放到该处；没有复杂时间轴、倒放动画或任意状态恢复。
- 取舍：C 不提供真实运行过程的单步暂停；若将来确有调试动画时序的需求，再评审 B 所需的正式控制接口。首版仅新增浏览与编排层设计，沿用现有完整回放入口，无需为单步控制而改写 Replayer。

## DECISION-4.0-008 — ACCEPTANCE_TRIGGER_POLICY

Status: APPROVED

Decision: A. 点击按钮启动完整验收

批准日期：2026-09-19。用户明确回复 A，批准编辑时自动做轻量检查并标记旧报告过期，点击 Run Level Acceptance 才启动完整流水线；不在每次保存后自动进行完整搜索与回放。

原始需求已明确要求提供一键 Level Acceptance，不重复询问是否需要。下一个问题只确认编辑过程中的完整验收触发方式。

| 候选 | 默认行为 | 主要取舍 |
|---|---|---|
| A. 手动启动完整验收 | 编辑时自动做轻量字段检查并标记旧结果过期；点击 Run Level Acceptance 才运行完整流水线 | 便于连续编辑，设计师决定何时承担完整分析开销 |
| B. 保存后自动完整验收 | 每次保存相关场景或 Resource 后自动启动完整流水线 | 自动反馈充分；连续保存可能反复启动较昂贵的搜索与回放 |

轻量 authoring 检查只针对编辑数据形状/引用反馈，不能代替正式 StaticValidator 或复制其算法，也不能产生完整验收 PASS。它的精确范围与调用边界留待设计章节批准。

完整流水线消费正式 Baker / Validator / Solver / Softlock / Intent / Trace semantic validation / RuntimeParity。Baker 已内置 StaticValidator 的事实保留，界面阶段不创建第二套验证或允许未验证产物流入后续。任何选择都必须绑定输入身份、区分过期与当前报告；运行中编辑、保存多个依赖、排队/取消与迟到结果的处理仍需在生命周期合同中设计。此处只批准触发偏好，不预先扩展现有同步分析 API。

## DECISION-4.0-009 — LEVEL_SOURCE_AND_ARTIFACT_VERSIONING

Status: APPROVED

Decision: A. Git 管理源文件，生成产物独立保存

批准日期：2026-09-21。用户明确回复 A，批准 authoring Scenes / Resources 及依赖进入 Git；生成的 canonical LevelDefinition 与验收报告独立保存，交付时归档，不作为日常源码重复维护。

原始需求询问关卡版本管理的文件组成。根据已批准的独立 World 子场景方案，不能继续承诺只有一个 Scene 和一个 Intent 文件；关卡源至少包括 Level 主场景、Surface / Inner 两个子场景、PuzzleIntent Resource，以及引用的可复用配置与必要 UID。共享配置可作为项目公共源文件管理，不必每关复制。

下一个问题只确认生成产物是否进入 Git。

| 候选 | Git 管理范围 | 主要取舍 |
|---|---|---|
| A. 源文件入 Git，生成产物独立保存 | 提交 authoring Scenes / Resources 及依赖；本地 Bake 与报告留作忽略的生成产物，交付时生成并归档对应产物 | 避免源与产物重复维护；新环境需要重新 Bake / 验证 |
| B. 源文件 + 验收快照入 Git | 源文件之外，在明确验收节点提交匹配的 canonical LevelDefinition 与验收摘要，不提交每次临时运行 | 便于直接审阅或取用已验收产物；需维护源、产物和报告的身份一致性 |

当前仓库已有 .godot/ 与 tests/gameplay/evidence/ 忽略规则；本次不修改 .gitignore 或创建产物目录。正式产物与报告的归档位置、交付入口及生命周期合同仍待设计批准。

两方案均不改变 canonical LevelDefinition 的运行时规则定义地位：不进 Git 不等于不生成、不归档或让游戏直接读取 Authoring Scene。正式交付必须携带由正式 Baker 产生、版本与内容身份匹配的 canonical 产物；具体发布/构建流程仍待设计。源码、canonical 内容、PuzzleIntent 与分析结果的身份关联需在后续合同中明确；归档的报告不能自动成为当前修改后地图的有效 PASS。

## 设计章节 1 — 关卡源文件与场景职责

Status: APPROVED

批准日期：2026-09-21。用户明确回复“确定”，批准本章文件组织与职责分配。此批准不代表后续桥接、身份、生命周期章节或实现工作获批。

以下为基于九项已批准偏好的第一章设计提案，不是已冻结合同或实现计划。原始问题 A–K 的工作流偏好已通过上述决策覆盖；下面逐章审查具体职责、接口与边界。

| 对象 | 提议职责与归属 |
|---|---|
| LevelAuthoringRoot / Level 主场景 | 整关装配入口；显式关联 Surface 与 Inner 子场景、PuzzleIntent Resource，持有关卡级配置、Spawn / Exit 和唯一共享 Celestial 配置 |
| WorldAuthoringRoot / 两个独立 World 子场景 | 各自组织本世界 Cube、Mechanism 空间实例、FaceTransition 与 RotatableGroup；统一由 Level 主场景提供整关上下文 |
| CubeAuthoringNode | 作者摆放的空间单元；持有稳定 Cube ID 与六面配置；选面编辑不要求六个永久子节点；Anchor / Normal / Frame 从正式几何接口派生 |
| MechanismAuthoringNode + 配置 Resource | Node 负责空间实例与关卡内绑定，Resource 负责可复用语义参数；最终适配到既有 MechanismDefinition，由正式 Kernel 执行 |
| PuzzleIntent Resource | 独立意图源数据；不复制 LevelDefinition，也不包含整个地图；与当前 canonical 产物绑定生成正式 puzzleintent.v1 sidecar 的边界在后续章节定义 |

概念性文件组成：level.tscn + surface.tscn + inner.tscn + puzzle_intent.tres，加引用的共享机制配置及必要 UID。名字仅为展示示例，本轮不创建文件或场景。

主场景是完整关卡的 Bake / 一键验收入口。World 子场景可独立编辑，但不能将子场景的局部检查标记为整关验收 PASS。举例：单独移动 Inner 中的 Cube 并保存后，引用该子场景的 Level 旧产物/报告需要重新判断有效性，不能只监听主场景文件的改动；精确依赖身份与失效规则在后续生命周期章节冻结。

World 子场景组织层级不新增空间规则：两世界仍使用同一个 Shared Space，Cube ID 在整关跨世界唯一，Face ID 仍为正式 cube_id/FACE_SYMBOL。实例变换、ID 冲突处理和跨场景引用将在后续 identity / 坐标章节明确，本章不默认支持任意子场景缩放、旋转或自动重命名。

Player 的可变 PuzzleState、运行事务、调试视图选择不进入作者配置；canonical LevelDefinition 是运行时规则定义，独立 PuzzleIntent 是质量分析输入。只读状态查看与真实 Runtime 回放保持 DECISION-4.0-006/007 的区别。

作者场景到现有 Reader / Baker 的兼容适配尚未冻结，本章不宣称当前平铺 Cubes / Slots Reader 已支持该层级；后续单独审查桥接方案并保持量化、几何、编码、验证各有唯一正式 Owner。

本轮不修改 production、Godot Scene 或既有合同，不创建插件、Gizmo、Dock、测试实现或实施计划；不提交 Contract Freeze。本章已确认，继续审查下一章。

## 设计章节 2 — 作者场景到正式烘焙的桥接

Status: APPROVED

批准日期：2026-09-21。用户明确回复 B，批准共享适配器生成临时旧 profile，再调用现有 Reader / Baker 的路径与本章职责边界；本轮仍不实施代码。

事实依据：foundation/level/authoring_reader.gd 的 read_scene 要求直接 Cubes / Slots 容器及显式 metadata，并独占场景坐标量化、姿态识别及六面生成入口。现有 Reader 尚不能直接读取第一章的新层级。

| 候选 | 边界与取舍 |
|---|---|
| A. 扩展正式 Reader 读取新层级 | 减少中间节点，但将新工具配置与层级知识加入已有 Reader；须维护旧 profile 兼容性 |
| B. 共享适配器生成临时旧 profile，再调用现有 Reader（推荐） | 保留正式读取与烘焙路径；增加短生命周期的中间节点及来源映射，适配器需要明确限制职责 |
| C. 编辑器直接拼装十八字段 authoring Dictionary | 表面直接，但易复制量化、姿态、六面生成及校验逻辑，不建议作为独立实现路径 |

建议 B：Editor 与 headless 命令行共用同一无 EditorPlugin 依赖的 authoring 适配器。适配器读取新场景及 Resource 的声明数据，建立内存中的、未挂入 SceneTree 的纯 Node3D 旧 profile；不复制或执行作者脚本，不保存中间场景，不修改作者源节点。Reader 消费该 profile，产出正式 authoring Dictionary，再交给现有 LevelBaker。中间节点在读取完成或失败后统一释放。

适配器只负责结构展开、声明字段映射与 source map；不自行量化坐标、生成正式 Face ID / 法线 / 锚点、计算内容哈希、执行规则或搜索。不得通过自动吸附、消除非法变换等方式掩盖输入错误。新层级允许的实例变换和引用规则留待下一章；此处不批准任意变换或通用场景扁平化。

现有 LevelBaker 内置 StaticValidator，必须沿用其结果。读取失败或 Bake 未成功时停止下游，不允许通过工具绕过验证生成可运行产物。成功后 Solver / Preview / Parity 消费同一 canonical LevelDefinition；PuzzleIntent 仍为独立 sidecar。

来源映射独立保存，关联临时 profile 路径、正式实体 ID 与原始作者对象；供诊断定位使用，不增加 LevelDefinition 字段，不影响 canonical 内容哈希。映射结构、稳定作者身份和排序后诊断定位将在后续章节冻结。

本章只请求批准共享桥接路径与职责边界，不声明适配器已实现或现有接口已支持新结构。

## 设计章节 3 — 坐标、稳定身份与引用

Status: APPROVED

批准日期：2026-09-21。用户明确回复“确定”，批准本章坐标限制、稳定身份分工与引用策略；不构成实现授权。

建议首版采用以下明确约束，避免场景组织隐式改变既有空间规则。

### 坐标与实例

- Level 根节点是作者坐标参考系，保留现有 Reader 对根节点有限刚体放置的约束；整关根节点在外部场景中的放置不改变逻辑坐标。
- 两个 World 实例根和空间组织容器必须使用单位变换，不允许 top_level；不允许通过平移、旋转、缩放 World 实例布置世界。Cube 与 Slot 的位置因此直接处于共同的 Level 局部 Shared Space。首版不支持任意带变换的中间空间分组或同一 World 的多实例拼装。
- Cube 的网格与离散姿态仍交给正式 Reader 检查；适配器原样传递，不静默吸附或修正。RotatableGroup 的正式 pivot / 初始状态字段保持既有合同，不以作者父节点变换另行表达组旋转。
- 一关明确绑定一个 Surface 与一个 Inner；子场景声明的世界与装配角色必须一致，否则报告错误。不同关卡可引用同一子场景，但编辑共享源会使所有引用它的关卡需重新判断验收有效性。

### 三种不同身份

- authoring_id：持久化、不透明的作者对象 UUID，属于工具源数据；节点显示名、NodePath 和运行期 instance_id 都不能替代它。作用域为整关装配，独立可编辑的作者实体必须唯一；六面以所属 Cube 的 authoring_id 加正式 FaceDirection 定位，不额外创建六个作者节点。它不进入 LevelDefinition 或 PuzzleState，不参与 canonical 内容哈希。
- 正式实体 ID：CubeID、SlotID、MechanismID 等沿用各自既有合同；CubeID 跨表里世界整关唯一。Face ID 只由官方接口根据 CubeID 与局部面方向生成，作者不能自由填写另一套 Face ID。
- StateKey：继续使用正式完整 statekey.v1，只标识状态；不作为编辑对象身份，也不与 authoring_id 混用。Godot Resource UID / 文件路径只帮助定位源资源，不取代上述身份。

### 引用与修改

- 跨场景规则引用使用显式正式实体 ID，面引用采用 CubeID + FaceDirection，由适配路径调用正式几何接口解析；不把 NodePath 当作游戏语义引用。可复用机制配置承载参数，关卡专属目标 ID 放在实例绑定中，避免修改共享配置意外改写其他关卡绑定。
- 改节点显示名或场景树排序不改变身份或规则引用。正式 ID 的变更属于规则数据编辑，必须同步检查整关引用；首版不承诺自动跨文件重命名。未同步的悬空引用阻止 Bake。
- 工具提供的创建/复制操作为新实体分配新的 authoring_id 与无冲突正式 ID，并在同一可撤销编辑中处理所复制集合内部的引用；指向集合外部的引用保持原目标。具体编辑事务接口留待 UndoRedo 章节。
- 外部编辑、Godot 原生复制或多实例引入的重复 ID 必须显式报错，不能在读取或烘焙时静默重编号。删除对象产生的悬空引用同样阻止 Bake；不自动删除引用来掩盖问题。
- source map 以稳定作者身份和正式实体身份关联对象，文件/节点路径作为当前快照定位提示；映射绑定源快照。canonical 相同而作者结构变化时也需更新映射，不能直接用旧路径定位新场景。精确 schema 与版本规则留待报告/生命周期章节。

本章为待审设计，仅提出坐标限制、身份分工及引用策略，不修改场景或正式合同。

## 设计章节 4 — 输入快照、生命周期与结果有效期

Status: APPROVED

批准日期：2026-09-21。用户明确回复“确定”，批准保存后固定快照验收、运行中编辑失效及本章结果有效期规则；不构成实现授权。

建议首版使用“保存依赖后，针对固定快照验收”的模型。完整 Bake / Acceptance 启动前，主场景、两个 World 子场景及递归引用配置必须已保存，且无已知的未保存依赖编辑；未满足时显示需要保存的文件，阻止启动。提供显式保存相关源文件的操作，不在后台静默保存，不把磁盘旧版本误称为当前编辑内容。只读浏览历史结果不要求保存。

保存完成后捕获整个依赖闭包的不可变快照及清单。快照采集遇到依赖变化则作废重取或明确失败，不拼接不同时间版本的文件。后续阶段只使用该快照经正式 Reader / Baker 产生的产物；禁止各阶段再从活动场景或磁盘重新取部分输入。具体快照存储、资源解析和执行隔离方式将在编排章节设计，不声称当前模块已有此能力。

### 身份分层

- source_fingerprint：作者源快照及依赖内容身份，覆盖场景、配置、Intent、持久作者 ID 及定位所需信息；不只依赖主文件时间戳。具体清单与规范化算法留待合同 schema 审查。
- level_hash：继续由正式 Codec / Baker 计算 canonical 关卡内容身份；工具不能生成替代算法或把编辑器元数据加入其中。
- intent 身份与质量请求身份：Intent 内容、策略、预算、相关合同/工具版本共同绑定质量结果。仅 level_hash 相同不足以复用验收 PASS。
- run_id / generation：标识本次执行和发布代次，避免迟到结果覆盖当前结果；运行身份不是内容哈希。

### 状态与转换

状态应分开表达源的新旧程度、作业进度、静态验证结论和质量结论，不能将它们挤入单个互斥枚举。

- DIRTY：源或依赖相对结果发生变化，包含尚未保存的编辑；保存文件本身不会恢复 VALID 或质量 PASS。
- BAKING：正处理固定输入快照。用户可继续编辑；修改立即将当前关卡标记 DIRTY，但不改变正在执行的输入。
- BAKED：存在本次正式 Baker 成功返回的 canonical 产物。现有 Baker 已内置 Validator，因此成功 BAKED 同时具有该快照的静态 VALID；不得制造“绕过验证的 BAKED”中间产物。
- INVALID：正式静态验证确认非法；读取错误、作业错误、取消和预算不足分别记录，不冒充 INVALID。Validator 的 INCOMPLETE 必须保留，Baker 未成功时不发布新的 canonical 产物。
- 质量结论单独保存 Solver、Softlock、Intent 与 Parity 原始状态；静态 VALID 不等于整关质量 PASS，未完成不等于无解。

执行中发生修改或启动了更新代次后，旧运行结果可以作为绑定旧快照的历史结果保存，必须标记非当前，不能覆盖当前报告或恢复绿色通过状态。首版保守处理：任何相关源修改使报告过期；即便撤销到疑似相同内容，也需显式重新验收才恢复当前通过状态，不承诺自动缓存复用。

修改 Intent 或分析预算可能不改变 level_hash，但会使对应质量结果不再适用。改作者显示名可能不改变规则，却会影响 source map；来源映射必须匹配新快照。缺失依赖、外部文件变更或无法确定依赖是否一致时，不显示当前有效 PASS。

取消/停止是工具作业状态，不新增或篡改正式 Solver 枚举；停止后不启动下一阶段、不发布完整 PASS，已完成阶段可保留为部分历史证据。同步阶段的立即终止能力需由后续执行隔离设计明确，不在本章承诺现有接口支持随时取消。

本章只请求批准保存后快照验收及结果有效期规则，实际报告 schema、后台执行方案和验收通过条件仍待后续章节确认。

## 设计章节 5 — 一键验收范围与通过条件

Status: APPROVED

批准日期：2026-09-21。用户明确回复“确定”，批准本章验收标准，包含零软锁及真实 GRAPHICAL RuntimeParity 完整 MATCH 门槛；通过范围仍限于本章列出的证据，不扩展为所有解证明。

建议首版采用固定、明确命名的验收范围；界面用“本轮验收通过”并始终展示范围，不使用“所有解均符合设计意图”等普遍性宣称。质量判定是工具编排层对正式结果的汇总，不改变任何正式模块的枚举或结论。

### 阶段与证据

1. 适配 / Reader / Baker：固定源快照经正式路径成功 Bake，保留 Baker 内置 StaticValidator 的 VALID 结果；失败或未完成时不启动依赖 canonical 产物的阶段。
2. 原关卡搜索：从正式 Spawn 初态运行 UNFILTERED / FULL_GRAPH。正常返回 SOLVED 且 graph.complete=true 才满足本章完整探索要求。找到见证但预算耗尽仍保留 BUDGET_EXCEEDED，不改称完整成功；可以单独浏览经语义检查的见证。
3. 软锁：对本次正式 Explorer 产生的同进程活图调用正式 Softlock 分析器，不以磁盘图重新载入伪造可信完整性。建议首版验收门槛为 COMPLETE 且 softlock_count=0。可 Reset 恢复的软锁仍计入软锁，不抵消门槛；未来若要允许需单独评审显式策略，首版不引入例外名单。
4. Intent：把本次作者 Intent 绑定本次 level_hash，使用正式校验、消融与里程碑接口。所有已声明请求完成且无 required / forbidden 对应硬质量问题，才满足该阶段。COMPLETE 只是完成度，不自动等于质量通过；optional 或 UNUSED_MECHANISM 警告保留展示，不阻塞。无声明条目标记无适用检查，不冒充完成了非空请求。
5. Trace：明确选择并记录本次原关卡搜索提供的 trace，使用正式 Trace.validate_semantics；里程碑结果必须对应这条被选中的 trace，不能混用另一条见证的结论。required 里程碑必须获得 TRACE_MATCH；始终标明 SINGLE_TRACE。原分析器内部 trace 如与所选 trace 不同，原结果保留并另调用正式 Milestones 接口检查所选 trace，不复制分析算法。
6. RuntimeParity：同一选定 trace 从 Spawn 交给正式 GRAPHICAL Replayer，经真实 Session / Presenter 自然完成，结果为 MATCH 才满足完整验收。纯逻辑回放不替代图形回放。没有图形执行能力时，该阶段标记未执行，整体不能显示完整通过；CLI / CI 可交付明确缺少图形验证的部分报告。

各阶段保留实际策略、预算、指标与原始状态。原关卡完整探索不替代消融器内部正式 baseline / 子搜索，也不擅自添加跳过验证或图复用参数。初态已为 Goal 的合法零步解仍按正式接口处理，不强制非空 trace。

### 汇总规则与范围限制

- “本轮验收通过”：上述必需阶段全部达到门槛，输入身份一致且报告仍匹配当前源。它证明静态有效、可解、在本次完整原图上无软锁、声明消融检查无硬问题，以及选定 trace 的里程碑匹配和图形运行一致。
- “未通过”：存在已确认的静态/质量反例，例如正式无解、确定软锁、禁止绕过、required 里程碑 TRACE_BYPASS 或 Parity DIVERGED；同时保留其他阶段未完成情况。
- “未完成 / 执行错误”：缺少必须证据、预算不足、停止、未执行或模块 ERROR，不能把这些情况称为已证明关卡无解或质量不合格。精确汇总枚举与错误优先级留待报告 schema 章节。
- “已过期”是当前适用性标记，可以附在任何历史结论上；旧快照通过不能成为当前关卡通过。

一个 trace 的 TRACE_MATCH / Parity MATCH 只证明该 trace，不证明所有解满足教学顺序或所有运行都无问题。首版没有所有解里程碑证明，也不以人工试玩代替自动证据。人工试玩可另留记录，不属于本轮自动通过门槛。

用户仍可单独触发 Bake、搜索或回放获取局部结果，局部成功不能升级为完整验收通过。本章新增的严格零软锁门槛及完整图形回放要求均为待批准提案。

## 设计章节 6 — LevelAcceptanceReport 归属与报告合同

Status: APPROVED

批准日期：2026-09-21。用户明确回复“确定”，批准跨工具共享版本化报告、证据组成及质量判定/执行完成度/当前适用性分离；本轮仍仅维护设计工作笔记。

建议将 LevelAcceptanceReport 定义为独立、版本化的工具层共享验收合同，供 Editor、headless / CI 与归档消费者共同使用。它不依赖 EditorPlugin，不是 Dock 私有显示数据，也不进入 LevelDefinition / PuzzleState 或改写 foundation.analysis.v1 的已有结果记录。唯一汇总器依据第五章规则组合正式结果；Editor 只展示和定位，不能自行重判一次 PASS。

### 报告组成（待正式 schema 冻结）

- report_version：建议 levelacceptance.v1；保存运行身份、工具/合同版本、验收 profile 版本及时间信息。时间和 run_id 是执行元数据，不作为关卡内容身份。
- inputs：source_fingerprint、依赖清单及内容摘要、level_hash（Bake 未成功时为 null）、Intent 内容身份、所选 trace 身份、各阶段实际策略与预算。未生成的身份使用显式 null，不填写旧运行数据。
- stages：适配/读取、Bake 及其静态验证、原图探索、软锁、Intent/消融、所选 trace 语义与里程碑、GRAPHICAL Parity 的阶段记录。记录是否运行、输入身份、完成情况、正式模块状态、指标、问题与证据引用；包装状态不取代原始枚举，未运行阶段没有伪造的上游结果。
- evidence：canonical 产物、正式 solutiontrace.v1、各阶段结果及独立 source map 的内容摘要与相对归档路径；小结果可内嵌。归档读取必须核对版本、身份及引用内容，缺失或不匹配不能显示已核验通过。序列化 StateGraph 仅用于查阅，不升级为可供正式 Softlock 接受的活图。
- summary：分别保存质量判定 verdict=PASS/FAIL/UNDETERMINED 和执行完成度 completion=COMPLETE/INCOMPLETE/ERROR/CANCELLED，并列出确定反例、缺少的必需证据及警告。具体字段类型、枚举值和序列化细则在最终合同中审查，此处为结构提案。

### 汇总语义

所有必需阶段完成且达到第五章门槛才有 PASS + COMPLETE。任一可信正式结果给出确定反例则 verdict=FAIL，即使另有阶段未完成或错误；其完成度仍如实显示。无确定反例但缺少证据时 verdict=UNDETERMINED，不能因没有 ERROR finding 就默认通过。任务结束时 completion 优先级为 ERROR、CANCELLED、INCOMPLETE、COMPLETE；所有阶段原状态仍完整保留，不依靠顶层字段隐藏细节。

只有正式合法返回、身份匹配的阶段证据可以参与汇总；损坏记录或无法核验的附件不能充当 FAIL/PASS 证据。加载归档时的完整性错误属于报告读取状态，不修改原归档结论，也不能将未核验声明当作有效结论。

### 当前性与来源定位

当前性是报告消费者对“报告输入与当前工作区”的比较结果，使用 CURRENT / STALE / UNKNOWN；它不写成不可变历史报告的永久事实。只有已核验 PASS + COMPLETE 且 CURRENT 可显示当前绿色通过。未关联工作区的归档可显示“该快照验收通过”，不得显示“当前关卡通过”。延续第四章保守策略，编辑后需显式重新验收，不以加载旧报告恢复当前通过。

source map 是绑定源快照的独立工具附件。诊断保留正式 code、severity、path、entity_ids / subject_ids 与 upstream；定位优先使用正式实体 ID，再通过准确匹配该产物的结构路径映射到作者 ID、字段、源文件与当时 NodePath。若正式问题只能定位整关，或映射不唯一/过期，显示整关或未定位问题，不猜测某个方块，也不按当前数组顺序解释旧下标。

源映射可表达一对多对象关系；视图选中时再次检查作者身份。面问题定位到所属 Cube 与 FaceDirection，关系问题可定位多个端点。它不改变错误严重性，也不将作者对象 ID 混入正式状态或 hash。

### 保存与交付

每次运行使用独立产物位置，最终报告与其附件在完整写入并核验后发布；中断时保留明确的部分记录，不覆盖上一份完整归档，不留下貌似成功的半份最终报告。报告与附件默认是被忽略的生成产物，交付时成套归档；精确目录和原子发布接口留待执行编排章节。

本章请求批准报告作为跨工具共享合同、证据组成及质量/完成度/当前性分离，不创建正式 schema 文件或实现。

## 设计章节 7 — 后台执行、停止与产物发布

Status: APPROVED

批准日期：2026-09-22。用户明确回复 C，批准独立 Godot 作业进程及本章执行规则；本轮只记录设计，不启动进程或实施功能。

| 候选 | 取舍 |
|---|---|
| A. Editor 主线程执行全部分析 | 接入简单，但既有同步 Explorer / Ablation 会阻塞编辑与停止响应，不推荐 |
| B. Editor 内工作线程 | 可释放主线程，但需证明所有资源与调用路径的线程安全，并难以中断已有同步批次 |
| C. 独立 Godot 作业进程（推荐） | 隔离同步搜索，便于停止与 headless 复现；需增加快照输入、进程状态及结果发布协议 |

推荐 C，Editor 只管理编辑、启动/停止、进度展示与结果读取。共享工具编排层接收固定源快照、配置和 run_id，不接受任意脚本命令。具体进程启动 API 在实现前据 Godot 官方文档核实；本章不实现或宣称线程/进程 API 已验证。

### 两段执行，正式接口不变

- 后台无界面 Godot 进程运行快照适配、Reader / Baker、正式原图探索、Softlock、Intent 和 Trace 检查。原图探索与 Softlock 必须留在同一进程，直接传递本次正式活图；不能把图跨进程序列化后再当可信活图分析。
- 图形阶段使用独立、可见的 Godot 验证进程，从该次 canonical 产物和已核验的同一 trace 启动正式 GRAPHICAL Replayer，使用真实 Session / Presenter 完成动画和状态比较。增加的启动入口只负责加载输入和调用现有回放器，不另写规则或动作调度。
- 无图形能力的 CLI / CI 可完成后台阶段并输出部分报告；补充图形阶段必须严格绑定同一输入、trace 和执行版本，再由共享汇总器生成新报告，不拼接来源不明的 MATCH。
- 依赖阶段失败则下游标为未执行并附原因；已有合法 canonical / trace 时，可继续仍有诊断价值且前置条件满足的检查，即使已存在质量反例。不能只因已有 FAIL 就丢弃已完成证据。

### 快照与输入

保存后为本次作业物化独立输入包，保留源资源相对关系与必要 UID 解析信息；运行中的 worker 不读取活动工作区替代缺失依赖。项目工具/合同版本与源依赖一并绑定，物化前后核验清单一致；不能获得一致快照即不启动分析。具体工程装载布局、UID remap 和 snapshot schema 需在正式合同阶段审查，不能承诺仅复制三个 tscn 即可运行。

### 作业控制

- 首版每个编辑器实例最多一个完整验收作业，不自动排队或因保存反复重启；运行中可继续编辑。再次启动前需当前作业结束或显式停止，不由旧任务自动占用后续运行。
- 进度只报告真实阶段边界、已完成子结果与可用指标；既有同步接口没有内部进度时显示“正在分析”，不伪造百分比、预计时间或扩展正式 API。总作业看门狗与各模块预算分别记录，外部超时不伪装成正式 Solver BUDGET_EXCEEDED。
- 停止先禁止后续阶段与最终通过发布，再结束该作业拥有的进程；不得按程序名杀死用户其他 Godot 实例。作业所有权与进程退出确认必须匹配。终止的同步调用没有正式返回结果，阶段记为中断，不伪造上游记录。
- 已原子保存的阶段结果可保留；部分写入文件不作证据。窗口关闭或进程异常退出在无法取得正式结果时记录中断/执行错误，不能当作 MATCH。启动失败与用户停止分别保留原因。
- 本章停止机制仅限新验收作业进程，不扩大为任意 Runtime 状态恢复、暂停/单步 Replayer API 或修改正式分析模块。

### 产物发布

建议本地使用 .godot/foundation-authoring/runs/<run_id>/，分 input、staging、artifacts 与 manifest；均为生成数据，不加入日常源文件提交。依赖与证据引用限制在本次包内，以相对路径和摘要核验。完整报告在附件落盘并核验后通过同目录临时文件替换发布；进度/部分报告使用不同记录，不能冒充最终报告。

当前结果索引只指向经过核验且 run_id / generation / 输入匹配的结果。旧作业完成不覆盖新代次；已过期结果仍可归档。每次运行独立目录，不覆盖旧证据。交付通过显式导出将清单、报告、canonical、Intent 与 trace 等引用证据成套复制到指定目录；不能把可被 Godot 清理的 .godot 缓存当作永久交付存储。首版不自动清理历史运行，清理策略后续另审。

本章请求批准独立进程编排方案、真实阶段进度、受控停止及每次运行独立发布；不创建 worker、场景、进程或新代码。

## 设计章节 8 — 编辑界面、视口反馈与撤销边界

Status: APPROVED

批准日期：2026-09-22。用户明确回复“确定”，批准本章首版交互范围、基础视口反馈与单文档撤销边界；本轮不实现编辑器功能。

建议使用一个关卡工具 Dock、Godot Inspector 与现有三维编辑视口，不另建完整地图编辑器。Dock 分区负责关卡上下文/作业入口、问题与结果、状态/解法查看。Inspector 编辑所选作者对象及六面数据；Dock 不维护第二份可写关卡模型。面选择是工具选择状态，不要求永久 Face 子节点。

### 作者操作与显示

- Dock 明确当前 Level 主场景及其 Surface / Inner、Intent 关联，提供保存依赖、独立 Bake、求解、完整验收、停止、查看/导出报告与真实回放入口；各入口依赖第四至七章的统一作业与结果身份规则。未满足前置条件时显示具体原因，不静默使用旧产物。
- 选中 Cube 后可在视口选面，并在 Inspector 编辑允许的面字段；FaceDirection 为固定局部面身份。Anchor / Normal / Frame 为只读派生显示，不提供独立编辑值。选择、过滤、相机和显示开关不修改关卡源。
- 对机制实例只暴露正式支持的触发方式与动作参数、实例目标绑定；Resource 保存共享配置。编辑共享配置时明确显示共享属性，不暗中复制 Resource，也不无声改成实例独有。可显式另存独立配置，文件管理与参数编辑分开。
- 编辑时轻量检查限于作者字段形状、必填值、ID 唯一性、引用存在性、层级/profile 约束；空间合法性、光照与玩法结论由正式模块提供。缺少已烘焙产物时，不能将编辑草稿的视觉效果标记为已验证。

### MVP Gizmo / Overlay

| 对象 | 首版视觉反馈 |
|---|---|
| Cube / Face | 方块边界、选中面、局部面方向、官方派生 anchor / normal；文字与选中轮廓辅助辨认 |
| Spawn / Exit | 明确的图标、标签及目标面绑定 |
| World | Surface / Inner 的文字标识、独立显隐与选中强调；不通过偏移世界来方便展示 |
| FaceTransition / 机制绑定 | 显式配置的关系线与端点、方向和目标标识；不画成任意跨方块传送能力 |
| RotatableGroup | 成员范围、正式 pivot 与配置标识；不使用作者父节点旋转伪造运行状态 |
| Celestial | Slot 位置、标识及所查看状态的当前 Slot；正式派生结果可用时展示方向，不另算一套光照 |
| 问题定位 | 对应对象/面/关系高亮，同时显示严重性图标与文字，不仅依靠颜色 |

配置关系可从作者声明显示并标记未验证；状态相关的连接、光照和空间构型只消费所绑定 canonical Level + PuzzleState 的正式派生结果。禁止把当前状态的连接画成对所有状态恒成立。首版不提供热力图、全图状态网络或复杂关系图编辑器。

### 只读结果查看

Softlock 状态与解法步骤共用独立只读状态视图，以相应快照 Level 和完整 PuzzleState 展示真实构型。明确标识“分析状态”或“解法预期状态”，不覆盖源场景 transform，不把中间状态注入 RuntimeSession。选中某个状态只提供上下文相关结论，不把一个 Face 永久标成软锁。

解法提供初态、步骤列表、上一/下一步与直接选步、动作与状态差异；真实完整回放使用独立入口。报告过期后仍可查看其历史快照，但不得将其图层作为当前场景有效诊断覆盖；跳转当前作者对象需重新核验身份，无法匹配时只显示历史定位。

### UndoRedo

- 每个工具发起的源数据修改都进入 Godot 编辑撤销体系：字段变更、面配置、创建/复制/删除、绑定调整及组成员调整。一次拖动作为一次操作；Redo 恢复原已分配 ID，不重新随机生成。具体 Godot history API 的使用在实现前核实。
- 默认把一次编辑限制在一个源文档/所属编辑历史；跨独立 World 文件的批量修改首版不提供，跨文件正式 ID 自动重命名继续延期。跨世界引用可在引用方所属文档内修改目标 ID，整关轻量检查负责揭示未修复引用。
- 复制集合内部引用的同步更新与新 ID 分配归入同一个撤销操作；不自动修改集合外部引用。删除导致的外部悬空引用显式报错，Undo 恢复原对象及身份。
- 共享 Resource 的编辑需进入该资源适当的编辑历史并标记相关依赖失效，不分裂成 Dock 私有历史。文件保存/导出、作业启动/停止及报告查看不伪装为可撤销源数据编辑。
- Undo / Redo 同样触发源失效检查，依第四章不自动恢复验收 PASS。卸载工具清理选择、Gizmo 与只读视图等临时状态，不修改作者源文件。

本章请求批准首版交互范围、基础视觉反馈和单文档编辑撤销边界；不创建 Dock、Inspector 扩展、Gizmo、场景或代码。

## 设计章节 9 — 模块所有权、验证层次与后续阶段

Status: APPROVED

批准日期：2026-09-22。用户明确回复“确定”，批准本章 Owner 分工、八层验证与 FOUNDATION-4.1 至 4.5 阶段边界；不构成 Implementation Plan 或执行授权。

以下为未来开发的职责分区与阶段验收边界，不是实施计划，不分派 agent、不创建目录、不开始 FOUNDATION-4.1。

### 所有权提案

| Owner | 唯一职责与建议目录（尚未创建） |
|---|---|
| 4A Authoring | foundation/authoring/：作者数据类型、作者组件、显式引用、适配器及 source map 生成；tests/foundation/authoring/ 对应测试 |
| 4B Editor | addons/block_girl_level_tools/：唯一插件入口、Dock、Inspector、选择/Gizmo、UndoRedo、诊断定位显示；tests/foundation/editor/ 对应测试 |
| 4C Quality workflow | tools/foundation/authoring_quality/：纯分析编排，调用正式 Explorer / Softlock / Intent / Trace，不改写分析算法；tests/foundation/authoring_quality/ 对应测试 |
| 4D Acceptance / Preview | tools/foundation/authoring_acceptance/：快照包、worker 启动/停止、共享报告合同及唯一汇总器、证据发布/归档、正式图形回放入口和只读状态展示服务；tests/foundation/authoring_acceptance/ 对应测试 |

4B 独占插件注册与 UI 文件，4C/4D 通过冻结接口提供数据/服务，不分别修改插件入口；4A 独占 source map 的定义与生成，4B 消费定位、4D 随证据归档。4D 提供可嵌入的只读展示服务，4B 负责 UI 容器与选择传递，避免两方编辑同一场景。共享类型跟随其唯一 Owner，不另建四方共同修改的共享文件。

已有 foundation/level、contracts、spatial、rules、solver、quality、parity 和 prototype runtime 不纳入四方自由修改范围。发现正式接口缺口先报告合同问题并单独审查，不复制算法绕过。project.godot、全局测试入口及跨模块装配由最终集成负责；四方只维护各自入口，不并发修改这些文件。

依赖关系：4A 的作者/映射输出供 4B 与 4D 消费；4D 的固定输入与任务协议调用 4C 的质量编排；4C 返回正式分析记录供 4D 汇总，4B 展示。合同先确定，UI 可使用窄接口测试数据，但最终集成必须接真实模块，不能以 mock 通过冒充完整验收。

### 测试层次（仅设计，不写测试）

| 层 | 需证明的性质 |
|---|---|
| A. 作者序列化 | 保存/加载保留配置、稳定 ID 与引用，未知或缺失字段显式失败 |
| B. 编辑器集成 | 单次修改/撤销/重做一致，共享配置及子场景修改使结果失效 |
| C. 确定性烘焙 | 同一规则输入经 Editor / headless 得到相同 canonical 内容与 level_hash；树顺序和显示名不改变规则，非法坐标不静默修正 |
| D. 选择与诊断映射 | 六面、跨文件实体、排序后的正式 issue 路径准确定位；旧映射/缺失对象不能误选 |
| E. Solver Tool 集成 | 保留真实 Solver / Softlock / Ablation 状态和预算；不完整图不产生无软锁结论，SINGLE_TRACE 不升级为全解证明 |
| F. Runtime Preview | 只读查看不改作者源，真实回放使用同一 trace、自然回调和完整状态比较；预期快照不能冒充 MATCH |
| G. 全流程验收 | 保存依赖、快照一致性、停止/崩溃/超时、迟到结果、证据缺失及发布完整性；所有门槛满足才显示当前通过 |
| H. 既有回归 | FOUNDATION 与 P-01 正式回归保持原语义，不降低阈值或删除测试；既有已知问题原样记录，不趁本轮改玩法 |

确定性针对 canonical / 内容身份和无墙钟限制时的逻辑分析结论；报告 run_id、时间、耗时可变化，实际墙钟预算触发结果不可承诺跨设备完全相同。不能要求两份完整报告字节相同来替代语义验证。

### 后续阶段建议

- FOUNDATION-4.1：作者组件、源身份/引用与共享适配；形成正式 Reader / Baker 可消费的数据边界。
- FOUNDATION-4.2：Bake / Validation 编辑入口、基础选面与诊断映射、撤销及源失效反馈。
- FOUNDATION-4.3：Solver / Softlock / Intent 质量编排与结果查看，明确全部证据范围。
- FOUNDATION-4.4：固定快照 worker、只读状态视图、真实 Runtime 验证、报告汇总及归档。
- FOUNDATION-4.5：跨模块真实端到端集成与八层验证收口。

阶段表示交付验证顺序，不等同于四个 Owner 或独立可同时完成的任务；快照/报告/作业服务的接口需在上层消费前已冻结。涉及阶段内部任务拆分、逐文件改动与执行命令，留待用户另行批准 Implementation Plan。

已延期范围保持不变：自动关卡/AI 生成、难度 AI、高级热力图、状态图编辑、所有解探索、SAT/SMT UI、Monte Carlo、多人/云协作、游戏内编辑器、Workshop、复杂资产管理，以及真实回放暂停/单步、任意状态恢复、跨文件批量重命名。本章批准后仍需完成具体合同字段与快照装载等未决细节的审查，不能立即宣称 Contract Freeze。

## 设计章节 10 — 作者配置版本与 PuzzleIntent 绑定

Status: APPROVED WITH USER-SPECIFIED BOUNDARIES

批准日期：2026-09-22。用户明确确认第十章并补充以下强制边界。作者只维护设计意图；工具绑定同轮成功 Bake 的正式产物；绑定后的 puzzleintent.v1 随报告归档，不回写源文件。显式空 Intent 是否允许最终整关通过仍待完整验收策略单独决定，本章批准不包含该结论。

事实依据：正式 IntentValidation.validate 要求恰好八个字段，intent_version=puzzleintent.v1，level_hash 与当前 Level.content_hash 相等，rule_version 与当前 Level.rule_version 相等；不能把未绑定的作者 Resource 当作已合法正式 Intent。

### 作者源版本

建议 Level 作者 profile 使用独立的 authoring_version=levelauthoring.v1。其版本管理工具字段与装配格式，不替换正式 Level / rule / analysis 版本。作者组件和配置采用封闭声明字段，适配器不把任意 metadata 合并进正式 authoring Dictionary。Godot 自身的存储属性不属于此封闭领域字段集合，不因存在引擎属性就误报未知字段。

节点/Resource 的声明字段与正式字段映射在最终合同中逐表列明。作者可编辑规则字段只对应现有正式合同；空间数据由 Reader 读取，正式派生字段只读，authoring_id 和显示标签只供工具使用。适配器只展开、引用解析和类型映射，不增加玩法默认值来掩盖缺失输入。

### Intent 作者源与正式 sidecar

作者 PuzzleIntent Resource 建议领域字段为 authoring_version、authoring_id、intent_id、required_mechanics、optional_mechanics、expected_milestones、forbidden_bypasses。authoring_version 使用独立 puzzleintentauthoring.v1；作者不编辑 level_hash，不持久维护一份每次 Bake 后需回写的 hash，也不自行选择与 Level 冲突的 rule_version。

正式绑定流程：

1. 读取本次源快照的 Intent，检查作者 profile；不回写源 Resource。
2. Bake 成功后，取本次 canonical Level 的 content_hash 与 rule_version。
3. 将意图声明映射成正式八字段 puzzleintent.v1；face 谓词的作者 CubeID + FaceDirection 引用通过官方 Face ID 接口解析。required 里程碑顺序保持原序，不擅自排序；标签集合仅可做正式合同规定且不改变语义的表示转换，不能静默去重、丢弃非法条目或填入缺失约束。非法声明明确报错。
4. 调用正式 IntentValidation.validate；失败阻止依赖 Intent 的质量阶段，不影响此前已合法生成的 Level 产物身份，也不篡改上游错误。
5. 正式 sidecar 随本次报告归档；分别记录作者源身份与生成 sidecar 内容身份，使“地图未变但意图变了”也能正确使质量结果失效。

缺少 Intent 不自动创建空声明来取得完整 PASS；独立 Bake 可产生关卡产物，完整验收缺少必需意图输入则未完成。作者显式保存的空意图集合可以合法存在并接受检查，但界面必须显示“未声明设计约束”，不得将其通过表述为“已验证核心机制必要性”或“已证明不存在机制绕过”。是否允许最终整关通过需由完整验收策略单独批准，不能从第五章的无适用检查规则推导出授权。

### 自动绑定范围与同轮一致性（用户明确补充）

自动填写仅限既有正式合同要求的关卡内容标识、规则版本及格式绑定信息。必需机制、可选机制、里程碑和禁止绕过条件完全来源于作者声明，不自动增删或调整，不得为了验收通过修改作者意图。绑定转换是保义映射，不是意图修复或生成器。

输入必须为同一 run_id 所绑定源快照中的作者 Intent，以及该快照本次成功 Bake 的 canonical 产物。不得混用历史 LevelDefinition 与当前编辑中的 Intent；即便历史产物内容哈希相同，首版也不以此绕过本次成功 Bake 要求。Bake 失败时不生成可供当前验收使用的绑定结果，不回退旧产物冒充本次成功。

任务期间源文件或相关配置变化时，继续执行的仅是原快照任务；其结果按第四章标记为非当前/过期，不得显示当前版本 PASS。绑定校验失败明确保留错误，失败候选如作诊断附件必须标明无效，不能作为正式有效 sidecar 发布。

### 单一实现与职责（沿第九章）

- 4A：作者格式、共享适配能力及唯一的纯绑定转换实现；输入固定作者声明和成功 Bake 产物，输出待正式校验的八字段记录，不执行搜索，不自行判定质量 PASS。
- 4B：编辑入口、缺失/空配置提示与诊断展示；调用共享能力，不写另一套绑定转换。
- 4C：调用既有正式 IntentValidation 及质量分析，保留原始错误与证据范围；不重写转换算法。
- 4D：保证同轮快照与 Bake 身份一致，编排 4A 转换和 4C 正式校验/分析，统一汇总与归档；后台 worker 同样调用 4A，不自行拼装第二份 Intent。

这里的单一绑定实现属于工具适配层，消费现有正式合同；不修改现有正式 IntentValidation 或运行时合同。

### 配置引用与版本失败

机制 Resource 保存可复用的正式动作参数，实例保存其身份、所在世界、触发/面绑定及关卡专属目标；具体字段归属表必须消除同一语义字段的双重可写来源。共享配置变更影响全部依赖，不由适配器自动复制或修正。

未知作者版本、无法加载的声明类型、缺失必填字段或正式版本不匹配均显式停止相应阶段。首版不执行静默迁移；未来迁移必须是独立、显式、可审阅的源修改，不能夹带在读取/Bake 中。已有平铺旧 profile 保留其正式 Reader 路径，不因为新增作者 profile 而重写旧 fixture。

本章已按用户补充边界确认。最终字段表仍需在设计文档中完整列出并审查；此处不创建 Resource 类或迁移工具，不修改既有生产代码。

## 已批准验收策略补充 — 显式空 Intent

Status: APPROVED WITH USER-SPECIFIED BOUNDARIES

批准日期：2026-09-22。用户明确选择 A，并给出六项强制边界。此补充收拢第五章验收策略、第六章报告语义和第十章空 Intent 的待决问题；其明确规则优先于前文关于“待决”的历史描述。本次批准不代表其他尚待审查合同字段已冻结。

Decision: A. 允许显式空 Intent 在限定验收范围内通过。

以下候选表仅保留决策依据；B 未采用。

| 方案 | 最终验收含义与取舍 |
|---|---|
| A. 允许限定范围的通过（推荐） | 其他必需门槛均满足时，可以通过，但摘要必须同时显示“未声明设计约束”；意图约束项记为无适用检查，不显示机制必要性或无绕过证明。适合基础关卡、流程验证与尚未声明意图的合法关卡 |
| B. 阻止整关通过 | 其他检查仍运行并保留结果；显式空配置不视为非法或玩法失败，但完整验收缺少策略要求的意图覆盖，不能 PASS。作者需要填写实际约束后重跑 |

### 1. 显式空的定义

必须是作者明确提供、格式有效且必填配置完整的 Intent，其设计约束集合按最终冻结的作者格式为空。当前设计中 required_mechanics、optional_mechanics、expected_milestones、forbidden_bypasses 必须全部为空。

缺少 Resource、未知版本、缺失必填字段、解析失败均不是显式空，不得自动转为空配置。只要存在可选机制、任意里程碑或其他声明，就不能仅因没有必需机制而将整份 Intent 标为空；按各项实际声明判断检查适用范围。

### 2. 空配置仍执行校验

作者格式校验、同轮成功 Bake 后的唯一绑定转换、正式 IntentValidation.validate 对 puzzleintent.v1 的校验全部正常执行，不能把整个 Intent 阶段标成无需校验。

只有确实没有声明内容可检查的意图约束子项才显示“无适用检查”。作者与正式格式校验均有实际结果；按现有接口实际执行的分析也保留原结果，不能以工具层不适用标记覆盖正式返回状态或伪造未执行的正式结果。

### 3. 其他门槛不变

Bake、正式结构与安全校验、UNFILTERED 完整原图搜索、零软锁、所选轨迹语义检查和 GRAPHICAL RuntimeParity 等继续严格按第五章执行。Intent 为空不降低任何适用门槛，也不免除完整图或真实回放要求。

### 4. 最终显示与证明范围

其他适用门槛全部满足、校验成功且报告匹配当前输入时，摘要必须显示：

“验收通过 · 未声明设计约束”

并同时说明：

“未对特定机制必要性、禁止绕过条件或教学里程碑作出证明，因为作者未声明相应约束。”

不能仅显示不带范围说明的绿色 PASS。底层汇总可以为 PASS / COMPLETE，但界面、命令行摘要与导出报告必须保留此限定；不得宣称已验证核心机制必要性或不存在机制绕过。报告过期时在该历史结论之外明确显示已过期，不能保留当前绿色通过状态。

### 5. 不适用、未完成与错误分别表达

| 情况 | 表达 | 可否作为该子项不适用依据 |
|---|---|---|
| 合法 Intent 确实未声明相应约束 | 无适用检查 | 可以，仅限对应约束子项 |
| 预算耗尽、取消、依赖未就绪等 | 未完成，并保留具体原因 | 不可以 |
| 输入非法、解析/绑定校验失败、执行异常等 | 错误，并保留正式诊断或工具阶段错误 | 不可以 |

这些是报告编排层的适用性/完成情况，不增加或篡改正式分析器枚举。任何适用的必需检查未完成或错误均阻止最终通过；不存在相应正式结果时不得补造 COMPLETE。

### 6. 报告追溯、失效与职责

报告必须保留本次实际绑定的 Intent（内嵌或经摘要核验的证据附件）、显式空约束说明、每个实际校验与约束子项的状态及不适用原因。来源快照、level_hash、Intent 身份和 run_id 按既有合同关联，不能只保留一句 PASS。

作者后续补充约束时，旧质量分析和验收结论必须标为过期，即使 level_hash 未变；不能沿用空 Intent 的通过结果。仍由 4A 维护作者格式与唯一转换，4B 展示准确范围，4C 调用正式校验/分析，4D 绑定输入、汇总与归档。

不修改 LevelDefinition、PuzzleState 或 statekey.v1；不复制分析算法，不自动补充作者约束。后续验证设计须覆盖缺失/非法误判为空、仅 optional 非空、空配置校验失败、适用阶段超预算以及补充约束后旧 PASS 失效等边界，本轮不写测试实现。
