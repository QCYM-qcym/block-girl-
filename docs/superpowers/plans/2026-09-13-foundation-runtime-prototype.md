# FOUNDATION-2D Runtime Foundation Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. NOT EXECUTED; wait for subsequent user authorization.

**Goal:** 在独立极小技术场景验证Input→PuzzleAction→真实Kernel→完整PuzzleState→Visual Sync，并保持旧P-01不变。

**Architecture:** InputMapper负责观察坐标量化，KernelPort只转发，RuntimeSession负责单事务生命周期/Reset，Presenter只显示。以稳定StateKey与纯Kernel动作回放比较；不得从视觉位置猜规则位置。

**Tech Stack:** Godot 4.7.2、Node3D/Camera3D/简单几何体、GDScript、SceneTree图形回归。

**Spec:** `docs/superpowers/specs/2026-09-13-foundation-puzzle-rule-kernel-contracts.md` §3–15、§18–20。

## Execution record — 2026-09-13

User authorized FOUNDATION-2D implementation in this worktree and explicitly allowed a strict Kernel Adapter/Test Double when the real Kernel is not integrated. This supersedes the historical “not executed” notes and real-Kernel-only prototype gate below. Public ABI remains unchanged.

- [x] Task 1: InputMapper TDD, 330 checks PASS.
- [x] Task 2: RuntimeSession/KernelPort TDD, 62 checks PASS, including synchronous signal reentrancy.
- [x] Task 4: independent real graphical scene, ghost interpolation, MOVE/Rotate/Shadow Shift/Reset, 116 checks PASS with explicit test injection.
- [x] Runtime new-stage wrapper: 60-second stage limits, logs, PASS/error/exit gates; optional legacy regression import preflight.
- [x] First-wave FOUNDATION regression: 81,014 checks PASS.
- [x] P-01 state/runtime: 31 + 167 checks PASS after generating missing import caches; initial failed evidence retained.
- [x] Full legacy regression chain PASS: Perspective, earlier prototype, Sprite, Tileset, Mechanism; no tracked legacy changes.
- [ ] Task 3 / real 2A+2B integration: NOT RUN; dependencies absent. Canned busy/composite results test scheduling only. No real safety/permission proof claimed.

Ruling: accept the explicitly authorized contract-double Runtime prototype; do not claim real Kernel/Safety integration. Production adapter has no double fallback. User instructions override the earlier plan gate, not the frozen result/state schemas.

Ruling: ghost endpoint interpolation is visual-only and uses formal Spatial/Orientation owners; it does not approximate a physical safety proof.

Report: `docs/development-records/FOUNDATION_RUNTIME_PROTOTYPE_REPORT.md`. No commit/push/merge or public contract/P-01 changes. The original checklists below retain their historical real-integration meaning.

## Global Constraints

- FROZEN DESIGN / NOT IMPLEMENTED。最多Surface 2–3 Cube、Inner 2–3 Cube、一个Shadow Shift、一个Rotate，不制作P-02或正式美术。
- 不改project.godot/F5主场景、P-01、正式Sprite/Tileset/Mechanism资产、tests/visual。
- Runtime没有第二套移动/Shift/光照/权限/姿态公式；Camera/RotateTarget/键值/时间不进入PuzzleState。
- 2A未就绪可用tests目录中的Kernel double验证会话，但production adapter不能fallback到double；最终PASS必须真实Kernel。
- 本轮不实现、不commit/push/merge，不自动启动本plan。

## Exact files / Ownership

以下新增.gd的.uid同属2D；只可更新本plan与专属report。

| 文件 | 职责 |
|---|---|
| foundation/runtime/input_mapper.gd | 屏幕方向/RotationIntent→语义action |
| foundation/runtime/kernel_port.gd | 正式Kernel/RuleRecords/Goal的薄转发 |
| foundation/runtime/runtime_session.gd | 完整状态提交、单ticket、generation/transaction_id |
| foundation/runtime/prototype_presenter.gd | 简单几何状态同步、拒绝反馈、插值 |
| prototype/foundation/runtime/foundation_runtime.tscn | 独立技术场景，非F5入口 |
| prototype/foundation/runtime/foundation_runtime.gd | 场景装配与输入调用，逻辑交给session |
| prototype/foundation/runtime/runtime_fixture.gd | 最小19字段定义；明确是技术fixture，不是正式关卡/Bake替代 |
| tests/foundation/runtime/kernel_double.gd | 仅测试会话成功/拒绝/异常/旧回调 |
| tests/foundation/runtime/test_input_mapper.gd | 相机方向/平局/退化/开放意图 |
| tests/foundation/runtime/test_runtime_session.gd | 会话生命周期、原子提交、Reset与回放 |
| tests/foundation/runtime/test_runtime_graphics.gd | 实际图形输入路线、姿态/世界变化与截图 |
| tests/foundation/runtime/run_validation.ps1 | headless与图形分阶段、证据与旧回归 |
| docs/development-records/FOUNDATION_RUNTIME_PROTOTYPE_REPORT.md | 控制方式、真实链接、Runtime与回放结果 |

Prohibited files：其它foundation目录与第一波tests/wrapper；tests/foundation/{rules,validation,level}/；game/、原prototype/perspective等、production/、tests/visual/、project.godot；所有Spec及其它三plan/report。新增prototype路径不授权重构旧prototype。

## Interfaces / Dependencies

```text
InputMapper.map_move(frame: Dictionary,camera_basis: Basis,screen_direction: Vector2) -> {ok,action,issues}
InputMapper.map_rotation(intent: int,camera_basis: Basis,world: Dictionary) -> {ok,action,issues}
KernelPort.evaluate_action(level,state,action,context) -> PuzzleTransitionResult
KernelPort.complete_global(level,state,context) -> PuzzleTransitionResult
KernelPort.begin_global(level,result) -> ContextResult
KernelPort.idle_context() -> ExecutionContext
KernelPort.is_goal(level,state) -> GoalResult
Session.load_level(level: Dictionary) -> {ok,issues}
Session.request_action(action: Dictionary) -> PuzzleTransitionResult
Session.finish_global(transaction_id: int,generation: int) -> {ignored,transition}
Session.reset() -> void
```

Port调用正式2A同名接口（begin/idle在RuleRecords、is_goal在Goal），不复制结果判定。Session.load_level先DATA/真实Safety验证；Runtime fixture可独立真实验证，不要求依赖2C authoring场景。需要已发布Bake时消费2C Codec；本首版可直接使用不可变技术fixture，不自行实现hash算法。

技术fixture content_hash必须是真实规则内容身份；若2C尚未就绪，可用离线人工固定canonical内容与SHA-256生成测试常量，并记录其原始字节证据，不能用重复0/1假hash伪称Baker产物。最终报告区分fixture与真实Bake。

## Task 1：Input Mapper离散语义

Files：input_mapper、test_input_mapper。

- [ ] RED：四屏幕方向在六种Face法线上映射、opposite成对、斜对角平局、近退化、非离散观察基、未开放RotationIntent和delta。

```gdscript
var positive := InputMapper.map_move(frame, camera_basis, Vector2(1, -1))
var negative := InputMapper.map_move(frame, camera_basis, Vector2(-1, 1))
check(positive.ok and negative.ok, "nondegenerate pair")
check(negative.action.face_axis == (positive.action.face_axis + 2) % 4, "opposite input pair")
check(positive.action.keys().size() == 2 and not positive.action.has("camera"), "semantic MOVE only")
check(not degenerate.ok and degenerate.action == null, "no guessed axis")
```

- [ ] 最小实现：先按Spec规范半平面代表量化，再把反向轴还原；代表平局使用+u,+v,-u,-v。Camera只用于投影，不按是否可通行改选方向。旋转从量化观察基调用正式Math.quarter_turn，不写第二旋转表。
- [ ] GREEN：全方向黄金样例与逆输入，特别是投影+u/-v等距；开放intent与delta同时检查，不向Kernel传RotationAxis。

## Task 2：Session薄适配与Reset

Files：kernel_port、runtime_session、kernel_double、test_runtime_session。

- [ ] RED：REJECTED/ERROR不改变state；global请求在到达前保持旧稳定态；Reset旧token不能提交；local roll落定才提交；重复输入不进队列。

```gdscript
var accepted := session.request_action(global_action)
check(session.state == before, "animated global not committed at acceptance")
var old_id := session.transaction_id
var old_generation := session.generation
session.reset()
var late := session.finish_global(old_id, old_generation)
check(late.ignored and late.transition == null, "late callback ignored")
check(session.state == spawn_state, "reset cannot be overwritten")
```

- [ ] 最小实现：state替换只取完整Kernel结果；global保存begin_global返回context，ID/generation仅在session；完成转调complete_global。Port只转发，不在UI里写亮暗条件或直接改Slot。
- [ ] GREEN：double阶段明确标记仅会话单测，production没有测试目录preload；错误明确反馈，无queue/deferred/pending marker。

## Task 3：实际Kernel、Busy与复合踏板

Files：runtime_fixture、runtime_session、test_runtime_session。

- [ ] RED：真实USE console触发天体后允许安全MOVE，complete保持最新位置；真实承载旋转与roll须有2B并发扫掠证明；未证明拒绝；MOVE+ENTER压力板与Slot一次提交。

```gdscript
var final := session.finish_global(session.transaction_id, session.generation)
check(not final.ignored and final.transition.status == RuleTypes.TransitionStatus.APPLIED, "real completion")
check(StateKey.build(level, session.state).key == pure_replay_key, "runtime/atomic replay parity")
# ENTER fixture: moving onto plate is a single composite transition.
check(plate_result.next_state.player.location.cube_id == &"plate_cube", "plate entry included")
check(plate_result.next_state.celestial.slot_id == &"b", "same atomic result contains effect")
check(session.context.global_transition_state == Types.GlobalTransitionState.IDLE, "composite uses no delayed global ticket")
```

- [ ] 最小实现：纯global/USE效果可延迟ticket；MOVE+ENTER在本地roll落定一次提交全部state，之后只做表现反馈，不能把player先提交、Slot后提交。所有busy准入向Kernel查询，local_moves只追加已提交动作。
- [ ] GREEN：与规范串行Kernel回放比较完整key，含pose；进入ENTER/goal的busy拒绝不会变成稳定后补触发；Reset所有阶段/旧callback/失败completion均不写旧player。仅串行路径安全却并发扫掠未证明的反例也要拒绝。

## Task 4：独立可运行场景与实际图形验收

Files：foundation_runtime.tscn、foundation_runtime.gd、prototype_presenter、test_runtime_graphics、run_validation。

- [ ] RED：用实际图形场景注入按键与鼠标语义输入，断言动作记录通过Kernel；Shadow Shift/世界Rotate/非法Shift反馈/Reset均有截图及状态key。不是headless冒充图形Runtime。
- [ ] 最小实现：简单Cube/Mesh、Surface/Inner颜色区分、玩家pose可辨，显示当前世界/拒绝文本/控制说明。WASD/方向键移动、Space发SHIFT、Q/E发开放旋转意图、Tab只选RotateTarget、R Reset；不能直接更改PuzzleState。
- [ ] GREEN：2–3Cube/世界范围、一个Shift和Rotate闭环；玩家跟随真实World旋转；实际Node姿态与逻辑24态一致；相机变动不改规则状态；全程不改F5入口或旧资源测试场景。

## Task 5：旧系统共存回归与报告

Files：run_validation、report、本plan。

- [ ] 真实2A/2B版本到位后跑全部Runtime tests，不能用Kernel double的结果声明通过。
- [ ] 使用既有P-01 wrapper完整回归及Orientation Sprite核心资源检查，记录首次失败与重跑，不修改旧测试期望求绿。
- [ ] wrapper按headless/实际Windows图形分段、隐藏启动进程、不改变用户原Godot项目；退出码/明确PASS/错误扫描/最多60秒单阶段超时；日志和截图ignored新目录。
- [ ] 输出控制方式、技术fixture路线、自动与手动分别结果、StateKey parity、已知问题和文件diff；不声称真人体验或正式关卡验收。

## Acceptance command / PASS

后续实现后执行：

```powershell
& './tests/foundation/runtime/run_validation.ps1' -EvidenceName runtime_foundation_final
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . res://prototype/foundation/runtime/foundation_runtime.tscn
& './tests/foundation/run_validation.ps1' -EvidenceName runtime_foundation_regression
& './tests/gameplay/run_p01_validation.ps1' -EvidenceName runtime_foundation_p01 -IncludeRegressions
```

wrapper必须包含test_input_mapper/test_runtime_session的headless入口及test_runtime_graphics的真实图形入口；开发者手动打开scene无自动退出期限。所有真实链接、Runtime parity、Reset/拒绝/旧回归通过后输出 **FOUNDATION_RUNTIME_PROTOTYPE_PASS**。没有原生系统键鼠工具时明确标注自动Godot输入事件验收与未执行的系统手动项，不能冒充操作。本轮不执行这些命令。
