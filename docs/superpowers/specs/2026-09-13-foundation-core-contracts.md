---
title: FOUNDATION-0 Core Contracts
contract_version: foundation.contract.v1
orientation_version: cube24.v1
status: FROZEN CONTRACT / IMPLEMENTATION NOT STARTED
date: 2026-09-13
---

# FOUNDATION-0 公共合同

本文件是第一波四个 Work 的共同接口来源。架构依据为同目录 `2026-09-13-foundation-spatial-puzzle-architecture-design.md`，尤其 §33 DECISION-01/02/03。只冻结合同，不声明新系统已实现；本轮不创建运行代码。变更公共名称、字段、枚举值、坐标或 ID 排序必须先串行修订合同版本，再同步四计划，不能在某个 Work 私自解释。

## 1. 路径、风格与所有权

当前仓库使用 snake_case 文件/字段、PascalCase preload 别名、纯逻辑 RefCounted 与独立 SceneTree 测试，未采用通用全局 class_name 注册。后续沿用：每个脚本由调用方 preload，禁止新增同名全局类、迁移旧脚本或修改 P-01。

| 唯一 Owner | 预计实现路径 | 职责 |
|---|---|---|
| DATA | `foundation/contracts/foundation_types.gd` | 公共枚举；不含 RotationAxis |
| DATA | `foundation/contracts/contract_records.gd` | 本文记录的工厂、深复制；非业务结算 |
| DATA | `foundation/contracts/contract_validation.gd` | 类型/版本/引用形状/域检查与 ValidationIssue |
| MATH | `foundation/orientation/discrete_orientation.gd` | 唯一 24 态数学与内部 RotationAxis |
| SPATIAL | `foundation/spatial/surface_geometry.gd` | 纯整数层级变换、FaceAnchor/SurfaceFrame、结构快照 |
| SPATIAL | `foundation/spatial/spatial_validation.gd` | 初态快照的重叠/封闭面/格点检查 |
| CELESTIAL | `foundation/celestial/celestial_rules.gd` | Slot 请求解析，纯数据接口 |
| CELESTIAL | `foundation/celestial/logical_lighting.gd` | 单个稳定快照的逻辑入射/遮挡查询 |

第一波不实现 World Mapping Solver、完整全构型 Validator、Kernel、BFS、Scheduler、InputMapper、Editor、Baker 或 Runtime 迁移。Shared Space 在 SPATIAL 仅指坐标快照，无搜索或 Shift 候选求解。Lighting 是本波 CELESTIAL 后续计划的范围，本次只写计划。

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

第一波不实现 StateHasher/Baker。未来序列化固定为 UTF-8、LF、无空白 JSON、键按 Unicode 码点排序；枚举以符号、ID 以字符串、坐标以三整数数组编码；记录集合按 ID 排序，worlds 按 layer，状态 Orientation 数组保持顺序，slot_order 与 rotation_steps 保持作者顺序。Level content_hash 排除自身与 build_info；StateKey 还带 level content_hash + rule_version。禁止 Dictionary 遍历顺序充当规范排序。

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

## 9. 四模块接口签名（未来实现，本轮不执行）

静态纯函数；输入均不修改。以下 Dictionary 对应前文命名 schema。无 SceneTree、Timer、ResourceLoader、全局状态、Camera 或 Godot 物理服务器依赖。math 使用严格已校验前置条件；外部错误由 DATA/SPATIAL 边界转 ValidationIssue，不能自动返回 identity。

| Owner / 脚本 | 唯一签名 |
|---|---|
| MATH / discrete_orientation | `is_valid(id: int) -> bool`; `columns(id: int) -> Array[Vector3i]`; `from_columns(right: Vector3i, up: Vector3i, forward: Vector3i) -> int`（非法=-1） |
| MATH / discrete_orientation | `compose(a: int, b: int) -> int`; `inverse(id: int) -> int`; `apply(id: int, vector: Vector3i) -> Vector3i` |
| MATH / discrete_orientation | `quarter_turn(axis: int, sign: int) -> int`（内部 RotationAxis，sign=±1）; `reframe(source_frame: int, target_frame: int, pose: int) -> int` |
| DATA / contract_records | `make_player_location(layer: int, cube_id: StringName, face: int) -> Dictionary`; `make_player_state(location: Dictionary, orientation: int) -> Dictionary`; `make_action(kind: int, payload: Dictionary) -> Dictionary`; `initial_state(level: Dictionary) -> Dictionary`（要求 validate_level_shape 无错误） |
| DATA / contract_validation | `validate_level_shape(level: Dictionary) -> Array[Dictionary]`; `validate_state_shape(level: Dictionary, state: Dictionary) -> Array[Dictionary]`; `validate_action_shape(level: Dictionary, action: Dictionary) -> Array[Dictionary]` |
| SPATIAL / surface_geometry | `face_frame(face: int) -> Dictionary`; `face_id(cube_id: StringName, face: int) -> StringName`; `resolve_cube(cube: Dictionary, world_transform: Dictionary, group_transform: Dictionary) -> Dictionary`（ResolvedCube；无组传 identity/pivot2=0） |
| SPATIAL / surface_geometry | `resolve_anchor(cube: Dictionary, face: int) -> Dictionary`（输入 ResolvedCube）；`snapshot(level: Dictionary, state: Dictionary) -> Dictionary`（SpatialSnapshot；前置形状合法） |
| SPATIAL / spatial_validation | `validate_snapshot(snapshot: Dictionary, faces: Array[Dictionary]) -> Array[Dictionary]`；只检查当前快照，不枚举全部构型 |
| CELESTIAL / celestial_rules | `resolve_slot_request(definition: Dictionary, current_slot_id: StringName, operation: int, target_slot_id: StringName, alternate_slot_id: StringName) -> Dictionary`（SlotRequestResult） |
| CELESTIAL / logical_lighting | `query(anchor: Dictionary, slot: Dictionary, cubes: Array[Dictionary]) -> Dictionary`（LightQueryResult；输入 FaceAnchor / CelestialSlot / ResolvedCube 数组） |

## 10. 并发依赖与集成 Gate

文件写权限互斥：DATA 只写 contracts，MATH 只写 orientation，SPATIAL 只写 spatial，CELESTIAL 只写 celestial；各自测试仅在 tests/foundation/<模块>/。公共合同与其它 Work 文件只读；禁止自建共享 helpers 修改对方文件。每个 Work 只修改自己的实施计划进度与专属验收报告。

依赖方向：MATH 不依赖其它模块；DATA 不依赖算法模块（orientation 范围/版本按合同检查，不另造旋转表）；SPATIAL → MATH + DATA 枚举；CELESTIAL → DATA 枚举与 SPATIAL 值记录合同，不调用 SPATIAL 算法，测试最终接真实 snapshot。不存在 contracts→spatial→contracts 环。

四 Work 可以同时写自身测试和实现：依赖未到位时测试先使用本测试文件中按本文写出的值 fixture，不创建或提交邻模块假脚本；依赖接口测试清晰记录未运行，不能报集成 PASS。数据 fixture 可独立验证 shape，数学独立验证整数表，空间先验证六面 golden vectors，光照先验证手写固定快照。真实 preload / 联合 fixture Gate 在 DATA+MATH 可用后完成 SPATIAL，再接 CELESTIAL；不会因为“同时开始”把依赖顺序抹掉。

准备就绪只指可以启动第一波开发。四模块完成后仍需要新的 Kernel/全局调度/Mapping/全构型 Validator/Solver/Runtime 授权与验收，不可用模块 PASS 宣称整套 FOUNDATION 可玩。
