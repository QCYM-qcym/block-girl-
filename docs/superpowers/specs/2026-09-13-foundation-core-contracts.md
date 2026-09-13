---
title: FOUNDATION-0.1 Core Contracts Reconciliation
contract_version: foundation.contract.v1
contract_revision: foundation.contract.v1.1
statekey_version: statekey.v1
orientation_version: cube24.v1
status: FROZEN CONTRACT / RECONCILED / IMPLEMENTATION PENDING IN B AND D
date: 2026-09-13
---

# FOUNDATION-0 公共合同

本文件是第一波四个 Work 的共同接口来源。架构依据为同目录 `2026-09-13-foundation-spatial-puzzle-architecture-design.md`，尤其 §33 DECISION-01/02/03。只冻结合同，不声明新系统已实现；本轮不创建运行代码。变更公共名称、字段、枚举值、坐标或 ID 排序必须先串行修订合同版本，再同步四计划，不能在某个 Work 私自解释。

FOUNDATION-0.1 将公共 API 修订号冻结为 `foundation.contract.v1.1`（contract_revision）。LevelDefinition 的序列化 schema/contract/orientation/rule 标签仍为 `1 / foundation.contract.v1 / cube24.v1 / foundation.rules.v1`：19 个定义字段和 6 个状态字段未改变，不向记录新增 contract_revision 字段。API 修订与数据格式版本分开；集成报告必须记录两者。§9 的三个 Spatial 派生接口改为结果包装，这是明确的 API 不兼容修订，旧裸返回接口不再作为第二套合法格式。A 的八个数学接口、C 的两个查询接口及其输出记录不变。新增 StateKey 编码单独使用 statekey.v1。只扩充 B/D 后续实施范围，本轮仅改文档。

## 1. 路径、风格与所有权

当前仓库使用 snake_case 文件/字段、PascalCase preload 别名、纯逻辑 RefCounted 与独立 SceneTree 测试，未采用通用全局 class_name 注册。后续沿用：每个脚本由调用方 preload，禁止新增同名全局类、迁移旧脚本或修改 P-01。

| 唯一 Owner | 预计实现路径 | 职责 |
|---|---|---|
| DATA | `foundation/contracts/foundation_types.gd` | 公共枚举；不含 RotationAxis |
| DATA | `foundation/contracts/contract_records.gd` | 本文记录的工厂、深复制；非业务结算 |
| DATA | `foundation/contracts/contract_validation.gd` | 类型/版本/引用形状/域检查与 ValidationIssue |
| DATA | `foundation/contracts/state_key.gd` | 唯一 statekey.v1 编码入口；不做搜索或内容 Bake |
| MATH | `foundation/orientation/discrete_orientation.gd` | 唯一 24 态数学与内部 RotationAxis |
| SPATIAL | `foundation/spatial/surface_geometry.gd` | 纯整数层级变换、FaceAnchor/SurfaceFrame、结构快照 |
| SPATIAL | `foundation/spatial/spatial_validation.gd` | 初态快照的重叠/封闭面/格点检查 |
| SPATIAL | `foundation/spatial/mapping_query.gd` | 单稳定快照的候选发现、分类收集、唯一映射解析 |
| CELESTIAL | `foundation/celestial/celestial_rules.gd` | Slot 请求解析，纯数据接口 |
| CELESTIAL | `foundation/celestial/logical_lighting.gd` | 单个稳定快照的逻辑入射/遮挡查询 |

第一波仍不实现完整全构型 Validator、Kernel、BFS、Scheduler、InputMapper、Editor、Baker 或 Runtime 迁移。FOUNDATION-0.1 补充授权 B 后续实现单稳定快照的几何 Mapping Query、D 后续实现 StateKey；不包含跨状态 Mapping Solver、路径搜索或完整 ShiftPermission。Lighting 沿用 C 既有范围。

公共记录为规范 Dictionary：字段键统一 String，ID 值统一 StringName，枚举/Orientation 值为 int；Vector3i 为内存坐标。不是 Node、Resource 或自定义全局类。类型名是文档 schema 名，跨模块不得各自再建同名 class_name。序列化时 ID 变为字符串、Vector3i 变为三个整数的数组、枚举变为本文件符号名；读入时恢复内存表示。Dictionary 的可变性由所有权约束：所有查询不修改输入；工厂和下一状态输出深复制集合。

枚举数值是内存 ABI，符号字符串是持久化 ABI，二者都冻结；序列化字段不能同时接受数字与字符串两种未标版形式。方法表是内存接口，本波不实现通用序列化器。`make_action` 的 payload 不得含 kind；若含则返回空 Dictionary，后续 validate_action_shape 必须拒绝，不能覆盖显式 kind 或默默删除冲突字段。

`PlayerSurfaceFrame` 是语义称呼，唯一结构类型为 `SurfaceFrame`；`PlayerLayer` 与 `RotateTarget` 均取 `WorldLayer` 值，但分别是 PlayerLocation 字段与 Runtime UI 字段。禁止另建 PlayerLayer/RotateTarget 枚举。旧 CubeOrientation 是历史类，目标数学类型只叫 DiscreteOrientation。

## 2. 枚举：名字、数值、唯一含义

每行数值从左到右明确给出；值不可依赖自动重新排序。错误输入拒绝，不取模、不转成默认值。

| 枚举 | 固定成员 |
|---|---|
| WorldLayer | SURFACE=0, INNER=1 |
| FaceDirection | FRONT=0, BACK=1, LEFT=2, RIGHT=3, TOP=4, BOTTOM=5 |
| RotationIntent | TURN_LEFT=0, TURN_RIGHT=1, TIP_UP=2, TIP_DOWN=3, ROLL_CLOCKWISE=4, ROLL_COUNTERCLOCKWISE=5 |
| RotationAxis | X=0, Y=1, Z=2；仅 MATH 脚本内部，禁止出现在 LevelDefinition/PuzzleAction/序列化字段 |
| FaceCompatibility | SAME_NORMAL=0, OPPOSITE_NORMAL=1 |
| MappingResolutionStatus | NONE=0, UNIQUE=1, AMBIGUOUS=2, ERROR=3；只表示查询解析结果，不进入 PuzzleState |
| LightState | LIT=0, SHADOW=1；无 PARTIAL/UNKNOWN，无法计算通过错误结果表达 |
| GlobalTransitionState | IDLE=0, MOVING=1, TRANSITION=2 |
| GlobalTransitionKind | NONE=0, CELESTIAL=1, WORLD_ROTATION=2, GROUP_ROTATION=3, SHIFT=4, FACE_TRANSITION=5 |
| FaceAxis | U_POS=0, V_POS=1, U_NEG=2, V_NEG=3 |
| PuzzleActionKind | MOVE=0, SHIFT_WORLD=1, ROTATE_SURFACE=2, ROTATE_INNER=3, USE_FACE_TRANSITION=4, TRIGGER_MECHANISM=5, LOCAL_GROUP_ROTATE=6, MOVE_CELESTIAL=7 |
| CelestialOp | SET_SLOT=0, NEXT_SLOT=1, PREVIOUS_SLOT=2, TOGGLE_BETWEEN=3 |
| ValidationSeverity | ERROR=0, WARNING=1, INFO=2 |

GlobalTransitionState 描述 Runtime 会话：MOVING 为唯一已接受事务的视觉运动，TRANSITION 为原子切换/提交准备；不是 Stable PuzzleState 的一部分。active_kind 给出事务种类，不再使用 CELESTIAL_MOVING 或 GlobalState 别名。它与本地 roll phase 是不同状态域。

RotationIntent 是输入意图，不是 Kernel 的世界轴动作。未来 Adapter 提供已量化的右手观察基 C=[right,up,toward_viewer]：TURN_LEFT/RIGHT 绕 up 正/负 90°；TIP_UP/DOWN 绕 right 负/正 90°；ROLL_CLOCKWISE/COUNTERCLOCKWISE 绕 toward_viewer 负/正 90°。无法得到确定离散轴时拒绝输入，不能猜。解析后的 PuzzleAction 只带 rotation_delta；当前第一波不实现 Adapter 或相机。

## 3. 身份与坐标字段

CubeCellId、RotatableGroupId、CelestialSlotId、MechanismId、FaceTransitionId、LevelId、LevelFlagId 均为 StringName；格式 `[a-z][a-z0-9_]*`，在同类、同一 LevelDefinition 中唯一。CubeCellId 跨两个 WorldLayer 也必须唯一，旋转/世界变化不改 ID；不同类型可同字面 ID，因为引用字段带类型。没有默认合法 ID；空 StringName 仅用于本文明确允许的“无引用”。

FaceNodeId 为 `cube_id/FACE_SYMBOL`，例如 `bridge_01/TOP`；FACE_SYMBOL 必须为六个大写符号之一。由 CubeCellId 与本地 FaceDirection 唯一生成，禁止作者另填任意 Face ID。ID 不编码可变 Shared Space 法线，不重复编码 layer。引用的 layer 从 CubeCell 定义检查，不靠字符串推断。

| 类型 | 必须字段 / 内存类型 |
|---|---|
| CubeCell | `cube_id: CubeCellId`, `layer: WorldLayer`, `center2: Vector3i`, `orientation: DiscreteOrientation`, `group_id: RotatableGroupId`（空表示无组）, `occludes_light: bool`, `tags: Array[StringName]` |
| FaceNode | `face_id: FaceNodeId`, `cube_id: CubeCellId`, `face: FaceDirection`, `walkable: bool`, `shift_exit_blocked: bool`, `shift_entry_blocked: bool`, `mechanism_ids: Array[MechanismId]` |
| DiscreteTransform | `rotation: DiscreteOrientation`, `pivot2: Vector3i`；含 pivot 的旋转不是平移变换 |
| SurfaceFrame | `u: Vector3i`, `v: Vector3i`, `normal: Vector3i`；三轴单位正交，u×v=normal |
| FaceAnchor | `face_id: FaceNodeId`, `layer: WorldLayer`, `position2: Vector3i`, `frame: SurfaceFrame`；无可编辑重复 normal |
| PlayerLocation | `layer: WorldLayer`, `cube_id: CubeCellId`, `face: FaceDirection`；不另存 face_id、Anchor 或物理姿态 |
| PlayerState | `location: PlayerLocation`, `orientation: DiscreteOrientation`（Shared Space 玩家姿态） |
| WorldDefinition | `layer: WorldLayer`, `pivot2: Vector3i`, `initial_orientation: DiscreteOrientation`, `allowed_states: Array[int]`, `allowed_rotation_deltas: Array[int]`, `allowed_rotation_intents: Array[RotationIntent]` |
| RotatableGroup | `group_id: RotatableGroupId`, `layer: WorldLayer`, `cube_ids: Array[CubeCellId]`, `pivot2: Vector3i`, `initial_orientation: DiscreteOrientation`, `allowed_states: Array[int]`, `allowed_rotation_deltas: Array[int]`, `edges: Array[RotationEdge]` |
| RotationEdge | `from_orientation: int`, `rotation_delta: int`, `to_orientation: int`；delta 必须 ±90°，to=compose(delta,from) |

每个 Cube 必须有且仅有六个 FaceNode，walkable 默认 false，两个 Shift 限制默认 false。Cube.group_id 与 Group.cube_ids 是同一归属的正反索引，必须完全一致，不能分别决定归属。首版无跨世界组、无嵌套组、一个 Cube 最多一个组。

### 3.1 坐标与量化

Godot 3D 采用右手系：+X 右、+Y 上，Camera 的观察前方通常为 -Z。项目逻辑 FRONT 明确为 +Z（对应 Godot Vector3.BACK），BACK=-Z（对应 Vector3.FORWARD）；禁止直接拿 Godot 常量 FORWARD 当 FaceDirection.FRONT。没有固定玩法重力。

Cube 边长 L=1 个逻辑单位，对应 Godot 1.0 世界单位；逻辑 Cube 中心是整数 L 网格。所有逻辑位置/pivot/Slot/Anchor 字段以 L/2 为单位，名称统一后缀 `2`。Cube.center2 每分量必须偶数；pivot2 / Slot.position2 可奇数，但每个合法旋转端态必须仍使 Cube 中心全偶数。

未来导入边界：以 Shared Space 根的逆变换将可视世界点 p 转入逻辑空间，计算 q=2p/L；每分量按“最近整数、恰半值远离零”取整，并要求 |q-round(q)|≤0.000001。超过容差返回 OFF_LATTICE，不静默吸附；导入合法后只保留整数。Cube 中心另验偶数。Basis 的三列须各在 0.000001 内匹配有符号单位轴且行列式 +1，否则 INVALID_ORIENTATION；缩放、剪切和镜像禁止进入规则数据。该容差只用于 Authoring 导入，AnchorOverlap 必须是 Vector3i 完全相等，不能用 epsilon。

内存 Vector3i 的每个坐标分量范围固定为有符号 int32：[-2147483648,2147483647]。GDScript 标量 int 为 int64，不能误把两者视为同一范围。导入值须先验范围再构造 Vector3i；范围越界为 ARITHMETIC_OVERFLOW，格点错误为 OFF_LATTICE，互不替代。完整溢出传播合同见 §5.1。

### 3.2 面基与层级变换

| FaceDirection | normal | u | v | Frame 的 cube24.v1 ID |
|---|---|---|---|---|
| FRONT | +Z | +X | +Y | 0 |
| BACK | -Z | -X | +Y | 4 |
| LEFT | -X | +Z | +Y | 18 |
| RIGHT | +X | -Z | +Y | 22 |
| TOP | +Y | +X | -Z | 3 |
| BOTTOM | -Y | +X | +Z | 2 |

矩阵列向量、主动旋转；右手正 90°：X:+Y→+Z，Y:+Z→+X，Z:+X→+Y。从正轴端朝原点看是逆时针。

Cube.center2 是父 World 未旋转坐标，Cube.orientation 是自身静态局部基 C。Group pivot2 也在未旋转父 World 坐标；无 Group 时 G=I。World pivot2 在 Shared Space。对本地面 (n,u,v)：

```
group_center2 = pg + G * (center2 - pg)
shared_center2 = pw + W * (group_center2 - pw)
R = W * G * C
anchor.position2 = shared_center2 + R * n
anchor.frame = {u: R*u, v: R*v, normal: R*n}
```

没有 Group 时 group_center2=center2；无额外隐式平移。每次从不可变定义和已提交状态重算，不把上一帧浮点结果累乘。World delta 在 Shared Space 左乘 W，Group delta 在父 World 左乘 G；支撑玩家的 Shared Space delta 分别为 delta、W*delta*inverse(W)。Face ID 始终本地面身份。

Local MOVE 切向 d∈{±u,±v}，玩家 roll 为绕 normal×d 正90°后左乘旧姿态。OPPOSITE Shift 为 compose(target_frame_id,inverse(source_frame_id)) 左乘玩家；SAME_NORMAL 不作切向自动对齐。例：源 TOP Frame=3、目标 BOTTOM Frame=2、旧姿态0→新姿态1；若目标 frame=(+Z,-X,-Y)=17，同一源/旧姿态→19。两个同样反法线目标不能硬编码成同一个半圈。

## 4. DiscreteOrientation 稳定编号

内存/序列化为 int 0..23，identity=0，版本 `cube24.v1`。表示三列 right/up/forward；forward=right×up。按 right 从 [+X,-X,+Y,-Y,+Z,-Z] 枚举，up 按同序跳过平行项；即下表。编号不能由 DFS/BFS/Dictionary 遍历临时决定。

| ID | right | up | forward |
|---|---|---|---|
| 0 | +X | +Y | +Z |
| 1 | +X | -Y | -Z |
| 2 | +X | +Z | -Y |
| 3 | +X | -Z | +Y |
| 4 | -X | +Y | -Z |
| 5 | -X | -Y | +Z |
| 6 | -X | +Z | +Y |
| 7 | -X | -Z | -Y |
| 8 | +Y | +X | -Z |
| 9 | +Y | -X | +Z |
| 10 | +Y | +Z | +X |
| 11 | +Y | -Z | -X |
| 12 | -Y | +X | +Z |
| 13 | -Y | -X | -Z |
| 14 | -Y | +Z | -X |
| 15 | -Y | -Z | +X |
| 16 | +Z | +X | +Y |
| 17 | +Z | -X | -Y |
| 18 | +Z | +Y | -X |
| 19 | +Z | -Y | +X |
| 20 | -Z | +X | -Y |
| 21 | -Z | -X | +Y |
| 22 | -Z | +Y | +X |
| 23 | -Z | -Y | -X |

compose(a,b)=a×b，先 b 后 a；inverse 为转置。六个单位 ±90° 增量固定：X+=2、X-=3、Y+=22、Y-=18、Z+=9、Z-=12。ROT_X_POS/NEG、ROT_Y_POS/NEG、ROT_Z_POS/NEG 为对每个旧姿态左乘相应增量的 24 项查表，不是另六个编号体系。

## 5. Celestial、结构快照与光照输出

| 类型 | 必须字段 |
|---|---|
| CelestialSlot | `slot_id: CelestialSlotId`, `position2: Vector3i`（Shared Space 固定源点） |
| CelestialState | `slot_id: CelestialSlotId`；仅一份，不分 sun_slot/moon_slot |
| CelestialDefinition | `slots: Array[CelestialSlot]`, `slot_order: Array[CelestialSlotId]`, `wrap: bool`, `initial_slot_id: CelestialSlotId`, `edges: Array[SlotEdge]` |
| SlotEdge | `from_slot_id: CelestialSlotId`, `to_slot_id: CelestialSlotId` |
| ResolvedCube | `cube_id`, `layer`, `center2`（已解析 Shared Space）, `orientation`（WGC）, `occludes_light: bool` |
| SpatialSnapshot | `cubes: Array[ResolvedCube]`, `anchors: Array[FaceAnchor]`；按 cube_id / face_id 字节序排序，只含同一稳定配置 |
| LightQueryResult | `ok: bool`, `light_state: LightState`（失败时 null）, `reason: StringName`, `occluder_id: CubeCellId`（无则空）, `issues: Array[ValidationIssue]` |
| SlotRequestResult | `ok: bool`, `changed: bool`, `next_slot_id: CelestialSlotId`（失败时空）, `issues: Array[ValidationIssue]` |

LightQueryResult.reason 仅 FRONT_CLEAR / BACK_OR_TANGENT / OCCLUDED / INVALID；ok=false 不等于 SHADOW。同世界遮挡立方体在 center2±(1,1,1) 内；精确射线 t∈(0,1)，n·(source-anchor)>0 才可亮，其它归 SHADOW。其他 Cube 擦边算阻挡；接收 Cube 仅终点不计，源点位于该世界遮挡体闭包内部或边界则 LIGHT_SOURCE_INVALID。同世界多个遮挡者取最小精确 t，平局按 cube_id。跨世界 Cube 不遮挡，视觉灯光不参与。整数中间量若会溢出 int64，返回 ARITHMETIC_OVERFLOW，禁止浮点回退。

NEXT/PREVIOUS 使用 slot_order；不环绕时越界拒绝 SLOT_STEP_UNAVAILABLE；TOGGLE 使用明确两端，当前不在两端则拒绝。所有变更必须是 edges 的有向边；设置当前 Slot 成功但 changed=false，不生成新的全局事务或 Solver 自环。Slot 请求解析不自行推进 CelestialState，不创建 Timer。

### 5.1 Spatial 范围与失败结果

`SpatialQueryResult` 的唯一字段为 `ok: bool`, `value: Dictionary|null`, `issues: Array[ValidationIssue]`。resolve_cube 的 value 是 ResolvedCube；resolve_anchor 的 value 是 FaceAnchor；snapshot 的 value 是 SpatialSnapshot。成功为 ok=true、非 null value、issues=[]；失败为 ok=false、value=null、至少一条 ERROR issue。禁止返回空成功快照、部分 cubes/anchors、默认原点或 identity 来代替失败。各调用者先检查 ok，再读 value；禁止直接把包装传给 Lighting.query。

- 按分量提升到 int64 **后**做差、符号置换、加 pivot 和加 normal；不能先做 Vector3i 减法/取负/加法再提升。使用唯一 MATH.columns/compose 的基与编号，不复制 24 态表或旋转组合算法。A.apply 的 Vector3i 返回边界不能承载超 int32 中间值；该签名不改，SPATIAL 负责宽整数位置运算。
- `pg + G*(center2-pg)` 的完整结果、`pw + W*(group_center2-pw)` 的完整结果以及每个派生 Anchor 分别必须落入 int32。差向量/旋转差向量是 int64 临时量，不要求落入 int32，因此 identity + 极端 pivot 但最终中心合法不能误拒绝。Group 结果越界即失败，不能靠后续 World 旋转把它抵消后放行。
- 任何承诺输出的坐标越界，或精确整数计算将超 int64，均为唯一 `ARITHMETIC_OVERFLOW=1105`。预检在危险运算/Vector3i 构造之前完成；不 wrap、不 clamp、不浮点近似、不依赖 assert 报用户数据错误。纯几何范围安全并不代表偶数格点/支撑安全通过。
- resolve_cube / resolve_anchor 验证各自记录形状、引用字段格式及方向/姿态域；snapshot 先通过 DATA level/state shape，再派生全部 Cube 的全部六个 Anchor（包含不可站立面）。任一错误使整个 snapshot 原子失败，不能漏掉坏 Cube/Face 后继续发现候选。
- `validate_snapshot(snapshot_result,faces)` 接收 SpatialQueryResult。上游合法失败包装直接深复制并返回其 issues；包装损坏返回结构错误。成功包装才检查 raw value 的偶数格点、重叠、封闭面、Anchor 公式等。重新验证 Anchor 也必须使用 checked resolve_anchor 并传播 1105。对已丢失溢出信息的历史 wrapped Vector3i 不可能逆向恢复，不能用后置校验替代生成边界。
- 溢出 issue 保留原 code/severity/path/entity_ids。details 固定提供 `operation: String`（GROUP_TRANSFORM / WORLD_TRANSFORM / ANCHOR_DERIVATION）、`component: String`（x/y/z）、`representation: String`（int32/int64）、`operands: Array[int]`、`minimum: int`、`maximum: int`。int64 运算超界时只记录合法输入操作数，不先计算不存在的精确结果。路径指向出错输出，例如 cubes[0].center2 或 anchors[0].position2；低层独立调用用 center2/position2，snapshot 重定位为 canonical ID 排序后的下标路径。
- AnchorOverlap 不接收 failure 包装/null/部分数据；Mapping Query 接收 snapshot_result，失败时传播为 ERROR，绝不 NONE 或假的 UNIQUE。合法派生值只在同一稳定快照内使用，期间不得人工修改。

C 的 LightQueryResult 不改：有理区间乘法超 int64 同样返回 1105、ok=false、light_state=null、reason=INVALID。其内部闭 AABB 边界与坐标差可为 int64 临时量，不能因超 int32 而误判坐标输出溢出；C 不输出这些量为 Vector3i。上游 Spatial 失败时停止调用 C；C 无法替坏快照追溯丢失的溢出信息。

范围回归 golden：center2=(-2147483648,0,0)、姿态0 的 LEFT Anchor 应为 -2147483649，resolve_anchor 必须失败1105；cube.center2=(0,0,0)、World rotation=4、pivot2=(2147483646,0,0)、无组时预期 Shared x=4294967292，resolve_cube 必须失败1105。snapshot/validate_snapshot/Mapping 必须一路保留失败。旧 -4 等“仍为偶数”的 wrapped 值不得被接受。

### 5.2 Spatial Mapping Query：三个显式阶段

所有类型为 Dictionary schema；公有枚举只由 DATA 定义。source_face / target_face 均为 FaceNodeId（StringName），不是 Frame、屏幕坐标或人工目标配置。

| 类型 | 唯一字段与含义 |
|---|---|
| AnchorOverlapResult | ok: bool, overlaps: bool|null, issues: Array[ValidationIssue] |
| FaceCompatibilityResult | ok: bool, compatibility: FaceCompatibility|null, issues: Array[ValidationIssue] |
| SpatialMappingPair | source_face: FaceNodeId, target_face: FaceNodeId |
| MappingDiscoveryResult | ok: bool, pairs: Array[SpatialMappingPair], issues: Array[ValidationIssue] |
| SpatialMappingCandidate | source_face: FaceNodeId, target_face: FaceNodeId, compatibility: FaceCompatibility |
| MappingCandidateResult | ok: bool, candidates: Array[SpatialMappingCandidate], issues: Array[ValidationIssue] |
| MappingResolutionResult | status: MappingResolutionStatus, candidates: Array[SpatialMappingCandidate], mapping: SpatialMappingCandidate|null, issues: Array[ValidationIssue]；不另设含糊的 ok |

除 Resolution 的1400/1401语义结果外，上述 ok=true 均要求 issues=[]；ok=false 均要求至少一条 ERROR issue，pairs/candidates 置空，overlaps/compatibility 置null。包装及值记录必填字段齐全、未知字段拒绝，类型/枚举/ID/引用错误按 §8 返回；不接受 partial 或“成功但有 ERROR”的中间结果。所有新输出集合深复制，输入不改。

**基础 AnchorOverlap**：校验两个 FaceAnchor 的记录/Frame 后，只比较 Shared Space position2 的三个整数分量相等。它不要求 layer 相同或不同，不比较 normal，不读 walkable/光照/出入限制。合法不重合返回 ok=true、overlaps=false；输入错误返回 ok=false、overlaps=null、issues 非空。不得用距离、epsilon、屏幕投影或轴向差的潜在溢出运算判定。

**1. Candidate Discovery**：`discover_mapping_candidates` 先调用 validate_snapshot，任何错误原样传播；检查 source_face 存在且 walkable，target_layer 合法且恰为另一 WorldLayer（错误分别为 INVALID_REFERENCE / INVALID_FACE / INVALID_ENUM；同层请求为 INVALID_REFERENCE）。检查完整输入，不能先过滤再漏掉损坏记录。然后只收集目标层 walkable Face 中 AnchorOverlap=true 的 pairs，包含法线垂直或暂不兼容的重合项。没有目标是成功空集合。源的 blocked、光照和 busy 不参与发现。

**2. Compatibility Classification**：`classify_face_compatibility` 校验两个完整 FaceAnchor/SurfaceFrame，但只根据法线分类。n_target=n_source→SAME_NORMAL；n_target=-n_source→OPPOSITE_NORMAL；其它合法轴关系→ok=true、compatibility=null、issues=[]（正常不兼容，非输入错误）。不要求 Anchor 已重合，不读取 LightState/ShiftPermission/GlobalTransitionState，不计算玩家新姿态。错误返回 ok=false、compatibility=null。

`collect_mapping_candidates` 是前两步的固定编排入口：校验 enabled_compatibilities 非空、唯一、成员为 FaceCompatibility（分别 INVALID_REFERENCE / DUPLICATE_ID / INVALID_ENUM），调用 discover_mapping_candidates，再逐 pair 调用 classify_face_compatibility，仅保留非 null 且在 enabled_compatibilities 中的项并附 classification。必须显式复用这两个公共入口的语义，不能另写一套筛选。任何阶段失败返回 ok=false、candidates=[]、原始 issues；成功返回 ok=true、issues=[]。此处不把正常不兼容项发成 FACE_INCOMPATIBLE 错误。

**3. Unique Mapping Resolution**：`resolve_mapping` 消费同一次 collect 的完整、未经修改的 MappingCandidateResult。检查包装、候选字段、重复 pair（DUPLICATE_ID）、相同 source 与有效 compatibility；损坏输入为 ERROR，不能把重复项去重后伪装唯一。不证明外部手工拼的列表是否覆盖全部空间，因此正式入口只能链上真实 collect 的结果，不能先按权限筛选再传入。

所有 pairs/candidates 按 `(String(source_face), String(target_face))` 的 ASCII/UTF-8 字节升序排序；有相同 pair 必为输入错误，不把 compatibility 当第二候选身份。按完整 FaceNodeId 排序，**不是** FaceDirection 枚举序。所有输入数组/Dictionary 可乱序，函数自行生成新排序数组，不依赖插入顺序或修改输入。

| 条件 | status | mapping | candidates / issues |
|---|---|---|---|
| 有效 collection，0 项 | NONE | null | []；NO_SHIFT_MAPPING=1400 |
| 有效 collection，1 项 | UNIQUE | 唯一候选的深复制 | 完整单项；issues=[] |
| 有效 collection，>1 项 | AMBIGUOUS | null | 全部 canonical 候选；AMBIGUOUS_SHIFT_MAPPING=1401 |
| 上游失败或结果记录非法 | ERROR | null | []；原始或结构错误 issues，禁止替换成1400 |

NONE / AMBIGUOUS 是已完成几何查询的非唯一结论；ERROR 是查询无法有效完成。1400/1401 的 severity=ERROR、path="mapping"，1401 的 entity_ids 为源及全部目标 ID 排序去重，details.candidates 为全部候选的序列化字段（ID/compatibility 符号字符串）；禁止挑第一项。后续全构型 Validator 另附构型 StateKey，本单快照接口不自行搜索。

完整 ShiftPermission 由后续 PuzzleRuleKernel 负责：取得 UNIQUE 后，才检查 Shadow（Surface→Inner）、source.shift_exit_blocked、target.shift_entry_blocked、global busy、PlayerSafety 等。即使多候选中只有一个当前阴影/未 blocked，也仍 AMBIGUOUS；Geometry 不变更玩家姿态或 PuzzleState。

## 6. LevelDefinition / PuzzleState

| LevelDefinition 字段 | 类型与约束 |
|---|---|
| schema_version | int，固定1 |
| contract_version / orientation_version / rule_version | String：foundation.contract.v1 / cube24.v1 / foundation.rules.v1 |
| level_id / content_hash | LevelId / String；hash 是规范内容 SHA-256 小写十六进制 |
| cell_size | int，固定1 |
| worlds | Array[WorldDefinition]，SURFACE、INNER 各一条 |
| cubes / faces / groups | Array[CubeCell] / Array[FaceNode] / Array[RotatableGroup] |
| celestial | CelestialDefinition |
| mechanisms | Array[MechanismDefinition] |
| face_transitions | Array[FaceTransitionDefinition] |
| shift_compatibilities | Array[FaceCompatibility]，唯一值且非空 |
| spawn / goal | PlayerState / GoalDefinition |
| flag_definitions | Array[FlagDefinition] |
| build_info | Dictionary[String,String]，来源元数据；不参与规则 hash |

| 辅助定义 | 必须字段 |
|---|---|
| MechanismDefinition | `mechanism_id`, `face_id`, `trigger: StringName`（ENTER/USE）, `action: PuzzleAction`, `priority: int`, `initial_state: StringName`, `allowed_states: Array[StringName]` |
| FaceTransitionDefinition | `transition_id`, `source_face_id`, `target_face_id`, `entry_axis: FaceAxis`, `exit_axis: FaceAxis`, `rotation_steps: Array[DiscreteOrientation]`（各为±90°）, `required_flags: Array[LevelFlagId]`；反向另定义一条 |
| GoalDefinition | `face_id: FaceNodeId`, `required_flags: Array[LevelFlagId]`；当前基础目标为占据指定 Face 且所有 flags=true |
| FlagDefinition | `flag_id: LevelFlagId`, `initial_value: bool`；第一版只允许有限 bool flags |

这是第一波基础 schema，尚未提供任意 Goal AST、PuzzleIntent、扫掠证明数据或完整能力策略。非空机制/FaceTransition 可做结构引用验证，但未通过后续业务/安全 Validator 前不得据此声明 LEVEL_VALID 或交付运行关卡。第一波有效构造 fixture 使用空 mechanisms/face_transitions/groups 和简单 Face Goal；不把缺省字段当已经支持的业务。

| PuzzleState 字段 | 类型 |
|---|---|
| player | PlayerState |
| world_orientations | Array[DiscreteOrientation]，索引0=Surface、1=Inner |
| celestial | CelestialState |
| group_orientations | Dictionary[RotatableGroupId,DiscreteOrientation]，恰好覆盖定义的组 |
| mechanism_states | Dictionary[MechanismId,StringName]，值属于各 allowed_states |
| level_flags | Dictionary[LevelFlagId,bool]，恰好覆盖定义的 flags |

不存派生 Anchor、Frame、Lighting、Mapping、Connectivity；不存 rotate_target、Camera、held keys、时间、动画、Audio、事务队列。变更状态工厂必须深复制，不能在失败时修改输入。Runtime 会话独立保存 `global_transition_state`, `active_kind`, `transaction_id`, `generation`, `accepted_action`；accepted_action 只指当前唯一事务，没有 pending_actions 集合。Reset 递增 generation，取消旧事务与回调。

未来 Level 序列化使用 UTF-8、无空白 JSON、键按 Unicode 码点排序；枚举以符号、ID 以字符串、坐标以三整数数组编码；记录集合按 ID 排序，worlds 按 layer，状态 Orientation 数组保持顺序，slot_order 与 rotation_steps 保持作者顺序。Level content_hash 排除自身与 build_info，Baker 仍不实现。StateKey 在本次冻结为下面唯一格式，不能套用文件编辑器的末尾 LF 习惯。禁止 Dictionary 遍历顺序充当规范排序。

### 6.1 StateKey：唯一公共入口与输入边界

Owner DATA，文件 `foundation/contracts/state_key.gd`，preload 别名 StateKey；唯一静态函数 `build(level: Dictionary, state: Dictionary) -> Dictionary`，返回 `StateKeyResult={ok: bool, key: String, issues: Array[ValidationIssue]}`。成功 ok=true、key 非空、issues=[]；失败 ok=false、key=""、至少一条 ERROR issue，空字符串绝不是 visited key。调用方以成功结果的 key 直接作为 Dictionary/visited 的键，不使用结果包装作为键。

build 先调用 DATA.validate_level_shape；无错误后调用 DATA.validate_state_shape。两阶段错误顺序遵守 §8，输入/输出无共享可变集合。错误类型/多余字段/缺字段/坏引用/域外姿态/未支持版本均明确拒绝，不能返回部分 key。未知字段包括任意层级的 UI/Camera/derived 字段；不能用“忽略额外字段”规避 schema 升版。对 String/StringName 的文本还要求合法 Unicode scalar 序列（孤立 surrogate 等返回 INVALID_TYPE），不做 Unicode 正规化或区域排序。此函数验证结构，不做几何、安全、可达性或 Baker hash 重算；content_hash 的内容真实性由提供已验证定义的调用方负责。

编码输入由两部分组成：命名空间取 level.content_hash、level.rule_version；状态取 **完整六字段 PuzzleState**。level_id、build_info 和其它定义内容不重复拼入 key，定义差异通过 content_hash 隔离。

| 状态字段 | 全量编码内容 / 排序 |
|---|---|
| player | location 的 cube_id、face、layer，以及 orientation；记录字段按下节顺序 |
| world_orientations | 两项 int，固定 [SURFACE orientation, INNER orientation]，不得排序数值 |
| celestial | 唯一 slot_id 字符串，无 sun/moon 双份 |
| group_orientations | 定义中全部 group_id→orientation；键按 ID Unicode 码点升序 |
| mechanism_states | 定义中全部 mechanism_id→StringName 状态值；键按 ID 升序，值精确保留 |
| level_flags | 定义中全部 flag_id→bool；键按 ID 升序，false 也必须编码 |

所有 map 恰好覆盖定义，不用“缺省值相同”删除条目。禁止 Camera、RotateTarget、Animation Progress、Visual FX、Audio、FaceLightState、ShiftMapping、AnchorOverlap、Connectivity Cache、Debug State、UI State、派生 Frame、时间/事务字段进入 key；它们本来就不是 PuzzleState 字段。若未来新增真正影响规则的状态，必须扩展状态 schema 并升级为 statekey.v2，不得静默修改 v1。

### 6.2 statekey.v1 字符串规范

完整 key = ASCII 前缀 `statekey.v1:` + 一个 canonical JSON 对象。不是摘要、二进制包、Godot Variant 文本或第二个对象表示。UTF-8 编码，无 BOM，无结构性缩进/空白，无末尾换行（既没有 LF 也没有 CR）；字符串自身的合法空格保留，字符串内换行只能按 JSON 转义。无任何分隔符追加在 JSON 之后。

固定对象字段顺序（也就是 Unicode 码点序）：

- 顶层：`level_hash`, `rule_version`, `state`。
- state：`celestial`, `group_orientations`, `level_flags`, `mechanism_states`, `player`, `world_orientations`。
- celestial：`slot_id`；player：`location`, `orientation`；location：`cube_id`, `face`, `layer`。
- 三个 ID map 的键使用上述排序；空 map 编码 `{}`。对象使用 `{}`、数组使用 `[]`、字段名与值间单个 `:`、成员间单个 `,`。不额外给每个字段加长度前缀。

Orientation 为十进制整数0..23，无正号、前导零或小数；bool 为 `true`/`false`。WorldLayer 序列化为 `"SURFACE"`/`"INNER"`，FaceDirection 为本地面大写符号；StringName 转为同内容 String。UTF-8 中非 ASCII 的合法 Unicode 字符原样编码，不变成 \u 序列，不正规化。字符串中的 `"`→`\"`，`\`→`\\`；U+0008/0009/000A/000C/000D 分别为 `\b`/`\t`/`\n`/`\f`/`\r`；其它 U+0000..001F 用小写十六进制四位 `\u00xx`。`/`、其它可打印字符、U+2028/U+2029 不转义。不可依赖引擎 JSON 默认排序/转义选项恰好一致。

golden A（定义 fixture 的 content_hash 指定为64个0；这是结构测试输入，不宣称零摘要来自真实 Bake；slot=a，floor/TOP，空组/机关/flags）：

```text
statekey.v1:{"level_hash":"0000000000000000000000000000000000000000000000000000000000000000","rule_version":"foundation.rules.v1","state":{"celestial":{"slot_id":"a"},"group_orientations":{},"level_flags":{},"mechanism_states":{},"player":{"location":{"cube_id":"floor","face":"TOP","layer":"SURFACE"},"orientation":0},"world_orientations":[0,0]}}
```

golden B（fixture 声明组 alpha/beta、flags done/open、机关 plate/z_gate 的合法域、Inner cube inner_floor/BOTTOM 与 Slot b；空间可达性非本编码测试要求）：

```text
statekey.v1:{"level_hash":"0000000000000000000000000000000000000000000000000000000000000000","rule_version":"foundation.rules.v1","state":{"celestial":{"slot_id":"b"},"group_orientations":{"alpha":2,"beta":22},"level_flags":{"done":false,"open":true},"mechanism_states":{"plate":"down","z_gate":"open"},"player":{"location":{"cube_id":"inner_floor","face":"BOTTOM","layer":"INNER"},"orientation":19},"world_orientations":[9,0]}}
```

上面两个 code block 的展示换行不是 key 的一部分。把 B 的 map 逆序插入，字节结果仍必须等于 B。转义 golden 片段：状态文本含 `开`、双引号、反斜线、LF、U+0001、斜杠，依次编码为 JSON 字符串 `"开\"\\\n\u0001/"`；仅在其属于对应机关 allowed_states 时可进入完整 key。文档 fixture 的同一占位 hash 仅方便独立 golden，不允许真实不同关卡复用摘要。

Equality 是完整 String 精确内容相等（等价于上述规范 UTF-8 字节相等）；不比较 Dictionary 插入顺序、对象身份或区域化文本。Godot Dictionary 内部哈希只是查桶，必须保留完整 String 的相等比较；禁止把 String.hash()/短整数摘要当唯一状态身份。跨进程持久化/回放/debug 一律使用这条完整字符串，不定义第二种 hash 输出或 debug key。level_hash 或合法支持的 rule_version 改变必须使 namespace 改变；本版只接受 foundation.rules.v1，其它值当前返回 VERSION_MISMATCH，未来支持新规则时另行版本化扩展。

## 7. PuzzleAction 判别联合

所有动作有 `kind: PuzzleActionKind`；只允许对应行字段，未知/多余字段拒绝。SHIFT_WORLD 的目标是另一层唯一空间映射，不能手工塞 target_face_id。

| kind | 额外字段 |
|---|---|
| MOVE | `face_axis: FaceAxis` |
| SHIFT_WORLD | 无 |
| ROTATE_SURFACE / ROTATE_INNER | `rotation_delta: DiscreteOrientation`，六个±90°之一 |
| USE_FACE_TRANSITION | `transition_id: FaceTransitionId` |
| TRIGGER_MECHANISM | `mechanism_id: MechanismId` |
| LOCAL_GROUP_ROTATE | `group_id: RotatableGroupId`, `rotation_delta: DiscreteOrientation`, `mechanism_id: MechanismId`（授权来源） |
| MOVE_CELESTIAL | `celestial_op: CelestialOp`, `target_slot_id: CelestialSlotId`, `alternate_slot_id: CelestialSlotId`, `mechanism_id: MechanismId` |

SET_SLOT 需要 target，alternate 空；NEXT/PREVIOUS 两个 Slot 字段都空；TOGGLE 两个不同合法 Slot。直接组/天体动作必须具备机关授权，结构合法不等于有权执行。第一波仅检查形状与引用，Kernel 权限/入场触发属于后续独立阶段。

GlobalTransitionState!=IDLE 时，除安全且可交换的普通 MOVE 外上述动作都返回 GLOBAL_TRANSITION_BUSY；MOVE 只能更新允许的局部占用事实。被拒的全球效果立即丢弃，稳定后无补触发。FrameTransition 不是普通 Local Movement。未来序列控制不藏在本联合的任意 Dictionary 扩展字段中。

## 8. ValidationIssue / ValidationCode

ValidationIssue 字段：`code: ValidationCode`, `severity: ValidationSeverity`, `path: String`（例如 cubes[2].center2）, `entity_ids: Array[StringName]`, `message: String`, `details: Dictionary`（只允许规范标量、整数坐标数组、数组/字典；不含 Node 或浮点状态）。issues 按 path、code、entity_ids 排序。message 可本地化，程序只看 code。成功的验证返回空 issues；没有名为 LEVEL_VALID 的基础结构结果来冒充完整关卡验证。

| ValidationCode 固定编号 | 含义 |
|---|---|
| INVALID_TYPE=1000, UNKNOWN_FIELD=1001, MISSING_FIELD=1002 | 记录形状错误 |
| INVALID_ENUM=1003, INVALID_ID=1004, DUPLICATE_ID=1005 | 枚举/身份错误 |
| INVALID_REFERENCE=1006, VERSION_MISMATCH=1007 | 引用或版本错误 |
| OFF_LATTICE=1100, INVALID_ORIENTATION=1101, INVALID_SURFACE_FRAME=1102 | 数学输入错误 |
| INVALID_FACE=1103, INVALID_ANCHOR=1104, ARITHMETIC_OVERFLOW=1105 | 面/派生坐标/整数范围错误 |
| SAME_WORLD_CUBE_OVERLAP=1200, SEALED_WALKABLE_FACE=1201 | 单稳定快照几何错误 |
| INVALID_GROUP=1202, INVALID_ROTATION_EDGE=1203, PLAYER_UNSAFE=1204 | 结构/端态/安全错误 |
| INVALID_CELESTIAL_REFERENCE=1300, SLOT_STEP_UNAVAILABLE=1301, LIGHT_SOURCE_INVALID=1302 | 天体或光源错误 |
| NO_SHIFT_MAPPING=1400, AMBIGUOUS_SHIFT_MAPPING=1401, FACE_INCOMPATIBLE=1402 | 映射错误 |
| SHIFT_REQUIRES_SHADOW=1403, SHIFT_EXIT_BLOCKED=1404, SHIFT_ENTRY_BLOCKED=1405 | Shift 条件拒绝 |
| GLOBAL_TRANSITION_BUSY=1500, MULTIPLE_GLOBAL_MUTATIONS=1501 | 串行事务拒绝 |
| INVALID_ACTION=1502, UNAUTHORIZED_MECHANISM=1503, MOVE_NOT_COMMUTATIVE=1504 | 动作拒绝 |
| VALIDATION_BUDGET_EXCEEDED=1600, VALIDATION_INCOMPLETE=1601 | 不能完成验证，不是通过 |

未列出的未来 Kernel/Solver Code 只能在版本化扩展后新增；本波不使用临时字符串伪装枚举。不再有单一 shift_blocked 字段或 SHIFT_BLOCKED Code。

### 8.1 Requested Semantic → Canonical ValidationCode

下面是语义映射，左栏是需求描述，**不是可新增的枚举别名**。同一个细分错误仅有右栏一个名字/编号；复合检查按实际失败字段分解，不创建笼统的 INVALID_SPAWN/INVALID_EXIT/GROUP_STATE 替代码。本次没有新增 ValidationCode 数值；只新增 §2 的 MappingResolutionStatus 枚举。

| Requested Semantic | Canonical ValidationCode / 定位边界 |
|---|---|
| Duplicate Cube ID | DUPLICATE_ID=1005；path 指向重复 cube_id，entity_ids 保留 ID |
| Cube Overlap | SAME_WORLD_CUBE_OVERLAP=1200；仅同层；跨层重合本身合法 |
| Invalid Face | INVALID_FACE=1103；本地面编号/face_id 组成/完整性错误；缺引用按 INVALID_REFERENCE=1006 |
| Invalid Orientation | INVALID_ORIENTATION=1101；0..23 或声明域不合法；类型错误仍 INVALID_TYPE=1000 |
| Invalid Rotatable Group State | 姿态/域→INVALID_ORIENTATION=1101；归属/跨层/嵌套→INVALID_GROUP=1202；转换边→INVALID_ROTATION_EDGE=1203 |
| Invalid Celestial Reference | INVALID_CELESTIAL_REFERENCE=1300；已确定为 Slot 引用的缺失目标/引用集合不完整，涵盖 DATA、state、action 与 C 请求解析 |
| Invalid Mechanism Reference | INVALID_REFERENCE=1006；机制 ID 缺失或归属引用不一致；权限不足另为 UNAUTHORIZED_MECHANISM=1503（未来 Kernel） |
| Invalid Spawn | 缺 spawn/必填子字段→MISSING_FIELD=1002；位置引用/层不符→INVALID_REFERENCE=1006；面→1103；姿态→1101；支撑/净空→PLAYER_UNSAFE=1204（后续安全层） |
| Invalid Exit | 公共字段是 goal；缺 goal/子字段→MISSING_FIELD=1002；目标 Face/flag 引用→INVALID_REFERENCE=1006；面身份错误→INVALID_FACE=1103；不新增 exit 字段 |
| Ambiguous Shift Mapping | AMBIGUOUS_SHIFT_MAPPING=1401；全部几何候选，不按亮暗/限制删候选 |
| Player Unsafe After Rotation | PLAYER_UNSAFE=1204；不是只检查姿态整数范围 |
| Coordinate Overflow | ARITHMETIC_OVERFLOW=1105；Spatial 输出范围或 C 精确整数中间计算范围越界 |

D 当前实现中已知为 Celestial 的引用仍有路径返回通用1006；这属于此次必须收敛的具体实现差异：恢复 D 时这些引用失败改用已有1300，并只更新对应断言。不能给同一 Slot 缺失语义保留1006/1300两套名字。其它引用继续1006；未知/缺字段、错误类型、重复 ID 等独立形状错误保留原码，不强改成1300。C 已使用1300，无需为了 D 历史通用码改 C。1105 不新增 COORDINATE_OVERFLOW 别名，LOCAL_GROUP_ROTATE 动作名也不更名。

## 9. 四模块接口签名（未来实现，本轮不执行）

静态纯函数；输入均不修改。以下 Dictionary 对应前文命名 schema。无 SceneTree、Timer、ResourceLoader、全局状态、Camera 或 Godot 物理服务器依赖。math 使用严格已校验前置条件；外部错误由 DATA/SPATIAL 边界转 ValidationIssue，不能自动返回 identity。

| Owner / 脚本 | 唯一签名 |
|---|---|
| MATH / discrete_orientation | `is_valid(id: int) -> bool`; `columns(id: int) -> Array[Vector3i]`; `from_columns(right: Vector3i, up: Vector3i, forward: Vector3i) -> int`（非法=-1） |
| MATH / discrete_orientation | `compose(a: int, b: int) -> int`; `inverse(id: int) -> int`; `apply(id: int, vector: Vector3i) -> Vector3i` |
| MATH / discrete_orientation | `quarter_turn(axis: int, sign: int) -> int`（内部 RotationAxis，sign=±1）; `reframe(source_frame: int, target_frame: int, pose: int) -> int` |
| DATA / contract_records | `make_player_location(layer: int, cube_id: StringName, face: int) -> Dictionary`; `make_player_state(location: Dictionary, orientation: int) -> Dictionary`; `make_action(kind: int, payload: Dictionary) -> Dictionary`; `initial_state(level: Dictionary) -> Dictionary`（要求 validate_level_shape 无错误） |
| DATA / contract_validation | `validate_level_shape(level: Dictionary) -> Array[Dictionary]`; `validate_state_shape(level: Dictionary, state: Dictionary) -> Array[Dictionary]`; `validate_action_shape(level: Dictionary, action: Dictionary) -> Array[Dictionary]` |
| DATA / state_key | `build(level: Dictionary, state: Dictionary) -> Dictionary`（StateKeyResult，§6.1–6.2） |
| SPATIAL / surface_geometry | `face_frame(face: int) -> Dictionary`; `face_id(cube_id: StringName, face: int) -> StringName`; `make_face_nodes(cube_id: StringName) -> Array[Dictionary]`（六 FaceNode，见下文） |
| SPATIAL / surface_geometry | `resolve_cube(cube: Dictionary, world_transform: Dictionary, group_transform: Dictionary) -> Dictionary`（SpatialQueryResult.value=ResolvedCube；无组传 identity/pivot2=0） |
| SPATIAL / surface_geometry | `resolve_anchor(cube: Dictionary, face: int) -> Dictionary`（输入 ResolvedCube，输出 SpatialQueryResult.value=FaceAnchor）；`snapshot(level: Dictionary, state: Dictionary) -> Dictionary`（SpatialQueryResult.value=SpatialSnapshot） |
| SPATIAL / surface_geometry | `anchor_overlap(source: Dictionary, target: Dictionary) -> Dictionary`（输入 FaceAnchor，输出 AnchorOverlapResult）；`classify_face_compatibility(source: Dictionary, target: Dictionary) -> Dictionary`（FaceCompatibilityResult） |
| SPATIAL / spatial_validation | `validate_snapshot(snapshot_result: Dictionary, faces: Array[Dictionary]) -> Array[Dictionary]`；只检查当前快照/传播派生失败，不枚举全部构型 |
| SPATIAL / mapping_query | `discover_mapping_candidates(snapshot_result: Dictionary, faces: Array[Dictionary], source_face: StringName, target_layer: int) -> Dictionary`（MappingDiscoveryResult） |
| SPATIAL / mapping_query | `collect_mapping_candidates(snapshot_result: Dictionary, faces: Array[Dictionary], source_face: StringName, target_layer: int, enabled_compatibilities: Array[int]) -> Dictionary`（MappingCandidateResult） |
| SPATIAL / mapping_query | `resolve_mapping(collection_result: Dictionary) -> Dictionary`（MappingResolutionResult） |
| CELESTIAL / celestial_rules | `resolve_slot_request(definition: Dictionary, current_slot_id: StringName, operation: int, target_slot_id: StringName, alternate_slot_id: StringName) -> Dictionary`（SlotRequestResult） |
| CELESTIAL / logical_lighting | `query(anchor: Dictionary, slot: Dictionary, cubes: Array[Dictionary]) -> Dictionary`（LightQueryResult；输入 FaceAnchor / CelestialSlot / ResolvedCube 数组） |

make_face_nodes 补足 B 报告的六 FaceNode 工厂缺口：输入是已经验证的 CubeCellId，逐次调用返回新六元素数组，顺序固定 FaceDirection 0..5（FRONT/BACK/LEFT/RIGHT/TOP/BOTTOM）；每项 face_id 由唯一 face_id 函数生成、cube_id 保持输入、三个 bool 均 false、mechanism_ids 为各自独立空 Array[StringName]。此工厂不产生 Anchor 或偷偷把 TOP 标为 walkable。它与 face_frame/face_id 一样使用严格合法 ID/枚举前置条件；不承诺错误输入回退值。DATA 检查六面完整性但不复制该生成算法。

## 10. 并发依赖与集成 Gate

文件写权限互斥：DATA 只写 contracts，MATH 只写 orientation，SPATIAL 只写 spatial，CELESTIAL 只写 celestial；各自测试仅在 tests/foundation/<模块>/。公共合同与其它 Work 文件只读；禁止自建共享 helpers 修改对方文件。每个 Work 只修改自己的实施计划进度与专属验收报告。

依赖方向：MATH 不依赖其它模块；DATA 不依赖算法模块（orientation 范围/版本按合同检查，不另造旋转表），StateKey → DATA 自身 shape validator；SPATIAL → MATH + DATA 枚举/shape validator；mapping_query → surface_geometry + spatial_validation，spatial_validation → surface_geometry，surface_geometry 不反向 preload 二者，避免循环。CELESTIAL → DATA 枚举与 SPATIAL 值记录合同，不调用 SPATIAL 算法，测试最终接真实 snapshot。不存在 contracts→spatial→contracts 环。

四 Work 可以同时写自身测试和实现：依赖未到位时测试先使用本测试文件中按本文写出的值 fixture，不创建或提交邻模块假脚本；依赖接口测试清晰记录未运行，不能报集成 PASS。数据 fixture 可独立验证 shape，数学独立验证整数表，空间先验证六面 golden vectors，光照先验证手写固定快照。真实 preload / 联合 fixture Gate 在 DATA+MATH 可用后完成 SPATIAL，再接 CELESTIAL；不会因为“同时开始”把依赖顺序抹掉。

FOUNDATION-0.1 就绪只指 B/D 合同缺口已收敛，可以在后续恢复实现。B 需升级派生结果包装并清掉已知两项范围失败、补齐单快照 Mapping Query；D 需对齐1300引用码并实现 StateKey。A 只同步了解修订，代码/表/签名不变。C 生产代码及 LightQueryResult/SlotRequestResult 不变，但真实依赖测试需在 B 更新后先检 snapshot.ok 再消费 snapshot.value，并把包装传给 validate_snapshot；只同步测试消费边界，禁止复制算法或自动宣称旧132项证明新接口。四模块完成后仍需要新的 Kernel/全局调度/全构型 Mapping Validator/Solver/Runtime 授权与验收，不可用模块 PASS 宣称整套 FOUNDATION 可玩。
