# FOUNDATION-0 — CORE CONTRACT FREEZE REPORT

Date: 2026-09-13

Status: **FOUNDATION_CORE_CONTRACT_FREEZE_PASS**

Branch: `feat/playable-puzzle-p02`

HEAD: `0043ea56dc1cd19b87139e7c989b9fc5126ad71f`（开始与结束相同）

当前仅冻结文档合同与后续实施计划，没有实现 FOUNDATION 算法、最小可执行骨架或新玩法。未启动 Godot/Blender，未修改 P-01，未 commit/push/merge/rebase、未切换分支。当前用户分支名包含 p02 不代表本轮开始 P-02。

## 1. §33 三项最终合同

| 决策 | 正式规则 |
|---|---|
| DECISION-01 | GlobalTransitionState=MOVING/TRANSITION 时允许安全且可交换的 WASD Local Movement；拒绝 Space、世界旋转、局部组全局变更、再次改变天体及其它全局变更。立即拒绝，不 queue/deferred-trigger/完成后补触发。occupancy 可记录，被拒的机关边缘触发不能在稳定后重播。未来连锁显式 SequenceController。 |
| DECISION-02 | OPPOSITE_NORMAL 使用完整 U/V/N：ShiftFrameTransform=TargetSurfaceFrame×inverse(SourceSurfaceFrame)，NewCubeOrientation=ShiftFrameTransform×OldCubeOrientation。只用旋转基，结果属于24态；不回正、不固定轴半圈。SAME_NORMAL 保持 Shared Space 姿态。 |
| DECISION-03 | Source.shift_exit_blocked=false AND Target.shift_entry_blocked=false，两个字段各自默认false；Inner→Surface 也用同一机制。旧单字段不作为正式字段或兼容别名。 |

除 §33.5/33.6 外，同步修订正文 §7/9/13/14/15/18/19/21/23/30 中的相反或含糊表述，保留前阶段范围/验收记录的历史标识。

## 2. 新增与修改文件

游戏仓库内，修改1份已有但未跟踪的文件：

- `docs/superpowers/specs/2026-09-13-foundation-spatial-puzzle-architecture-design.md`

新增6份文档：

- `docs/superpowers/specs/2026-09-13-foundation-core-contracts.md`
- `docs/superpowers/plans/2026-09-13-foundation-orientation-math.md`
- `docs/superpowers/plans/2026-09-13-foundation-spatial-model.md`
- `docs/superpowers/plans/2026-09-13-foundation-celestial-lighting.md`
- `docs/superpowers/plans/2026-09-13-foundation-data-contracts.md`
- `docs/development-records/FOUNDATION_CORE_CONTRACT_FREEZE_REPORT.md`

知识库新增 `E:/obsdian/青澄的水泥房/方块娘/若叶睦/06-决策记录/2026-09-13-FOUNDATION-0核心合同冻结.md`，更新同根目录 `00-索引/00-MOC-核心玩法架构.md` 的当前规范入口，明确旧页面相反解释已被新合同替代。没有重写历史技术页。

本轮前后快照、独立文档核对脚本、报告与差异在 `E:/godot/若叶睦/foundation-0-evidence/2026-09-13/`。未在 C 盘新建项目工作文件，未使用 Blender 工作目录。

## 3. 公共类型与字段摘要

规范版本：`foundation.contract.v1`，数学编号版本 `cube24.v1`，schema_version=1，规则版本保留为 `foundation.rules.v1`。完整字段、固定枚举值和方法签名见公共合同 §2–9。

| 类别 | 唯一公共名称 / 字段 |
|---|---|
| 必需枚举 | WorldLayer、FaceDirection、RotationIntent、FaceCompatibility、LightState、GlobalTransitionState；RotationAxis 仅数学内部 |
| 辅助枚举 | GlobalTransitionKind、FaceAxis、PuzzleActionKind、CelestialOp、ValidationSeverity、ValidationCode |
| ID | CubeCellId、FaceNodeId、RotatableGroupId、CelestialSlotId、MechanismId；补充 FaceTransitionId、LevelId、LevelFlagId |
| DiscreteOrientation | int 0..23，identity0，固定24行列基表；不沿用旧遍历顺序临时编号 |
| SurfaceFrame | u、v、normal；PlayerSurfaceFrame 是语义称呼，不另定义一类 |
| FaceAnchor | face_id、layer、position2、frame |
| PlayerLocation | layer、cube_id、face；PlayerState=location+orientation |
| CubeCell / FaceNode | cube_id/layer/center2/orientation/group_id/occludes_light/tags；face_id/cube_id/face/walkable/shift_exit_blocked/shift_entry_blocked/mechanism_ids |
| LevelDefinition | 版本/header、cell_size、worlds、cubes、faces、groups、celestial、mechanisms、face_transitions、shift_compatibilities、spawn、goal、flag_definitions、build_info |
| PuzzleState | player、world_orientations、celestial、group_orientations、mechanism_states、level_flags；无派生缓存或 Runtime 事务/Camera 字段 |
| PuzzleAction | kind 判别联合；MOVE带face_axis，旋转带rotation_delta，组/天体动作显式mechanism_id授权来源；SHIFT不允许人工target_face_id |
| ValidationIssue | code、severity、path、entity_ids、message、details；稳定Code而非本地化文字决定程序行为 |

记录采用规范 Dictionary，ID 为 StringName，字段键为 String；没有新增全局 class_name。序列化枚举使用冻结符号名，内存使用固定 int。工厂深复制，失败不修改输入。PlayerLayer/RotateTarget 复用 WorldLayer 值但分属位置/会话语义，不合并状态。

## 4. 坐标、姿态和空间映射

Godot 右手系，+X右、+Y上；项目 FRONT=+Z、BACK=-Z、LEFT=-X、RIGHT=+X、TOP=+Y、BOTTOM=-Y。Godot Camera 通常看向-Z，不能把 Vector3.FORWARD 当项目 FRONT。

L=1 逻辑单位=1.0 Godot 世界单位。内部使用 L/2 整数坐标，Cube中心每分量为偶数。Authoring 导入只在1e-6半格误差内接受量化；正式 AnchorOverlap 永远精确整数比较。禁止浮点视觉矩阵累积作为规则状态。

U×V=N；TOP=[+X,-Z,+Y]，完整六面表在合同中。正90°按右手方向，列向量主动变换，compose(a,b)先b后a。Cube/Group/World 变换为 W×G×C，pivot各处在明确父空间；Anchor=shared_center2+R×local_normal。Face ID 保留本地命名，旋转后不按 Shared Space 法线重命名。

24态表、六轴±90°增量、两种不同切向轴的 OPPOSITE 示例均做了独立整数核对：TOP→BOTTOM旧姿态0得到1；另一反法线目标Frame17得到19，避免固定半圈轴假设。

## 5. 四个模块依赖与计划路径

| Work | 所有权 | 依赖 / 计划 |
|---|---|---|
| MATH | foundation/orientation/ | 无算法依赖；`docs/superpowers/plans/2026-09-13-foundation-orientation-math.md` |
| DATA | foundation/contracts/ | 无算法依赖；`docs/superpowers/plans/2026-09-13-foundation-data-contracts.md` |
| SPATIAL | foundation/spatial/ | MATH数学 + DATA枚举；`docs/superpowers/plans/2026-09-13-foundation-spatial-model.md` |
| CELESTIAL | foundation/celestial/ | DATA枚举 + SPATIAL值记录合同，最终接真实snapshot；`docs/superpowers/plans/2026-09-13-foundation-celestial-lighting.md` |

四计划都写明预计文件、输入输出、TDD RED/GREEN 顺序、具体golden fixtures、禁止跨模块修改范围和 Windows Godot headless 验收命令。不存在 TODO/TBD。

可以开始第一波并发开发，各自先做本模块测试与实现；真实集成按 DATA+MATH→SPATIAL→CELESTIAL 执行。缺依赖时不提交公共stub，不把未运行的集成测试记为通过。公共合同与别的Work文件只读，需要改合同则串行提案。没有在本轮自动启动这四个 Work。

## 6. 旧代码与新合同的边界

| 旧实现 | 与新合同的关系 |
|---|---|
| prototype/perspective/cube_orientation.gd | 整数列基、+Z物理脸、主动旋转一致，可作数学参考；旧key字符串不是新稳定0..23 ID，不能直接序列化复用 |
| perspective_controller.gd | 四个二维投影视角是观察/分平台重构；不等于三维 WorldRotation，禁止把“旋转保玩家姿态”套到载体真旋转 |
| P-01 state / grid_movement | 二维同cell Shift、单平面支撑；不符合新独立三维地图/FaceAnchor/OPPOSITE/出入限制模型，保留历史专用实现，不迁移 |
| grid_input.gd | P-01自己的phase/view锁与按键合同保留；新全局事务锁不能由修改该旧控制器偷渡 |
| 正式 Orientation Sprite | 覆盖现有呈现合同；不作为三轴/任意支撑面新Runtime完整美术验收 |

这些是预期的新旧架构差异，不是本轮要修复的 P-01 缺陷；本次没有做兼容适配。

## 7. 自检、Git 差异与结论

独立文档审计 `audit_contract.py` 读取实际Markdown表而非未来实现：156项检查，0失败。覆盖24个合法基、唯一性、全部576组合闭合、六面Frame/编号、六个正负90°、OPPOSITE切向差异、层级顺序golden、三个决策、旧矛盾清除、枚举/ValidationCode唯一、四计划关键段与命令、占位扫描、已有文件哈希。

开始时 Git 只有 `?? docs/superpowers/specs/`。已有Spec本来未跟踪；因此 `git diff --stat` 和 `git diff --numstat` 对跟踪文件为空是预期，不能把空diff误称没有文档改动。逐项检查 `git ls-files --others --exclude-standard`，仅本报告列出的7份FOUNDATION文档；Spec本轮修改另与保存的 spec.before.md 比较。2275个已跟踪文件SHA-256全部不变，包含游戏业务、旧测试、资源和project.godot。

`git diff --check` 通过；新文件另扫描尾随空白/冲突标记/计划占位与字段一致性。证据：E盘 `contract-audit.json`、`tracked-before.json`、`status-before.txt`、`spec-round.diff`、`final-files.json`。未运行未来计划中的Godot测试，因为其实现尚不存在；没有用历史Runtime PASS代替本轮合同自检。

**是否可以开始第一波并发：可以。** 只表示命名、坐标、接口、文件归属与集成顺序已冻结；不是 FOUNDATION_IMPLEMENTATION_PASS，也不是 LEVEL_VALID。当前停止，等待用户安排后续工作。
