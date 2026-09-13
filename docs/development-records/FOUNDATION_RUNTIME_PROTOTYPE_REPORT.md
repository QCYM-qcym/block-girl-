# FOUNDATION-2D Runtime Foundation Prototype

2026-09-13 · `feat/foundation-runtime-prototype` · baseline/HEAD `b7fd6ae9cfa1961a4ca52bb977d66e87903fcec5`.

## Acceptance scope

**FOUNDATION_RUNTIME_PROTOTYPE_PASS — explicit contract-double prototype.**

**CONTRACT_MISMATCH: NONE.** No public contract, first-wave implementation, P-01, project setting, or production asset was changed. No commit, push, merge, or branch synchronization was performed.

The current worktree does not contain the real `foundation/rules` or `foundation/validation` implementations. The latest user instruction expressly permits a strict Kernel Adapter/Test Double when the formal Kernel has not been integrated. That authorization governs this prototype acceptance and supersedes the plan's earlier real-Kernel-only acceptance condition. It does not certify real Kernel/Safety integration, full motion safety, or a playable production level.

**Real Kernel + Safety integration: NOT RUN.** Real busy permission, concurrent swept-volume proof, and actual MOVE+ENTER mechanism evaluation remain dependent on 2A/2B. Scheduler tests inject complete prerecorded outcomes; they do not implement these algorithms.

Sources read: formal architecture spec, FOUNDATION-0.1 core contracts, FOUNDATION-2.0 execution contracts, and the dedicated runtime plan. Existing first-wave ABI remains authoritative.

## Scene and launch

[Independent scene](E:/godot/worktrees/block-girl-foundation-runtime/prototype/foundation/runtime/foundation_runtime.tscn), [composition script](E:/godot/worktrees/block-girl-foundation-runtime/prototype/foundation/runtime/foundation_runtime.gd), [fixture](E:/godot/worktrees/block-girl-foundation-runtime/prototype/foundation/runtime/runtime_fixture.gd).

Two Surface cubes (`s0`, `s1`) and two Inner cubes (`i0`, `i1`), one celestial slot, no mechanism/group/flag expansion. Surface and Inner are separated horizontally **only in presentation**. Geometry, Mapping and StateKey still use their shared logical coordinates. The colored visual light is not logical lighting.

From `E:/godot/worktrees/block-girl-foundation-runtime`:

```powershell
# Explicit interactive contract-double demonstration; no automatic exit.
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . --script res://tests/foundation/runtime/test_runtime_graphics.gd -- --interactive

# Normal production scene: real-only port; clearly reports missing dependencies.
& 'D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe' --path . res://prototype/foundation/runtime/foundation_runtime.tscn

# Fresh evidence name required. Optional legacy regressions import assets first.
& './tests/foundation/runtime/run_validation.ps1' -EvidenceName my_runtime_check -IncludeRegressions
```

The test launcher injects the double before adding the same production scene to the tree and displays `TEST DOUBLE / fixed contract results; real Kernel + Safety not integrated`. Production code never loads a test script or silently substitutes a double. Normal-scene graphical smoke test exited 0 with empty stderr; it displays the unavailable backend rather than accepting actions.

Controls: D → Q → Space demonstrates MOVE → Surface world rotation → Shadow Shift. Space at spawn demonstrates blocked exit. R or the Reset button restores the initial state. Tab/Target button selects RotateTarget without changing PlayerLayer. WASD/arrows are projected through InputMapper; directions degenerate under the fixed observation camera are rejected. E is intentionally not enabled by this fixture's intent/delta lists.

## Input Adapter and Kernel boundary

[InputMapper](E:/godot/worktrees/block-girl-foundation-runtime/foundation/runtime/input_mapper.gd) returns the frozen `{ok,action,issues}` wrapper. MOVE uses the canonical halfplane representative, frozen tie order, and opposite-pair restoration. ROTATE accepts a discrete right-handed observation basis, checks both permitted intent and delta, and delegates quarter turns to formal Orientation math. Camera/key codes never enter an action or PuzzleState.

[KernelPort](E:/godot/worktrees/block-girl-foundation-runtime/foundation/runtime/kernel_port.gd) forwards `evaluate_action`, `complete_global`, `begin_global`, `idle_context`, and `is_goal` to the formal owners. Defaults dynamically load real scripts only; missing dependencies yield `VALIDATION_INCOMPLETE` with a complete ValidationIssue. No shadow, adjacency, Mapping, permission, Slot, or pose rule is implemented in the port.

[RuntimeSession](E:/godot/worktrees/block-girl-foundation-runtime/foundation/runtime/runtime_session.gd) validates DATA and calls the Safety boundary on load. It owns generation/transaction IDs outside the six-field state. It holds one global ticket, permits busy MOVE only through Kernel results, and records only committed MOVE actions in `local_moves`. It replaces the complete `next_state` once at completion; it never merges player/global fields. MOVE with a composite global effect stays one local atomic proposal and opens no delayed global ticket.

Reset invalidates all prior tokens. Repeated local input is dropped without a queue. Global completion forwards the latest committed state and trace; a completion error retains that state. Synchronous signal observers see the state and trace atomically. Guards prevent old acceptance/completion feedback from overriding Reset, reload, immediate completion, or a newer transaction.

[Kernel double](E:/godot/worktrees/block-girl-foundation-runtime/tests/foundation/runtime/kernel_double.gd) is a finite whole-state/action lookup with an explicit test Safety stub. Its queued/overridden records support unit fault injection only. It contains no graph search, movement resolver, Mapping/Lighting, orientation computation, or motion-safety implementation. Unknown demo routes reject rather than extrapolate rules.

## Visual Sync and state identity

[Presenter](E:/godot/worktrees/block-girl-foundation-runtime/foundation/runtime/prototype_presenter.gd) stages the full visual snapshot before touching nodes. It calls formal Spatial `snapshot` and Orientation `columns`, synchronizes player/world/celestial poses, and keeps the committed face frame for input. The player center is derived from the formal anchor and normal; it is never read back from Node transforms.

Transparent ghost meshes interpolate between the authorized previous/next records. The committed meshes and StateKey stay unchanged until visual completion. This interpolation is presentation only, not a physical trajectory or a safety proof. Default duration is 0.25 s; graphical tests explicitly use 0.5 s to capture the pre-commit boundary. Reset kills both preview and progress tweens. REJECTED and ERROR start no new preview and perform no logical or visual commit. Errors after an authorized preview leave the committed meshes intact and discard the preview.

PuzzleState remains exactly `player`, `world_orientations`, `celestial`, `group_orientations`, `mechanism_states`, `level_flags`. Camera, RotateTarget, progress, meshes, visual effects, debug labels, light state, Mapping, connectivity and anchors are excluded. Only the public `StateKey.build(level,state)` produces keys; there is no runtime serializer/hash cache.

| Route checkpoint | Player | World orientations | Pose | Logical commits |
|---|---|---|---:|---:|
| Initial / Reset | Surface `s0/TOP` | `[0,0]` | 0 | 0 |
| D / MOVE U_POS | Surface `s1/TOP` | `[0,0]` | 12 | 1 |
| Q / ROTATE_SURFACE delta 22 | Surface `s1/TOP` | `[22,0]` | 15 | 2 |
| Space / SHIFT_WORLD | Inner `i1/TOP` | `[22,0]` | 15 | 3 |

Actual graphical checkpoints equal direct double evaluation using complete `statekey.v1` strings. Tests call the real first-wave Mapping and Lighting owners separately to confirm the route's unique `s1/TOP → i1/TOP` overlap and `SHADOW` source. These checks do not substitute for real Kernel or Safety validation.

## Validation evidence

| Suite | Checks | Result |
|---|---:|---|
| InputMapper | 330 | PASS |
| RuntimeSession / explicit double | 62 | PASS |
| Actual Windows/D3D12 runtime graphics | 116 | PASS |
| **New Runtime total** | **508** | **PASS** |
| Existing Orientation | 77,965 | PASS |
| Existing DATA contracts | 733 | PASS |
| Existing StateKey | 546 | PASS |
| Existing Spatial | 1,533 | PASS |
| Existing Celestial | 132 | PASS |
| Existing foundation integration | 105 | PASS |
| **Existing FOUNDATION total** | **81,014** | **PASS** |
| P-01 state | 31 | PASS; 108 reachable/solvable states |
| P-01 actual runtime | 167 | PASS |
| Existing Perspective logic | 66 | PASS |
| Existing Perspective bugfix | 172 | PASS |
| Existing Perspective actual runtime | 54 | PASS |
| Earlier prototype state | 50 | PASS; 94 reachable/solvable states |
| Earlier prototype actual runtime | 3,451 | PASS |
| Earlier input fallback | unnumbered gate | PASS |
| Sprite / Tileset / Mechanism | unnumbered gates | PASS; Tileset 107 captures |

**Total explicitly counted checks: 85,513**, plus the unnumbered input/resource gates. Capture counts are not added to assertion counts. Both the P-01 wrapper and its complete `-IncludeRegressions` chain exited 0. All successful legacy stage stderr files are empty. [P-01 graphical report](E:/godot/worktrees/block-girl-foundation-runtime/tests/gameplay/evidence/runtime_foundation_p01_imported/runtime_report.json), [legacy regression evidence](E:/godot/worktrees/block-girl-foundation-runtime/tests/gameplay/evidence/runtime_foundation_p01_imported_regression/runtime_report.json).

Runtime commands exited 0, explicit PASS markers, and empty stderr. [Final Runtime evidence](E:/godot/worktrees/block-girl-foundation-runtime/.godot/foundation-2d-evidence/runtime_final_visual/results.json), [graphical report and complete keys](E:/godot/worktrees/block-girl-foundation-runtime/.godot/foundation-2d-evidence/runtime_final_visual/runtime_report.json), [FOUNDATION regression evidence](E:/godot/worktrees/block-girl-foundation-runtime/.godot/foundation-1-validation/runtime_foundation_regression/results.json).

Graphical automation uses `Input.parse_input_event` for keys and `Viewport.push_input` for viewport-local mouse events. This exercises Godot input/Control dispatch in a real D3D12 window; it is not an OS keyboard/mouse manual playtest. Human/system manual playtest: NOT RUN. Screenshot inspection confirmed initial, transition preview and route views; all screenshot captures and StateKeys are stored with the report.

[Initial screenshot](E:/godot/worktrees/block-girl-foundation-runtime/.godot/foundation-2d-evidence/runtime_final_visual/initial.png), [pre-commit interpolation](E:/godot/worktrees/block-girl-foundation-runtime/.godot/foundation-2d-evidence/runtime_final_visual/move_preview.png), [Shadow Shift](E:/godot/worktrees/block-girl-foundation-runtime/.godot/foundation-2d-evidence/runtime_final_visual/shadow_shift.png), [ERROR](E:/godot/worktrees/block-girl-foundation-runtime/.godot/foundation-2d-evidence/runtime_final_visual/error.png).

RED→GREEN evidence includes missing scene/mapper/session, malformed endpoint handling, five commit-notification reentrancy failures, and four transition-start reentrancy failures. Review found and fixed atomic trace notification, readable rejection feedback, interpolation, and stale synchronous acceptance. Final scoped review has no remaining findings.

First P-01 attempt failed because the fresh worktree lacked imported `.ctex` caches. The first error names the missing imported Surface tileset; the later nil errors were consequences. That failed run is preserved at `tests/gameplay/evidence/runtime_foundation_p01/`. Headless editor import exited 0 with empty stderr and changed no tracked files. A new evidence directory `runtime_foundation_p01_imported` was used for the successful rerun. The unchanged legacy wrapper owns its existing larger timeouts; the new Runtime stages each have a 60-second bound. No old test expectations or assets were changed to get a pass.

## Fixture identity and deferred integration

The fixture is hand-authored, not a Baker artifact. Its content hash is `3d6ff71bf204675a105ff77f834064af95f55db20d2a85c04983ecbb810cb032`. It was computed offline with SHA-256 over 4,755 UTF-8 bytes: canonical rule JSON, no BOM/trailing newline, excluding `content_hash` and `build_info`. [Exact byte evidence](E:/godot/worktrees/block-girl-foundation-runtime/.godot/foundation-2d-evidence/fixture.rules.canonical.json) and [digest](E:/godot/worktrees/block-girl-foundation-runtime/.godot/foundation-2d-evidence/fixture.sha256) are preserved. The exact JSON is also retained below so the fixed digest can be audited without ignored caches. No runtime Baker/Codec/hash algorithm was introduced.

No BFS/A*/Solver, StaticValidator algorithm, full Kernel, Editor, P-02, formal resource work, Blender or P-01 migration was implemented. Real Kernel/Safety integration, busy legality/swept-volume proofs and real mechanism execution remain explicitly unverified.

## Files and git diff

Added: four production Runtime scripts; two scene/fixture scripts and one `.tscn`; four test scripts and the Runtime wrapper; ten generated script `.uid` files; this report. **23 added files + 1 modified plan = 24 files.** All implementation changes are untracked/unstaged; no commit/push/merge.

The full review patch, including untracked additions, is saved at [runtime.patch](E:/godot/worktrees/block-girl-foundation-runtime/.godot/foundation-2d-evidence/runtime.patch). A normal `git diff` alone omits these newly added files. `git diff --check` passes. HEAD remains the baseline above; ownership audit permits only the three Runtime directories and the dedicated plan/report.

## Exact offline canonical fixture bytes

The code fence's line break is documentation formatting; the hashed bytes contain only the single JSON line, without that terminal newline.

```json
{"celestial":{"edges":[],"initial_slot_id":"a","slot_order":["a"],"slots":[{"position2":[0,-8,0],"slot_id":"a"}],"wrap":false},"cell_size":1,"contract_version":"foundation.contract.v1","cubes":[{"center2":[0,0,0],"cube_id":"i0","group_id":"","layer":"INNER","occludes_light":true,"orientation":0,"tags":[]},{"center2":[0,0,-2],"cube_id":"i1","group_id":"","layer":"INNER","occludes_light":true,"orientation":0,"tags":[]},{"center2":[0,0,0],"cube_id":"s0","group_id":"","layer":"SURFACE","occludes_light":true,"orientation":0,"tags":[]},{"center2":[2,0,0],"cube_id":"s1","group_id":"","layer":"SURFACE","occludes_light":true,"orientation":0,"tags":[]}],"face_transitions":[],"faces":[{"cube_id":"i0","face":"BACK","face_id":"i0/BACK","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"i0","face":"BOTTOM","face_id":"i0/BOTTOM","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"i0","face":"FRONT","face_id":"i0/FRONT","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"i0","face":"LEFT","face_id":"i0/LEFT","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"i0","face":"RIGHT","face_id":"i0/RIGHT","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"i0","face":"TOP","face_id":"i0/TOP","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":true},{"cube_id":"i1","face":"BACK","face_id":"i1/BACK","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"i1","face":"BOTTOM","face_id":"i1/BOTTOM","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"i1","face":"FRONT","face_id":"i1/FRONT","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"i1","face":"LEFT","face_id":"i1/LEFT","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"i1","face":"RIGHT","face_id":"i1/RIGHT","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"i1","face":"TOP","face_id":"i1/TOP","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":true},{"cube_id":"s0","face":"BACK","face_id":"s0/BACK","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":true,"walkable":false},{"cube_id":"s0","face":"BOTTOM","face_id":"s0/BOTTOM","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":true,"walkable":false},{"cube_id":"s0","face":"FRONT","face_id":"s0/FRONT","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":true,"walkable":false},{"cube_id":"s0","face":"LEFT","face_id":"s0/LEFT","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":true,"walkable":false},{"cube_id":"s0","face":"RIGHT","face_id":"s0/RIGHT","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":true,"walkable":false},{"cube_id":"s0","face":"TOP","face_id":"s0/TOP","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":true,"walkable":true},{"cube_id":"s1","face":"BACK","face_id":"s1/BACK","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"s1","face":"BOTTOM","face_id":"s1/BOTTOM","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"s1","face":"FRONT","face_id":"s1/FRONT","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"s1","face":"LEFT","face_id":"s1/LEFT","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"s1","face":"RIGHT","face_id":"s1/RIGHT","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":false},{"cube_id":"s1","face":"TOP","face_id":"s1/TOP","mechanism_ids":[],"shift_entry_blocked":false,"shift_exit_blocked":false,"walkable":true}],"flag_definitions":[],"goal":{"face_id":"i1/TOP","required_flags":[]},"groups":[],"level_id":"runtime_fixture","mechanisms":[],"orientation_version":"cube24.v1","rule_version":"foundation.rules.v1","schema_version":1,"shift_compatibilities":["SAME_NORMAL"],"spawn":{"location":{"cube_id":"s0","face":"TOP","layer":"SURFACE"},"orientation":0},"worlds":[{"allowed_rotation_deltas":[22],"allowed_rotation_intents":["TURN_LEFT"],"allowed_states":[0,22],"initial_orientation":0,"layer":"SURFACE","pivot2":[0,0,0]},{"allowed_rotation_deltas":[],"allowed_rotation_intents":[],"allowed_states":[0],"initial_orientation":0,"layer":"INNER","pivot2":[0,0,0]}]}
```
