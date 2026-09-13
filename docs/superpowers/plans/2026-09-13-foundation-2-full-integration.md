# FOUNDATION-2 Full Integration Plan

**Goal:** Prove the user's Authoring → Baker → Validator → Kernel/Safety → Runtime → State → Visual chain on `feat/foundation-core`.

**Architecture:** Reuse all eight frozen owners. The technical scene obtains its definition from a two-slot authoring scene through the real Reader/Baker. Keep the original 2C authoring scene for regression; explicit doubles remain only in unit launchers. Preserve frozen delayed atomic transaction boundaries.

**Tech stack:** Godot 4.7.2, GDScript, existing PowerShell validation wrappers, GitHub Desktop.

**Spec:** `../specs/2026-09-13-foundation-puzzle-rule-kernel-contracts.md`, §§3, 11, 16–18; user's 23-section FULL INTEGRATION REVIEW request.

## Constraints

No public contract, main merge, PR, P-01 migration, Solver, Editor expansion or P-02. Retain all branches/worktrees and ignored evidence. All commits, merges and pushes use GitHub Desktop. User explicitly authorizes integration on core.

## Tasks

- [x] Verify five PASS gates and clean core; fresh Baker and Runtime source suites. Commit/push scoped C/D changes. Record real graph from shared b7fd6ae baseline.
- [x] Merge accepted Kernel/Safety (fast-forward), Baker, Runtime in order. No duplicate A/B merges; record actual merge hashes and conflicts.
- [x] Add `tools/foundation/level/runtime_authoring.tscn` with two Surface/Inner Cubes, two Slots, MOVE/World Rotate/Shadow Shift route. Add `tests/foundation/full_integration/test_full_integration.gd` to load original and E2E scenes through `Reader.read_scene` then `Baker.bake`; independently call Validator on the exact baked object. Invalid authoring and budget exhaustion must return no artifact.
- [x] Run the E2E test before production wiring. Its level identity assertion must detect the old hand-authored runtime definition. Change only `prototype/foundation/runtime/runtime_fixture.gd` to compose Reader/Baker and the scene load boundary to report Bake failures without inventing a level. Do not write any rule algorithm.
- [x] Preserve missing-dependency unit coverage by explicitly nulling the test port's dependencies. Prove the merged default Session loads real dependencies. Existing first merged run already failed the obsolete absence assumption.
- [x] In a real graphical scene dispatch D/Q/Space/R input events. Compare complete StateKeys and literal route poses against direct Kernel replay on the exact Baker output. Verify REJECTED/ERROR keep state/authoritative transforms; commit once, independent animation progress, and Reset cancelling stale local/global tokens.
- [x] Run all FOUNDATION suites and complete P-01/Perspective/Cube Orientation/Orientation Sprite/Polish/Pixel regressions with fresh ignored evidence. Record positive assertion totals separately from expected CLI rejection exits and captures.
- [x] Independent review: ownership, double leakage, semantic conflicts, atomicity and meaningful E2E assertions. Resolve actionable findings within frozen contracts.
- [x] Write `docs/development-records/FOUNDATION_2_INTEGRATION_REPORT.md` with graph, provenance, all 19 requested sections and coverage limits. Prepare final GUI commit/push to core after every required test passes. Record resulting HEAD in exported receipt, preserve all worktrees and stop.
