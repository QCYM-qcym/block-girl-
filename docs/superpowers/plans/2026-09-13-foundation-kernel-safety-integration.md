# Kernel × Safety Integration Plan

**Goal:** Execute the user's authorized 2B → 2A closeout and isolated real Safety acceptance.

**Architecture:** Production Kernel loads the existing 2B Safety owner. Integration tests exercise real level/state/action records; test doubles remain exclusively in the unit suite. No new Safety algorithm or public ABI.

**Spec:** `../specs/2026-09-13-foundation-puzzle-rule-kernel-contracts.md`, especially §§3, 11, 15, 16. User's supplied 19-stage task is the execution scope.

**Constraints:** Only this integration branch may change. No main/core merge, other second-wave integration, Solver, contract change, branch/worktree deletion, rebase or force push. Commit/push through GitHub Desktop.

## Verified preparation

- [x] 2B closeout: 13 current production hashes match final evidence; 370 checks and 81,014 regression checks pass. GUI commit/push.
- [x] 2A provisional gate: only missing real Safety; fresh 833 unit checks pass. GUI commit/push.
- [x] Shared baseline equals core HEAD b7fd6ae9cfa1961a4ca52bb977d66e87903fcec5; isolated worktree created via GUI; fresh 81,014 baseline checks pass.
- [x] Safety first (fast-forward), Kernel second (two-parent merge); no conflicts.

## Real test adaptation and safety matrix

- [x] Keep the original unit fixtures by default. In real mode, move the unrelated third floor Cube outside the conservative roll envelope. Use three alternating moves on a proven two-support route for busy completion, ending away from the original player location. Preserve the four-forward-roll algebra test in unit mode and assert real UNPROVEN rejection on that obstructed conservative route.
- [x] Add `tests/foundation/kernel_safety/test_kernel_safety.gd` and UID, using production Kernel, Safety, StaticValidator and StateKey. Verify real state SAFE/UNSAFE/ERROR, motion SAFE/UNSAFE/UNPROVEN, concurrent SAFE/UNSAFE/UNPROVEN, World/Group/FaceTransition, diagnostics and atomicity. Static INCOMPLETE is a distinct API status; do not fabricate a state-query UNPROVEN unreachable in the frozen implementation. Existing doubles separately test defensive consumer statuses.
- [x] Add a hidden-process wrapper in that directory. Record production dependency hashes, process exits, explicit success markers, empty stderr, assertion counts and fresh ignored evidence. Fail on script errors even when the process exits zero.
- [x] Run complete Kernel real suites, complete Kernel double suites, 2B suites, dedicated integration and all 81,014 FOUNDATION-1 checks. Audit real imports, public contract equality, duplicate geometry ownership and independent review findings.
- [x] Write the requested report with exact commits, merge order, test totals, semantic distinctions, failed-first evidence, known limitations and final decision. Prepare the prescribed tests/report GUI commit. The final commit hash and push verification are recorded in the task closeout receipt after this document is committed; retain all worktrees.
