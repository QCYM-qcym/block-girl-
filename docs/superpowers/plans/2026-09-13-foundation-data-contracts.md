# FOUNDATION Data Contracts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax. 本文仅计划，FOUNDATION-0 不执行。

**Goal:** 实现已冻结枚举、纯记录工厂与结构验证边界，供其它 Work 直接消费。

**Architecture:** 三个 preload 脚本；公共记录是 Dictionary schema，不注册全局类。DATA 不依赖任何数学/空间/光照算法，结构检查不能冒充完整关卡 Validator。

**Tech Stack:** Godot 4.7.2 GDScript、StringName ID、Vector3i、Dictionary、SceneTree 单元测试。

**Spec:** `docs/superpowers/specs/2026-09-13-foundation-spatial-puzzle-architecture-design.md` §20–24/33；`docs/superpowers/specs/2026-09-13-foundation-core-contracts.md` 全文是逐字段规范。

## Global Constraints

- 根路径 `E:/godot/若叶睦/方块少女-若叶睦`；foundation.contract.v1 / cube24.v1 / foundation.rules.v1，schema_version=1。
- 只写 `foundation/contracts/foundation_types.gd`、`contract_records.gd`、`contract_validation.gd`、相应 UID、`tests/foundation/contracts/test_contracts.gd`、UID、本计划进度和 `docs/development-records/FOUNDATION_DATA_CONTRACTS_REPORT.md`。
- orientation/spatial/celestial、公共 Spec、game/、prototype/、production/、project.godot、其它测试只读。不创建 CubeOrientation 同名全局类，不重命名旧 P-01 字段。
- 不实现 Kernel/StateHasher/Mapping/Lighting/BFS/Baker/Editor/Runtime Scheduler；不启动 Blender，不做 P-02；不自动 commit/push/merge/rebase。

## 接口与依赖

无算法依赖，所有固定枚举仅在 foundation_types 定义一次，RotationAxis 除外，它由 MATH 内部所有。按合同 §9 输出 make_player_location、make_player_state、make_action、initial_state 与 validate_level_shape / validate_state_shape / validate_action_shape。工厂不是合法性证明，initial_state 前置为 shape 验证通过；非法输入由明确的验证接口返回排序后的 ValidationIssue。

DATA 可以与 MATH 完全并行；SPATIAL/CELESTIAL 读取枚举与值记录，不能修改 DATA 文件。发现缺字段需要串行改合同，不能自行加 optional Dictionary 逃逸字段。

### Task 1：枚举和记录所有权

**Files:** foundation_types、contract_records 与本测试。

- [x] 创建 SceneTree 测试入口，运行时检查实现路径；缺实现明确 quit(1)。先写以下 golden RED：

```gdscript
var Types=load("res://foundation/contracts/foundation_types.gd")
var Records=load("res://foundation/contracts/contract_records.gd")
check(Types.WorldLayer.SURFACE==0 and Types.WorldLayer.INNER==1,"layer wire IDs")
check(Types.FaceDirection.FRONT==0 and Types.FaceDirection.TOP==4,"face wire IDs")
var location=Records.make_player_location(0,&"floor",4)
var player=Records.make_player_state(location,0)
location.cube_id=&"changed"
check(player.location.cube_id==&"floor","factory owns deep copy")
var action=Records.make_action(1,{})
check(action=={"kind":1},"Shift action has no target override")
```

- [x] 执行下方命令保存 RED；按合同逐值定义枚举/ValidationCode；工厂只复制规范记录，make_action 把 kind 与深复制 payload 组合。payload 中已有 kind 时返回空 Dictionary，由 validate_action_shape 返回 MISSING_FIELD；不能覆盖函数 kind 参数或静默删去冲突。
- [x] 增加每个枚举值、空/非空 ID、集合深复制 golden；initial_state 从 spawn/world初态/唯一Slot/group/机制/flags构造新状态，不能持有定义集合引用。运行 GREEN。

### Task 2：形状、版本、身份与动作联合

**Files:** contract_validation 与本测试。

- [x] 先写最小合法 fixture：两 World 各identity0且allowed_states=[0]，无旋转开放；一个 Surface Cube `floor` 的六面定义，仅 TOP walkable；Celestial Slot `a` 位于(0,6,0)，order=[a]、wrap=false、edges=[]；groups/mechanisms/face_transitions/flags=[]；spawn=(SURFACE,floor,TOP,0)，goal=floor/TOP；所有 header 与空 build_info 按合同提供。
- [x] RED 检查：上述 shape 无错误；缺 field→MISSING_FIELD；额外 field→UNKNOWN_FIELD；重复 cube_id→DUPLICATE_ID；无目标引用→INVALID_REFERENCE；orientation=24→INVALID_ORIENTATION；错误版本→VERSION_MISMATCH；单一旧 Shift 字段→UNKNOWN_FIELD；两个新限制各自 bool 接受。
- [x] 按合同验证必填/未知字段、类型、范围、ID格式、六面完整性、引用、组归属正反一致、初态属于声明域、Slot顺序/边、机制状态域。数学组合/几何Overlap/光照/安全性不在 shape 校验中；不复制24态矩阵表或射线算法。
- [x] 动作联合 RED：SHIFT_WORLD 携带 target_face_id 拒绝；MOVE 缺 face_axis 拒绝；rot delta=1（180°）拒绝；group/天体动作缺 mechanism_id 拒绝；SET/NEXT/PREVIOUS/TOGGLE Slot字段组合逐项检查；合法形状不代表运行时拥有权限。
- [x] 状态 RED：组/机制/flag 的 key 必须恰好覆盖定义，不许缺失或追加未知 ID；PlayerLocation 引用必须同 layer；不得含 Frame/LightState/held_keys/global_transition_state。按确定 path/code/entity_ids 排序 issues，输出前后输入深比较一致。
- [x] 运行 GREEN，报告 STRUCTURE_CONTRACT 检查范围，不输出 LEVEL_VALID、不宣称 Kernel 或 Solver 实现。

## 验收命令

```powershell
$foundationEvidence='E:/godot/若叶睦/foundation-0-evidence/contracts'
New-Item -ItemType Directory -Path $foundationEvidence -Force | Out-Null
$foundationResult=Start-Process -FilePath 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' -ArgumentList '--headless --path "E:/godot/若叶睦/方块少女-若叶睦" --script res://tests/foundation/contracts/test_contracts.gd' -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput "$foundationEvidence/final.stdout.log" -RedirectStandardError "$foundationEvidence/final.stderr.log"
if ($foundationResult.ExitCode -ne 0 -or (Get-Content "$foundationEvidence/final.stderr.log" -Raw) -match 'ERROR:|FAIL:') { throw 'Data contracts failed' }
git diff --check
```

RED 与最终日志分别保存。通过输出 FOUNDATION_DATA_CONTRACTS_PASS、字段清单和报告；停止，不替其它模块实现算法。

## Work D execution — 2026-09-13

- Task 1 / Task 2 complete in the explicitly assigned worktree on feat/foundation-data-contracts.
- RED evidence retained for missing implementations. Full suite: 655 checks, Godot 4.7.2, exit 0, empty stderr.
- Independent Task 1 and final whole-Work reviews: spec compliant, quality clean.
- Acceptance: FOUNDATION_DATA_CONTRACTS_PASS (STRUCTURE_CONTRACT only). Report: docs/development-records/FOUNDATION_DATA_CONTRACTS_REPORT.md.
- Public contract unchanged; no CONTRACT_MISMATCH identified; no commit/push/merge/rebase. Other Work acceptance is not certified here.

## FOUNDATION-1D follow-up review

- Current frozen STRUCTURE_CONTRACT revalidated: FOUNDATION_DATA_CONTRACTS_PASS, 655 checks, Godot 4.7.2, exit 0, empty stderr.
- Expanded request: CONTRACT_MISMATCH. Several requested exact ValidationCode names are absent from the frozen ABI; StateKey has canonicalization principles but no frozen callable API/result/byte golden.
- The new user request authorizes StateKey implementation in principle, superseding the earlier phase deferral. Public ABI freeze remains authoritative; no aliases or new public StateKey interface were invented in this Work.
- Requirements mapping, StateKey design constraints, pending contract decisions, tests, dependencies, and full working-tree diff location are recorded in FOUNDATION_DATA_CONTRACTS_REPORT.md.
- No production/test changes in this follow-up; only this progress entry and the report. No public Spec changes, cross-worktree edits, commit/push/merge/rebase. Expanded acceptance remains pending; stop at contract mismatch.


## FOUNDATION-0.1 恢复补充（新增任务，不重写已完成结构部分）

**Revision:** API合同 foundation.contract.v1.1；LevelDefinition 标签仍 schema_version=1 / foundation.contract.v1 / cube24.v1 / foundation.rules.v1，仍19字段；PuzzleState 仍6字段。前文 Task 1/2 和“不实现 StateHasher”是旧范围记录，以下仅授权新增 StateKey 字符串编码；不授权 BFS/Kernel/Baker。中央计划不复制或覆盖 D worktree 原有完成勾选。历史655项结构检查已通过，StateKey 未实现；新任务需重新验证，不能继承该计数作为新功能 PASS。

**新增文件权限：** D 可新增 `foundation/contracts/state_key.gd`、其 UID、`tests/foundation/contracts/test_state_key.gd`、其 UID。可修改原 foundation_types.gd、contract_validation.gd、tests/foundation/contracts/test_contracts.gd 与自己的报告/计划；其它模块仍只读。

### Task 3：Canonical ValidationCode 与新增结果枚举

**Interfaces:** foundation_types 维持原 ValidationCode 全部名字/值；新增 MappingResolutionStatus={NONE:0,UNIQUE:1,AMBIGUOUS:2,ERROR:3}，记录只是公共 Dictionary schema，不建别名类。唯一语义表为公共合同 §8.1。

- [x] 增补 RED：固定四态枚举；检查1105只有 ARITHMETIC_OVERFLOW，无 COORDINATE_OVERFLOW/DUPLICATE_CUBE_ID/CUBE_OVERLAP/INVALID_SPAWN/INVALID_EXIT 等旧提示词别名；LOCAL_GROUP_ROTATE 仍6。
- [x] 针对已知 Slot 引用的缺失目标/覆盖错误，分别建立 level.celestial（initial/order/edges）、PuzzleState.celestial.slot_id、MOVE_CELESTIAL target/alternate 的案例，期望1300。缺字段/类型/重复ID等独立形状错误保留1002/1000/1005。机关和其它普通引用仍1006。
- [x] 运行 test_contracts 保存 RED；只将 DATA 中已确定的 Celestial 引用失败从通用1006收敛到已有1300，并更新相应旧断言。不能把所有 _reference 调用无差别改码；不修改 C 已通过的专用引用检查。

```gdscript
check(Types.MappingResolutionStatus.NONE == 0, "resolution NONE ABI")
check(Types.MappingResolutionStatus.ERROR == 3, "resolution ERROR ABI")
check(Types.ValidationCode.ARITHMETIC_OVERFLOW == 1105, "single overflow code")
check(Types.ValidationCode.INVALID_CELESTIAL_REFERENCE == 1300, "slot reference canonical code")
check(not Types.ValidationCode.has("COORDINATE_OVERFLOW"), "no overflow alias")
```

- [x] 重跑完整结构回归，报告因1300收敛而改变的断言清单与最终 check 数；不声称 DATA 已实现几何、安全或歧义求解。其它原655检查语义保留，不为了绿灯删除案例。

### Task 4：唯一 StateKey API 与 canonical format

**Interfaces:** `foundation/contracts/state_key.gd::build(level: Dictionary,state: Dictionary)->Dictionary`，StateKeyResult={ok:bool,key:String,issues:Array[ValidationIssue]}。依赖仅为 DATA.contract_validation/foundation_types；不依赖 MATH/SPATIAL/CELESTIAL。格式严格按合同 §6.1/6.2，schema prefix 为 statekey.v1:。

- [x] 新建独立 headless SceneTree test_state_key.gd，缺实现明确失败并非零退出。建立合同 golden A/B 的完整 shape 合法 LevelDefinition；B 的组、机制、flags、Inner Face/Slot 和允许姿态域必须真实声明，不能跳过 validator；canonical key 预期从文档固定字符串复制，不能用待测编码器生成 expected。
- [x] RED：所有六状态字段和嵌套位置/姿态分别做合法单变量改变，key均改变；三个map正序/逆序/多种插入次序均得到golden B。world_orientations 保留 [Surface,Inner] 序，不排序；false flag不省略。新增未声明map成员、缺成员、嵌套 UI/derived字段、错误类型/引用/版本一律失败，key=""。

```gdscript
var first = state_key.build(level, state)
check(first.ok and first.key == expected_golden, "statekey.v1 exact golden")
var reversed = state.duplicate(true)
var groups: Dictionary = {}
groups[&"beta"] = 22
groups[&"alpha"] = 2
reversed.group_orientations = groups
check(state_key.build(level, reversed).key == first.key, "map insertion order ignored")
var invalid = state.duplicate(true)
invalid["rotate_target"] = 1
var rejected = state_key.build(level, invalid)
check(not rejected.ok and rejected.key == "", "unknown UI state rejected")
```

- [x] 单独 RED 覆盖文本转义 golden、合法非ASCII、引号/反斜线/控制字符、无BOM、无末尾LF/CR、枚举符号而非数字、十进制Orientation、no-whitespace对象边界。非法 Unicode scalar 返回INVALID_TYPE，不做正规化。两个合法不同content_hash得到不同key；unsupported rule_version得到VERSION_MISMATCH，不能伪造两个都合法的v1规则版本来测试。
- [x] 运行新入口保存 RED；实现 build 的两阶段shape检查和唯一字符串编码。保留完整String相等/UTF-8序列化，不做二进制打包或hash-only返回；不新增第二个 debug/compact key方法。只编码严格验证后的完整状态和level_hash/rule_version namespace，不把build_info/表现/派生加入。
- [x] GREEN：检查输入深比较不变，返回issues可修改但不污染后续调用。对成功key直接用 Dictionary 建visited并确认同状态去重、不同状态不合并；invalid key不能插入。重跑 test_contracts 与 test_state_key 两个入口，记录独立check数与错误输出，不把文档JSON检查称作GDScript实现验证。

新入口验收命令（在恢复后的 D 工作区/其独立真实依赖测试工程执行，日志使用本轮新文件名；不在中央合同修订中执行）：

```powershell
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path 'E:/godot/worktrees/block-girl-foundation-contracts' --script res://tests/foundation/contracts/test_state_key.gd
if ($LASTEXITCODE -ne 0) { throw 'StateKey failed' }
```

最终报告分别给 STRUCTURE_CONTRACT 与 STATEKEY 验证结果、API revision和statekey.v1；二者新检查均通过才清除本轮 CONTRACT_MISMATCH。本计划不执行恢复动作、不自动改其它 Work、不 commit/push/merge。

## FOUNDATION-1D 恢复完成

- 同步中央提交 b360bfe20f01dca164ac31e1b214ed018d5250fa；仅内容同步，未merge/commit，保留历史完成记录。
- Task3：733 checks（原655+78）；Task4：546 checks；合计1279，最终exit0、stderr为空。独立进程StateKey复验一致。
- FOUNDATION_DATA_CONTRACTS_PASS / STATE_KEY_PASS / CONTRACT_MISMATCH: NONE。独立审查完成，最终报告已更新。
- Ruling：公共合同§8.1的本地面/面身份1103映射优先于旧Task3仅改Celestial断言措辞；保留原用例，只改相应预期。调用方若依赖旧面错误码须同步，未新建别名。
- Unicode非法scalar/NUL构造被引擎先拒绝或替换；对应防御分支代码审查通过，不声称动态覆盖。其余Unicode/全部可表示C0控制字符/24姿态均有动态测试。
- 无公共合同自主修改、跨模块算法、BFS/A*、Runtime或自动commit/push/merge。到此停止。
