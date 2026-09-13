# FOUNDATION-2C LevelDefinition / Baker Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking. EXECUTED with the user's FOUNDATION-2C authorization on 2026-09-13. All four tasks and final real-Validator acceptance passed; no commit/push/merge.

**Goal:** 最小Godot authoring scene经严格量化、规范编码/hash和真实Static Validator，产生可消费LevelDefinition。

**Architecture:** Scene读取与纯数据Bake分开；失败不输出部分level。只读第一波规范和2B冻结接口；Validator未接入时仅报告codec/adapter单元结果。

**Tech Stack:** Godot 4.7.2 Node3D/RefCounted、规范UTF-8 JSON、SHA-256、SceneTree验收。

**Spec:** `docs/superpowers/specs/2026-09-13-foundation-puzzle-rule-kernel-contracts.md` §16–19；数据与导入容差以core §3.1/6为准。

## Global Constraints

- FROZEN DESIGN / IMPLEMENTED AND VERIFIED。不是Editor Plugin/正式关卡/P-02；不加Face Edit Mode/Overlay/Heatmap。
- LevelDefinition仍19字段、schema1；Baker是content_hash的唯一生产编码Owner，不创建第二StateKey。
- 通用Scene元数据仅在authoring边界；输出不得保留Node/Basis/float/隐藏规则字段。
- 2C只消费2B验证合同，不实现静态Validator替代品或默认返回VALID。
- 本轮已获用户授权执行实现；不commit/push/merge。输出与临时证据仅写E盘项目ignored目录，不写C盘资源。

## Exact files / Ownership

下列.gd对应.uid同属2C；只可更新本plan和专属report。

| 文件 | 职责 |
|---|---|
| foundation/level/level_codec.gd | canonical JSON encode/decode/hash，封闭19字段 |
| foundation/level/level_baker.gd | bake(authoring,options)纯数据编排 |
| foundation/level/authoring_reader.gd | read_scene(root)量化边界 |
| tools/foundation/level/bake_level.gd | 命令行读取指定scene、成功后写指定输出 |
| tools/foundation/level/minimal_authoring.tscn | 最多双世界各3Cube的最小作者输入 |
| tests/foundation/level/baker_fixture.gd | 有效/无效数据，明确作者元数据到definition映射 |
| tests/foundation/level/validator_double.gd | 仅测试INVALID/INCOMPLETE失败传播 |
| tests/foundation/level/test_level_codec.gd | 编码/hash/解码/版本/未知字段 |
| tests/foundation/level/test_level_baker.gd | 量化、文件副作用与真实Validator集成 |
| tests/foundation/level/run_validation.ps1 | 两套件和真实Bake验收 |
| docs/development-records/FOUNDATION_LEVEL_BAKER_PROTOTYPE_REPORT.md | hash、证据、实际Validator结果 |

Prohibited files：其它foundation目录含contracts；第一波tests/wrapper；tests/foundation/{rules,validation,runtime}/；game/、prototype/、production/、project.godot、tests/visual；所有Spec和其它plan/report。

## Interfaces / Dependencies

```text
Codec.encode(level: Dictionary) -> {ok,text,issues}
Codec.decode(text: String) -> {ok,level,issues}
Codec.compute_content_hash(level: Dictionary) -> {ok,content_hash,issues}
Baker.bake(authoring: Dictionary,options: Dictionary) -> {ok,level,issues,validation}
AuthoringReader.read_scene(root: Node3D) -> {ok,authoring,issues}
StaticValidator.validate(level: Dictionary,options: Dictionary) -> StaticValidationResult
```

正式依赖为DATA shape、Geometry.make_face_nodes/face_id、Math.from_columns、2B真实StaticValidator；statekey测试消费正式StateKey.build，不复制它。Baker options沿2B `{max_configurations,max_checks}`，没有skip_validation开关。

最小作者容器约定：root为Node3D且metadata `foundation_authoring`保存18字段模板（无content_hash），其中cubes/faces为空、celestial.slots为空。root直接子容器`Cubes`/`Slots`均identity Transform。Cubes子Node3D的metadata `foundation_cube`保存cube_id/layer/group_id/occludes_light/tags，metadata `foundation_faces`为六面属性数组，只含face、walkable、shift_exit_blocked、shift_entry_blocked、mechanism_ids；Slots子Node3D的metadata `slot_id`是StringName。模板其余字段是原canonical定义，不接受任意脚本Callable。

这些Node的根相对位置表示World/Group未旋转的作者绑定坐标；reader不把initial_orientation再烘一次进去。Cube局部Basis量化为静态Cube.orientation；Slot位置在Shared Space。root逆变换只归一化场景放置，逻辑尺度仍L=1；非法根/子缩放剪切镜像均明确拒绝。生成六FaceNode后覆写明确作者属性，face_id只用正式工厂生成。容器外隐藏规则Node不得影响Bake，同ID冲突报错。该私有authoring profile只归2C，不扩展公共LevelDefinition。

## Task 1：规范Level编码与内容身份

Files：level_codec、baker_fixture、test_level_codec。

- [x] RED：同定义重排记录、改build_info、改真正逻辑字段；UTF-8转义、枚举符号、坐标数组、无BOM/LF、未知字段和错误hash。

```gdscript
var first := Codec.compute_content_hash(level)
check(first.ok and first.content_hash.length() == 64, "canonical SHA-256")
check(Codec.compute_content_hash(reordered).content_hash == first.content_hash, "record ordering irrelevant")
check(Codec.compute_content_hash(new_build_info).content_hash == first.content_hash, "metadata excluded")
check(Codec.compute_content_hash(changed_flag).content_hash != first.content_hash, "rule data changes identity")
var encoded := Codec.encode(level)
check(encoded.ok and not encoded.text.ends_with("\n"), "no final LF")
check(Codec.decode(encoded.text).level == canonical_level, "typed canonical roundtrip")
```

- [x] 最小实现：按Spec规定字段/记录排序及有序数组规则序列化；先验证类型/Unicode/枚举，数字字段禁止默默截断float。hash排除content_hash/build_info。编码不调用StateKey私有方法。
- [x] GREEN：固定已人工确认的canonical JSON/hash golden，字符串转义反例，重复ID不去重；decode恢复StringName/Vector3i/int，验证内容hash真实性，不默许旧Bake的伪造hash。保留StateKey v1 golden不改。

## Task 2：Authoring读取与拒绝量化

Files：authoring_reader、minimal_authoring.tscn、test_level_baker。

- [x] RED：根平移/旋转归一化后一致；偏离半格超过1e-6、奇数Cube中心、非单位basis、镜像、缩放、溢出、漏Face配置、重复ID。

```gdscript
var read := AuthoringReader.read_scene(root)
check(read.ok and read.authoring.cubes[0].center2 == Vector3i(0,0,0), "bind-space integer center")
check(read.authoring.faces.size() == read.authoring.cubes.size() * 6, "six canonical faces")
check(not read.authoring.has("content_hash"), "hash not author input")
check(not off_lattice.ok and has_code(off_lattice.issues, 1100), "no silent snapping")
check(not overflow.ok and has_code(overflow.issues, 1105), "range checked before Vector3i")
```

- [x] 最小实现：读取明确元数据与根相对Transform；按容差比较最近整数/合法Math基；生成规范预输入，失败authoring=null。无隐藏Node扫描规则，无Editor插件。
- [x] GREEN：真实.tscn加载后读取，不仅手写Dictionary测试；重排scene兄弟节点、改显示名不影响ID与hash；报错路径可定位Node/字段。

## Task 3：Bake→真实Validator Gate

Files：level_baker、validator_double、test_level_baker。

- [x] RED：Validator INVALID/INCOMPLETE、预算不足、坏spawn/goal、非法槽源、宽机制profile；任何失败level=null，不能返回仅shape通过的“可用level”。

```gdscript
var baked := Baker.bake(authoring, {"max_configurations": 4096, "max_checks": 100000})
check(baked.ok and baked.validation.status == ValidationTypes.ValidationStatus.VALID, "real validator gate")
check(Data.validate_level_shape(baked.level).is_empty(), "canonical DATA accepts output")
check(Codec.compute_content_hash(baked.level).content_hash == baked.level.content_hash, "true content identity")
check(not incomplete.ok and incomplete.level == null, "INCOMPLETE is not bake success")
```

- [x] 最小实现：纯authoring→shape检查→规范hash→真实StaticValidator；失败issues保留，成功完整level。占位hash只允许局部shape校验，绝不作为产物输出。
- [x] GREEN：先double单测，再真实2B加载，报告清楚区分；实际最小scene可Bake VALID，坏scene拒绝输出。调用Baker不写磁盘、不修改输入。

## Task 4：命令行产物与证据

Files：bake_level.gd、run_validation、report、本plan。

- [x] RED：目标文件已存在/路径非法、解析/Bake失败时不创建最终文件；不同逻辑level不能同hash。
- [x] 最小实现：命令行只在完整成功后写UTF-8无BOM文本；默认路径要求调用者显式指定，并检查不覆盖现有文件。scene/free由工具层处理，不放入纯Baker。
- [x] GREEN：真实产物decode→Validator VALID→StateKey(initial_state)成功；main场景与旧资源无diff；日志ignored。记录产物hash及完整命令。

## Acceptance command / PASS

计划验收入口（真实2B未合并时，用下方wrapper生成隔离依赖项目）：

```powershell
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/foundation/level/test_level_codec.gd
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/foundation/level/test_level_baker.gd
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script res://tools/foundation/level/bake_level.gd -- --scene=res://tools/foundation/level/minimal_authoring.tscn --output=res://.godot/foundation-2c/minimal.level.json
& './tests/foundation/level/run_validation.ps1' -EvidenceName level_baker_final
& './tests/foundation/run_validation.ps1' -EvidenceName level_baker_foundation_regression
```

CLI负责创建输出父目录，已有输出必须换新路径而非覆盖。wrapper采用隐藏进程/60秒超时/exit0+明确PASS+错误扫描，记录真实2B版本；不得提交.godot、evidence或日志。真实scene→Bake→Validator→decode全链及回归通过后输出 **FOUNDATION_LEVEL_BAKER_PROTOTYPE_PASS**。只有double时不允许该token。上述文件已创建并验收。最终wrapper证据：.godot/foundation-2c/level_baker_final/；真实Validator为VALID（4 configurations / 156 checks），Codec 75 checks、Baker 65 checks、产物复验70 checks。第一波六套回归证据：.godot/foundation-1-validation/level_baker_foundation_regression_final/。完整交付见本Work专属report。
