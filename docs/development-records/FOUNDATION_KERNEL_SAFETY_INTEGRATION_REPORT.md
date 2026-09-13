# FOUNDATION Kernel × Safety Integration Report

Date: 2026-09-13 (Asia/Shanghai)

```text
FOUNDATION_KERNEL_SAFETY_INTEGRATION_PASS
FOUNDATION_RULE_KERNEL_PASS
CONTRACT_MISMATCH: NONE
```

The final Safety dependency acceptance for 2A is satisfied on this isolated integration branch. The original 2A branch retains its accurate provisional report. This acceptance does not declare complete FOUNDATION-2 integration or authorize merging into core/main.

## 1. Git provenance and closeout

| Item | Recorded value |
| --- | --- |
| Integration branch | `integration/foundation-2-kernel-safety` |
| Worktree | `E:/godot/worktrees/block-girl-foundation-kernel-safety` |
| Core / common FOUNDATION-2 baseline | `b7fd6ae9cfa1961a4ca52bb977d66e87903fcec5` |
| 2B branch | `feat/foundation-static-validator` |
| 2B commit | `f530e2fe16c64880812b1b20a06504798a477b6b` |
| 2B message | `feat: add foundation static validator and safety` |
| 2A branch | `feat/foundation-rule-kernel` |
| 2A commit | `384696f3708504d806c630b7e57a898139780695` |
| 2A message | `feat: add puzzle rule kernel foundation` |
| Combined merge commit | `e176c1e18e72ab3d300d90542d8a9cea9769a3bc` |
| Final tests/report commit title | `test: verify puzzle kernel safety integration` |

2B and 2A were committed and published through GitHub Desktop. Both origin branch tips were independently verified to equal the full local hashes above; both source worktrees became clean. 2B reused its final evidence only after all 13 production dependency hashes matched. 2A passed the provisional gate with the sole remaining blocker `WAITING_FOR_2B_SAFETY_INTEGRATION`, then freshly passed 833 unit assertions before its commit.

The common ancestor of 2A and 2B equals the clean core HEAD above, so the ancestry requirement is satisfied. GitHub Desktop created the independent integration worktree from that baseline. A fresh FOUNDATION-1 baseline run passed before integration.

Merge order was strictly Safety first, then Kernel. The Safety merge fast-forwarded to the 2B commit. The Kernel merge produced the two-parent commit above, with parents 2B then 2A. No conflicts, squash, rebase or history replacement occurred. Core and source branches were not changed by integration work.

This report is prepared before its own final GUI commit; the resulting full commit hash and remote verification are recorded in the task's final closeout receipt, avoiding a self-referential commit hash.

## 2. Real production dependency and canonical statuses

`foundation/rules/puzzle_rule_kernel.gd` and `goal_evaluator.gd` already preload `foundation/validation/safety_queries.gd`. Merging the owners provided the real dependency without any production wiring edit. The dedicated integration suite directly loads production Kernel, Safety, StaticValidator, contract records, geometry and StateKey. No double, adapter, shadow project or fallback is used in real mode.

The frozen contract distinguishes two APIs:

| API | Canonical statuses |
| --- | --- |
| Safety queries | `SAFE=0`, `UNSAFE=1`, `UNPROVEN=2`, `ERROR=3` |
| StaticValidator | `VALID=0`, `INVALID=1`, `INCOMPLETE=2` |

The user's incomplete-safety requirement is evaluated using these canonical names. No status alias or public contract was changed.

### validate_state

A real safe state permits World Rotate. A non-walkable current support produces real `UNSAFE` with issue `1204`; Kernel returns `ERROR`, rejection code 0, and no mutation. The real StaticValidator separately returns VALID, INVALID with 1204, and budget-limited INCOMPLETE with 1600.

Production `validate_state` exhaustively checks one finite stable configuration and has no budget option or reachable UNPROVEN return path. Therefore an actual state-query INCOMPLETE/UNPROVEN cannot honestly be manufactured. The unit-only double explicitly returns UNPROVEN to verify the defensive Kernel path: dangerous World Rotate returns ERROR, does not call motion Safety, and leaves input state unchanged. This is reported as defensive unit coverage, not real state-query integration coverage.

### validate_motion

Real MOVE on a two-support route returns SAFE and applies the exact player pose; the reverse move restores the complete state. The original dense three-Cube route produces UNPROVEN with issue 1601, and Kernel returns REJECTED / 2000 without changing state. Direct invalid endpoint coverage returns UNSAFE; a malformed motion pose returns ERROR / 1502.

Local Group Rotate has a real SAFE path and a conservative-sweep UNPROVEN path that returns REJECTED / 2002. FaceTransition verifies all three segments, exact final pose, and a real UNPROVEN rejection / 2003. World Rotate verifies SAFE and real arithmetic overflow 1105; overflow remains ERROR with rejection code 0.

### validate_concurrent_motion

A real moving Group plus local MOVE returns SAFE and applies through the busy transition path. Another fixture makes each individual motion SAFE while their combined sweep is UNPROVEN. Kernel returns the canonical busy rejection 1504, preserves the complete Safety issue records, and does not append a trace or partially mutate state. A direct non-walkable concurrent endpoint returns UNSAFE / 1204.

Coverage limitation: for the non-walkable destination examples, Kernel rejects earlier in connectivity validation. These demonstrate real Safety UNSAFE and Kernel prevention independently; they do not claim that candidate Safety UNSAFE issue propagation was reached through Kernel. Defensive consumer propagation statuses remain covered by the explicit unit suite. The real UNPROVEN and ERROR propagation paths are exercised end to end.

## 3. Incomplete fail-safe, atomicity and code domains

UNPROVEN is never promoted to SAFE. Current unsafe/unproven/error state prevents dangerous mutation using the frozen ERROR semantics. Unproven candidate movement, Group Rotate and FaceTransition are rejected with their action-specific codes; concurrent uncertainty uses 1504. Arithmetic overflow 1105 remains an ERROR, not an ordinary action rejection.

Integration helpers compare serialized input Level/State/Action records and StateKey before and after every evaluated action. Rejected/error results require `next_state == null`, `changed == false`, and no global mutation. Applied results retain all six state fields and a valid StateKey. Busy completion uses three alternating proven rolls and ends away from its original player location, detecting stale player-state overwrite. Existing unit coverage retains the four-forward-roll algebra case and atomic ENTER/rollback tests.

Safety issue dictionaries are compared in full, including their deterministic order and metadata. ValidationCode values remain in the issue domain; ActionRejectionCode values remain in the result's rejection field. No remapping of 1105 or 1601 into an action rejection was introduced.

## 4. Final validation results

All final suites completed with exit code 0, zero failures, and empty stderr. The final 13 stderr files were checked. Counts below are executed assertions, not unique test cases.

| Suite | Assertions | Evidence directory under this worktree |
| --- | ---: | --- |
| Kernel, real Safety | 645 (532 main + 113 busy) | `.godot/foundation-2a-validation/kernel_safety_final_real_20260913_172953` |
| Kernel, explicit unit double | 844 (728 main + 116 busy) | `.godot/foundation-2a-validation/kernel_safety_final_unit_20260913_172822` |
| Safety + StaticValidator | 370 (199 + 171) | `.godot/foundation-2b-validation/kernel_safety_final_2b_20260913_172822` |
| Dedicated Kernel × Safety matrix | 161 | `.godot/kernel-safety-integration/matrix_final_20260913_172953` |
| FOUNDATION-1, all six suites | 81,014 | `.godot/foundation-1-validation/kernel_safety_final_foundation_20260913_172823` |

Real-dependency suites plus FOUNDATION-1 total **82,190** assertions. The separate double suite adds 844, giving **83,034** final executed assertions overall. Unit doubles are not counted as proof of real Safety integration.

Dedicated matrix breakdown: state/budget 21, motion 36, rotations 34, FaceTransition 19, concurrent movement 51. FOUNDATION-1 breakdown: Orientation 77,965; Data Contracts 733; StateKey 546; Spatial 1,533; Celestial 132; Integration 105.

Reproduction wrappers: `tests/foundation/rules/run_validation.ps1` (real by default; explicit `-UnitDouble` for unit coverage), `tests/foundation/validation/run_validation.ps1`, `tests/foundation/kernel_safety/run_validation.ps1`, and `tests/foundation/run_validation.ps1`. Use a fresh EvidenceName for each run. The dedicated wrapper records all 21 production GDScript dependency SHA-256 hashes, exit status, timeout status, assertion count and log paths. All 21 still matched at report preparation.

### Initial failure and scoped correction

The first real run in `.godot/foundation-2a-validation/kernel_safety_first_real_20260913_172041` failed on fixtures inherited from unit tests. Their third contiguous Cube intersects the conservative player-roll envelope. Under frozen §16.1, only source and target supports are exempt; the third Cube correctly causes UNPROVEN / 1601. No production bug or missing contract was found.

Real happy-path fixtures now move that unrelated Cube to `(20,0,0)` and use a two-support Group. Original unit fixtures remain the default. The original dense route is explicitly tested for real rejection, while the unit four-roll property remains intact. The failed evidence and diagnosis are retained locally. The correction adapts the happy-path preconditions and adds the negative real case; it does not weaken Safety or simply flip a failed expected result to PASS.

## 5. Ownership audit, diff and known limits

Read-only production audit and independent review found no second collision, sweep, player-safety or concurrent-safety implementation under `foundation/rules/`. Safety remains owned by `foundation/validation/`; Kernel prepares transactions, invokes Safety and propagates results. Test doubles remain under tests and are activated only by explicit unit mode. A second review of the test adaptations found no blocking issue or material loss of coverage.

Production files are byte-for-byte unchanged from merge commit `e176c1e18e72ab3d300d90542d8a9cea9769a3bc`. Frozen specs are unchanged from the core baseline. `git diff --check` passes. `CONTRACT_MISMATCH: NONE`.

The final commit scope is eight test/documentation files:

- `tests/foundation/rules/kernel_fixture.gd`
- `tests/foundation/rules/test_rule_kernel.gd`
- `tests/foundation/rules/test_busy_transition.gd`
- `tests/foundation/kernel_safety/test_kernel_safety.gd`
- `tests/foundation/kernel_safety/test_kernel_safety.gd.uid`
- `tests/foundation/kernel_safety/run_validation.ps1`
- `docs/superpowers/plans/2026-09-13-foundation-kernel-safety-integration.md`
- `docs/development-records/FOUNDATION_KERNEL_SAFETY_INTEGRATION_REPORT.md`

All `.godot/` logs, evidence, temporary diagnostic scripts and generated shadow projects remain ignored and local; none is part of the intended commit. They were not deleted or restored. No production code, public contract or remote setting was edited.

Known limits are the frozen conservative sweep's intentional false-negative/UNPROVEN outcomes, the unreachable production state-query UNPROVEN case, and the early-connectivity UNSAFE coverage distinction described above. There is no unresolved integration blocker. This does not prove arbitrary-level solvability, replace continuous physics, or cover 2C/2D.

## 6. Disposition

2A may be upgraded to `FOUNDATION_RULE_KERNEL_PASS` based on the real dependency acceptance on this integration branch. Keep all source branches and worktrees. The authorized final action is a GitHub Desktop tests/report commit and push of this integration branch as backup; no PR. Then wait for 2C/2D readiness and explicit authorization for final FOUNDATION-2 Integration. Do not merge into `feat/foundation-core` or `main` in this task.
