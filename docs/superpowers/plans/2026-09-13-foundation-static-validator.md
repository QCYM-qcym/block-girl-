# FOUNDATION-2B Static Validator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. NOT EXECUTED; wait for subsequent user authorization.

**Goal:** 对完整声明的有限构型域给出可解释VALID/INVALID/INCOMPLETE，并提供唯一共享几何Safety查询。

**Architecture:** 复用第一波DATA、Math、Spatial、Mapping、Celestial。几何Safety是Validator和Kernel共享的底层接口；此Work不实现动作权限、Shadow Shift、busy或Solver。

**Tech Stack:** Godot 4.7.2纯GDScript、SceneTree测试、PowerShell。

**Spec:** `docs/superpowers/specs/2026-09-13-foundation-puzzle-rule-kernel-contracts.md`，尤其§8、§12、§15–16及§19。

## Global Constraints

- FROZEN DESIGN / NOT IMPLEMENTED。数据schema与既有错误码不改；没有INVALID_SPAWN/INVALID_EXIT等自定义替代码。
- 2B只依赖FOUNDATION-1；不得反向依赖Kernel动作执行。对动作记录只检查静态引用/声明profile，Safety只读几何。
- 枚举声明域是静态验证，不是玩家可达性/BFS。未完成不能输出VALID。
- 本轮无实现/commit/push/merge；其它Work和旧P-01只读。

## Exact files / Ownership

以下新增.gd对应.uid同属2B。另只可更新本plan与专属report。

| 文件 | 职责 |
|---|---|
| foundation/validation/validation_types.gd | ValidationStatus及SafetyStatus，非ValidationCode副本 |
| foundation/validation/safety_queries.gd | 共享玩家体积/支撑/保守扫掠与checked运动路径 |
| foundation/validation/static_validator.gd | 结构/声明域枚举与完整验证编排 |
| tests/foundation/validation/validation_fixture.gd | 最小有效/无效定义与极端坐标变体 |
| tests/foundation/validation/test_safety_queries.gd | 净空、载体、roll/FaceTransition/旋转扫掠 |
| tests/foundation/validation/test_static_validator.gd | 完整域、引用、歧义、预算、顺序确定性 |
| tests/foundation/validation/run_validation.ps1 | 真实依赖与日志验收 |
| docs/development-records/FOUNDATION_STATIC_VALIDATOR_REPORT.md | 证明范围与限制 |

Prohibited files：foundation/{orientation,contracts,spatial,celestial,rules,level,runtime}/；第一波tests及wrapper；game/、prototype/、production/、project.godot、tests/visual；全部Spec、其它plan/report。禁止修改DATA以接受新flag effect或Face路径字段。

## Interfaces / Dependencies

```text
StaticValidator.validate(level: Dictionary, options: Dictionary) -> Dictionary
options={max_configurations: int, max_checks: int}
result={status,issues,configurations_checked,checks_performed}
ValidationStatus: VALID=0,INVALID=1,INCOMPLETE=2

Safety.validate_state(level: Dictionary,state: Dictionary) -> Dictionary
Safety.validate_motion(level: Dictionary,before: Dictionary,after: Dictionary,action: Dictionary) -> Dictionary
Safety.validate_concurrent_motion(level: Dictionary,before: Dictionary,after_local: Dictionary,after_global: Dictionary,local_action: Dictionary,global_action: Dictionary) -> Dictionary
result={status,issues}
SafetyStatus: SAFE=0,UNSAFE=1,UNPROVEN=2,ERROR=3
```

依赖真实`Data.validate_*_shape`、`Geometry.snapshot`、`SpatialValidation.validate_snapshot`、`Mapping.collect_mapping_candidates/resolve_mapping`、`Lighting.query`、`Orientation`。所有上游错误保留code/path/实体等原始字段，静态构型上下文另附报告外部记录或issue.details的新字段，不能覆盖原底层details。

## Task 1：SafetyResult与稳定玩家体积

Files：validation_types、safety_queries、validation_fixture、test_safety_queries。

- [ ] RED：同层Cube内穿透、支撑接触、跨世界重合、非walkable、引用错误、极限anchor+normal范围失败。

```gdscript
var safe := Safety.validate_state(level, state)
check(safe.status == ValidationTypes.SafetyStatus.SAFE, "support contact is legal")
check(Safety.validate_state(blocked_level, state).status == ValidationTypes.SafetyStatus.UNSAFE, "same-world player penetration")
var failed := Safety.validate_state(extreme_level, state)
check(failed.status == ValidationTypes.SafetyStatus.ERROR, "overflow is not unsafe gameplay")
check(has_code(failed.issues, 1105), "canonical arithmetic overflow")
```

- [ ] 最小实现：先DATA→checked snapshot→validate_snapshot，再中心2=anchor+normal的宽整数体积检查；规范边长1，开内部穿透拒绝，接触允许。绝不使用Godot PhysicsServer或float collision。
- [ ] GREEN：输入全量不变、错误包装无半数据、TRUE/FALSE几何正反例及跨层隔离。

## Task 2：唯一保守运动安全查询

Files：safety_queries、test_safety_queries。

- [ ] RED：World整体旋转、组内玩家跟随、组外玩家阻挡、普通roll、显式同Cube换面三段通道；端点合法但扫掠无法证明返回UNPROVEN。

```gdscript
check(Safety.validate_motion(level, before, after, rotate).status == ValidationTypes.SafetyStatus.SAFE, "clear rigid carrier")
var uncertain := Safety.validate_motion(tight_level, before, after, rotate)
check(uncertain.status == ValidationTypes.SafetyStatus.UNPROVEN, "bounding overlap is not collision proof")
check(has_code(uncertain.issues, 1601), "explicit incomplete safety proof")
check(before == saved_before and after == saved_after, "query never patches state")
```

- [ ] 最小实现：正式Math与Spatial解析载体，按Spec §16.1构造整段保守整数包围域；运动路径不按渲染采样。支持§8固定三段换面运输；源/目标实际中心与normal必须匹配声明，禁止回正或路径穿透豁免。
- [ ] GREEN：SAFE/UNSAFE/UNPROVEN/ERROR四态、+/-90与极限pivot、支撑合法接触、其它实体不误豁免；不依赖当前Shadow/机关权限。并发承载正例需通过先包局部roll再包global旋转的组合包围证明；同层组外玩家则比较不旋转的roll域与Group扫掠域，另世界旋转退化为普通roll。三分支均有测试；Spec中(4,4,4)障碍反例不能因为串行路径安全而放行。换面三段运输须有真实SAFE正例，原距离2中心旋转的穿透不得豁免。

## Task 3：静态结构profile与声明域验证

Files：static_validator、test_static_validator、validation_fixture。

- [ ] RED：在初态合法但另一allowed配置重叠、封面、Slot光源非法或1105的fixture上验证不能只查初态；坏组边、机制自引用不符、跨Cube换面、错误spawn/goal引用逐条断言canonical codes。

```gdscript
var result := StaticValidator.validate(level, {"max_configurations": 4096, "max_checks": 100000})
check(result.status == ValidationTypes.ValidationStatus.VALID, "full declared domain completed")
var invalid := StaticValidator.validate(noninitial_bad, {"max_configurations": 4096, "max_checks": 100000})
check(invalid.status == ValidationTypes.ValidationStatus.INVALID, "noninitial bad configuration detected")
check(has_code(invalid.issues, Types.ValidationCode.SAME_WORLD_CUBE_OVERLAP), "existing1200")
```

- [ ] 最小实现：shape→机制/通道profile→按稳定顺序笛卡尔域→每构型的Spatial、walkable安全、Lighting、Mapping及声明边Safety。不存在映射通常正常；多候选含全部ID，不能按光照/blocked裁掉。
- [ ] GREEN：所需12类静态错误完整覆盖；同位置内部封面先1201而不是伪造合法多候选；独立完整candidate测试标明边界；失效列表不被静默裁剪。

## Task 4：预算、确定性与生产联调

Files：test_static_validator、run_validation、report、本plan。

- [ ] RED：构型数量超过预算返回INCOMPLETE1600；保守扫掠不够证明返回INCOMPLETE1601；坏定义+预算不足仍INVALID且保留预算诊断。

```gdscript
var short := StaticValidator.validate(level, {"max_configurations": 1, "max_checks": 1})
check(short.status == ValidationTypes.ValidationStatus.INCOMPLETE, "budget cannot imply valid")
check(short.configurations_checked <= 1 and short.checks_performed <= 1, "bounded work")
check(StaticValidator.validate(reordered_level, budget) == StaticValidator.validate(level, budget), "stable enumeration and issue paths")
```

- [ ] 最小实现：预算在每次新增构型/语义查询前扣计数，无墙钟参与结果；规范顺序来自layer/ID/枚举值，issues canonical路径稳定。
- [ ] GREEN：重复、重排、空/非法预算、极大域不先展开内存爆炸；记录真实依赖HEAD与测试数。
- [ ] 提供真实Safety给2A，完整Validator给2C；不主动修改他们的目录。最终检查无规则权限算法/BFS/默认VALID或测试double生产泄漏。

## Acceptance command / PASS

后续运行：

```powershell
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/foundation/validation/test_safety_queries.gd
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --headless --path . --script res://tests/foundation/validation/test_static_validator.gd
& './tests/foundation/validation/run_validation.ps1' -EvidenceName static_validator_final
& './tests/foundation/run_validation.ps1' -EvidenceName static_validator_foundation_regression
```

wrapper记录exit0/错误扫描/真实依赖、计数、failures=[]；日志写ignored新目录，进程隐藏、超时60秒。所有正反例与旧FOUNDATION回归通过后输出 **FOUNDATION_STATIC_VALIDATOR_PASS**。该token是模块测试通过，不表示任何INCOMPLETE关卡可Bake或已证明可解。当前这些生产文件和命令结果均不存在，不能提前勾选。
