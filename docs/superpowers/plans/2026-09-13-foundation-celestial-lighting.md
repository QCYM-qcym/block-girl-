# FOUNDATION Celestial / Logical Lighting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax. FOUNDATION-0 时仅计划；Work C 已按用户授权执行，最终验收见文末。

**Goal:** 用唯一 Slot 状态与确定整数几何，完成一个稳定快照的 Slot 请求解析和 LIT/SHADOW 查询。

**Architecture:** 两个纯脚本，不创建灯光 Node、动画事务或调度器。输入为 DATA 定义与 SPATIAL 值记录；光照不读取另一个世界的实体，也不影响 gameplay 状态。

**Tech Stack:** Godot 4.7.2 GDScript、int64/有理数比较、Dictionary、headless 测试。

**Spec:** `docs/superpowers/specs/2026-09-13-foundation-spatial-puzzle-architecture-design.md` §15/16/33；`docs/superpowers/specs/2026-09-13-foundation-core-contracts.md` §2/5/7–10。

## Global Constraints

- 根路径 `E:/godot/若叶睦/方块少女-若叶睦`；foundation.contract.v1 / cube24.v1；Slot.position2 是 Shared Space 半格整数。
- 只写 `foundation/celestial/celestial_rules.gd`、`logical_lighting.gd`、相应 UID、`tests/foundation/celestial/test_celestial.gd`、UID、本计划进度和 `docs/development-records/FOUNDATION_CELESTIAL_LIGHTING_REPORT.md`。
- contracts/orientation/spatial、公共 Spec、game/、prototype/、production/、project.godot、其它测试只读；不能给缺依赖写公共假实现。
- 不做 Celestial Node/Timer、事务调度、Mapping Solver、BFS、Editor、Baker、Blender 或 P-02；不自动 commit/push/merge/rebase。

## 接口与依赖

消费 DATA 的 WorldLayer/CelestialOp/LightState/ValidationCode；消费 CelestialDefinition、FaceAnchor、CelestialSlot、ResolvedCube 值记录。输出完整 `resolve_slot_request(definition,current_slot_id,operation,target_slot_id,alternate_slot_id) -> Dictionary` / SlotRequestResult 和 `query(anchor,slot,cubes: Array[Dictionary]) -> Dictionary` / LightQueryResult；参数类型及字段严格见合同 §9。

不调用 SPATIAL 算法、不读取状态单例。SPATIAL 未到位时可用本测试中明确整数快照做单元测试；最终必须用真实 snapshot 完成旋转后的光照集成检查。MOVING 锁与丢弃第二次全局触发是后续 Scheduler/Kernel 任务，本模块不假装靠 Slot 查询实现它。

### Task 1：唯一 Slot 的纯请求解析

**Files:** celestial_rules 与本测试。

- [x] SceneTree 入口缺实现时明确 quit(1)，失败累积并非零退出。先建立 A/B/C fixture，slot_order=[a,b,c]，wrap=false，edges=[a→b,b→a,b→c,c→b]。
- [x] RED tests：SET a→b 得 changed=true；SET b→b 得 changed=false；NEXT c 越界拒绝 SLOT_STEP_UNAVAILABLE；TOGGLE(a,b) 在 c 拒绝；非法引用拒绝 INVALID_CELESTIAL_REFERENCE。
- [x] 实现四种操作，NEXT/PREVIOUS 检查 wrap 与有向 edges，TOGGLE 明确两端；不修改传入 definition/current，不持有 sun_slot/moon_slot 两份状态。错误输出 ok=false、next_slot_id 为空和确定 issues。
- [x] GREEN：增加 wrap=true 的首尾边、顺序配置变化、空 Slot 列表、重复 ID、目标当前相同无自环；两个 World 的相同请求返回相同 Slot 结果。

### Task 2：精确入射与同世界遮挡

**Files:** logical_lighting 与本测试。

- [x] 写独立固定几何 RED 用例：

```gdscript
var lighting=load("res://foundation/celestial/logical_lighting.gd")
var anchor={"face_id":&"floor/TOP","layer":0,"position2":Vector3i(0,1,0),"frame":{"u":Vector3i.RIGHT,"v":Vector3i(0,0,-1),"normal":Vector3i.UP}}
var slot={"slot_id":&"a","position2":Vector3i(0,7,0)}
var cubes: Array[Dictionary]=[]
check(lighting.query(anchor,slot,cubes).light_state==0,"front clear LIT")
cubes.append({"cube_id":&"blocker","layer":0,"center2":Vector3i(0,4,0),"orientation":0,"occludes_light":true})
check(lighting.query(anchor,slot,cubes).occluder_id==&"blocker","same-world obstruction")
cubes[0].layer=1
check(lighting.query(anchor,slot,cubes).light_state==0,"other world does not occlude")
```

- [x] 实现整数 normal 点积、射线与闭 AABB 的有理区间求交：射线 t∈(0,1)，每轴保留分子/正分母，交叉乘法比较，平行轴单独判断；乘法预检 int64 溢出并报告 ARITHMETIC_OVERFLOW。禁止使用 PhysicsServer、视觉 RayCast、浮点 epsilon 或 GPU shadow。
- [x] 增加 golden 边界：source=(4,1,0) 相对 TOP 为切向→SHADOW；背面→SHADOW；anchor 与 source 相等→LIGHT_SOURCE_INVALID；other Cube 擦边→OCCLUDED；接收 Cube 只在 t=1 接触→不遮挡；源在同世界 occluder 内或边界→错误；最近命中优先，精确同 t 按 cube_id。
- [x] GREEN 后与真实 SPATIAL.snapshot 接线：旋转 Cube/World 改变 Frame/位置后重新 query，固定 Slot 不跟 World 转；输入原数组不变；打乱遮挡 Cube 顺序结果相同。
- [x] 报告查询/集成范围，不报完整 Lighting 全构型验证、事务并发 PASS 或可玩 FOUNDATION。

## 验收命令

```powershell
$foundationEvidence='E:/godot/若叶睦/foundation-0-evidence/celestial'
New-Item -ItemType Directory -Path $foundationEvidence -Force | Out-Null
$foundationResult=Start-Process -FilePath 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' -ArgumentList '--headless --path "E:/godot/若叶睦/方块少女-若叶睦" --script res://tests/foundation/celestial/test_celestial.gd' -WindowStyle Hidden -PassThru -Wait -RedirectStandardOutput "$foundationEvidence/final.stdout.log" -RedirectStandardError "$foundationEvidence/final.stderr.log"
if ($foundationResult.ExitCode -ne 0 -or (Get-Content "$foundationEvidence/final.stderr.log" -Raw) -match 'ERROR:|FAIL:') { throw 'Celestial failed' }
git diff --check
```

保留独立 RED 日志。真实 snapshot 集成通过后输出 FOUNDATION_CELESTIAL_LIGHTING_PASS 与报告，停止。

## Work C execution — 2026-09-13

- Active worktree: `E:/godot/worktrees/block-girl-foundation-celestial`, branch `feat/foundation-celestial-lighting`, base `4643062`.
- Both planned tasks complete; final acceptance: 113 checks, zero failures, exit 0, empty stderr, FOUNDATION_CELESTIAL_LIGHTING_PASS.
- Source-to-anchor ray parameterization follows architecture §16. The source is t=0, receiver is t=1.
- The historical acceptance command's main-project path is replaced by an external integration harness at `E:/godot/若叶睦/foundation-0-evidence/celestial/integration-project`. This contains unchanged copies of the genuine sibling DATA/MATH/SPATIAL implementations and Work C scripts/tests. No dependency stubs, foreign worktree edits, or integration merge.
- Independent slot and lighting RED logs were preserved. First real snapshot integration: 108 checks, exit 0, empty stderr. Final authoritative results and dependency hashes are in `docs/development-records/FOUNDATION_CELESTIAL_LIGHTING_REPORT.md`.
- Public contracts remain read-only. Interface insufficiency must report `CONTRACT_MISMATCH`; none identified.
- User has explicitly required collecting all four module PASS results before any merge; this Work performs no commit/push/merge/rebase.

- Final scoped review closed the malformed-field-key finding. Final evidence: `final.stdout.log` / `final.stderr.log` and `verified-sources.json` under the celestial evidence directory. No remaining Work C implementation or verification tasks.

## FOUNDATION-1C revalidation — 2026-09-13

- Re-read the formal Spec and frozen contract. Production interfaces remain exactly §9: SlotRequestResult and LightQueryResult. CelestialState and CelestialSlot remain the existing DATA-owned Dictionary schemas.
- Added 19 explicit combined checks for one committed Slot across Surface/Inner, A→B→A lighting refresh, moving an occluder off the ray, repeatable old/new snapshots, and binary FaceAnchor sampling. Existing production scripts unchanged.
- Full real-dependency acceptance: **132 checks, zero failures, exit 0, empty stderr, FOUNDATION_CELESTIAL_LIGHTING_PASS**.
- Current evidence is outside the main workspace: `E:/godot/foundation-evidence/celestial-1c/`; verified dependency hashes and full unstaged/untracked Git patch retained there. Prior evidence remains historical and read-only.
- Stable→MOVING→Stable and immediate busy rejection/no queue are documented in the Work C report. Runtime enforcement remains the explicitly deferred Scheduler/Kernel responsibility; no new public interface, test scheduler, or concurrency PASS claim.
- Independent review of new tests and scope interpretation: clean. CONTRACT_MISMATCH: none. No main workspace edits, foreign module edits, commit/push/merge.
