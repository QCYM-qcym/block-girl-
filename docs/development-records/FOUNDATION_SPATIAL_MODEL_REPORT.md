# FOUNDATION-1B — SPATIAL MODEL 恢复验收

**FOUNDATION_SPATIAL_MODEL_PASS**

**CONTRACT_MISMATCH: NONE**

日期：2026-09-13。此次结论基于新的全量执行；旧1018 checks / 2 failures仅作历史证据。

## 1. 工作区、合同同步与版本

- 工作区：`E:/godot/worktrees/block-girl-foundation-spatial`。
- 分支：`feat/foundation-spatial-model`。
- 同步提交：`b360bfe20f01dca164ac31e1b214ed018d5250fa`，来自 `feat/foundation-core`，标题 `docs: reconcile foundation implementation contracts`。
- 同步方式：`git cherry-pick --no-commit`，仅应用该文档提交，没有创建新 commit 或 merge；HEAD 仍为 `4643062e83a962000d14f0e1dbfbece6e310d4ed`。没有同步 A/C/D 功能分支历史。
- 公共 API revision：`foundation.contract.v1.1`。数据标签仍为 `foundation.contract.v1 / cube24.v1 / foundation.rules.v1`、schema_version=1，未新增 LevelDefinition 字段。
- core contracts、architecture spec、reconciliation report、DATA plan 与同步提交一致；Spatial plan 仅在同步后更新本 Work 完成状态和验收记录。

## 2. 本 Work 文件

| 文件 | 本次结果 |
|---|---|
| `foundation/spatial/surface_geometry.gd` | 保留六面基与层级规则；checked cube/anchor/snapshot、六 FaceNode 工厂、精确重合、方向分类及输入/范围校验 |
| `foundation/spatial/spatial_validation.gd` | 消费 SpatialQueryResult；原始失败传播；保留格点/重叠/封闭面检查；checked Anchor 重验；完整 FaceNode 字段校验 |
| `foundation/spatial/mapping_query.gd` | 新增三阶段候选查询与四态 Resolution |
| 三个同名 `.gd.uid` | 前两个 UID 保留；mapping_query UID 由 Godot 生成 |
| `tests/foundation/spatial/test_spatial.gd` 及 UID | 保留原 golden/结构回归，适配包装；补齐工厂、候选、范围、顺序、深复制与错误传播；原 UID 保留 |
| `docs/superpowers/plans/2026-09-13-foundation-spatial-model.md` | Task 3/4 完成勾选与恢复记录 |
| 本报告 | 本次真实验收及历史失败根因 |

没有重写 Orientation、复制生产旋转表或新增第二套 compose/inverse。Spatial 从真实 MATH.columns/compose 获取基与姿态；面法线/切向量采用其 apply。宽整数位置计算是新合同明确归属 Spatial 的职责。

## 3. FaceAnchor 与 Shared Space

Cube 边长 L=1，`center2/pivot2/position2` 为 L/2 单位的 Vector3i。`make_face_nodes` 恰好生成六项，顺序 FRONT/BACK/LEFT/RIGHT/TOP/BOTTOM；三个 bool 默认 false，每面有独立机制 ID 数组。

FaceAnchor 为 `{face_id, layer, position2, frame}`；frame 只保存 `{u,v,normal}`。normal 是随 Cube/Group/World 离散基派生的有符号单位轴，不另存可编辑 FaceNormal 或浮点 Anchor。Face ID 始终保留 Cube 本地面名。

两层有独立 Cube 布局、World orientation 与 pivot。Shared Space 使用 `World × Group × Cube`；center 经 Group pivot 和 World pivot 顺序变换，Anchor 是 shared_center2 + rotated_normal。每次从定义与已提交状态重算，按 cube_id/face_id 字节序输出，输入不变。

## 4. Candidate API

| API | 返回 | 职责 |
|---|---|---|
| `surface_geometry.anchor_overlap(source,target)` | AnchorOverlapResult | 完整 Anchor/Frame 校验后，仅比较三个 position2 整数完全相等 |
| `surface_geometry.classify_face_compatibility(source,target)` | FaceCompatibilityResult | 仅按法线输出 SAME_NORMAL / OPPOSITE_NORMAL / 正常不兼容 null |
| `mapping_query.discover_mapping_candidates(snapshot_result,faces,source_face,target_layer)` | MappingDiscoveryResult | 先验证完整快照及所有 Face，收集另一层 walkable 且精确重合的 pair |
| `mapping_query.collect_mapping_candidates(snapshot_result,faces,source_face,target_layer,enabled_compatibilities)` | MappingCandidateResult | 校验启用模式，复用 discovery 和 classification，只保留启用分类 |
| `mapping_query.resolve_mapping(collection_result)` | MappingResolutionResult | 严格校验完整 collection 并按候选总数解析 |

pair/candidate 按完整 `(source_face,target_face)` 字节序排序，与 Dictionary/数组插入次序无关。重复 pair 是 DUPLICATE_ID，不去重成 UNIQUE；不同 source 混装拒绝。所有输出拥有独立可变集合。

SAME：`n_target == n_source`。OPPOSITE：`n_target == -n_source`。垂直合法法线返回成功但 compatibility=null；坏 Frame 返回错误。位置不同不改变方向分类；基础重合不筛层、不筛法线。

没有 epsilon、距离阈值或屏幕投影；没有 LightState、ShiftPermission、GlobalState、玩家姿态变更或权限筛选。翻转两种 Shift bool 不改变合法几何查询结果。

## 5. Mapping Resolution

| 状态 | 数值 | mapping | 候选与 issue |
|---|---:|---|---|
| NONE | 0 | null | 空；NO_SHIFT_MAPPING=1400 |
| UNIQUE | 1 | 唯一候选深复制 | 完整单项；issues=[] |
| AMBIGUOUS | 2 | null | 全部 canonical 候选；AMBIGUOUS_SHIFT_MAPPING=1401 |
| ERROR | 3 | null | 空；保留上游或结构错误，不能改成 NONE |

1400/1401 的 path="mapping"、severity=ERROR。歧义 issue 包含排序去重后的源和全部目标 ID，以及 ID/compatibility 符号字符串形式的全部候选证据。多个候选从不选择第一项。

真实几何与独立解析测试分开：相对内部目标面都 walkable 会先 SEALED_WALKABLE_FACE→ERROR，不能伪装成合法歧义空间。AMBIGUOUS 用合同指定的独立完整 collection fixture 验收；真实 discovery/collect 测试涵盖合法 SAME、OPPOSITE、NONE 和非法结构 ERROR。

## 6. Overflow 与原两项失败

resolve_cube、resolve_anchor、snapshot 唯一返回 `{ok,value,issues}`。成功 value 为完整记录、issues=[]；任一错误时 ok=false、value=null，不返回部分快照。

位置分量在运算前提升为 int64；差、符号置换和加 pivot 完成后，分别检查 Group 端态、World 端态及全部六面 Anchor 的 int32 范围，再构造 Vector3i。Group 已越界不能靠 World 抵消后放行；中间差超 int32 但完整端态可表示时正常接受。合法输入为 int32、有符号单位基，位置临时量有界于 int64 内；代码没有可能先溢出 int64 再判断的乘法路径。

溢出采用唯一 `ARITHMETIC_OVERFLOW=1105`，details 含 operation/component/representation/operands/minimum/maximum。snapshot 路径定位到按 ID 排序的 cubes[i].center2 或 anchors[i].position2。任何不可站立面的 Anchor 溢出同样使整个快照失败。

| 历史失败 | 旧根因及错误值 | 本次结果 |
|---|---|---|
| LEFT Anchor 应为 x=-2147483649 | Vector3i 加法先回绕为 2147483647，重验复用了回绕值 | 构造前拒绝1105 / ANCHOR_DERIVATION；value=null |
| World 旋转中心应为 x=4294967292 | pivot 运算先回绕为 -4，偶数格点检查无法识别 | 构造前拒绝1105 / WORLD_TRANSFORM；value=null |

两例均通过 snapshot→validate_snapshot→collect→resolve 全链测试：原始1105传播、无候选、mapping=null、status=ERROR。失败包装/null 不能作为正常 Anchor 参与重合。

## 7. 本次全量测试

Godot `4.7.2.stable.steam.ed1daf0bf`，headless，完整 `tests/foundation/spatial/test_spatial.gd`。

**1533 checks，0 failures，exit 0，stderr 0 bytes。**

| 分组 | checks |
|---|---:|
| 真实依赖存在及脚本装载 | 10 |
| 独立六面/24态 fixture 自检 | 311 |
| 六 FaceNode 工厂 | 10 |
| 重合与方向分类 | 44 |
| 六面 × 24 姿态、完整 Frame/Anchor/身份/所有权 | 907 |
| 层级顺序、静态基、pivot、奇数格点 | 39 |
| 真实 DATA 快照接线与重排 | 31 |
| checked 范围与坏输入回归 | 37 |
| 重叠与封闭面 | 34 |
| 无效快照、错误排序、输入不变 | 31 |
| 候选/四态/多 Cube/多高度/顺序/错误传播 | 79 |

checks 是实际断言计数，含包装校验和独立 fixture 断言，不等于1533个独立场景。新多高度用例中，Inner 中心(0,2,0)经 X+ 到 Shared(0,0,2)，其 BACK 与 Surface TOP 在(0,1,2)精确重合；其它两 Cube 不产生假候选。打乱 cubes/worlds/faces/anchors 与兼容模式顺序结果不变。

TDD记录：Task3/4 RED 在旧裸返回/缺工厂与 Mapping 实现上失败；随后全量覆盖并修复。审查额外发现非 walkable Face 的 mechanism_ids 成员可能漏检，新增两个回归先1526/2失败，修复后1526/0；再增加 collection→ERROR 与旧World溢出的完整传播断言，最终1533/0。最终审查复核无剩余发现。

## 8. 真实依赖、日志与复现

验收目录完全位于本 Work 内：`.godot/spatial-recovery/integration-project`。A/D 文件只读复制至该 ignored 工程；本 Work 的正式 foundation/contracts 和 orientation 路径没有被塞入复制文件或 stub。未使用 test double，未修改其它 Work。真实 DATA 包含 MappingResolutionStatus 的 canonical 枚举。

`verified-sources.json` 记录8个实际消费脚本和8个UID，共 **16/16** 来源/被测副本 SHA-256 一致。来源分别是本 Work、orientation Work 与 contracts Work；读文件不是合并其分支。

证据均在 `.godot/spatial-recovery/`：

- `final.stdout.log`、`final.stderr.log`、`final.exitcode.txt`：本次1533/0。
- `task3-red.*`、`task4-red.*`：新接口实施前失败。
- `review-red.*`、`review-green.*`：完整 FaceNode 成员校验的失败/修复。
- `historical-1018.stdout.log`、`historical-1018.stderr.log`：保留旧两项失败。
- `pre-reconciliation-plan.md`、`pre-reconciliation-report.md`：同步前已有进度和报告。
- `verified-sources.json`：被测文件来源/哈希。

```powershell
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path 'E:/godot/worktrees/block-girl-foundation-spatial/.godot/spatial-recovery/integration-project' --script res://tests/foundation/spatial/test_spatial.gd
```

直接以 B 根目录运行会因 A/D 尚未合并而缺依赖；正式通过结论来自上述真实文件逐字副本的完整接线工程，不以依赖缺失时的测试结果冒充通过。

## 9. git diff 与停止边界

- `git diff --cached --stat`：仅中央合同提交的5个文档，+459/-11。它们已暂存但没有新提交。
- `git diff`：同步后本 Work Spatial plan 的勾选/验收记录。
- `git ls-files --others --exclude-standard`：本 Work三个脚本、三个UID、测试及UID、本报告，共9个未跟踪文件；未把它们冒充已提交文件。
- 公共合同/Spec/中央报告/DATA计划相对 b360bfe 无额外差异。所有中央文档变化都来自用户授权的合同同步。
- 未修改 P-01、Lighting、Celestial、ShiftPermission、Kernel、Solver、Editor、P-02 或任何其它 Work。

本 PASS 只覆盖单个稳定空间构型与几何候选查询，不证明完整 ShiftPermission、全构型安全、LEVEL_VALID 或游戏可玩。保留未提交工作，停止；不 commit/push/merge。
