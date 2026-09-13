# FOUNDATION Spatial Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax. 本文仅计划，FOUNDATION-0 不执行。

**Goal:** 从离散 Cube/World/Group 变换生成六面 Shared Space 快照，并校验单个稳定构型。

**Architecture:** 无 SceneTree 的 surface_geometry 与 spatial_validation；FaceAnchor 由整数几何派生。只做数据快照，绝不实现 Shared Space Mapping Solver 或路径搜索。

**Tech Stack:** Godot 4.7.2 GDScript、Vector3i、Dictionary、headless 测试。

**Spec:** `docs/superpowers/specs/2026-09-13-foundation-spatial-puzzle-architecture-design.md` §5/6/11/18/33；`docs/superpowers/specs/2026-09-13-foundation-core-contracts.md` §3/4/5/9/10。

## Global Constraints

- 根路径 `E:/godot/若叶睦/方块少女-若叶睦`；foundation.contract.v1 / cube24.v1；L=1，所有 position2/center2/pivot2 是半格整数。
- 只写 `foundation/spatial/surface_geometry.gd`、`spatial_validation.gd`、相应 UID、`tests/foundation/spatial/test_spatial.gd`、UID、本计划进度和 `docs/development-records/FOUNDATION_SPATIAL_MODEL_REPORT.md`。
- contracts/orientation/celestial、公共 Spec、game/、prototype/、production/、project.godot、其它测试全部只读；不新建邻模块假脚本。
- 不做 Mapping/Lighting Solver、BFS、全构型枚举、扫掠证明、输入或 Runtime、Blender、P-02；不自动 commit/push/merge/rebase。

## 接口与依赖

消费 MATH `apply(id,vector)`, `compose(a,b)` 和 DATA foundation_types 枚举；消费合同中的 CubeCell、DiscreteTransform、LevelDefinition、PuzzleState 值记录。输出合同 §9 SPATIAL 完整签名：face_frame、face_id、resolve_cube、resolve_anchor、snapshot、validate_snapshot。snapshot 输出 cubes/anchors 排序数组，不能返回 Godot Node 或把玩家位置写回输入。

DATA/MATH 未落地时先写独立的六面 golden fixture 和接口失败测试；实际 preload 接线/集成测试必须等真实模块到位，不向公共路径塞 stub。CELESTIAL 可以先按本合同写固定 ResolvedCube fixture，不必等待本实现。

### Task 1：六面基与整数层级变换

**Files:** surface_geometry 与本测试。

- [ ] 创建 SceneTree 测试入口：缺实现打印 FAIL 并 quit(1)，检查失败累积到 Array[String]，最终失败 quit(1)。先写 golden tests，运行下方命令保存 RED：

```gdscript
var spatial=load("res://foundation/spatial/surface_geometry.gd")
var frame=spatial.face_frame(4)
check(frame.u==Vector3i.RIGHT and frame.v==Vector3i(0,0,-1) and frame.normal==Vector3i.UP,"TOP frame")
check(spatial.face_id(&"tile_a",4)==&"tile_a/TOP","immutable local face identity")
var cube={"cube_id":&"tile_a","layer":0,"center2":Vector3i(2,0,0),"orientation":0,"group_id":&"","occludes_light":true,"tags":[]}
var identity={"rotation":0,"pivot2":Vector3i.ZERO}
var resolved=spatial.resolve_cube(cube,identity,identity)
check(spatial.resolve_anchor(resolved,4).position2==Vector3i(2,1,0),"half-grid TOP anchor")
```

- [ ] 实现合同六面表，返回新 Dictionary；实现 W×G×C 和 pivot2 公式，不用 Transform3D 插值/epsilon。所有面 ID 保留 Cube 本地名称。
- [ ] 添加非交换层级 golden：cube.center2=(2,0,0)、Group delta=22/Y+、pivot2=(0,0,0)、World=2/X+，最终中心=(0,2,0)；交换层级所得中心不同，必须拒绝“顺序无所谓”的实现。
- [ ] 添加奇 pivot2=(1,0,0)、Y+ 后 center2=(1,0,-1) 的非法格点 fixture；resolve 返回确定整数，validate_snapshot 才报告 OFF_LATTICE，不偷偷四舍五入。
- [ ] 运行 GREEN；覆盖六 Face、24 orientation，所有 Frame 正交且 u×v=n；输出数值必须与独立 golden 一致。

### Task 2：快照与初态结构校验

**Files:** 新建 spatial_validation，并扩充本测试。

- [ ] RED fixtures：同层同中心两个 Cube→SAME_WORLD_CUBE_OVERLAP；异层同中心→无该错误；同层中心差(2,0,0)只共面，内部相对 walkable 面→SEALED_WALKABLE_FACE；外侧 Face 不误报。移动/Shift 候选不属于本模块。
- [ ] 实现 snapshot，按 level Cube IDs 与 state World/Group orientation 解析；所有输入先通过 DATA shape。处理数据派生副本，不修改 LevelDefinition/PuzzleState。validate_snapshot 检查中心偶数、锚公式、唯一 Face ID、Frame 合法、同层体积重叠和内部 walkable 面。
- [ ] 接入真实 MATH/DATA fixture：World/Group 旋转后中心和法线变化而 face_id 不变；重算两次相同；交换输入数组次序不改排序后的快照；深比较原输入未变。
- [ ] GREEN 后写报告，明确仅单稳定构型，不含全状态枚举、Shift mapping、安全扫掠或 LEVEL_VALID。

## 验收命令

```powershell
$foundationEvidence='E:/godot/若叶睦/foundation-0-evidence/spatial'
New-Item -ItemType Directory -Path $foundationEvidence -Force | Out-Null
$foundationResult=Start-Process -FilePath 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' -ArgumentList '--headless --path "E:/godot/若叶睦/方块少女-若叶睦" --script res://tests/foundation/spatial/test_spatial.gd' -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput "$foundationEvidence/final.stdout.log" -RedirectStandardError "$foundationEvidence/final.stderr.log"
if ($foundationResult.ExitCode -ne 0 -or (Get-Content "$foundationEvidence/final.stderr.log" -Raw) -match 'ERROR:|FAIL:') { throw 'Spatial failed' }
git diff --check
```

RED 与最终日志分别保存。真实依赖集成未跑则不能报告 FOUNDATION_SPATIAL_MODEL_PASS；通过后停止，只交付模块报告。

## FOUNDATION-0.1 恢复补充（新增任务，不重写 Task 1/2 历史）

**Revision:** 公共合同 `foundation.contract.v1.1`，序列化标签仍 foundation.contract.v1 / cube24.v1。以上 Task 1/2 的原始代码示例和范围为旧实施记录；恢复执行时以公共合同 §5.1/5.2/9 与下列增量为准，旧裸 resolve/snapshot 返回不再合法。此前最终1018 checks / 2 failures，不能沿用更早1011/0作为通过。中央只修改本主仓库计划，不覆盖 B worktree 的完成勾选/日志。

**新增文件权限：** B 可新增 `foundation/spatial/mapping_query.gd`、其 UID；其余沿用 surface_geometry.gd、spatial_validation.gd、tests/foundation/spatial/test_spatial.gd 及其 UID、本 Work 报告/计划。只做当前稳定构型的几何查询，不做 Lighting/ShiftPermission/全构型搜索/Kernel/BFS。新 MappingResolutionStatus 只消费 DATA 定义；缺依赖先记录 RED，不能在 B 本地另建公共枚举。

### Task 3：Checked 派生结果与六 FaceNode 工厂

**Interfaces:** surface_geometry 的 resolve_cube/resolve_anchor/snapshot 签名参数不变，统一返回 SpatialQueryResult={ok,value,issues}；spatial_validation.validate_snapshot(snapshot_result: Dictionary,faces: Array[Dictionary])->Array[Dictionary] 消费包装。surface_geometry.make_face_nodes(cube_id: StringName)->Array[Dictionary] 返回六个独立默认 FaceNode（规范见 §9）。消费 DATA shape validator 与 MATH.columns/compose，不修改 A。

- [x] 保留旧2条失败证据；先补 RED：两个范围 golden 经 resolve→snapshot→validator 均1105，failure.value=null。覆盖 GROUP_TRANSFORM、WORLD_TRANSFORM、ANCHOR_DERIVATION，完整group端态越界后world抵消仍拒绝；identity 大 pivot 而端态可表示不得误拒。测试禁用面 Anchor 溢出也让快照失败。
- [x] 将已有合法几何 golden 改为先断言 ok，再读 value，预期坐标不变；只调整返回包装，不重写独立 golden 数值。

```gdscript
var resolved = spatial.resolve_cube(cube, identity, identity)
check(resolved.ok and resolved.issues.is_empty(), "checked cube")
if resolved.ok:
	var anchor = spatial.resolve_anchor(resolved.value, 4)
	check(anchor.ok and anchor.value.position2 == Vector3i(2,1,0), "checked TOP")
cube.center2 = Vector3i(-2147483648,0,0)
var edge = spatial.resolve_cube(cube, identity, identity)
if edge.ok:
	var overflow = spatial.resolve_anchor(edge.value, 2)
	check(not overflow.ok and overflow.value == null, "LEFT overflow fails atomically")
	check(overflow.issues[0].code == 1105, "canonical overflow code")
```

- [x] 运行原验收入口保存独立 RED；按 §5.1 修为标量 int64 分量计算与端态 int32 预检。不得先 Vector3i 运算再检查；不得复制 A 旋转表或为错误默认 identity。
- [x] validate_snapshot 对上游失败直接传播 issues，成功才校验 value；重新推导 Anchor 同样 checked。保留奇数端态 OFF_LATTICE 校验，不把可表示但非格点的数值误作 overflow。
- [x] make_face_nodes 测试六面0..5、三个bool默认false、机制数组独立、face_id与localface一致；修改一次返回的数组/记录不影响同次其它面或下一次输出。
- [x] 运行 GREEN，单独列出原2失败已解决的真实证据、范围结果形状、历史全量回归，不能只打印新测试通过。

### Task 4：Candidate API / 四态 Resolution

**Interfaces:** surface_geometry.anchor_overlap(source,target)->AnchorOverlapResult；classify_face_compatibility(source,target)->FaceCompatibilityResult。mapping_query.discover_mapping_candidates(snapshot_result,faces,source_face,target_layer)->MappingDiscoveryResult；collect_mapping_candidates(snapshot_result,faces,source_face,target_layer,enabled_compatibilities)->MappingCandidateResult；resolve_mapping(collection_result)->MappingResolutionResult。完整参数类型见合同 §9，唯一字段见 §5.2。

- [x] RED 覆盖 exact integer overlap、±1不重合、Frame非法ERROR；分类 SAME/OPPOSITE/垂直正常null，与位置/亮暗/blocked无关。0/1候选用下列真实有效快照验收；多候选用独立 resolution fixture 验收。相邻 TOP 不会重合 Anchor，不能伪造其成为有效多候选证据；结构非法快照必须先 ERROR。

```gdscript
var candidates: Array[Dictionary] = [
	{"source_face": &"source/TOP", "target_face": &"target_b/BOTTOM", "compatibility": 1},
	{"source_face": &"source/TOP", "target_face": &"target_a/TOP", "compatibility": 0},
]
var result = mapping.resolve_mapping({"ok": true, "candidates": candidates, "issues": []})
check(result.status == 2 and result.mapping == null, "multiple candidates are AMBIGUOUS")
check(result.candidates[0].target_face == &"target_a/TOP", "canonical full face ID order")
check(result.issues[0].code == 1401, "ambiguity canonical code")
```

- [x] 真实 discovery/collect fixture：源 Surface Cube 中心(0,0,0)的TOP，目标 Inner Cube 中心(0,0,0)的TOP及另一个 Inner Cube 中心(0,2,0)的BOTTOM，共享Anchor(0,1,0)。两个目标面均walkable时先由结构校验报 SEALED_WALKABLE_FACE→ERROR；不得靠非法内部面制造“有效多候选”。独立 resolution 的上例检验必须保留，真实几何若可证明结构域内不会歧义也不能删去公共 AMBIGUOUS 状态。
- [x] 合法两层同中心、各仅TOP walkable检验 UNIQUE；源TOP、目标同中心但仅BOTTOM walkable检验 NONE；目标位于(0,2,0)且仅BOTTOM walkable检验 OPPOSITE_NORMAL，启用仅SAME时collect为空。打乱 cubes/anchors/faces 和 compatibility 输入顺序，输出完全一致。
- [x] 保存 RED 后实现三个显式阶段；mapping_query 调用 geometry+spatial_validation，geometry 不反向依赖 mapping_query/validator。查询不改 PuzzleState，不按 light、blocked、busy 过滤；同一几何 fixture 翻转所有两个 Shift bool 后结果保持一致。
- [x] 覆盖上游1105/缺引用/同层目标/非法compatibility/重复pair→ERROR；collect 任一步失败 candidates=[]，resolution mapping=null；0→NONE/1400，1→UNIQUE，>1→AMBIGUOUS/1401，禁止任选第一。独立 synthetic collection 仅为 resolution 单元测试，不称真实空间映射集成。
- [x] 用真实 DATA/MATH 集成重跑本 Work 入口，保留各阶段计数、所有原范围失败回归；报告本次 API revision。C 的测试包装适配由 C 自己后续同步，B 不修改 C。Gate 为新接口和全量现有测试通过后才能 FOUNDATION_SPATIAL_MODEL_PASS，不含完整 ShiftPermission/全构型 LEVEL_VALID。

以上待恢复任务本轮不执行，不自动启动其它 Work，不 commit/push/merge。


## FOUNDATION-1B 恢复验收记录

- **FOUNDATION_SPATIAL_MODEL_PASS；CONTRACT_MISMATCH: NONE。**
- 工作区 `E:/godot/worktrees/block-girl-foundation-spatial`；分支 `feat/foundation-spatial-model`。
- 已将 `feat/foundation-core` 的唯一合同修订提交 `b360bfe20f01dca164ac31e1b214ed018d5250fa` 用 `git cherry-pick --no-commit` 应用至本工作区；没有创建新提交或 merge。同步的五个中央文档在 index 中，本计划完成勾选/本记录为本 Work 后续未暂存修改。
- 公共 API revision `foundation.contract.v1.1`；LevelDefinition 数据标签保持 `foundation.contract.v1` / `cube24.v1`。公共合同、架构 Spec、中央 reconciliation report 和 DATA plan 与该提交逐字一致，B 没有自行改约定。
- 保留旧实现后完成 Task 3/4：checked 派生、六 FaceNode 工厂、AnchorOverlap、Compatibility Classification、deterministic discovery/collect、NONE/UNIQUE/AMBIGUOUS/ERROR、原子范围失败。
- 本次全量入口实测：**1533 checks / 0 failures / exit 0 / stderr 0 bytes**，Godot 4.7.2。其中包括原几何、结构、所有权与排序用例，不仅是旧两项范围回归。
- 原 LEFT -2147483649、WORLD 4294967292 现在均1105；snapshot.value=null，validator保留issues，Mapping为ERROR且无候选。Group越界后World抵消仍拒绝；极端pivot但可表示的identity端态接受。
- 独立验收工程位于本 Work 的 `.godot/spatial-recovery/integration-project`。仅只读复制真实 A/D 文件，不复制算法实现到 B 正式模块、不用 test double、不修改其他 worktree；16/16脚本及UID哈希与源一致。
- 新测试TDD日志、全量结果、来源清单和历史1018/2证据均保存在 `.godot/spatial-recovery/`（ignored）。旧本 Work 进度和报告分别备份为 `pre-reconciliation-plan.md` / `pre-reconciliation-report.md`。
- 最终代码审查发现的 FaceNode.mechanism_ids 成员漏检已用 RED/GREEN 回归修复，复核无剩余发现。完整报告为 `docs/development-records/FOUNDATION_SPATIAL_MODEL_REPORT.md`。
- 上文中央任务“本轮不执行”是合同修订阶段历史，当前用户恢复授权下 Task 3/4 已执行并验收。保留工作区及未提交结果，停止；不 push/merge、不开启后续模块。
