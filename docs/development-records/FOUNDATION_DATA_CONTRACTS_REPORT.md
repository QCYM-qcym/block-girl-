# FOUNDATION-1D — DATA CONTRACTS & STATEKEY

**FOUNDATION_DATA_CONTRACTS_PASS**  
**STATE_KEY_PASS**  
**CONTRACT_MISMATCH: NONE**

2026-09-13。结构契约 733 checks、StateKey 546 checks，合计 **1,279 项检查通过**。独立审查及最终回归通过。这里只认证 DATA / statekey.v1，不认证几何、光照、安全、搜索或整套 FOUNDATION 可玩。

## 1. 同步的中央合同

- 工作区：`E:/godot/worktrees/block-girl-foundation-contracts`。
- 分支：`feat/foundation-data-contracts`。
- 来源：`feat/foundation-core` 的 **b360bfe20f01dca164ac31e1b214ed018d5250fa**，`docs: reconcile foundation implementation contracts`。
- 同步方式：只将该提交的五份文档内容同步到本工作树；不是 merge/cherry-pick，不创建提交。HEAD 仍为 `4643062e83a962000d14f0e1dbfbece6e310d4ed`。
- 两份 Spec、Spatial plan、reconciliation report 与来源 Git blob 逐一一致；DATA plan 的中央恢复补充完整同步，保留上轮勾选/历史，之后仅更新自己的任务进度。
- API revision：`foundation.contract.v1.1`。LevelDefinition 标签仍为 `schema_version=1`、`foundation.contract.v1`、`cube24.v1`、`foundation.rules.v1`。没有向19字段定义增加 contract_revision。
- 未同步 A/B/C 功能分支，未自行修改公共合同内容。只读核对后，以同步的公共合同 §6.1/6.2/8.1/9、架构 Spec、DATA plan Task 3/4、reconciliation report 为依据。

## 2. 文件

| 类别 | 文件与变化 |
|---|---|
| 中央文档同步 | `docs/superpowers/specs/2026-09-13-foundation-core-contracts.md`、`2026-09-13-foundation-spatial-puzzle-architecture-design.md`；`docs/superpowers/plans/2026-09-13-foundation-spatial-model.md`；`docs/development-records/FOUNDATION_CONTRACT_RECONCILIATION_REPORT.md`，逐字来源同步 |
| 自有计划/报告 | `docs/superpowers/plans/2026-09-13-foundation-data-contracts.md` 同步追加任务并保留完成历史；本报告更新为恢复阶段结果 |
| 枚举 | `foundation/contracts/foundation_types.gd`：保留全部 ValidationCode；新增 MappingResolutionStatus 四态 |
| 结构校验 | `foundation/contracts/contract_validation.gd`：已知 Slot 引用统一1300；面身份/面编号错误统一1103；其它既有模型与接口保留 |
| 新 StateKey | `foundation/contracts/state_key.gd` 及 UID：唯一 build 入口、校验与完整字符串编码 |
| 结构测试 | `tests/foundation/contracts/test_contracts.gd`：保留原655检查，新增78检查 |
| 新 StateKey 测试 | `tests/foundation/contracts/test_state_key.gd` 及 UID：546检查 |
| 保留 | `foundation/contracts/contract_records.gd` 及原有 UID、本轮没有重写记录工厂或原数据模型 |

累计差异为18个文件，含中央同步文档及上轮尚未提交的实现。所有新证据都放在本工作树内已被忽略的 `.godot/foundation-1d-evidence/`。没有跨工作树写入。

## 3. 测试与审查

| 套件 | 数量 | 最新结果 |
|---|---:|---|
| test_contracts.gd | 733 = 原655 + 新78 | FOUNDATION_DATA_CONTRACTS_PASS；Godot 4.7.2；exit0；stderr为空 |
| test_state_key.gd | 546 | STATE_KEY_PASS；Godot 4.7.2；exit0；stderr为空 |
| 合计 | **1,279** | 全部通过，独立代码审查通过 |

另起独立 Godot 进程完整重跑 StateKey，两个进程均通过固定 golden，输出完全一致：`CROSS_PROCESS_DETERMINISM_PASS`。重复运行不重复计入1,279。

TDD 证据：Task3 RED（30个预期失败）→698 GREEN；面canonical补充 RED（32个预期失败）→733 GREEN；StateKey 缺实现 RED→正式实现与全部546检查 GREEN。StateKey 首次实现已通过精确 golden，JSON解码辅助断言因解析器生成float数组而失败；用独立探针确认原因后改为逐项数值断言，原始精确字符串断言不变。

原655用例没有删除。五处旧预期按中央合同更新：celestial initial_slot_id、slot_order覆盖、edge目标、slot_order诊断筛选四处1006→1300；faces[0].face=6一处1003→1103。后者按公共合同 §8.1 的面语义执行，优先于旧Task3“只改天体断言”的较窄描述，已独立审查确认；无新增名字/字段/API。

### Unicode 验证的实际范围

动态覆盖：U+0001..001F全部可构造控制字符、引号/反斜线/斜杠、非ASCII/非BMP字符、U+2028/U+2029原样、U+FFFD合法保留、Unicode不正规化、24种姿态的十进制输出。

非法Unicode scalar与嵌入U+0000未能通过已测试的 Godot 4.7.2 GDScript String构造方式注入：String.chr会先替换并诊断；JSON解析拒绝surrogate并替换NUL；String索引不能赋整数码点。因此**不宣称动态覆盖**这些不可构造输入。编码器包含非法scalar返回INVALID_TYPE及NUL转义为小写四位JSON转义的防御分支，已逐项代码审查；相关引擎探针日志单独保存，不混入最终零错误测试日志。

## 4. ValidationCode canonical mapping

以中央 reconciliation report §6 / 公共合同 §8.1 为唯一真相；下表是语义对应，不是新增别名。

| 语义 | 唯一 canonical code / 边界 |
|---|---|
| Duplicate Cube ID | DUPLICATE_ID=1005，path/entity_ids定位重复Cube，跨两个世界唯一 |
| Cube Overlap | SAME_WORLD_CUBE_OVERLAP=1200，仅同层；DATA只定义码，不实现几何 |
| Invalid Face | INVALID_FACE=1103：本地面编号/身份组成/完整性；已成形但缺引用1006；错误类型1000 |
| Invalid Orientation | INVALID_ORIENTATION=1101，范围/声明域；错误类型1000 |
| Invalid Rotatable Group State | 姿态/域1101；归属INVALID_GROUP=1202；边域INVALID_ROTATION_EDGE=1203 |
| Invalid Celestial Reference | INVALID_CELESTIAL_REFERENCE=1300：level initial/order/edges、state slot、action target/alternate及嵌入机关动作；缺字段/类型/重复ID仍1002/1000/1005 |
| Invalid Mechanism Reference | INVALID_REFERENCE=1006；权限UNAUTHORIZED_MECHANISM=1503仅为后续Kernel码 |
| Invalid Spawn | 缺字段1002；位置引用/层1006；面1103；姿态1101；安全PLAYER_UNSAFE=1204由后续安全层负责 |
| Invalid Exit | 冻结字段goal；缺字段1002；目标/flag引用1006；面身份1103 |
| Ambiguous Shift Mapping | AMBIGUOUS_SHIFT_MAPPING=1401，DATA不实现Mapping |
| Player Unsafe After Rotation | PLAYER_UNSAFE=1204，DATA不实现安全算法 |
| Arithmetic Overflow | **ARITHMETIC_OVERFLOW=1105** |

无 COORDINATE_OVERFLOW、DUPLICATE_CUBE_ID、CUBE_OVERLAP、INVALID_SPAWN、INVALID_EXIT 等第二套枚举名称。LOCAL_GROUP_ROTATE仍为6，没有ROTATE_LOCAL_GROUP别名。新增公共 MappingResolutionStatus 为 NONE=0、UNIQUE=1、AMBIGUOUS=2、ERROR=3；不进入PuzzleState或key。

## 5. PuzzleState 与 PuzzleAction

PuzzleState严格六字段：

1. `player`：`location={cube_id,face,layer}` 和 `orientation`。
2. `world_orientations`：固定 `[SURFACE orientation, INNER orientation]`。
3. `celestial`：唯一 `slot_id`。
4. `group_orientations`：完整group_id→orientation。
5. `mechanism_states`：完整mechanism_id→StringName状态。
6. `level_flags`：完整flag_id→bool，false也保留。

LevelDefinition仍19字段。Mechanism、RotatableGroup、Celestial定义与工厂沿用旧模型；新增的不是第二份状态记录。

PuzzleAction保留八种语义联合：MOVE、SHIFT_WORLD、ROTATE_SURFACE、ROTATE_INNER、USE_FACE_TRANSITION、TRIGGER_MECHANISM、LOCAL_GROUP_ROTATE、MOVE_CELESTIAL。按键不作为Action。

## 6. StateKey API、格式与排序

唯一入口：

```gdscript
StateKey.build(level: Dictionary, state: Dictionary) -> Dictionary
```

唯一返回：`{ok: bool, key: String, issues: Array[ValidationIssue]}`。先验证level，再验证state及合法Unicode文本；失败key=""且包含ERROR issues，不返回部分key。输入不变，返回issue集合深复制，不能污染下一次调用。

成功key是完整 **`statekey.v1:` + canonical JSON**，可直接作为Dictionary/visited的String键。没有binary、hash-only、cache hash或第二个debug序列化API。成功String精确相等即同key；测试以完整String建小型Dictionary验证去重，没有搜索算法。

固定顺序：

- 顶层：`level_hash, rule_version, state`。
- state：`celestial, group_orientations, level_flags, mechanism_states, player, world_orientations`。
- player：`location, orientation`；location：`cube_id, face, layer`。
- 三个map：按ID Unicode码点升序，全量编码；对象顺序显式生成，map排序显式比较码点，不依赖Godot Dictionary遍历顺序。
- 世界姿态数组保持SURFACE/INNER位置，不按数值排序；整数是十进制0..23，布尔是true/false，Layer/Face使用冻结符号。
- UTF-8、无BOM、无结构空白、无末尾LF/CR；手动按合同转义，合法非ASCII不转换为Unicode转义、不正规化。

命名空间只取level.content_hash/rule_version，完整状态取六字段。level_id/build_info不重复加入；content_hash真实性不由StateKey重算。另一合法content_hash改变key；不支持的rule_version返回VERSION_MISMATCH，未伪造第二种合法v1规则版本。

合同golden A为347 UTF-8字节、B为428字节，预期直接复制合同文字，逐字/长度验证。所有核心字段敏感性、三个map独立正逆序的8种组合、顶层/嵌套插入顺序、每个机关/组/flag值变化及world数组顺序均覆盖。

## 7. UI / Derived exclusion

Camera、RotateTarget、AnimationProgress、Visual FX、Audio、FaceLightState、ShiftMapping、AnchorOverlap、Connectivity、Debug/UI、Frame、事务字段均不编码。

按冻结边界区分：独立的UI数据不传入build，改变它不会改变核心key；把这些字段混入正式PuzzleState任一记录层级会返回UNKNOWN_FIELD且key=""，不会静默丢字段后生成看似合法的key。map新增未声明ID或缺声明成员同样拒绝。返回错误保留code和path/entity_ids/details上下文。

## 8. ARITHMETIC_OVERFLOW 与依赖

1105唯一名称为ARITHMETIC_OVERFLOW，已有enum及无别名检查通过。Vector3i为int32、宽整数临时运算为int64的传播合同已同步；实际Spatial/Lighting溢出算术及结果包装由相应Owner实现。DATA没有新增坐标运算，也没有伪造溢出几何回归PASS。

依赖：`state_key -> contract_validation + foundation_types`；`contract_validation -> foundation_types`；`contract_records`仍无算法依赖。没有Orientation/Spatial/Lighting算法、BFS/A*、Runtime Shift、Editor Plugin、P-02或跨模块stub。

## 9. CONTRACT_MISMATCH 与 git diff

**CONTRACT_MISMATCH: NONE。** 上轮缺少的正式StateKey API/返回格式和canonical code映射，已通过指定中央提交解决并按本轮测试重新验收。唯一实现解释是按权威§8.1修正面码；潜在代价为仍依赖旧1003/1004面码的调用方需要同步canonical语义，未改变其他枚举的类型/范围行为。

未自动commit/push/merge/rebase；保留分支和全部未提交变更。`git diff --check`通过。普通git diff只显示跟踪文档，新增代码/报告仍未跟踪；已另外生成包含所有18个文件的完整新增/修改补丁，避免漏报。

## 10. 证据与复现

证据目录：`E:/godot/worktrees/block-girl-foundation-contracts/.godot/foundation-1d-evidence/`。

- `final-contracts.stdout.log` / `.stderr.log`：733通过。
- `final-statekey.stdout.log` / `.stderr.log`：546通过。
- `statekey-process2.stdout.log` / `.stderr.log`：独立进程重复通过，golden一致。
- `task3-red.*` / `task3-green.*`、`task3-face-red.*` / `task3-face-green.*`、`statekey-red.*` / `statekey-green.*`：TDD。
- `contract-sync-proof.txt`：来源commit内容逐字核验。
- `source-sha256.json`：交付源码与UID哈希。
- `working-tree.diff`：完整累计差异，包含未跟踪新文件。
- `diff-stat.txt`：含新文件的增删统计及工作区状态。
- `task3-report.md` / `task4-report.md`：子任务证据；`data-report-before-recovery.md` / `data-plan-before-sync.md`保留上轮历史。

```powershell
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path 'E:/godot/worktrees/block-girl-foundation-contracts' --script res://tests/foundation/contracts/test_contracts.gd
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path 'E:/godot/worktrees/block-girl-foundation-contracts' --script res://tests/foundation/contracts/test_state_key.gd
git -C 'E:/godot/worktrees/block-girl-foundation-contracts' diff --check
```

以上两项验收均完成，停止。未进入任何其他Work或功能阶段。
