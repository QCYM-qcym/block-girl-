# FOUNDATION-0.1 — CONTRACT RECONCILIATION REPORT

**FOUNDATION_CONTRACT_RECONCILIATION_PASS**

2026-09-13。仅完成中央公共合同修订；没有实现 Spatial Mapping、StateKey 或任何新功能。本轮未运行 Godot/Blender，未 commit/push/merge/rebase，未修改或恢复四个并发 worktree。

## 1. Branch / HEAD / 版本

- 唯一写入工作区：`E:/godot/若叶睦/方块少女-若叶睦`。
- Branch：`feat/foundation-core`；开始与结束均核对。
- HEAD：`4643062e83a962000d14f0e1dbfbece6e310d4ed`，未改变；开始工作区干净。
- 公共 API 修订号：`contract_revision=foundation.contract.v1.1`。
- LevelDefinition 的数据标签保留 `schema_version=1 / contract_version=foundation.contract.v1 / orientation_version=cube24.v1 / rule_version=foundation.rules.v1`。19个定义字段、6个状态字段不变；不向数据增加 contract_revision。
- StateKey 格式单独冻结为 `statekey.v1`。

API 修订与数据格式版本分开：B 的三个派生接口以及 validate_snapshot 消费边界明确改用包装，不假装兼容旧裸结果。A 数学编号/算法/API、C 生产查询/API/结果保持不变。

## 2. 实际修改文件

| 文件 | 实际变化 |
|---|---|
| [公共合同](E:/godot/若叶睦/方块少女-若叶睦/docs/superpowers/specs/2026-09-13-foundation-core-contracts.md) | Spatial结果/候选阶段/范围失败、ValidationCode语义表、StateKey精确格式及版本、接口/依赖边界 |
| [架构 Spec](E:/godot/若叶睦/方块少女-若叶睦/docs/superpowers/specs/2026-09-13-foundation-spatial-puzzle-architecture-design.md) | 同步空间/状态规则与§33.7真实反馈；保留原冻结历史 |
| [B Spatial plan](E:/godot/若叶睦/方块少女-若叶睦/docs/superpowers/plans/2026-09-13-foundation-spatial-model.md) | 只追加 Task 3/4，定义新接口、范围回归、候选/四态结果测试及新增文件权限 |
| [D Data Contracts plan](E:/godot/若叶睦/方块少女-若叶睦/docs/superpowers/plans/2026-09-13-foundation-data-contracts.md) | 只追加 Task 3/4，定义canonical码收敛、StateKey入口/golden/格式测试及新增文件权限 |
| [本报告](E:/godot/若叶睦/方块少女-若叶睦/docs/development-records/FOUNDATION_CONTRACT_RECONCILIATION_REPORT.md) | 新增本轮结论、证据、恢复边界 |

A/C 计划未改。没有新增/修改 .gd、.uid、场景、资产、project.godot、P-01、tests/visual 或 Obsidian 文件。B/D 原计划内容逐字前缀比较保持不变，新增部分明确覆盖旧接口示例的执行含义，不抹除各 Work 完成历史。

## 3. 四路真实反馈与根因

下列是只读报告/日志的既有运行结果，**不是本轮重跑测试**。

| Work | 已有结果 | 本次收敛 |
|---|---|---|
| A Orientation | 报告77,965数学检查+66旧逻辑回归通过；CONTRACT_MISMATCH: NONE | cube24.v1、identity0、先b后a、transpose、Frame重定向均不改 |
| B Spatial | 最终1018 checks、2 failures；CONTRACT_MISMATCH，不能PASS | 候选/歧义接口缺失；Vector3i int32溢出被偶数/快照检查漏过；还缺六FaceNode工厂签名 |
| C Celestial | 132 checks、failures=[]、stderr为0字节；模块PASS | 保留Slot/Lighting；同步说明事务/busy仅为后续调用层合同 |
| D Contracts | 结构655 checks PASS，但StateKey未实现、扩展CONTRACT_MISMATCH | 冻结入口/格式/失败结果；统一已确定的Celestial引用错误使用1300 |

根因是 FOUNDATION-0 冻结语义但没有完全冻结结果/API传播形状，导致 B/D 无法在自身文件权限内决定公共接口。本轮在中央修规范，不将缺口变成局部实现自由裁量。

报告来源（各自 worktree 只读）：

- [A 报告](E:/godot/worktrees/block-girl-foundation-orientation/docs/development-records/FOUNDATION_ORIENTATION_MATH_REPORT.md)
- [B 报告](E:/godot/worktrees/block-girl-foundation-spatial/docs/development-records/FOUNDATION_SPATIAL_MODEL_REPORT.md)
- [C 报告](E:/godot/worktrees/block-girl-foundation-celestial/docs/development-records/FOUNDATION_CELESTIAL_LIGHTING_REPORT.md)
- [D 报告](E:/godot/worktrees/block-girl-foundation-contracts/docs/development-records/FOUNDATION_DATA_CONTRACTS_REPORT.md)

## 4. Spatial Query 最终接口与结果

唯一 Owner 为 SPATIAL，完整类型签名见公共合同§9。

| 文件 | API / 返回schema |
|---|---|
| surface_geometry.gd | resolve_cube(cube,world_transform,group_transform) → SpatialQueryResult，value=ResolvedCube |
| surface_geometry.gd | resolve_anchor(resolved_cube,face) → SpatialQueryResult，value=FaceAnchor |
| surface_geometry.gd | snapshot(level,state) → SpatialQueryResult，value=SpatialSnapshot |
| surface_geometry.gd | anchor_overlap(source,target) → AnchorOverlapResult |
| surface_geometry.gd | classify_face_compatibility(source,target) → FaceCompatibilityResult |
| surface_geometry.gd | make_face_nodes(cube_id) → 六个独立默认FaceNode；face_frame/face_id原签名不变 |
| spatial_validation.gd | validate_snapshot(snapshot_result,faces) → Array[ValidationIssue] |
| mapping_query.gd | discover_mapping_candidates(snapshot_result,faces,source_face,target_layer) → MappingDiscoveryResult |
| mapping_query.gd | collect_mapping_candidates(snapshot_result,faces,source_face,target_layer,enabled_compatibilities) → MappingCandidateResult |
| mapping_query.gd | resolve_mapping(collection_result) → MappingResolutionResult |

三个显式阶段：Discovery按另一层walkable与整数Anchor重合发现pairs；Classification按法线输出SAME_NORMAL/OPPOSITE_NORMAL，collect只保留配置启用的分类；Resolution按完整候选数量解析。SpatialMappingCandidate={source_face,target_face,compatibility}，ID为StringName，compatibility为公共枚举。候选按完整source_face/target_face字节序排序，不依赖Dictionary插入顺序。

AnchorOverlap只比较三个整数坐标分量，不用epsilon、距离或屏幕投影。FaceCompatibility只负责几何；垂直法线是正常不兼容null，损坏Frame才是错误。两者均不判断Light/ShiftPermission/busy。多候选不能按阴影或blocked裁掉到一项；后续Kernel拿到UNIQUE才继续完整ShiftPermission。

| MappingResolutionStatus | mapping / candidates / issues |
|---|---|
| NONE=0 | null / [] / NO_SHIFT_MAPPING=1400 |
| UNIQUE=1 | 唯一候选副本 / 全部单项 / [] |
| AMBIGUOUS=2 | null / 全部canonical候选 / AMBIGUOUS_SHIFT_MAPPING=1401 |
| ERROR=3 | null / [] / 原始上游或结构错误；不能伪装NONE |

有效几何快照与独立resolution测试分开：两个目标Cube的相对内部面虽可共享Anchor，但都walkable会先触发SEALED_WALKABLE_FACE，不能当作有效多候选集成证据。计划保留独立完整候选集合的AMBIGUOUS单元用例，结构无效则真实查询ERROR；不为凑多候选案例放松已冻结结构规则。

## 5. Overflow 最终语义

唯一错误码 **ARITHMETIC_OVERFLOW=1105**；没有COORDINATE_OVERFLOW别名。Vector3i坐标分量是int32；标量int64用于精确临时运算。先提升分量再运算，完整Group端态、World端态与全部六面Anchor输出各自检查int32；不能先发生Vector3i wrap再验偶数。最终可表示的identity大pivot不应误拒，Group超界不能靠World抵消后继续。

SpatialQueryResult={ok,value,issues}；失败ok=false、value=null、ERROR issues，不提供部分快照。validator传播原始1105，Mapping最终ERROR，不调用Lighting，不生成假映射。空间overflow details明确operation/component/representation/operands/minimum/maximum；C沿用自己的LightQueryResult与issue details，不要求改成Spatial包装。

保留两项真实失败为恢复回归：LEFT Anchor预期x=-2147483649，以及World rotation4/pivot x=2147483646后的中心预期x=4294967292。它们均须在构造Vector3i前拒绝；历史wrap为2147483647或-4不代表合法。C有理数中间乘法超int64同样1105，无浮点回退；其int64内部AABB边界不属于新的Vector3i输出。

## 6. ValidationCode canonical mapping

完整规范与形状错误边界见公共合同§8.1；没有新增错误码数值。

| Requested Semantic | Canonical code |
|---|---|
| Duplicate Cube ID | DUPLICATE_ID=1005 |
| Cube Overlap | SAME_WORLD_CUBE_OVERLAP=1200 |
| Invalid Face | INVALID_FACE=1103；缺目标引用1006 |
| Invalid Orientation | INVALID_ORIENTATION=1101 |
| Invalid Rotatable Group State | 姿态/域1101；归属INVALID_GROUP=1202；边INVALID_ROTATION_EDGE=1203 |
| Invalid Celestial Reference | INVALID_CELESTIAL_REFERENCE=1300 |
| Invalid Mechanism Reference | INVALID_REFERENCE=1006 |
| Invalid Spawn | 缺字段MISSING_FIELD=1002；位置引用1006；面1103；姿态1101；安全PLAYER_UNSAFE=1204 |
| Invalid Exit | 正式字段goal；缺字段1002；目标/flag引用1006；面1103 |
| Ambiguous Shift Mapping | AMBIGUOUS_SHIFT_MAPPING=1401 |
| Player Unsafe After Rotation | PLAYER_UNSAFE=1204 |
| Coordinate Overflow | ARITHMETIC_OVERFLOW=1105 |

细分语义各只有一个canonical名字；复合输入检查不是另一个笼统错误枚举。D已知Slot引用失败从通用1006统一到已有1300，需更新对应断言；其它非Celestial引用仍1006。类型/缺字段/重复ID是不同语义，保留原码。C不跟随D旧通用码降级。

## 7. StateKey 输入、返回格式与版本

Owner DATA；唯一文件 `foundation/contracts/state_key.gd`；唯一静态函数 `build(level: Dictionary,state: Dictionary)->Dictionary`。

输入严格验证19字段LevelDefinition与6字段PuzzleState；编码namespace=level.content_hash+rule_version，以及全部player(location.layer/cube_id/face,orientation)、world_orientations[Surface,Inner]、celestial.slot_id、group_orientations、mechanism_states、level_flags。map恰好覆盖定义且按ID排序，false值不省略；未知/表现/派生字段直接UNKNOWN_FIELD，不静默忽略。

返回StateKeyResult={ok:bool,key:String,issues:Array[ValidationIssue]}。成功key为 `statekey.v1:` + canonical JSON，完整String可直接作为visited键；失败key=""，不能进入visited。固定字段序、十进制orientation、枚举符号、ID字符串、UTF-8无BOM、结构无空白、无末尾LF/CR、精确JSON转义。Unicode合法scalar原样编码，不正规化。golden A/B及转义片段均在合同§6.2，只有这一套格式。

Equality比较完整规范String；哈希仅供Dictionary查桶，不以短hash代替相等；持久化、debug、回放也使用同一String。未来核心状态schema变化必须升级statekey.v2。本版只接受foundation.rules.v1，其它rule_version返回VERSION_MISMATCH；不声称支持尚未声明的新规则。content_hash真实性仍由Baker/定义提供者负责，StateKey不重算Bake。

## 8. Work C compatibility check（只读）

检查C生产脚本、完整函数列表、测试真实依赖调用、外部integration-project及[verified-sources.json](E:/godot/foundation-evidence/celestial-1c/verified-sources.json)。重新计算清单中全部18个文件（9个脚本与9个UID）的SHA-256：当前Owner源文件=清单hash=外部测试工程副本，18/18一致。C自己的foundation目录只含celestial的两脚本及UID。

| 检查项 | 结论 |
|---|---|
| 是否另写/复制Orientation算法到C生产模块 | 未发现；没有24态表或compose/reframe替代实现；MATH依赖仅在外部测试工程逐字节复制 |
| 是否另写/复制Spatial变换算法到C生产模块 | 未发现；C消费FaceAnchor/ResolvedCube值，真实测试调用B.snapshot；不存在C版快照生成 |
| C._valid_frame | signed-axis/right-handed输入校验，非Orientation/Spatial变换的重复实现 |
| overflow/result冲突 | 无；既有1105、ok=false/light_state=null/reason=INVALID保持；宽整数有理运算范围与新Spatial边界兼容 |
| fixtures / adapter | 单元测试固定整数fixture；真实集成外部依赖为原文件副本，不是局部改写stub |
| 事务/busy实现 | C报告/计划明确没有Scheduler/Kernel/Runtime锁、提交调度或Reset回调；132项不证明这些行为 |

关键源/副本一致的SHA-256：MATH `D228A4230A6E8E2C72BDE07AF030E623BD3363FECAF17010621E54BB25B093F3`；SPATIAL geometry `B3EE6C4A52D6353C31BBC516A94D2FD36BF5A9EDA4B395D272185B5D56DB0A97`；SPATIAL validation `215963567516606FB3BE2D708A15BE2408F9975260E120B02EB013EE53C96635`。

**INTEGRATION_WATCHPOINT：** 未发现重复算法；但C真实集成测试当前按旧裸snapshot读取cubes/anchors。B恢复后C须在自己的测试先检查snapshot.ok，读取snapshot.value，将包装交给validate_snapshot，再把裸FaceAnchor/ResolvedCube传给Lighting。C生产接口无需改。旧132项只证明清单中的旧依赖版本，不能证明B已知两项极端坐标安全或新包装已接通。此次未修改C/其外部测试工程，后续同步须重跑并记录新hash。

## 9. 恢复实施文件与同步要求

| Work | 后续可恢复文件 / 必须工作 |
|---|---|
| B | 修改foundation/spatial/surface_geometry.gd、spatial_validation.gd；新增mapping_query.gd及UID；扩充tests/foundation/spatial/test_spatial.gd；修复2项范围失败、接包装、六面工厂、三阶段候选/四态结果，再更新自己的报告/计划 |
| D | 修改foundation/contracts/foundation_types.gd、contract_validation.gd；新增state_key.gd及UID；修改test_contracts.gd、新增test_state_key.gd及UID；统一1300、四态枚举、完整StateKey与新旧回归，再更新自己的报告/计划 |
| A | 同步阅读公共API修订即可；数学脚本、24表、签名与已通过逻辑无需修改 |
| C | 同步阅读；生产算法/API不改；B升级后由C适配自身真实集成测试并重新验收 |

**可以恢复 Work B / D：YES，公共合同缺口已解除。** 需消费主工作区这两份新spec与各自计划追加部分，记录contract_revision；数据标签没变不代表旧Spatial裸API继续合法。D先提供新增公共枚举后B完成真实依赖集成，B不得私建枚举/改D。此次只交付中央文档，没有复制文档进四worktree、没有发送恢复消息或启动开发。

## 10. 本轮自检与git diff

本轮实际执行的文档/文件验证：

- git branch/HEAD/status与diff --check；无格式错误。
- 两个golden JSON解析、原字段序、六状态字段、64位hash文本、无空白往返一致；完整key分别347/428 UTF-8字节；转义片段解码匹配预期字符。仅验证文档golden，不是实现StateKey。
- cube24.v1整节与HEAD逐字比较不变；A/C公共API行及C输出记录行不变；A/C计划无diff。
- B/D旧计划与当前文件前缀逐字一致，只追加恢复内容；公共新签名/所有权与追加任务逐项核对。
- 四worktree所有tracked+非ignored untracked文件，在编辑前后按path排序对每个文件SHA-256再聚合；分支/HEAD/数量/摘要全部一致（不宣称覆盖ignored缓存）。
- C清单18/18源/副本hash相同；既有final.stdout为132 checks、failures=[]，stderr为0字节。
- 人工语义自检9项：canonical名字单一；StateKey格式单一；overflow单码且原子失败；Overlap不混权限；Compatibility不混Light；多候选不选第一；derived不进key；A/C无无故破坏；无功能代码实现。

| 只读worktree | 文件数 | 编辑前后相同的聚合SHA-256 |
|---|---:|---|
| orientation | 2287 | CB950054DD5C694DC99A3EB7707BB5393FE8770C81C471D44A184EC6EE0E4E3B |
| spatial | 2289 | FF10E68208105BD1E801C93016D8790197ACED78C7F7421C2FB5890ED0D4EE66 |
| celestial | 2289 | 82B3B39DBFB6F48ECCBA44C3E1BDD04B2C5A5E7B9AFF1718B875A55831E46422 |
| contracts | 2291 | 6F902AB1E39B4F2FE90B1DC99F7D907F3707C021C93B00276C6D7AA2FD1C193C |

主工作区tracked diff：4个Markdown，291行新增/11行删除。另新增本报告（untracked，未暂存），合计5个文档文件。具体tracked numstat：D plan +59/-0；B plan +57/-0；公共合同 +150/-9；架构Spec +25/-2。`git diff` 可查看完整四文件补丁；本报告作为新文件另计，不将未暂存文件冒充已经提交。没有其它业务/资产差异，没有执行commit/push/merge。

本PASS只针对中央合同修订。B范围缺陷与D StateKey实现仍待各Work恢复后通过新验收；Kernel/busy调度、Baker、BFS、Editor、Runtime migration、Blender与P-02均未开始。
