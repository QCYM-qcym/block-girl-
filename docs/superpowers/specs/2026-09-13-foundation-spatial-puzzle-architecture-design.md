---
title: FOUNDATION Spatial Puzzle Architecture Design
project: 方块少女 / Block Girl - 若叶睦
stage: FOUNDATION_ARCHITECTURE_SPEC_FREEZE
design_status: FROZEN DESIGN
implementation_status: NOT IMPLEMENTED YET
review_status: CORE CONTRACT RECONCILED BY FOUNDATION-0.1
contract_version: foundation.contract.v1
contract_revision: foundation.contract.v1.1
date: 2026-09-13
baseline_branch: feat/playable-puzzle-p02
baseline_head: 0043ea56dc1cd19b87139e7c989b9fc5126ad71f
---

# FOUNDATION Spatial Puzzle Architecture Design

> FOUNDATION-0.1 更新（2026-09-13）：本轮仅在 feat/foundation-core 中修订公共合同与 B/D 计划。公共 API 修订为 foundation.contract.v1.1，数据标签 foundation.contract.v1 / cube24.v1 / foundation.rules.v1 不变。§33.7 记录四路真实反馈及恢复边界；下文旧“本轮/未实现”表述保留原冻结阶段的历史含义，不抹除 A/C 已完成的模块验收，也不把模块 PASS 升格为整体 FOUNDATION PASS。

> FOUNDATION-0 更新（2026-09-13）：用户已授权在既有架构冻结基础上完成 CORE CONTRACT FREEZE。§33.5 的三项决策与 `2026-09-13-foundation-core-contracts.md` 为当前规范；本文件原阶段范围/日志保留历史含义。当前只修订文档并准备四份计划，不实施系统。公共字段拼写、枚举值和编号以公共合同为准。

> 本文冻结目标架构与合同，不声明这些系统已实现。本次不修改 P-01，不实现 FOUNDATION/P-02，不生产资源，不运行 Godot/Blender，不提交或推送 Git。完成文档自检后等待用户 review。
>
> 下文“必须”“支持”均指 **FOUNDATION 目标要求**。现状仅见第 2 节。用户已给定的规则为 **FROZEN DESIGN**；为了使规则可确定执行而补充的坐标、歧义和并发约定统一列入第 33 节 review 记录，不伪称它们在历史代码中存在。

## 1. Purpose / 目的

从单关二维原型走向可重复制作三维空间谜题的基础：CubeCell/FaceNode 空间、可视化 Authoring→Validate→Bake→LevelDefinition、共享 PuzzleRuleKernel 与自动求解/质量验证。

长期制作循环是“摆 Cube → 配 Face → 配机关 → Validate → Bake → Solve → Playtest”，新增关卡主要产出数据与设计，不反复复制玩法代码。FOUNDATION 的底层能力完整，玩家按关卡逐步学习。

## 2. Scope / 范围与现状

### 2.1 当前已存在的本地基线

2026-09-13 只读检查：分支 feat/playable-puzzle-p02；HEAD 为 frontmatter 所列完整值；开始时工作区干净。docs/superpowers 现有 plans，无 specs 子目录，因此本文件按用户优先路径新建，不移动旧文档。

| 现有对象 | 依据 | 适用范围 |
|---|---|---|
| 24 态整数 CubeOrientation | prototype/perspective/cube_orientation.gd | 玩家方块的持久姿态 |
| 四个离散二维投影视角 | prototype/perspective/perspective_controller.gd | 显式分平台 2D 重构，不是真实世界旋转 |
| world/cell 与二维地面表 | game/levels/mutsumi/p01_state.gd | 当前正式 P-01 |
| 真实 roll/Shift 的落定提交 | prototype/perspective/grid_movement.gd | 同 cell 换世界、同平面移动 |
| 正式姿态 Sprite | game/player/orientation_sprite_presenter.gd | 现有相机/素材合同 |
| P-01 专属装配与 Polish | game/levels/mutsumi 与 game/polish | 仍有板门/提示字段依赖 |
| P-01 状态可达性检查 | tests/gameplay/test_p01_state.gd | 单关穷举，不是通用 Solver |

未发现 CubeCell、FaceNode、LevelDefinition、PuzzleRuleKernel、CelestialState、RotatableGroup 的目标实现。历史报告的 PASS 不证明 FOUNDATION 已具备这些能力。本次不重跑历史测试。

### 2.2 本轮与后续范围

本轮只产出本 Spec、Obsidian 知识页/日志、来源与自检证据。后续才实现数据类型、规则核心、编辑工具、Solver、真实 Runtime 与迁移适配。

旧 P-02 的无教程、一个投影连接路线保留为历史设计；其二维映射和仅相机旋转前提不能自动成为 FOUNDATION 的三维实现规格。本文天体 A/B 等例子不批准新增 P-02 机关或正式地图。FOUNDATION review/实现完成后再单独重审 P-02。

## 3. Non-goals / 本轮非目标

不修改玩法代码、不重构 P-01、不实现 P-02；不新增 Runtime、CubeCell/FaceNode、Solver、Editor Plugin 或 Celestial 实现。不修改正式 Sprite/Tileset，不启动 Blender，不制作模型。无 commit/push/merge/rebase/remote 修改。

战斗、Live2D、正式剧情、存档、主菜单、正式 BGM、完整 P-02 地图均排除。

目录合同：游戏代码/场景/正式资产留在 E:\godot\若叶睦\方块少女-若叶睦；知识沉淀在 E:\obsdian\青澄的水泥房\方块娘\若叶睦。未来 Blender 安装位于 D:\APP\blender，模型/贴图/渲染/导出及可配置临时文件放 E:\blender\若叶睦；本轮不启动或配置 Blender，不在 C 盘新建项目/Blender工作文件或临时资源。

## 4. Design Principles / 设计原则

1. 逻辑离散、视觉连续；连续渲染参数不能成为谜题规则。
2. 位置、所在表面、角色姿态、所属世界、旋转目标分开。
3. Shared Space 实体重合与屏幕投影连接分开。
4. 规则只有一份；Runtime/Solver/Validator/Replay 共同调用纯核。
5. 几何自动派生，作者配置语义，不手摆隐藏 Anchor。
6. 关卡能力数据驱动，早期不暴露完整三轴与复杂遮挡。
7. 无证明即未知；预算不足不能写无解或无软锁。
8. 当前实现、冻结目标、暂缓能力和体验结论分栏。

## 5. CubeCell / FaceNode

### 5.1 单位与身份

最小空间单位 CubeCell 是固定边长 L 的立方体；自动产生 TOP/BOTTOM/FRONT/BACK/LEFT/RIGHT 六个 FaceNode。六面都有身份，但仅标记 walkable 且通过冲突/支撑检查的 Face 可游玩。导航身份为 (world,cube_id,face)，不是二维 tile 坐标。Cube ID 在 LevelDefinition 内唯一，跨世界也不复用。

### 5.2 精确坐标合同

Shared Space 使用右手系，FRONT=+Z、BACK=-Z、RIGHT=+X、LEFT=-X、TOP=+Y、BOTTOM=-Y，沿用角色物理面命名但地图 Face 与角色脸身份是不同对象。

作者摆放的 Cube 中心吸附整数 L 网格；逻辑内部用半格单位的整数坐标，Cube 中心分量为偶数，FaceAnchor = Center2 + Normal（Normal 为有符号轴单位向量）。旋转 pivot 可在半格格点，但所有合法端态必须使 Cube 中心回到允许网格。禁止累计浮点 Transform 作为 StateKey 或 AnchorOverlap 依据。

Cube 的静态基变换、所属 World 与 Group 的离散变换组合后，自动导出 Shared Space Center/Normal/Anchor。Bake 可保存派生缓存，但作者不能自由编辑派生值。

Vector3i 坐标分量仅为 int32；先提升分量到 int64 计算完整 Group/World 端态及 Anchor，再检查表示范围，禁止先做可能溢出的 Vector3i 运算。Group 端态、World 端态或任一六面 Anchor 越界均返回 ARITHMETIC_OVERFLOW=1105；snapshot 整体失败，不保留部分几何。精确临时差可超 int32，不能误拒最终可表示的变换。细节、两个极端坐标 golden 和结果包装以公共合同 §5.1 为准。

### 5.3 重叠与邻接

同世界 Cube 内部不能重叠。共边界的相邻立方体可接触；相对且完全被封闭的内部 Face 不得标可站立。不同世界在 Shared Space 可重叠，这是映射可能成立的必要空间关系，不能用跨世界体积重叠一概拒绝关卡。

普通邻接只连接同世界、同法线、同平面、相邻一个 L 的合法 Face 中心，且通过边界/阻挡检查。Cube.TOP 到同 Cube.FRONT 没有默认邻接；非共面路线必须由 FaceTransition 显式提供。

## 6. PlayerLocation / PlayerSurfaceFrame

PlayerLocation 保存 world/layer、cube_id、face；解析到 Shared Space 后得到所在表面位置。当前 Face 是玩家局部地面，无永久全局重力方向。

PlayerSurfaceFrame 从该 Face 的变换自动生成，包含 anchor、normal、u/v 切向轴；u×v=normal。固定本地表如下，之后整体乘 Cube/Group/World 旋转：

| Face | n | u | v |
|---|---|---|---|
| TOP | +Y | +X | -Z |
| BOTTOM | -Y | +X | +Z |
| FRONT | +Z | +X | +Y |
| BACK | -Z | -X | +Y |
| RIGHT | +X | -Z | +Y |
| LEFT | -X | +Z | +Y |

Frame 决定站立面及输入解释，不保存角色哪张脸朝哪里；后者是 CubeOrientation。

输入链：Screen Input → Camera Basis → 投影到 Frame 切平面 → 吸附最近离散 Face Axis → MOVE → 真实 Cube Roll。W/S/A/D 近似屏幕上/下/左/右，不要求玩家背 Face 世界轴。

Input Mapper 把屏幕向量投到平面，在 ±u/±v 中选夹角最近的几何轴；“合法离散方向”指坐标轴集合，不能为了绕障碍自动转向另一个可走邻格。选轴后核验通行，阻挡则拒绝。平局按固定轴序 +u,+v,-u,-v；相反输入成对取反；近退化投影显示不可判定并拒绝，不随机选方向。相机配置应避免可玩 Face 长期边缘朝镜头；需要确定的相机/输入映射验收。

## 7. CubeOrientation / DiscreteOrientation

玩家姿态使用统一 DiscreteOrientation 的 24 个正交、右手、行列式 +1 旋转。目标复用到 Player、Surface、Inner、RotatableGroup；现有整数基向量算法是参考，不表示公共类型已抽取。

目标接口：ROT_X_POS/NEG[24]、ROT_Y_POS/NEG[24]、ROT_Z_POS/NEG[24]、compose(a,b)、inverse(a)。固定 compose(a,b) 表示先 b 后 a；ID 顺序、单位态和版本必须稳定，Bake/Replay/Hasher 同用。三轴 ±90° 查表闭合，旋转四次为单位态，正反互逆。

玩家 CubeOrientation 在 Shared Space 表达。MOVE 依据当前 normal 与切向移动方向形成真实 90° roll；FaceTransition 应用声明的真实离散旋转序列；所在 World/Group 真旋转时用 Shared Space 旋转增量左乘姿态。固定物理脸 local +Z 不自动对齐镜头。

仅观察用 Camera Rotate 不改变 CubeOrientation。World Rotate/Group Rotate 不是 Camera Rotate；不能引用 P-01“Rotate 保姿态”来忽略载体变换。SAME_NORMAL Shift 保持 Shared Space 姿态；OPPOSITE_NORMAL 按第 13/33 节完整 SurfaceFrame 变换姿态，不回正。

## 8. Surface / Inner

SurfaceWorld、InnerWorld 是两套独立三维 Cube 地图，各自 CubeCells、FaceNodes 和 World Orientation；不要求同布局或 Cube 一一对应。共享一个 Shared Space 和一个 CelestialState。

WorldOrientation 只旋转所选世界；另一个世界不跟转。玩家跟随其所属支撑结构；旋转不承载玩家的世界不能修改玩家物理姿态。固定世界 pivot 属 LevelDefinition。

同世界碰撞/光遮挡在该世界内求解；另一世界的 Cube 不默认替当前世界遮光/挡路。跨世界几何仅用于明确的 World Mapping 等规则。

## 9. World Rotation

底层目标支持 Shared Space X/Y/Z 三轴 ±90°离散旋转，禁止连续自由角度成为逻辑态。玩家表达左转/右转/上翻/下翻/滚转，Input Mapper 依据 Camera Basis 与 LevelConfig 生成明确轴/符号语义动作。

早期只开简单单轴，中期第二轴，后期完整三轴；合法离散增量、allowed_states 和可用 RotationIntent 由关卡配置。RotationAxis 仅在数学层内部使用；公共动作存 rotation_delta，不泄漏相机或轴枚举。未开放操作不显示 UI，也不能被 Solver 绕过。

World 旋转的 pivot/轴转换/端态通过 Validator；Runtime 原子提交 Cube/Face/Mechanism/支撑玩家的完整状态与派生量。全局过渡期间不整体关闭 WASD；仅允许基于已提交局部表面、满足安全与交换性条件的 Local Movement。Shift 和第二次全局空间变更一律拒绝，不排队。载体旋转与 MOVE 的姿态/位置规范组合必须通过第 33 节合同，不能凭动画可见位置接受输入。Camera 只观察结果。

## 10. PlayerLayer / RotateTarget

PlayerLayer=SURFACE/INNER 属 PuzzleState 位置语义。RotateTarget=SURFACE/INNER 属明确 Runtime 控制/UI 状态；站 Surface 可以选 Inner 旋转，两者互不赋值。

Tab 可切 RotateTarget，UI 可直选，未来手柄 Shoulder Button；只允许 Surface Rotate 的早期关卡锁定目标并隐藏无用选择器。不在本轮新增按键实现。

Solver 不为两个 RotateTarget 复制两个谜题节点，而直接生成 ROTATE_SURFACE/ROTATE_INNER。Runtime action 日志记录最终目标；切目标本身不改变 PuzzleState 或消耗求解步数。忙时允许只变选择 UI 与否是表现设置，但不能改变已接受动作的目标。

## 11. Shared Space / FaceAnchor

FaceAnchor、FaceNormal、SurfaceFrame 均由 CubeCell 层级 Transform 自动派生，不是作者拖动的自由 Marker。Shared Space 使用第 5 节精确格点/离散旋转，比较整数或确定有理值。

两个世界的稳定变换提交后再重算 Mapping/Lighting/Connectivity；预览半程不能生效。Face ID 保持 Cube 本地命名：世界旋转后 TOP 可能在 Shared Space 指向 -Z，不能根据当前法线重命名为 BACK。

## 12. World Mapping

Space 的目标来自空间推导，不使用 Surface Face A→人工 Inner Face Z 的常规传送表。候选集合为目标世界合法可站立 Face，其 Shared Space Anchor 与源 Anchor 精确一致，且满足配置的 FaceCompatibility。

0 候选：NO_SHIFT_MAPPING；1 候选：唯一几何映射；多于 1：AMBIGUOUS_SHIFT_MAPPING。先查歧义，再检查阴影/blocked；不能靠当前亮暗暂时遮住结构歧义。不同世界布局可不同，但必须满足同一个空间规则。

公共接口显式分为 Candidate Discovery（另一层 walkable + exact AnchorOverlap pairs）→ Compatibility Classification（SAME_NORMAL / OPPOSITE_NORMAL，按关卡启用项收集）→ Unique Mapping Resolution。SpatialMappingCandidate={source_face,target_face,compatibility}，按完整 source_face/target_face ID 字节序排序。最终 MappingResolutionStatus 为 NONE / UNIQUE / AMBIGUOUS / ERROR；损坏输入或上游溢出必须 ERROR，不能冒充无映射。>1 项保留完整候选、mapping=null，禁止排序后取第一项。Owner、签名与唯一返回记录见公共合同 §5.2/9；这里只做单稳定构型，不引入跨状态搜索。

World Shift 使用真实 AnchorOverlap；Perspective Connection 使用独立视觉投影/连通策略。不能复用旧投影容差当 Shift 的空间阈值；也不能把 Bake 自动生成的映射缓存误称人工传送表。

## 13. FaceCompatibility

底层支持 SAME_NORMAL（n_target=n_source）和 OPPOSITE_NORMAL（n_target=-n_source）；每关配置启用模式，早期只开 SAME_NORMAL。中后期才教学 TOP↔BOTTOM 等背面切换。

不接受任意斜角法线。SAME_NORMAL 保持 Shared Space 角色姿态。OPPOSITE_NORMAL 必须使用完整 SourceSurfaceFrame / TargetSurfaceFrame 的 U/V/N 列基：ShiftFrameTransform = TargetSurfaceFrame × inverse(SourceSurfaceFrame)，NewCubeOrientation = ShiftFrameTransform × OldCubeOrientation。仅取 Frame 的旋转基，不把 Anchor 平移左乘进 Orientation；结果必须属于 24 个合法正旋转。

FaceCompatibility 查询仅输出几何分类；其它合法轴关系返回正常不兼容，不是输入错误。它不读取 LightState、ShiftPermission 或 GlobalTransitionState，也不执行姿态更新；上段姿态规则留给后续成功 Shift 的 Kernel 结算。

这不是固定轴 180° 特例，也不是回正。目标切向轴不同会产生不同确定变换；角色中心的表现偏移另从目标支撑法线派生，不混入 AnchorOverlap。最终位置、姿态和净空仍须通过 PlayerSafety。详见 §33 DECISION-02 与公共合同。

## 14. Shift Rules

所有合法动作先满足位置引用有效、源/目标可站立、唯一映射和安全性等基础结构合同；世界切换的特殊条件如下：

| 方向 | 必要条件 |
|---|---|
| Surface→Inner | AnchorOverlap AND FaceCompatibility AND source.LightState==SHADOW AND !source.shift_exit_blocked AND !target.shift_entry_blocked AND GlobalTransitionState==IDLE |
| Inner→Surface | AnchorOverlap AND FaceCompatibility AND !source.shift_exit_blocked AND !target.shift_entry_blocked AND GlobalTransitionState==IDLE |

每个 Face 分别声明 shift_exit_blocked / shift_entry_blocked，默认 false。禁止离开与禁止进入互相独立；Inner→Surface 特殊禁切使用同一组字段。废弃单一旧字段，不能静默解释或迁移为其中任意一项。几何候选歧义仍须先于光照/出入限制检查。

无映射、normal 不兼容、LIT、离开受限、进入受限、busy、安全失败均给确定 ValidationCode。一次成功 Shift 改 PlayerLocation 并重解 Frame；不改世界 Orientation 或 CelestialSlot，玩家姿态按 SAME/OPPOSITE 规则处理。过程不暴露半切换状态给下一动作。

## 15. Celestial System

### 15.1 同一逻辑天体

只持有一个 CelestialState/CelestialSlot。Surface 显示 Sun，Inner 显示 Moon，共用 Slot 和同一次状态提交；A→B 后换世界仍在 B。不能存 sun_slot 与 moon_slot 两份可变值。

每关配置自己的 Slot IDs、Shared Space 源位置、视觉轨道/过渡与允许转换；数量不固定。A/B、A/B/C/D 是例子，不是本次 P-02 地图批准。Slot 编辑器 Marker 可摆放，但 Bake 量化为确定坐标；不存在 Slot A.1 谜题态。

Controller 目标支持 SET_SLOT、NEXT_SLOT、PREVIOUS_SLOT、TOGGLE_BETWEEN。NEXT/PREVIOUS 的顺序与是否环绕来自关卡 Slot 列表配置；TOGGLE 显式两个合法 ID；设置当前值视为无变化请求，不生成无意义 Solver 自环。两世界机关均可操纵同一状态。

### 15.2 事务与输入

天体视觉 A→MOVING→B，逻辑 committed Slot 在抵达前仍为 A。GlobalTransitionState=MOVING、active_kind=CELESTIAL 时：

| 操作 | 规则 |
|---|---|
| 普通 WASD MOVE | 允许，须通过下述并发合同 |
| SHIFT_WORLD | 拒绝 |
| World Rotate | 拒绝 |
| 再次修改 Celestial | 拒绝 |
| FaceTransition/GroupRotate/其他全局空间操作 | 拒绝 |

到达 B：在离散动作边界提交 Slot B→重算 Logical Lighting 与相关派生→GlobalTransitionState=IDLE→恢复操作。若 roll 正在进行，将视觉到达/提交对齐到该 roll 落定，禁止读到半 roll 状态；这是完成已经接受的一个事务，不是排队启动另一个动作。Reset 可取消整个事务，旧回调不再提交。

### 15.3 与原子 Solver 的一致性补充

为了同时保留“天体移动时可走路”和“Solver 单步 A→B”，本版禁止用动画时间窗作谜题机制。期间仅允许与该 Celestial change **可交换**的普通 MOVE：不改变天体/空间状态，不触发有顺序依赖的机关/Goal/flag 副作用，也不依赖中间光照。受影响的特定 MOVE 在 BUSY 期间拒绝；不关闭整个 WASD 通路。

已接受天体事务保存源 Slot、目标 Slot、机制接受上下文和事务 ID；提交时只更新天体字段，在玩家最新位置/姿态上重解派生，不能把启动时整份 PuzzleState 覆盖回来。自动触发第二次全局操作返回 GLOBAL_TRANSITION_BUSY，直接丢弃请求。允许记录 occupancy 等局部事实，但不保留待执行动作、deferred-trigger、补触发标记；稳定后不能扫描滞留 occupancy 补执行。详见 §33 DECISION-01。

Validator/Kernel 必须证明许可 MOVE 与天体动作的交换性；不能证明时该并发动作不获授权，且关卡不能把它作为唯一必要路线。Solver 用“Celestial 原子提交→许可 MOVE 序列”的规范串行轨迹表示同一最终稳定状态；Runtime 记录实际并发事件，在事务结束的稳定边界比较规范态。普通在途 MOVE 另按旧 Slot 上的核规则核对。将来需要时间窗机关时必须扩展动作模型，不能继续宣称现有原子 Solver 完备。

## 16. Logical Lighting

Visual Lighting 与 Logical Lighting 完全分离。一个 Face 只在 FaceAnchor 采一个逻辑点，只输出 LIT/SHADOW；没有面积百分比、PARTIAL 或柔阴影亮度阈值。

从当前共享 Slot 位置到当前世界 FaceAnchor 的逻辑射线，加 FaceNormal 入射判定及当前世界 occludes_light Cube 阻挡。直接入射且无遮挡为 LIT；背向/切向或被其他 Cube 遮挡为 SHADOW。Slot 源点不得与 Anchor 重合或在该世界不合法遮挡实体内部。

确定性补充：使用量化几何/有理射线；n·(light-anchor)>0 才算可照；等于 0 归 SHADOW。射线取源点与 Anchor 之间开区间，排除接收 Face 自身终点；其他 Cube 的擦边命中按阻挡处理，禁止 GPU epsilon 决定逻辑。返回遮挡 Cube ID/命中原因供调试。自身背面通过 normal 条件处理，不把自面终点当遮挡体。

FOUNDATION 目标从一开始包含真实遮挡逻辑；P-02/P-03 教学只用简单亮暗，不自动开放高塔、多遮挡或 Rotate+Celestial 组合。Slot/World/Group/遮挡机关变化后失效并重算派生缓存，灯光视觉特效不能写回状态。

## 17. FaceTransition

同世界非共面导航必须显式 FaceTransition，例如转角机构、翻面通道、特殊轨道、旋转结构。它与跨世界 Mapping 是两个独立机制，普通 WASD 到边缘不会自动包面。

定义包含稳定 ID、同世界源/目标 Face、进入/退出局部方向、条件与一段真实离散姿态变换；可逆则显式声明反向。端点和旋转由结构合同生成/校验，不能随意“目标姿态=默认值”。根据路径更新 PlayerLocation/Frame/CubeOrientation 及占用机关，并检查终点及运动路径安全。

未配置边就拒绝，没有隐式立方体绕边规则。关卡逐步教学，初期无此机制仍可用同一核。

## 18. RotatableGroup

数据概念：id、layer、cube_ids[]、pivot2、initial_orientation/allowed_states[]、allowed_rotation_deltas、允许状态间 ±90°边。整世界旋转是玩家基础能力；局部组主要由地图机关控制，不由 Tab/Q/E 直选。最终字段名以公共合同为准。

首版 Group 属单一世界，同一 Cube 最多一个局部组，禁止跨世界组与嵌套组。结构变换顺序为 World × Group(pivot) × CubeLocal；Group action 明确父世界坐标轴，Input/Mechanism Adapter 转为该语义，不让渲染矩阵反推规则。

R0/RX90/RX180 是例子。每关声明 AllowedStates，不能把任意连续角度存进去。Validator 检查状态、状态间合法边、多个组/世界配置组合中的同世界重叠、Face 冲突、PlayerSafety；声明非法状态拒绝 Bake，不静默裁掉。配置组合规模超预算报告无法完成验证，不能当 LEVEL_VALID。

玩家站在载体上时必须整体跟随：CubeCell 的共享位置、FaceNode 派生几何、Anchor、Mechanism、PlayerLocation 解析位置、Frame、CubeOrientation 同步转换。cube_id/face 作为本地身份可保持，但其共享位置必须变化；不会把玩家留在原地。

端态合法不证明转动过程安全。作者还需验证允许旋转边的扫掠/夹持安全；首版可用保守包围体证明无碰撞，证明不了则不授权该路径。运行时同合同安全检查作为保险；不以动画穿模当规则通过。

## 19. Godot Level Authoring

目标 Scene：

    PXX_Level
    ├─ SurfaceWorld
    │  ├─ CubeCells
    │  └─ Mechanisms
    ├─ InnerWorld
    │  ├─ CubeCells
    │  └─ Mechanisms
    ├─ Celestial / Slots
    ├─ RotatableGroups
    ├─ Spawn
    ├─ Exit
    └─ LevelConfig

Cube 编辑字段：Cube ID、World Layer、Walkable Faces、Occludes Light、Tags、Rotatable Group；自动生成 Anchor/Normal/Frame。Face Edit Mode 点击面分别配置 Walkable、FaceTransition、Shift Exit Blocked、Shift Entry Blocked、Mechanism；绿/灰/紫/红/黄可作表现，同时提供文字/图标避免只靠颜色。

SURFACE ONLY、INNER ONLY、OVERLAY；Overlay 半透明绿色/紫色观察共享空间与映射。Slot Marker 直接摆放，机关配置 Action 与 Target/Direction。Group 选中高亮成员，编辑 Pivot/AllowedRotationDeltas/AllowedStates，PreviewRotate 返回 INVALID STATE + 冲突 Cube ID。

不要求大量手工隐藏坐标。Editor Tool 只编辑/预览数据，不能持有另一套玩法规则。全局 gizmo 与最终玩法摄像机不同，不影响 Bake 逻辑。

## 20. LevelDefinition / Validate → Bake

Bake 前必须得到 LEVEL_VALID；至少检查 Unique IDs、同世界 Cube overlap、Face definition/conflict、自动 Anchor、Spawn/Exit、Celestial/Mechanism references、Group states/edges、Shift ambiguity、Lighting computable、Player safety。

LevelDefinition 是不可变的唯一规则定义；PuzzleState 是唯一可变谜题状态。所谓“规则真相”不是把动态状态写进配置。

建议字段合同：

| 分组 | 必须提供的规则数据 |
|---|---|
| Header | schema_version、rule_version、level_id、content_hash、来源/构建信息 |
| Spatial | 两世界 Cube 定义、本地几何、Face 属性、世界 pivot/初态/合法旋转域 |
| Navigation | 普通邻接生成策略、FaceTransition、独立 PerspectiveConnection 策略 |
| Groups | 成员、pivot、离散域、状态转换与安全证明信息 |
| Celestial | Slot IDs/精确位置/顺序/合法动作、初态、遮挡规则 |
| Mechanisms | ID、作用域、触发条件、语义动作、状态模式、确定结算顺序 |
| Rules | ShiftCompatibility、方向限制、输入开放能力、并发策略 |
| Objectives | Spawn、GoalPredicate、PuzzleIntent、Milestones |
| Domains | 有限状态域、可枚举配置、规范 ID/排序、验证报告与摘要 |

运行时不遍历 Scene 猜组成员或路径。Bake 标准化几何、声明和策略；Mapping/Lighting/Connectivity 随 PuzzleState 变化仍由 Kernel 推导，可缓存，但不是一张固定传送表。缓存用 content_hash + StateKey 定位，版本不符拒用。

Scene 编辑导致 hash 变化，旧 Bake 标为 stale，Runtime/Solver 不静默混用。只允许有版本与结构验证的 LevelDefinition 被加载，格式可以是 Godot Resource 或其他可序列化容器；容器实现语言不改变合同，留给后续实施设计。

## 21. PuzzleRuleKernel

纯逻辑接口概念：输入 LevelDefinition + PuzzleState + PuzzleAction，输出合法/非法及确定 BlockedReason；合法则输出 NextState 与可解释的规则事件。非法不部分修改状态。

组成：ActionValidator、StateTransition、DerivedStateResolver（SpatialMappingSolver、LogicalLightSolver、ConnectivityResolver）、StateHasher、ActionGenerator、GoalEvaluator。Runtime、Solver、Validator、Replay 都调用同一核。

Kernel 不处理 Shader、Animation、Audio、UI、Camera 对象。相机输入在外部变为 FaceAxis/旋转轴/目标的语义参数。核可消费明确 authored 的离散投影策略数据，但不依赖真实 Camera 节点。

同输入必须同输出，不依赖系统时间、帧率、随机遍历顺序或 SceneTree。机制采用稳定 ID/明确优先级结算局部事实；一次动作至多授权一个原子全局变更，多全局变更声明返回 MULTIPLE_GLOBAL_MUTATIONS，不逐个偷偷执行。MOVING/TRANSITION 中新全局请求立即拒绝，无隐式链或队列。未来连锁必须显式 SequenceController 并另行扩展规格；视觉事件不能反过来提交状态。

## 22. PuzzleState / Derived State

持久规则字段：

- PlayerState：layer、cube_id、face、cube_orientation。
- SurfaceOrientation、InnerOrientation。
- CelestialSlot。
- RotatableGroupStates、MechanismStates、LevelFlags（均限于会影响未来合法动作/Goal 的字段）。

FaceLightState、ShiftMappings、AnchorOverlap、Connectivity、PlayerSurfaceFrame、Camera Transform、Screen Direction 为派生或表现值，不另存可变副本。RotateTarget、held keys、动画进度、声音、鼠标拖动、pending 事务属于 Runtime 会话/调度状态，不作为稳定 Solver 状态。

Camera Transform 不能凭空由状态推导：玩法相机策略来自 LevelDefinition，连续观察/输入控制信息来自 Runtime；两者不得暗中影响 Kernel 动作合法性。若将来保留“玩家可独立改视角且视角改变投影连接”的规则，必须显式增加有限 PerspectiveViewId 与语义动作并纳入 StateKey；在此扩展获规格批准前，不允许以隐藏 Camera 变量决定图边。现有 P-01 的四视角状态仍按历史实现解释，不迁移为本轮承诺。

StateKey 使用固定字段顺序、稳定 ID、24 态 ID、按 ID 排序的组/机关/flags；不要哈希图像、Node 指针或浮点矩阵。删字段必须证明对动作/Goal 无影响；不得把有不同未来行为的姿态合并。缓存命中还比较规范序列化内容，避免只凭短哈希碰撞合并。

FOUNDATION-0.1 的唯一入口为 DATA `foundation/contracts/state_key.gd::build(level,state)`，输出 StateKeyResult。成功 key 为 `statekey.v1:` 加 canonical JSON，字段顺序/转义/UTF-8/no-BOM/no-final-newline/golden 以公共合同 §6.1–6.2 为唯一格式定义。其命名空间包含 level.content_hash/rule_version，状态包含完整 player、world_orientations、celestial、group_orientations、mechanism_states、level_flags；先严格 shape 验证，未知 UI/derived 字段直接报错，不静默删去。visited 使用完整成功 String，失败 key 为空且禁止使用。不会在本轮实现编码器或搜索。

## 23. PuzzleAction / 原子转换

MOVE(face_axis)、SHIFT_WORLD、ROTATE_SURFACE(rotation_delta)、ROTATE_INNER(rotation_delta)、USE_FACE_TRANSITION(transition_id)、TRIGGER_MECHANISM(mechanism_id)、LOCAL_GROUP_ROTATE(group_id,rotation_delta)、MOVE_CELESTIAL(celestial_op,target_slot_id,alternate_slot_id) 为语义动作族。rotation_delta 是 DiscreteOrientation 的一个合法 ±90° 增量 ID，RotationAxis 仅在内部数学层。目标/增量域来自配置，Solver 不模拟 WASD/Q/E/Drag/Tab/Space。

局部旋转和天体动作虽有核动作类型，但 ActionGenerator 只能在存在合法机关授权时产生，不能让玩家全局任意调用。主动触发动作和其派生效果规范为一条边；IDLE 时压力板可随 MOVE 发起唯一全局效果，忙时只记 occupancy，全球效果拒绝且不补执行。不能通过原子结算绕过串行限制。

Solver 中世界/组旋转 R0→RX90、天体 A→B 均原子，不包含插值角/Slot。Runtime 在提交边界调用核并播放确定事件；天体特殊并发采用第 15 节交换性合同。回放计数同时给动作边和产生的机制效果，区分一次 MOVE 触发的天体改变。

GlobalTransitionState 是 Runtime 调度状态，不是 PuzzleState 的字段或 Kernel 外部单例；核只接收合法稳定状态/确定语义动作。Runtime 在调用稳定核前应用同一份声明式动作锁策略，临时安全/并发校验调用核提供的纯函数，不另写规则分支。

## 24. Static Validator

无玩家路径搜索也必须发现：Duplicate Cube ID、Cube Overlap、Invalid Face/FaceAnchor/Orientation/GroupState/CelestialReference/MechanismReference/Spawn/Exit、Ambiguous Shift Mapping。FaceAnchor 非作者字段，校验生成公式、格点与缓存一致性，不能通过手修 Anchor 消除报错。

检查所有声明可用的稳定空间配置，而非只看初态；这是有限配置枚举，不是玩家解法搜索。每个 Face 在每个配置下最多 0/1 个跨世界候选。歧义输出源 Face、两个以上目标、构型 StateKey/Orientation、Anchor 与法线，禁止 Bake。

同世界 Cube overlap 与跨世界 overlap 分开报告；内部接触面冲突与允许共边也区分。源/目标 Face 可站立和角色净空、安全旋转路径可证；无法计算 lighting 或验证组合超预算返回 VALIDATION_BUDGET_EXCEEDED/VALIDATION_INCOMPLETE，不返回 LEVEL_VALID。Validate PASS 只证明声明域结构正确，不证明可解。

## 25. State Graph / Solver

初始稳定 PuzzleState → ActionGenerator 所有合法动作 → Kernel NextState → 标准 StateKey/Visited → 状态图。边保存动作/效果，反向邻接用于软锁分析。Goal 为终止节点；Reset 不属于 Primary Solver Action。

首版搜索策略 BFS，接口暴露 strategy、预算与结果，未来可换 A*。BFS 在每条规范语义边成本为 1 时给最短动作长度；不宣称最短时间。A* 必须声明成本/启发式条件后才能给最优性结论。

预算包括状态数、边数、时间/内存上限、trace/path-count 上限；超出必须 SOLVER_BUDGET_EXCEEDED。只有在完整有限域穷尽且无 Goal 时 PROVEN_UNSOLVABLE。找到一个解但搜索尚未完整可报 SOLUTION_FOUND + coverage_partial，不能顺便宣称无软锁或最短解数量完整。

Visited 去循环，数组稳定排序保证可复现；任何缓存都含 LevelDefinition hash/rule_version。最短解数量统计最短距离 DAG 的不同规范动作序列，不混入不同动画速度/按键。计数溢出返回截断/上界标记，不编造精确值。

## 26. Softlock Analysis

先完整得到 ReachableFromStart，再从全部 Goal 反向可达。集合差 ReachableFromStart − ReverseReachableFromGoal 即 SOFTLOCK_STATE（Goal 本身属于反向可达）。每个问题保留从起点可达的 witness trace 和状态。

Reset 不参与主图；另列 RecoverableByReset，由初态可解且 Runtime Reset 正确的独立验证支撑，不能用“按 R 就好”当无软锁。

图不完整时报告 SOFTLOCK_AUDIT_INCOMPLETE；不能把“没找到回路”当不可达证明，也不能因为已找到某个解便给全关无软锁 PASS。全关无解状态可同时出现在差集中，但报告区分 PROVEN_UNSOLVABLE 与局部死局，避免误导。

## 27. PuzzleIntent / Ablation / Quality

PuzzleIntent 配置 RequiredMechanics、OptionalMechanics、ExpectedMilestones、ForbiddenBypasses。只对 required 的机制做必要性否定判定，optional 未用不报错。

Mechanic Ablation：正常求解后分别禁用 ROTATE_SURFACE、ROTATE_INNER、SHIFT、CELESTIAL_CHANGE、FACE_TRANSITION、LOCAL_GROUP_ROTATE 等，再求解。禁用的是机制效果及全部入口，包括自动机关、派生链与别名，不只过滤一个按键/动作名称。仍可解则 MECHANIC_NOT_ESSENTIAL 或具体 *_BYPASS；禁用天体仍可解可报 CELESTIAL_MECHANIC_BYPASS。预算不足则该消融未知。

Milestones 明确 predicate、先后关系和 strict/advisory。严格教学顺序验证采用 StateKey + 进度自动机的乘积搜索，或等价完整 witness 检查；仅检查首条最短解不足。存在绕过严格顺序的解报 MILESTONE_ORDER_BYPASS。advisory 顺序只提示，不改玩法 Goal，不把两个不同历史进度合并漏查。

质量报告至少给：
ReachableStateCount、SoftlockStateCount、ShortestSolutionLength、ShortestSolutionCount、MechanicsUsed、WorldShiftCount、SurfaceRotateCount、InnerRotateCount、CelestialChangeCount、FaceTransitionCount、LocalGroupRotateCount、AverageBranchingFactor、MaxBranchingFactor。

计数标范围：选定最短 trace 的机制计数与全图覆盖分开；平均/最大分支按可达非 Goal 稳定节点的合法规范动作数，空集合时为 0；最短解数量指规范动作序列，提供是否完整。报告 INTENDED_ALTERNATE_SOLUTION 与 UNINTENDED_BYPASS，第二条合理路线不是自动错误。

## 28. Runtime Parity / Replay

Solver 输出 SolutionTrace，包括 level hash/rule version、初始 StateKey、每个语义动作、预期 NextState/StateKey、机制效果。真实 Runtime 在每个已提交的稳定动作边界逐字段比较 Core PuzzleState == Runtime PuzzleState，差异为严重 RUNTIME_SOLVER_DIVERGENCE，报告第一处动作/字段/前后值。

插值帧不与稳定 NextState 比较，不能为了让结果相等提前提交 Slot。天体并发记录实际 MOVE 及 pending 事务，核对旧 Slot 下的 MOVE，再按第 15 节规范串行序列在事务结束比较全部稳定状态；若不能证明等价即不允许该并发路径。回放用事务 token 防止 Reset 后旧提交。

语义回放证明核/Runtime parity，不证明真实键盘、鼠标、手柄映射与画面可读。后者需要独立 InputMapper 和真人 Playtest。禁用 Audio/FX 不能改变 StateKey。

## 29. Debugging / Visualization

编辑器与 Runtime 调试工具规划：Show Shift Mapping、Logical Lighting、Face Anchors、Face Normals、Rotatable Groups、Celestial Rays、Occlusion Reason。点击 Face 显示 World/Cube/Face/Anchor/Normal/LightState/OverlapTarget/Compatibility/ShiftAllowed/BlockedReason。

Replay Solution、Softlock Heatmap、Shift Mapping Heatmap、State Inspection 使用 Kernel/验证报告的结构化输出。Heatmap 必须标当前构型或多个状态聚合方式，不能给玩家看到的单 Face 贴上没有上下文的“永远安全”。错误显示具体 ID 和复现构型，不只亮红灯。

调试层只观察，禁止通过它悄悄改规则并把结果称正常通关。可视化不是本轮实现任务。

## 30. Testing Strategy / 后续实现验证

| 层 | 必须覆盖的目标（本次均未运行） |
|---|---|
| DiscreteOrientation | 24 态唯一、六轴表闭合、逆/组合律、4 次回原态、载体姿态增量 |
| Spatial | 六 Frame 正交/法线、半格格点、同世界重叠与跨世界允许重叠、禁止自动绕边 |
| Mapping | 0/1/多候选、SAME/OPPOSITE 完整 Frame 变换、旋转后重算、源 exit/目标 entry 独立限制、非阴影正向拒绝/反向允许 |
| Lighting | 正/背/切向、真实遮挡、擦边、源/端点、自面排除、两世界共 Slot |
| Actions | 合法/非法无副作用、机关权限、世界/组承载玩家、所有动作原子端态 |
| Celestial | 4 种控制、A/B Sun/Moon 一致、忙时锁、许可 MOVE 交换性、Reset 取消/无旧提交 |
| Validator/Baker | 结构错误拒 Bake、歧义全声明域、预算不足拒通过、版本/hash/stale |
| Solver/Quality | 有解/完整无解/超预算、循环、软锁、消融所有入口、里程碑乘积搜索、准确计数 |
| Parity | Solver trace 真实 Runtime 稳定端态逐步一致，首个偏离定位 |
| Regression/Experience | 后续适配才运行 P-01 受影响回归；键鼠/持键/丢焦/像素/首次玩家另验 |

实现测试要能用独立小 fixture 验证每个合同，再组合；不能复制 Kernel 算法到测试里做同源自证。旧 108 状态和 Sprite PASS 不迁用为三维 FOUNDATION 验收。

## 31. Future Extensions

在相应规格批准后扩展 A*、更大图/多关质量批处理、局部组复杂机关、OPPOSITE_NORMAL 教学、真实遮挡组合、多轴空间解谜、手柄与高级 Editor 辅助。

若开放独立影响规则的 PerspectiveViewId、嵌套/跨世界 Group、连续时间谜题、随机机关或额外面材质，需要扩展状态域/动作/版本/验证与素材合同，不可只加表现层。六面空间与底面观察也不能假定现有偏航 Sprite 已覆盖。

## 32. Explicitly Deferred Features / 实施边界

当前全部新架构 NOT IMPLEMENTED YET。本轮不做具体类文件、Godot Node/Resource 定义实现、插件脚手架、BFS/A* 代码、光射线程序、Blender 制作或 P-02 地图。

后续建议分阶段但本次不写实施代码：数学/数据合同 → 纯 Kernel 和小 fixture → Validator/Baker → Solver/Intent/Softlock → Runtime parity → Editor 体验完善 → P-01 兼容评估 → 重新评审 P-02。每阶段单独验收与授权，不因本文冻结就自动进入开发。

## 33. Acceptance Criteria / 冻结验收与 review 记录

### 33.1 前一阶段文档 Gate（历史记录）

正式 Spec 存在且涵盖上述 33 节；Obsidian 有导航、机制、工具、验证、心得、可复用方法与事实日志；旧笔记保留并明确版本边界。自检应确认无占位空洞、无概念混淆、无越界功能和无实现状态冒报。Git 变化仅本 Spec，既有跟踪文件哈希不变；Obsidian 差异符合清单。

本轮完成状态是 FOUNDATION_ARCHITECTURE_SPEC_FREEZE_PASS，仅指文档任务完成，不是 FOUNDATION_IMPLEMENTATION_PASS。完成后 AWAITING USER REVIEW，不进入实现。

### 33.2 后续关卡 Gate（不是本轮 PASS）

LEVEL_STRUCTURE_PASS → LEVEL_SOLVABLE_PASS → LEVEL_SOFTLOCK_AUDIT_PASS → LEVEL_PUZZLE_INTENT_PASS → LEVEL_RUNTIME_PARITY_PASS → 真人 Playtest → LEVEL_ACCEPTANCE_PASS。

各阶段必须记录证明范围/预算/版本/证据；技术 PASS ≠ 第一次玩家体验 PASS。

### 33.3 一致性补充与 review 重点

| 问题 | 本文处理 | 结论 |
|---|---|---|
| 旧 P-01 相机 Rotate 保姿态与新真旋转更新姿态 | 第 7/9 节区分 Camera/World/载体，旧实现不动 | 不混用旧合同 |
| 两世界独立布局与旧同 cell Shift | 第 8/12/14 节改为新目标空间映射；旧 P-02 暂停实施重审 | 保留历史不覆盖 |
| 同世界 Cube overlap 与跨世界重合 | 第 5/8 节区分碰撞层 | 不误禁映射机制 |
| OPPOSITE_NORMAL 的 Frame/姿态 | 第 13 节完整目标 Frame × 源 Frame 逆，左乘玩家姿态 | DECISION-02 替代旧保持姿态解释 |
| Shift 出入限制 | 第 14 节分为 shift_exit_blocked / shift_entry_blocked | DECISION-03 替代旧单字段解释 |
| 天体可移动与 Solver 原子转换 | 第 15/28 节限制为可交换普通 MOVE，稳定边界规范回放 | 不引入时间窗谜题 |
| Bake 真相与动态 Mapping/Light | 第 20 节固化规则输入，核推导状态相关结果 | 不烘成隐藏传送表 |
| Kernel 无 Camera 与投影连接 | 第 21/22 节区分相机表现和显式规则离散视角扩展 | 不保留隐藏状态 |
| 只静态 Validate 如何查所有构型歧义 | 第 24 节有限声明域枚举，预算不足不能 Bake | 不只检查初态 |
| 机关间接改变天体绕过消融 | 第 23/27 节按机制效果封锁全部入口 | 防漏检 |

半格坐标、切平面基、光照边界、非嵌套组与并发交换性保留。FOUNDATION-0 按用户明确决策修订下列三项及正文相关章节，作为后续公共合同；仍不表示新能力已经实现。

### 33.5 FOUNDATION-0 三项正式决策

**DECISION-01 — 全局状态迁移严格串行**

Stable PuzzleState → One Atomic Global Transition → Stable PuzzleState。GlobalTransitionState 为 MOVING 或 TRANSITION 时，允许合法 WASD Local Movement；禁止 Space、World Rotate、Local RotatableGroup Global Mutation、再次修改 Celestial 和其它全局 Puzzle State Mutation。拒绝立即生效：不 queue、不 deferred-trigger、不在完成后补触发。Reset 是取消会话事务的例外，不是第二次谜题全局动作。

期间可记录 occupancy 等非全局事实；踏板边缘触发被消费，稳定后持续站立不能补执行，须离开再进入或新的显式授权输入。可交换局部 MOVE 不可夹带被禁止的效果。World/Group 载体旋转按同一原则用最新 PlayerLocation 与局部 MOVE 序列完成确定的端态组合；无法证明安全/等价的那一步拒绝，不能一概关闭 WASD 或依赖动画窗口解谜。第 15 节给出天体情形；未来 Kernel 的并发许可纯函数负责其它情形，本轮只冻结合同。需要连锁时另行显式 SequenceController，不使用隐式事件队列。

**DECISION-02 — OPPOSITE_NORMAL 姿态转换**

SourceSurfaceFrame 与 TargetSurfaceFrame 必须完整提供 Tangent U、Tangent V、Normal，三列构成右手正交基。ShiftFrameTransform = TargetSurfaceFrame × inverse(SourceSurfaceFrame)；NewCubeOrientation = ShiftFrameTransform × OldCubeOrientation。所有乘法按列向量主动变换、右侧先执行。使用旋转部分，不包含 Anchor 平移。结果必须落在合法 24 态 DiscreteOrientation。不得保持错误 world orientation、自动回正，或固定绕某轴 180°。SAME_NORMAL 仍保持原 Shared Space 姿态。

**DECISION-03 — Shift 出入限制拆分**

正式字段为 shift_exit_blocked 与 shift_entry_blocked，默认 false；条件为 Source.shift_exit_blocked == false AND Target.shift_entry_blocked == false。允许进入但不能离开、不能进入但可以离开均可表达。Inner→Surface 特殊禁切复用相同规则。旧单字段只保留在历史来源解释中，不作为公共合同字段或兼容别名。

### 33.6 FOUNDATION-0 公共合同与 Gate

公共命名、字段、枚举值、24 态 ID 编号与数学约定的规范来源为同目录 `2026-09-13-foundation-core-contracts.md`，版本 `foundation.contract.v1`。本文早期概念大小写由该合同映射为唯一序列化字段，禁止各 Work 自建别名。四份实施计划位于 docs/superpowers/plans/2026-09-13-foundation-*.md，只准备后续工作，不在本轮执行。

FOUNDATION_CORE_CONTRACT_FREEZE_PASS 要求：三决策无正文矛盾，命名唯一，坐标与 Frame 一致，四计划接口/所有权一致，现有业务代码不改，Git 差异仅限本 Spec、公共合同、四计划及冻结报告。前一阶段 33.1 的文档 Gate 是历史记录；本阶段以本条为准。完成后停止，不 commit/push/merge/rebase、不启动 Blender。

### 33.7 FOUNDATION-0.1 合同修订与模块反馈

只读核对四个工作区报告、B/C/D 的相关实现与 C 依赖复制证据：A 报告 77,965 数学检查与66旧逻辑回归通过；B 最终1018项中2项范围失败，仍 CONTRACT_MISMATCH；C 报告132项模块/真实依赖检查通过；D 结构655项通过但 StateKey 未实现。此处引用各报告历史运行结果，本轮不重跑 Godot，也不替 B/D 报实现 PASS。

C 的 Stable A→MOVING(A)→Stable B、busy reject/no queue 是已接受的调用层合同；其报告与计划明确未实现 Scheduler/Kernel/Runtime 事务锁。§15/33.5 的目标规则保留，但不能把 C 的纯 Slot/Lighting 查询通过视为事务执行已验收。

本次中央规范冻结：SpatialQueryResult 与 checked range；AnchorOverlap/FaceCompatibility/三个候选阶段；MappingResolutionStatus 四态；ValidationCode 语义表；唯一 StateKeyResult 与 statekey.v1。公共合同 §8.1 是 canonical 名称映射，保留1105并将已确定的 Celestial 引用失败统一1300，不新增同义代码。公共签名修订不变更 A 数学编号或 C 生产输出。

B/D 计划仅附加 FOUNDATION-0.1 恢复任务与新文件边界，旧完成历史不重写。B/C 的快照接线须同步新包装，旧真实集成证据只证明当时被复制的版本；C 副本与源逐字节相同不等于 B 极端坐标安全。各自实施恢复时重新验收，A 无需改算法，C 只需同步其依赖测试消费边界。中央工作不修改四 worktree，不自行恢复它们。

本轮 Gate：FOUNDATION_CONTRACT_RECONCILIATION_PASS。检查公共名字唯一、StateKey 唯一、overflow 无静默退化、Geometry 不混入权限、所有多候选显式歧义、无代码/资产/运行配置变化；差异限两 Spec、B/D 计划及本轮报告。完成后停止，不 commit/push/merge/rebase。

### 33.4 原需求覆盖与来源（续）

用户要求 5.1–5.11 对应本文 5–10/17/18；6.1–6.6 对应 11–14；7.1–7.4 对应 15；8 对应 16；9.1–9.9 对应 19/20/29；10–14 对应 7/21–23；15–19 对应 24–26；20–26 对应 27–30/33；27–32 对应本文件、知识库同步与独立自检记录。

主要现状依据：docs/design/p01-another-world.md、docs/PERSPECTIVE_CONNECTION_TECH_PROTOTYPE_REPORT.md、docs/perspective_connection_design.md、docs/design/CUBE_SPRITE_PRESENTATION_SPEC.md、docs/development-records/PLAYABLE_PUZZLE_PROTOTYPE_01_REPORT.md、CUBE_ORIENTATION_VISUAL_AUDIT.md、CUBE_SPRITE_ORIENTATION_REWORK_REPORT.md、P01_POLISH_FOUNDATION_REPORT.md，以及第 2 节列出代码。旧 docs/prototype_01_design.md 与 docs/PLAYABLE_PUZZLE_PROTOTYPE_01.md 是更早 fixture，不代表当前 F5 主场景。

Obsidian 入口：E:\obsdian\青澄的水泥房\方块娘\若叶睦\00-索引\00-MOC-核心玩法架构.md。本文是目标规则主 Spec，知识页解释原因与复用；历史实现页不被用作新目标的反向约束。
