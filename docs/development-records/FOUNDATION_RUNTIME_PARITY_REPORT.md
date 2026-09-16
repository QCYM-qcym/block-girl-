# FOUNDATION-3D Runtime Parity — Root Cause & Real 3A Integration

日期：2026-09-16。仅工作于 `E:/godot/worktrees/block-girl-foundation-parity` / `feat/foundation-runtime-parity`。初始基线为 `69590f91e32c72103f885b32bb29e57eee36a0c3`；最新依赖 ancestry 与收口记录见第 10 节。

```text
FOUNDATION_RUNTIME_PARITY_PASS
CONTRACT_MISMATCH: NONE
HISTORICAL_TIMING_TEST_WATCHPOINT
DEPENDENCY_PENDING: NONE
```

本轮正式消费已 push 的 3A SolutionTrace；最终验收 1021 assertion checks、0 failures。旧图形测试最终 83/83，但它的固定 timer 采样窗口仍可在受控帧步长下触发。本次按用户允许的“历史 timing watchpoint 证明性处置”收口，没有通过修改 production/旧测试来消除该窗口，也不声称它此后永不间歇失败。

## 1. Root cause / 单一假设

原失败位于 `tests/foundation/full_integration/test_full_integration.gd:127`：

```gdscript
await create_timer(0.08).timeout
var progress: float = scene.presenter.transition_progress
check(progress > 0 and progress < 1 and key() == before_key,
    "visual interpolation advances independently of stable state")
```

**I think the root cause is that the old 80 ms timer can expire in its creation frame before the first idle Tween update, because failed observations have frame delta >= 80 ms, Tween elapsed=0, progress=0 and unchanged authoritative state, while passing observations have nonzero Tween elapsed.**

最小实验只改变独立 probe 的固定帧步长（`--fixed-fps 60` 对比 `--fixed-fps 10`）；timer 保持 80ms、Tween 保持 500ms，无 sleep、无 tolerance、无 production 变更：

| 实验 | Timer timeout frame | Tween elapsed / value | 下一 process frame | 自然完成 |
|---|---:|---|---|---|
| 16.7ms 固定步长 | 4（创建于 0） | 0.066667 / 0.133333 | 0.083333 / 0.166667 | value=1 |
| 100ms 固定步长 | 0（创建于 0） | 0 / 0 | 0.1 / 0.2 | value=1 |

实验确认：timer timeout 不保证 Tween 已执行一次更新。帧 delta 被用于 timer 倒计时，并不等于 timer 创建后的实际墙钟等待；某些窗口下 timer 在同一帧先于 Tween 更新触发。旧断言把“80ms timer 已到期”当作“Tween 已有中间帧”的保证，因此出现 progress=0 的假阴性。没有证据将原因归到 GPU、焦点或其它环境组件，本报告不作这种归因。

证据：`.godot/foundation-3d/investigation/hypothesis.txt`、`timer_tween_order.gd`、`order_60.stdout.log`、`order_10.stdout.log`。

## 2. 精确采样与正常 case 对照

完整 stdout/stderr 分别保存在各证据目录，不覆盖失败运行。`probe_1/sampling.json` 记录相对时间、frame、delta、动作、token/generation、完整 state/key、context、目标/当前 transform、ghost transform、Tween running/elapsed、commit count。

同套件、同一正式场景、同样 0.5s Tween 的观测如下。失败表来自带详细状态采集的 probe；正常表来自低开销 probe，**诊断开销会改变采样窗口，不能把 probe 的通过率当作原 wrapper 的通过率**。

| 动作 | 路线 / global_kind | 失败 frame / 相对 us | 失败 delta ms | elapsed / progress | token / generation / commits |
|---|---|---|---:|---|---|
| MOVE(U_POS) | local / 0 | 41 / 1584146 | 87.854 | 0 / 0 | 1 / 1 / 0 |
| ROTATE_SURFACE(22) | global / 2 | 77 / 2262532 | 97.351 | 0 / 0 | 2 / 1 / 1 |
| SHIFT_WORLD | global / 4 | 109 / 2910879 | 83.194 | 0 / 0 | 3 / 1 / 2 |

三个失败采样的 Tween 均 valid/running，key 均等于 before_key，权威 visual 仍为 previous_state；并非错误提交或提前结束。local 的 context 为 idle record，但 `_local_id` 仍持有待完成 token；不能仅从 global context 推断 local 已完成。global 则持有正式 ticket。日志含上述完整 context。

正常 `probe_light_1` 中，同样三种动作的 Tween 创建/采样 frame 分别为 40→41、78→79、113→114；elapsed 分别为 0.077550、0.058082、0.062663；progress 分别为 0.155100、0.116165、0.125327。token、generation、commit 基线及 local/global 类别与失败 case 相同。真正差异是采样时是否已经跨过 Tween 更新阶段，而不是动作规则、目标 transform 或场景装配。

visual 源/目标例：MOVE player 从 `(-2.4,1,0)` / pose 0 到 `(-1.4,1,0)` / pose 12；ROTATE 到 `(-2.4,1,-1)` / pose 15；SHIFT 到 `(2.4,1,-1)` / pose 15。完整 basis、各 cube/celestial/ghost transform 留在 JSON，不只记录位置。

## 3. Reproduction rate 与历史证明

**结论：INTERMITTENT。** 本轮未经修改的原 wrapper 三次自然运行：

| EvidenceName | 结果 |
|---|---|
| investigate_3d_baseline_1 | 82/83；采样断言失败 1 次 |
| investigate_3d_baseline_2 | 82/83；采样断言失败 1 次 |
| parity_rootcause_final_graphical | 83/83 PASS |

即本轮原 wrapper 2/3 runs 失败，不将一次最终通过解释为确定性修复。额外直接启动同一原脚本（`direct_original`）也为 82/83，排除“只有 wrapper 才会触发”的说法。上一轮的三次 82/83 是历史证据，不混入本轮分母。

为证明旧路径不依赖 3D，用 `git archive HEAD` 将正式基线的 project/foundation/runtime/authoring/旧测试放入当前 worktree 的 ignored 子目录 `investigation/historical_baseline`。该快照没有任何 parity 或新 Solver 文件：

- 原 wrapper 自然运行两次均 83/83（`historical_control`、`historical_control_2`）。
- 对该快照的原测试只设置受控 100ms frame step，83 个检查中恰好三个 animation sampling 检查失败，其余 80 个通过（`historical_fixed_10`）。
- 因此同一断言脆弱性存在于没有 3D 的冻结路径；3D production 不是该窗口的必要条件。
- 当前旧 production、旧测试、project 和公共 Spec 与 HEAD 相同；其资源加载路径不引用新 parity 模块。

这满足 HISTORICAL_TIMING_TEST_WATCHPOINT 的证明条件：完整权威状态正确、自然完成后的 visual 正确、旧路径未改、错误局限于首次 Tween 更新之前的采样窗口、重复行为可描述。未修改旧测试；对未来任意帧步长的确定性验收保证不在此次 PASS 声明内。

## 4. 数据流与是否修改 production / 旧测试

原路径是 action → request_action → Kernel proposal → transition_started → Presenter 创建预览 Tween。此时尚未 authoritative commit，稳定 visual 保持旧状态。自然完成后 finish_local/global → authoritative commit → committed → Presenter.sync_state → IDLE。旧套件第一轮还会在采样后手动 finish 来测试提交与动画解耦；第二轮完全依靠原场景自然 callback，全部终态检查通过。

**本恢复轮未修改任何既有 production，包括 3D Replayer；未修改 FOUNDATION-2 旧测试、断言、期望、tolerance 或时长。** 诊断只在 ignored probe 中收集数据/控制实验帧步长，正常最终验收命令没有 fixed-fps。没有增加 sleep 作为修复。

## 5. 真实 3A commit 与依赖接入

已只读核验 `feat/foundation-state-explorer-bfs` 与 `git ls-remote origin refs/heads/feat/foundation-state-explorer-bfs` 均指向：

`f34dd271adabcc4b724eb55b5fff1cb35f532e59`

其正式报告包含 `FOUNDATION_STATE_EXPLORER_BFS_PASS`、`CONTRACT_MISMATCH: NONE`。使用 `git restore --source=<该提交> --worktree -- foundation/solver` 原样接入七个正式脚本及七个 UID；这属于用户授权的依赖同步，不是复制/重写算法。未 merge、未提交、未改 3A 源码或报告。wrapper 对全部 14 个文件逐一验证 Git blob 与该 commit 一致，防止漂移。

production Replayer 保持通过正式 `solution_trace.gd` 做输入校验。新集成测试没有 `_trace_api`/Session/Kernel 替身，原缺失依赖测试改为 tests-only MissingTraceDriver 以继续验证依赖缺失时 fail closed。旧固定 fixture/adapter 只继续服务既有负例；它们不再是最终 real-trace 证明来源。

## 6. SolutionTrace 真实链

新增 `tests/foundation/parity/test_solver_trace_integration.gd`（及 UID）：

```text
正式 AuthoringReader → 正式 Baker / Validator VALID → LevelDefinition
→ BFSSolver.solve(level, Records.initial_state(level), formal policy/budget)
→ SolverResult.solution_trace → SolutionTrace.validate_semantics
→ production Replayer → Session.request_action
→ 正式 token completion → 一次 authoritative commit → IDLE
→ 逐步完整 statekey.v1 / expected_state 比较
```

两模式均覆盖真实求解的 zero、one、route、composite 四条链。route 的实际 Solver 输出为 MOVE → ROTATE_SURFACE → SHIFT_WORLD；composite 为一个 MOVE+ENTER FaceTransition。完成接口遵守冻结合同的 `transition_started.is_global`，composite 虽 global_kind=5 仍为 local。初态继续只支持 spawn。

图形模式由正式 Presenter 的 Tween.finished 自然触发 completion，没有输入模拟，没有设置 visual transform 来伪造终点。证据含真实 Solver policy/budget/metrics、完整 trace、validate_semantics transitions、每步 key/commit 与 parity result。

## 7. Divergence / commit / token

真实 3A 集成负例：篡改第二步的合法 expected_state 并同步 key，Trace.validate 通过而 validate_semantics 拒绝；Runtime replay 在 step 2 DIVERGED，matched_steps=1，记录 action、不同的 expected/actual key 及 issues。真实合法非 spawn 后缀 trace 在 Runtime 创建前 ERROR / 3013。

保留并完整重跑原负例：REJECTED 零提交、ERROR 零 partial commit（保留上游 1105）、APPLIED 一次提交、重复/缺失信号、两次真实 commit、超时、重入、Reset、旧 token/generation、相同数值 token 被新 Session 复用时旧 Tween callback 无效、移出/重新加入后的旧 coroutine 不能清理新会话。

RuntimeParityResult 仍严格八字段；没有新增任意状态恢复入口、公共合同或 Solver/StateExplorer 实现。

## 8. 最终测试（全部正常验收参数）

Godot 4.7.2 stable；Windows / D3D12 / RTX 5060 Ti。各阶段退出 0，stderr 空，无 failure。

| Suite | checks | 结果 |
|---|---:|---|
| 3D logical fixture/negative parity | 169 | PASS |
| 3D real Presenter graphical fixture/negative parity | 77 | PASS |
| 正式 3A SolutionTrace logical integration | 53 | PASS |
| 正式 3A SolutionTrace graphical integration | 53 | PASS |
| FOUNDATION-2 real full integration headless | 77 | PASS |
| FOUNDATION-2 原图形 83 项 | 83 | PASS |
| Runtime Input Mapper | 330 | PASS |
| Runtime Session 原合同回归 | 63 | PASS，原测试自身使用 contract double |
| Runtime Graphical 原回归 | 116 | PASS，原测试自身使用 contract double |
| **合计** | **1021** | **0 failures** |

实际命令：

```powershell
& ./tests/foundation/parity/run_validation.ps1 -EvidenceName parity_real3a_20260916
& ./tests/foundation/full_integration/run_validation.ps1 -Headless -EvidenceName parity_rootcause_final_headless
& ./tests/foundation/full_integration/run_validation.ps1 -EvidenceName parity_rootcause_final_graphical
& ./tests/foundation/runtime/run_validation.ps1 -EvidenceName parity_rootcause_runtime_final
```

证据分别位于 `.godot/foundation-3d/parity_real3a_20260916/`、`.godot/foundation-2-full/parity_rootcause_final_{headless,graphical}/`、`.godot/foundation-2d-evidence/parity_rootcause_runtime_final/`。新 real trace 报告为 `real_trace_logical.json` / `real_trace_graphical.json`。wrapper 保留原始日志、commit/blob 验证、依赖 SHA256；只输出本模块 suites PASS，整体 PASS 还需上述其它回归证据。

## 9. 文件与 git diff

上一轮 3D production：`foundation/parity/parity_types.gd`、`trace_replayer.gd` 及 UID，保持不变。

本轮变更：新增真实 Solver trace 集成测试及 UID；原 logical 测试中将“实际依赖缺失”改为显式 tests-only 缺失依赖注入；wrapper 新增两个真实链 stage 和 3A blob 校验；更新本报告和本 Work 计划。正式依赖为 `foundation/solver/` 的 14 个原样文件。

所有写入在指定 parity worktree。没有修改主工作树、公共 Spec、3A production 相对于正式提交的内容、3B、3C、P-01、旧 Runtime 或旧测试。上一阶段没有 commit/push/merge；本次按用户明确授权完成 3A merge，并使用 GitHub Desktop 提交/push 3D 自有变更。

完整含未跟踪文件的 diff：`.godot/foundation-3d/parity-rootcause.patch`；范围、正式依赖一致性和测试源 hash 审计：`.godot/foundation-3d/rootcause-git-audit.json`。之前 provisional 证据保留在 `parity_final_20260916`，本报告以上述本轮正式链和回归为准。

## 10. REAL 3A DEPENDENCY HYGIENE + FINAL GIT CLOSEOUT

正式 3A：`f34dd271adabcc4b724eb55b5fff1cb35f532e59`。依赖 merge commit：`64a324b22ecca004b1f2bd408b276577c14e4b49`，两个 parent 分别为 `69590f91e32c72103f885b32bb29e57eee36a0c3` 和正式 3A commit。使用 `--no-ff` 保留 merge history；没有 rebase/squash/cherry-pick，也没有 merge foundation-core/main。

已备份全部 34 个工作文件并验证 SHA256，再仅 stash 20 个 3D 自有文件；核验 14 个依赖副本后移除，merge 正式 3A 分支，恢复自有修改。stash 恢复带来的 CRLF 差异经 Git blob 与 LF 规范化比较确认后，恢复备份的原字节；全部 20 个文件保持原内容。备份/stash 均保留作为恢复证据。

`git merge-base HEAD f34dd271adabcc4b724eb55b5fff1cb35f532e59` 返回该完整 3A hash，`git merge-base --is-ancestor` 退出 0。merge commit 的 tree 与 3A commit 的 tree 相同；3A 的 production/test/report/plan 27 个文件从正式历史继承。它们不属于随后 3D 自有 commit。

原 14 个同步文件逐一用 `git hash-object --path=<path>` 对照 `git rev-parse <3A commit>:<path>`；下表每个本地 blob 都与上游相同（不是按文件名认定）：

| 原同步文件 | 本地及正式 3A 的相同 Git blob |
|---|---|
| `foundation/solver/action_generator.gd` | `dabd2ee51e6076349527ddd3eeb9bebec7d4d775` |
| `foundation/solver/action_generator.gd.uid` | `fd6c678829fdd60bd3819ef90fca68e940c0651d` |
| `foundation/solver/bfs_solver.gd` | `0bab8a2f44b902ca2b21c5f4c583c69c41fb502c` |
| `foundation/solver/bfs_solver.gd.uid` | `e5ffc9042a98f0805fef6c190257737f0164700a` |
| `foundation/solver/search_records.gd` | `4238bbbeae6d86d50482253d193e5271b7ed2731` |
| `foundation/solver/search_records.gd.uid` | `d9219af227fb7287a94c87e566a039aff61fcbf4` |
| `foundation/solver/solution_trace.gd` | `b243bcdf4b4ae835fa9827635555ea009ae32410` |
| `foundation/solver/solution_trace.gd.uid` | `89bfe5abc4413151bb42a9ca8159eaa27b2ac734` |
| `foundation/solver/solver_types.gd` | `98ec8d009fa6dafb2cebfc583bbe8988b8dfeb74` |
| `foundation/solver/solver_types.gd.uid` | `50edee4065b386a2d5aadc4ade9bdac9247f2a23` |
| `foundation/solver/state_explorer.gd` | `269865627447bbe98e74788eed4be4c67161edab` |
| `foundation/solver/state_explorer.gd.uid` | `7f6daed0afa27a2fb5a85f13131353164b06e1a7` |
| `foundation/solver/state_graph.gd` | `f60d82515be69161cd5b8bf1be987f4e35582b70` |
| `foundation/solver/state_graph.gd.uid` | `3bb96cdfef5eea62e53dbf170c4a76c9406a18d0` |

3D own diff 精确为以下 20 个文件；没有其它 Owner 的必要修改：

- `docs/superpowers/plans/2026-09-16-foundation-runtime-parity.md`
- `docs/development-records/FOUNDATION_RUNTIME_PARITY_REPORT.md`
- `foundation/parity/parity_types.gd`
- `foundation/parity/parity_types.gd.uid`
- `foundation/parity/trace_replayer.gd`
- `foundation/parity/trace_replayer.gd.uid`
- `tests/foundation/parity/parity_fixtures.gd`
- `tests/foundation/parity/parity_fixtures.gd.uid`
- `tests/foundation/parity/parity_replay_scene.gd`
- `tests/foundation/parity/parity_replay_scene.gd.uid`
- `tests/foundation/parity/parity_replay_scene.tscn`
- `tests/foundation/parity/run_validation.ps1`
- `tests/foundation/parity/test_parity_graphics.gd`
- `tests/foundation/parity/test_parity_graphics.gd.uid`
- `tests/foundation/parity/test_solver_trace_integration.gd`
- `tests/foundation/parity/test_solver_trace_integration.gd.uid`
- `tests/foundation/parity/test_trace_replayer.gd`
- `tests/foundation/parity/test_trace_replayer.gd.uid`
- `tests/foundation/parity/trace_contract_double.gd`
- `tests/foundation/parity/trace_contract_double.gd.uid`

合并后重新运行的验收（不引用上一轮结果）：

| 阶段 | 新 checks | 结果 |
|---|---:|---|
| 3D logical | 169 | PASS |
| 3D graphical | 77 | PASS |
| real 3A SolutionTrace logical | 53 | PASS |
| real 3A SolutionTrace graphical | 53 | PASS |
| FOUNDATION-2 headless | 77 | PASS |
| FOUNDATION-2 graphical | 83 | 83/83 PASS |
| Runtime Input Mapper | 330 | PASS |
| Runtime Session（既有 double 合同测试） | 63 | PASS |
| Runtime graphics（既有 double 合同测试） | 116 | PASS |
| **合计** | **1021** | **0 failures** |

新的证据目录：`.godot/foundation-3d/hygiene_final_3d_20260916/`、`.godot/foundation-2-full/hygiene_final_headless_20260916/`、`.godot/foundation-2-full/hygiene_final_graphical_20260916/`、`.godot/foundation-2d-evidence/hygiene_final_runtime_20260916/`。记录 merge HEAD、依赖 hash、真实计数、退出码和 stdout/stderr；所有阶段退出 0、stderr 空。

```text
FOUNDATION_RUNTIME_PARITY_PASS
CONTRACT_MISMATCH: NONE
WATCHPOINT: HISTORICAL_TIMER_BEFORE_FIRST_TWEEN_UPDATE
```

本轮仅调整 Git dependency ancestry 和本报告/计划；没有修改 production、测试脚本、旧断言或动画时长。GitHub Desktop 提交标题：`feat: add foundation runtime parity`，目标 `origin/feat/foundation-runtime-parity`；自有提交排除 3A 文件、`.godot/`、evidence、临时日志。最终 3D hash、远端一致性和 clean 状态在收口消息及 ignored `closeout_hygiene/final.json` 中核验，避免在提交内容中递归记录自身 hash。无 PR。
