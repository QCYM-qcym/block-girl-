# Perspective Bugfix Round 1 Implementation Plan

**Goal:** Resolve the reported four-view cycle and Inner aligned-link traversal defects with fresh runtime acceptance.

**Architecture:** Retain integer cube orientation, fixed nodes, authored edge, shared keyboard/mouse controller, and discrete 2D presentation. Expand only the view cycle/projection, configure this fixture's link for both worlds, and expose gate diagnostics. No graph/player rewrite.

**Tech Stack:** Existing Godot 4.7.2 / GDScript / PowerShell harnesses. No Git repository; preserve source snapshots and verify bugs separately instead of initializing Git or fabricating commits.

**Spec:** User attachment `C:/Users/QCYM/.codex/attachments/f915ba1c-fe4c-4711-9034-b32905a0f1a8/pasted-text.txt`.

## Root cause evidence (before changes)

Actual graphical test `tests/gameplay/test_perspective_bugfix.gd`, evidence `tests/gameplay/evidence/bugfix1_red/`: 84 checks, exit 1. E/Q and both mouse gestures visit only indices 0 and 1. Controller uses modulo 2, drag uses 1-current, projection only has 0/90 cases, and cube observation angle uses the same two-view assumption.

Inner reproduction repeated 3/3: Reset, Space, D×4, W×2, E, W. At (4,2), world=1/view=1, both endpoint screen coordinates=(962,262), distance=0, enabled=true, equal elevation=0, matching directions=true. allowed_world_states=[0] rejects Inner; active=false, reason=wrong world, edge absent, neighbor excludes (10,2), requested target=(4,2), roll never starts. Same node dictionary is used in both worlds; recalc revisions advance on Shift and snap; there is no stale player neighbor cache. The first disagreement is world-agnostic visual alignment versus the fixture's Surface-only link policy.

## Bug 1 — four views

- [x] Add failing real input cycles and pose-preservation tests in test_perspective_bugfix.gd, and observe failures before implementation.
- [x] Modify perspective_controller.gd: enum NORTH/EAST/SOUTH/WEST, target=posmod(current+step,4), signed step for transitions, explicit integer (x,z)/(z,-x)/(-x,-z)/(-z,x) projections. Q/E and drag release retain request_rotate_left/right paths.
- [x] Modify cube_visual.gd to observe `(current + signed_step * progress) * PI/2`, avoiding a 270-degree wrap transition. Never change CubeOrientation.
- [x] Update fixture framing so all four projected maps fit; update view names in overlay. No texture rotation.
- [x] Run `test_perspective_bugfix.gd -- --case=rotation` graphically; validate both keyboard and mouse four-step cycles, all direction mappings and 1000 model rotations. Save independent green evidence before Bug 2.

## Bug 2 — authored world policy and diagnostics

- [x] Add failing Inner ACTIVE/edge/neighbor/roll/commit tests and record 3/3 data-flow traces.
- [x] In connectivity.gd configure this authored pair with `link.allowed_world_states=[0,1]`. Preserve per-link restrictions; do not bypass validation or force active.
- [x] Expand existing debug_overlay.gd with allowed view/world, actual screen projections, direction/elevation matches, graph edge, player traversal readiness and blocker. Keep F3 toggle and supported window layouts.
- [x] Update feedback in grid_movement.gd/fixture to reflect the actual link reason and EAST connection, not the obsolete Surface-only message.
- [x] Run `--case=inner` graphically: three complete crossings, disconnect, Shift preservation. Add explicit Surface-only/Inner-only/both policy regressions.

## Regression and acceptance

- [x] Retain 66 logic / 54 runtime coverage, adapting only superseded two-view/default-world expectations: left from NORTH is WEST; configure Surface-only explicitly for the old disallowed-world test.
- [x] Add wrap-angle, short/long/vertical drag, four-view rendered bounds, locks and actual view-relative input regressions; run new and old suites through run_validation.ps1.
- [x] Run unchanged Sprite/Tileset/Mechanism and P-01 suites; preserve the legacy tileset sample bytes using the existing wrapper.
- [x] Perform system keyboard/mouse cases A–G against a fresh independent runtime; save observations and screenshots. Independent review permitted by requesting-code-review skill.
- [x] Update design and report with BUGFIX ROUND 1 roots/fixes/results and fresh status; preserve protected original assets/tests. Stop for user playtesting; no next phase.
