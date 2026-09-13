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

- [ ] 创建 SceneTree 测试入口，运行时检查实现路径；缺实现明确 quit(1)。先写以下 golden RED：

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

- [ ] 执行下方命令保存 RED；按合同逐值定义枚举/ValidationCode；工厂只复制规范记录，make_action 把 kind 与深复制 payload 组合。payload 中已有 kind 时返回空 Dictionary，由 validate_action_shape 返回 MISSING_FIELD；不能覆盖函数 kind 参数或静默删去冲突。
- [ ] 增加每个枚举值、空/非空 ID、集合深复制 golden；initial_state 从 spawn/world初态/唯一Slot/group/机制/flags构造新状态，不能持有定义集合引用。运行 GREEN。

### Task 2：形状、版本、身份与动作联合

**Files:** contract_validation 与本测试。

- [ ] 先写最小合法 fixture：两 World 各identity0且allowed_states=[0]，无旋转开放；一个 Surface Cube `floor` 的六面定义，仅 TOP walkable；Celestial Slot `a` 位于(0,6,0)，order=[a]、wrap=false、edges=[]；groups/mechanisms/face_transitions/flags=[]；spawn=(SURFACE,floor,TOP,0)，goal=floor/TOP；所有 header 与空 build_info 按合同提供。
- [ ] RED 检查：上述 shape 无错误；缺 field→MISSING_FIELD；额外 field→UNKNOWN_FIELD；重复 cube_id→DUPLICATE_ID；无目标引用→INVALID_REFERENCE；orientation=24→INVALID_ORIENTATION；错误版本→VERSION_MISMATCH；单一旧 Shift 字段→UNKNOWN_FIELD；两个新限制各自 bool 接受。
- [ ] 按合同验证必填/未知字段、类型、范围、ID格式、六面完整性、引用、组归属正反一致、初态属于声明域、Slot顺序/边、机制状态域。数学组合/几何Overlap/光照/安全性不在 shape 校验中；不复制24态矩阵表或射线算法。
- [ ] 动作联合 RED：SHIFT_WORLD 携带 target_face_id 拒绝；MOVE 缺 face_axis 拒绝；rot delta=1（180°）拒绝；group/天体动作缺 mechanism_id 拒绝；SET/NEXT/PREVIOUS/TOGGLE Slot字段组合逐项检查；合法形状不代表运行时拥有权限。
- [ ] 状态 RED：组/机制/flag 的 key 必须恰好覆盖定义，不许缺失或追加未知 ID；PlayerLocation 引用必须同 layer；不得含 Frame/LightState/held_keys/global_transition_state。按确定 path/code/entity_ids 排序 issues，输出前后输入深比较一致。
- [ ] 运行 GREEN，报告 STRUCTURE_CONTRACT 检查范围，不输出 LEVEL_VALID、不宣称 Kernel 或 Solver 实现。

## 验收命令

```powershell
$foundationEvidence='E:/godot/若叶睦/foundation-0-evidence/contracts'
New-Item -ItemType Directory -Path $foundationEvidence -Force | Out-Null
$foundationResult=Start-Process -FilePath 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' -ArgumentList '--headless --path "E:/godot/若叶睦/方块少女-若叶睦" --script res://tests/foundation/contracts/test_contracts.gd' -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput "$foundationEvidence/final.stdout.log" -RedirectStandardError "$foundationEvidence/final.stderr.log"
if ($foundationResult.ExitCode -ne 0 -or (Get-Content "$foundationEvidence/final.stderr.log" -Raw) -match 'ERROR:|FAIL:') { throw 'Data contracts failed' }
git diff --check
```

RED 与最终日志分别保存。通过输出 FOUNDATION_DATA_CONTRACTS_PASS、字段清单和报告；停止，不替其它模块实现算法。
