# FOUNDATION-3A StateExplorer + BFS Solver

Date: 2026-09-16

FOUNDATION_STATE_EXPLORER_BFS_PASS

CONTRACT_MISMATCH: NONE

## Workspace and scope

- Worktree: `E:/godot/worktrees/block-girl-foundation-solver`
- Branch: `feat/foundation-state-explorer-bfs`
- Baseline and pre-commit HEAD: `69590f91e32c72103f885b32bb29e57eee36a0c3`; implementation started clean, final closeout began with the expected 27 uncommitted files.
- Frozen contract: `foundation.analysis.v1`, consuming the existing execution/data contracts.
- No existing foundation production file, existing test, public Spec, other Owner module, P-01, or project.godot was changed. Final closeout explicitly authorizes commit and push of this branch; merge remains prohibited.

## Files

Seven production scripts, each with its own `.gd.uid`, under `foundation/solver/`:

- `solver_types.gd`: sole SolverStatus, SearchMode, BudgetReason, GraphStopReason and AnalysisCode enums.
- `search_records.gd`: policy/budget defaults, closed-record checks and result helpers.
- `action_generator.gd`: static semantic candidate domain and canonical ordering.
- `state_graph.gd`: stategraph.v1 structural/identity validation.
- `state_explorer.gd`: preflight, the sole FIFO BFS, atomic graph publication and budgets.
- `bfs_solver.gd`: thin call to StateExplorer.
- `solution_trace.gd`: predecessor reconstruction, structural validation, formal Kernel replay.

Five scripts, each with `.gd.uid`, plus one wrapper under `tests/foundation/solver/`:

- `solver_fixtures.gd`, `explorer_double.gd`, `test_action_generator.gd`, `test_state_explorer.gd`, `test_solution_trace.gd`, `run_validation.ps1`.
- This report and the execution checkboxes/record in `docs/superpowers/plans/2026-09-16-foundation-state-explorer-bfs.md`.

## Validation

Godot: `4.7.2.stable.steam.ed1daf0bf`.

| Suite | Assertion checks | Result |
|---|---:|---|
| ActionGenerator | 9 | PASS |
| StateExplorer / BFS / budget / formal integration | 103 | PASS |
| Graph / SolutionTrace / semantic negatives | 50 | PASS |
| Module total, three suites | 162 | PASS |
| Existing FOUNDATION-2 full integration, headless | 77 | PASS |

Final closeout reran all three suites and the existing integration regression on 2026-09-16 at 13:45 local time: 239 checks total, 0 failures. Every process exited 0, with empty stderr and no error/failure log marker. Counts are assertion checks, not an inflated count of independently named test functions. Initial baseline regression also passed 77 checks.

Evidence relative to this worktree:

- `.godot/foundation-3a/closeout_3a_20260916_134544/execution.json`: new closeout invocation, HEAD, source SHA256, stage counts and logs.
- `.godot/foundation-3a/closeout_3a_20260916_134544/real-fixtures.json`: every real fixture's complete policy descriptor, actual budget, metrics, validation result and full returned trace.
- `.godot/foundation-2-full/closeout_regress_3a_20260916_134544/execution.json`: new closeout 77-check regression.
- `.godot/foundation-3a/actions_red`, `explorer_red`, `trace_red`: missing-entry RED stages.
- `.godot/foundation-3a/expanded_red`: timeout outcome counters failed before the fix; `expanded_green` passed afterwards.
- `.godot/foundation-3a/deeper_goal_red`: deeper Goal incorrectly claimed shortest before the fix; `review_green_01` and final acceptance passed afterwards.
- `.godot/foundation-3a/wrapper_rejection_probe`: deliberately failing test caused wrapper exit 1, with no module PASS. Existing evidence folders are never overwritten.

Read-only independent review found the two defects above. Both were reproduced, fixed and re-reviewed; the final focused review found no remaining concrete defect. Reviewer read the evidence and hashes; final tests were run by the main worker.

## Solver status and budget

The four outcomes remain distinct: SOLVED=0, PROVEN_UNSOLVABLE=1, BUDGET_EXCEEDED=2, ERROR=3. Only an exhausted graph with no Goal produces PROVEN_UNSOLVABLE. FIRST_SHORTEST may solve before closure; FULL_GRAPH with a prior Goal still returns BUDGET_EXCEEDED if remaining work cannot fit.

Default SearchBudget: `max_states=10000`, `max_edges=100000`, `max_depth=-1`, `max_runtime_ms=0`, `max_action_evaluations=200000`. The runtime limit is disabled at zero; depth is unbounded only at -1. Validator defaults are 4096 configurations and 100000 checks.

Tests cover all five budget reasons, exact-capacity closure, depth-boundary edges to visited nodes, Goal-at-initial with zero edge capacity, no partial insertion, preflight time, final-report time, late Goal results and ERROR taking priority over timeout. Returned rejection/no-op/filter outcomes are counted even when their call crossed the deadline. Clock and controlled failure injection are confined to private test seams; public solve/explore cannot skip formal validation or select a double.

## StateGraph, ActionGenerator and BFS

StateGraph uses the complete formal `statekey.v1` String as its sole identity. Each node owns a full PuzzleState copy, shortest discovery depth, first predecessor and Goal/expanded flags. Forward and reverse edge indices are retained, including parallel semantic actions. No-op transitions produce no edge. Goal nodes are terminal.

ActionGenerator performs DATA checks and static domain enumeration only. It sorts by the frozen kind/field tuple, preserves TRIGGER wrappers alongside direct USE bindings, and never calls Mapping, Lighting or Safety to prune dynamic actions. Every attempted action is evaluated by the formal Kernel using IDLE context. Reset and explicit ENTER actions are never generated.

StateExplorer owns the only FIFO search. BFSSolver delegates directly. Codec verifies the content hash, StaticValidator must return VALID, and initial DATA/Goal/StateKey checks succeed before a graph is created. Kernel/Goal/StateKey/filter errors stop exploration with original upstream diagnostics preserved. Filters receive copied complete transitions and can remove whole edges only.

Graph validation checks closed schema, all StateKeys, first-predecessor/depth chains, terminal Goal markers, both adjacency maps and completeness/stop consistency. It is not a proof of provenance or omitted-edge absence: complete graphs are trusted only when produced by the live formal Explorer. External graph import is not implemented.

## SolutionTrace and semantic validation

`solutiontrace.v1` preserves initial full state/key, the exact policy descriptor, ordered semantic actions, every expected full state/key, global_kind, final Goal key, action count and shortest flag. A requested deeper Goal is marked `shortest=false` when a shallower Goal exists.

`validate_semantics` first validates structure, then replays each action through the real Kernel with IDLE context. It requires APPLIED.changed=true and exact full-state, StateKey and global_kind agreement, followed by the formal GoalEvaluator. On any failure, transitions is empty; it never exposes a partially verified trace as semantic evidence. Forged actions with valid expected keys, late-step divergence and wrong global_kind are rejected. Zero-step Goal succeeds with empty transitions.

Semantic validation proves the replayed transition sequence; it does not prove filter behavior, shortestness, Runtime parity, or general level quality. No Softlock/Ablation/PuzzleIntent/Runtime Parity implementation was added.

## Real fixture results and scope

All six fixtures were baked with the real Baker and received formal Validator VALID. All used UNFILTERED/version 1/empty disabled_mechanics, BFS, default validation options and the default SearchBudget above. `budget_reason=NONE` for each. Full descriptors and every metric are in `real-fixtures.json`; `shortest_solution_count=null` and its completeness flag is false throughout.

| Fixture | Status | Mode | complete / stop | visited / expanded | edges / duplicates | Goals / max depth | evaluations / rejected | trace actions | elapsed ms |
|---|---|---|---|---|---|---|---|---:|---:|
| two_step_move_shift | SOLVED | FIRST_SHORTEST | false / FIRST_GOAL | 3 / 2 | 3 / 1 | 1 / 2 | 10 / 7 | 2 | 236 |
| zero_step_goal | SOLVED | FIRST_SHORTEST | true / EXHAUSTED | 1 / 1 | 0 / 0 | 1 / 0 | 0 / 0 | 0 | 12 |
| required_flag_unsolvable | PROVEN_UNSOLVABLE | FULL_GRAPH | true / EXHAUSTED | 3 / 3 | 4 / 2 | 0 / 2 | 15 / 11 | null | 297 |
| safety_unproven_closed | PROVEN_UNSOLVABLE | FULL_GRAPH | true / EXHAUSTED | 1 / 1 | 0 / 0 | 0 / 0 | 5 / 5 | null | 92 |
| use_parallel_full | SOLVED | FULL_GRAPH | true / EXHAUSTED | 4 / 4 | 6 / 3 | 2 / 2 | 14 / 8 | 1 | 270 |
| move_enter_atomic | SOLVED | FIRST_SHORTEST | false / FIRST_GOAL | 2 / 1 | 1 / 0 | 1 / 1 | 1 / 0 | 1 | 78 |

The fixed two-action golden is MOVE(U_POS), SHIFT_WORLD, ending at Inner `cell2/TOP`, orientation 12. MOVE+ENTER celestial change remains one action with global_kind=CELESTIAL and slot b. USE wrapper and direct celestial actions produce parallel edges to the same canonical state. No-op and filtered counts are zero in these unfiltered real fixtures; controlled algorithm tests exercise both.

The Safety rejection fixture has one 1601 rejection; Solver does not retry it with alternative geometry. Its closure/unsolvability conclusion is relative to the current fail-safe Kernel, not proof that a relaxed physical model is unsolvable. Tests-only topology covers controlled long/short/equal routes, error/overflow propagation, and deterministic clocks; it is not presented as a second production game-rule implementation.

## Final closeout: duplicate-rule audit

All seven production scripts were reread against the frozen contract. No Shift, Rotation, Lighting, Mapping, Safety or Mechanism implementation is duplicated in `foundation/solver/`. The public Explorer binds its kernel Callable directly to `PuzzleRuleKernel.evaluate_action`; accepted next states are copied from that result only. Trace semantic replay calls the same formal Kernel directly. ActionGenerator reads only declared static action domains; it does not compute runtime permission or state changes. No production test-double fallback, Reset action, secondary BFS, or forbidden `solver_shift/rotate/lighting/mapping` module exists.

SolverResult retains exactly status, graph, solution_trace, metrics, budget_reason, issues and validation. Four status meanings, five budget limits, graph invariants, forged-trace rejection and Reset exclusion are covered by the fresh final runs. CONTRACT_MISMATCH: NONE.

## Git handoff

The commit scope is the 27 listed files: seven production scripts, five test scripts, their twelve UID files, wrapper, this report and the 3A implementation plan. Final closeout changes only report/plan text; validated production/tests remain unchanged. The reviewed full diff (including new files), status and ownership audit are kept in `.godot/foundation-3a/closeout-metadata-20260916_134544/` and excluded from Git, along with all other evidence/logs/cache.

Commit title: `feat: add foundation state explorer and bfs solver`. Commit and normal push target only `origin/feat/foundation-state-explorer-bfs` using GitHub Desktop. No PR, merge, rebase, force push, branch deletion, worktree deletion, or main-worktree edits are authorized or part of closeout. The resulting commit hash and verified push/clean status are supplied in the final handoff message; this committed report records the pre-commit acceptance evidence.

Ready for 3B / 3C / 3D to consume the real 3A interfaces after the user's integration step. This readiness does not claim those modules or FOUNDATION-3 integration have passed.
