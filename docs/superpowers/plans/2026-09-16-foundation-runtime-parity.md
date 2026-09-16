# FOUNDATION-3D SolutionTrace + Runtime Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. NOT EXECUTED；等待用户后续授权。

**Goal:** 把3A语义SolutionTrace送入真实RuntimeSession，对每次正式提交逐步比较完整statekey.v1，定位第一处分歧。

**Architecture:** Replayer是独立异步Node driver，直接调用现有Session.request_action。逻辑模式使用public finish接口；图形模式复用现有Presenter自然Tween完成回调，二者均走真实KernelPort/Safety，不能直写会话状态。

**Tech Stack:** Godot Node/Node3D、真实RuntimeSession与PrototypePresenter、SceneTree回放测试、PowerShell。

**Spec:** `docs/superpowers/specs/2026-09-16-foundation-solver-quality-contracts.md` §2–3、12、22、25–32。

## Global Constraints

- FROZEN DESIGN / NOT IMPLEMENTED；本轮不运行此计划、不commit/push/merge/worktree。
- 基线feat/foundation-core / 4dda1fdce9c562427ab7541f1ee21266a3b8214a。所有原Runtime/Kernel/Safety/StateKey只读。
- 首版只支持Records.initial_state(level)初态；禁止给session.state赋值或新增Runtime恢复入口。
- replay不模拟键鼠，截图只是辅助；单次commit增量1、IDLE和完整key比较才是MATCH依据。
- MOVE+ENTER使用local token，即便global_kind非NONE；完成接口选择依据transition_started的is_global。
- 新独立会话/回放场景不修改F5，不操作用户正在运行的P-01。

## Exact files / Owner 3D

| 文件 | 职责 |
|---|---|
| foundation/parity/parity_types.gd | ParityStatus/ReplayMode与私有结果记录 |
| foundation/parity/trace_replayer.gd | async driver、会话生命周期与两模式回放 |
| tests/foundation/parity/parity_fixtures.gd | 真实Baker关卡与具名回放期望 |
| tests/foundation/parity/trace_contract_double.gd | 3A未交付时固定trace记录；无Solver/StateKey算法 |
| tests/foundation/parity/test_trace_replayer.gd | headless真实Session逐步回放与错误/预算 |
| tests/foundation/parity/parity_replay_scene.tscn | 独立Node3D图形验收装配，不作F5主场景 |
| tests/foundation/parity/parity_replay_scene.gd | 相机/灯光、Replayer装配与观察证据 |
| tests/foundation/parity/test_parity_graphics.gd | SceneTree真实图形自然回调、Reset负例 |
| tests/foundation/parity/run_validation.ps1 | headless与真实图形分阶段证据 |
| docs/development-records/FOUNDATION_RUNTIME_PARITY_REPORT.md | 每步key/commit、分歧、图形证据 |
| docs/superpowers/plans/2026-09-16-foundation-runtime-parity.md | 本plan执行勾选 |

对应新增.gd.uid归3D。**Prohibited files:** foundation/solver/、foundation/quality/、全部既有foundation/runtime等production、原tests/prototype、其它Owner计划/报告、公共Spec、P-01、project.godot、tests/visual/及资产。生产Replayer不能preload测试场景或trace double；图形模式自身挂正式Presenter，测试场景只装配相机/环境。

## Interfaces consumed / produced

消费3A `Trace.validate(level,trace)->{ok,issues}`、真实 `Key.build(level,state)`、`Records.initial_state(level)`、`Goal.is_goal(level,state)`。消费Session实例load_level/request_action/finish_local/finish_global/reset；监听 `transition_started(result,id,generation,is_global)`、`committed(state)`、`feedback(result)`；只读state/context/commit_count/generation/transaction_id。

图形消费 `Presenter.sync_state(level,state)->{ok,issues}`、`animate_transition(level,result,duration)->{ok,issues,tween,preview}`、`clear_previews()`，实际文件`foundation/runtime/prototype_presenter.gd`。不假设不存在的Runtime.restore_state或Presenter.completed。

产出Node实例async `replay(level: Dictionary,trace: Dictionary,options: Dictionary)->Dictionary`，调用者await。ReplayOptions精确mode/max_steps/max_runtime_ms/step_timeout_ms，默认0/10000/0/5000。RuntimeParityResult字段与枚举严格按Spec §25，trace schema仍归3A。

## Task 1: 输入准入与零步/初态

**Files:** parity_types.gd、trace_replayer.gd、parity_fixtures.gd、trace_contract_double.gd、test_trace_replayer.gd。

**Interfaces:** 消费Trace.validate与真实Session.load_level；产出ERROR/MATCH/INCOMPLETE的基础记录。

- [ ] RED：错hash/rule_version/step索引/key/额外字段、负预算返回ERROR；合法非spawn trace返回3013 REPLAY_INITIAL_UNSUPPORTED，不能直接修改Session使其通过。初态Goal零步trace应MATCH/0。

```gdscript
var driver := Replayer.new()
root.add_child(driver)
var r := await driver.replay(level, zero_step_trace, {"mode": 0, "max_steps": 0, "max_runtime_ms": 0, "step_timeout_ms": 5000})
assert(r.status == 0)
assert(r.trace_length == 0 and r.matched_steps == 0)
assert(r.divergence_step == null)
```

- [ ] GREEN：封闭options/trace校验、真实Level验证、比较正式spawn key，再创建默认真实Session并load_level；初态committed信号不计入matched_steps，记录步骤前commit_count基线。零步仍需真实Goal确认。
- [ ] GREEN验证：无custom-state入口；即使trace.shortest=true也不信任最短性标签，本模块仅验证可回放路径。

## Task 2: 真实逻辑回放与首次分歧

**Files:** trace_replayer.gd、test_trace_replayer.gd、parity_fixtures.gd。

**Interfaces:** 消费Session真实token与public finish、StateKey；产出RuntimeParityResult与精确首错定位。

- [ ] RED：真实fixture分别含MOVE local、ROTATE global、SHIFT global、MOVE+ENTER复合local；每步一次commit。制造“expected为另一个合法状态且key同步修改”的结构合法trace，应在第一个不同step DIVERGED，matched_steps仅此前成功数。

```gdscript
var r := await driver.replay(level, real_solver_trace, options)
assert(r.status == 0)
assert(r.matched_steps == real_solver_trace.total_actions)
var bad := await driver.replay(level, valid_but_wrong_expected_trace, options)
assert(bad.status == 1)
assert(bad.divergence_step == first_wrong_index)
assert(bad.issues[0].code == 3015)
```

- [ ] GREEN：在request_action前连接信号并记录token/commit_count，避免同步信号丢失；LOGICAL_SESSION按is_global调用正确finish，等待committed及IDLE，重算actual key并对比完整expected_state与增量1，再发下一step。

```text
on transition_started(result,id,generation,is_global):
  logical mode => finish_global(id,generation) if is_global else finish_local(id,generation)
after request_action:
  ERROR => ERROR/RUNTIME_ERROR
  REJECTED => DIVERGED/RUNTIME_SOLVER_DIVERGENCE
  await one committed, IDLE, and commit_count_delta == 1
  compare official actual key to expected key; first mismatch => stop
after all steps => official Goal check => MATCH
```

- [ ] RED/GREEN：步数预算0遇非空trace→INCOMPLETE；步骤完成超时或总墙钟耗尽→INCOMPLETE，不补发finish伪造成功；Kernel ERROR→ERROR，commit0/2或错key→DIVERGED。故障注入仅tests私有钩子，不注入假Kernel到生产public replay。
- [ ] GREEN验证：每次创建自有新会话；重入同一driver时ERROR/ANALYSIS_INPUT_INVALID，不能串步骤；完成/失败清理自有回调/tween而非其它场景，旧generation不能提交新步骤。

## Task 3: 真实图形自然回调与Reset负例

**Files:** trace_replayer.gd、parity_replay_scene.tscn/.gd、test_parity_graphics.gd、parity_fixtures.gd。

**Interfaces:** 消费正式Presenter，不复制坐标/姿态公式；图形与逻辑模式返回同一ParityResult。

- [ ] RED：图形场景装配真实Replayer与相机/灯光，断言DisplayServer不是headless；自然播放local/global/复合MOVE trace，不能由测试逐帧直接finish冒充动画完成。故意断callback时INCOMPLETE。
- [ ] GREEN：GRAPHICAL模式on transition调用Presenter.animate_transition；成功后连接返回tween.finished再按真实is_global完成token。committed后sync_state并比key；Presenter失败ERROR。duration仅表现参数，不能进入trace/状态身份。
- [ ] RED/GREEN：独立Reset负例在真实动画期间调用自有Session.reset，清理预览，保留旧id/generation尝试finish必须ignored；下一次完整replay从spawn可MATCH。Reset不是trace step，不把测试报告混进semantic动作数。

```gdscript
var old_id: int = session.transaction_id
var old_generation: int = session.generation
session.reset()
var stale := session.finish_local(old_id, old_generation)
assert(stale.ignored)
assert(Key.build(level, session.state).key == Key.build(level, Records.initial_state(level)).key)
```

- [ ] GREEN验证：至少一条真实自然动画callback路线及开始/中间/Goal截图；每步实际key和commit证据为主，截图不决定MATCH。新scene不改project.godot/原场景。

## Task 4: 真实3A交接、验收与报告

**Files:** test_trace_replayer.gd、test_parity_graphics.gd、run_validation.ps1、专属report、本plan。

- [ ] RED：把trace fixture替换为真实3A.solve返回的trace，至少覆盖零步/普通/世界变化/ENTER复合。3A缺席只能声明记录double测试，不宣称端到端Solver parity。
- [ ] GREEN：真实Baker→Solver→Trace→Session→Kernel/Safety→committed→StateKey两模式通过，filtered trace也应在原未改Runtime合法回放。报告不把LOGICAL_SESSION等同自然动画验收。
- [ ] wrapper支持`-Godot/-EvidenceName`，默认同时headless与真实图形两stage，60秒上限、Hidden启动、自有进程清理；退出0/checks>0/PASS、无错误、graphics display非headless。证据`.godot/foundation-3d/<EvidenceName>/`不覆盖，保存HEAD/hash、每步expected/actual key、commit、首次分歧、辅助截图与log；不新增通用trace磁盘导出格式。
- [ ] 执行命令，完成禁止文件diff检查及report后停止review。

```powershell
$godotExe = 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe'
$projectRoot = 'E:/godot/若叶睦/方块少女-若叶睦'
Set-Location -LiteralPath $projectRoot
& $godotExe --headless --path $projectRoot --script res://tests/foundation/parity/test_trace_replayer.gd
& $godotExe --path $projectRoot --script res://tests/foundation/parity/test_parity_graphics.gd --max-fps 60
& ./tests/foundation/parity/run_validation.ps1 -Godot $godotExe -EvidenceName ('accept_3d_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
& ./tests/foundation/full_integration/run_validation.ps1 -Godot $godotExe -EvidenceName ('regress_3d_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
git diff --check
git status --short
```

**PASS token:** `FOUNDATION_RUNTIME_PARITY_PASS`。必须真实3A+正式Runtime/Safety，两模式及负例通过；只覆盖送入的trace，不宣称全部状态/键鼠/关卡体验已验收。

**CONTRACT_MISMATCH stop rule:** 真实Session信号/finish接口、Trace schema或Presenter返回值与Spec不一致，停止受影响步骤并报告path/expected/actual/Owner；不修改Runtime、3A或其它Owner代码迁就。依赖缺席标DEPENDENCY_PENDING；禁止以直接赋state/假Kernel完成最终PASS。
