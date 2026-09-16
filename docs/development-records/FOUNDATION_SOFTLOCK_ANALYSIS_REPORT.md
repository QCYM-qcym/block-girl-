# FOUNDATION-3B — Real 3A Integration and Final Acceptance

FOUNDATION_SOFTLOCK_ANALYSIS_PASS

CONTRACT_MISMATCH: NONE

DEPENDENCY_STATUS: REAL_3A_INTEGRATED

## Baseline and ownership

- Worktree: `E:\godot\worktrees\block-girl-foundation-softlock`.
- Branch: `feat/foundation-softlock-analysis`.
- Original FOUNDATION-3 baseline: `69590f91e32c72103f885b32bb29e57eee36a0c3`.
- Formal 3A dependency: `f34dd271adabcc4b724eb55b5fff1cb35f532e59`, from `feat/foundation-state-explorer-bfs`.
- Integrated the exact authorized commit with `git merge --ff-only`; no conflicts, rebase, squash or manual copying. The baseline remains an ancestor.
- Read the frozen solver/quality Spec, dedicated 3B plan and formal StateGraph, StateExplorer, BFSSolver, SolverResult/SearchBudget and SolutionTrace APIs before integration.
- No edits to 3A, public contracts/Specs, other Owner production/tests, P-01, P-02 or project configuration. No merge into foundation-core/main or PR.
- Existing 3B production files are byte-identical to the pre-expansion `real3a_initial` evidence hashes. This phase adds integration evidence without rewriting reverse analysis.

## Owned files

| Files | Responsibility |
|---|---|
| `foundation/quality/softlock/softlock_types.gd` | SoftlockStatus, ResetClassification and private result factory |
| `foundation/quality/softlock/softlock_analyzer.gd` | Public analyzer, owner validation boundary, reverse traversal, GraphPath witnesses, Reset and metrics |
| `tests/foundation/quality/softlock/softlock_fixtures.gd` | Explicit literal unit graphs and authored real integration levels |
| `tests/foundation/quality/softlock/graph_contract_double.gd` | Unit-only configured validation response; no graph validator algorithm |
| `tests/foundation/quality/softlock/test_softlock_analyzer.gd` | Algorithm, budgets, error propagation, ordering, mutation and deadline tests |
| `tests/foundation/quality/softlock/test_softlock_integration.gd` | Live real Baker/Validator → Explorer/BFSSolver → Graph → public Analyzer |
| `tests/foundation/quality/softlock/run_validation.ps1` | Hidden-process verification and provenance, plus eight-case JSON evidence gate |
| Corresponding six `.gd.uid` files | Resource identities |
| This report and the dedicated 3B plan | Evidence and completion state |

## Fresh verification

Godot `4.7.2.stable.steam.ed1daf0bf`; all suites below actually ran in this worktree after the real integration changes.

| Suite | Checks | Failures | Exit |
|---|---:|---:|---:|
| 3B unit | 115 | 0 | 0 |
| 3B real 3A integration | 117 | 0 | 0 |
| **3B total** | **232** | **0** | **0** |
| Formal 3A: ActionGenerator / StateExplorer / SolutionTrace | 9 + 103 + 50 = 162 | 0 | 0 |
| FOUNDATION-2 full integration, headless | 77 | 0 | 0 |
| FOUNDATION-1: Orientation / Contracts / StateKey / Spatial / Celestial / Integration | 77,965 + 733 + 546 + 1,533 + 132 + 105 = 81,014 | 0 | 0 |
| **Total freshly executed** | **81,485** | **0** | **0** |

```powershell
& ./tests/foundation/quality/softlock/run_validation.ps1 -EvidenceName real3a_acceptance
& ./tests/foundation/solver/run_validation.ps1 -EvidenceName real3b_acceptance
& ./tests/foundation/full_integration/run_validation.ps1 -Headless -EvidenceName real3b_acceptance
& ./tests/foundation/run_validation.ps1 -EvidenceName real3b_acceptance
```

Evidence is preserved under `.godot/foundation-3b/real3a_acceptance/`, `.godot/foundation-3a/real3b_acceptance/`, `.godot/foundation-2-full/real3b_acceptance/` and `.godot/foundation-1-validation/real3b_acceptance/`. Stage logs have empty stderr and no engine/script/failure markers. The 3B `results.json` records dependency hashes, dependency status, branch/HEAD, budgets, exits and counts. `real-graphs.json` records each real case's level hash, policy, SearchBudget, completion/stop reason, node/edge/Goal counts, full analysis and retained trace length. Evidence is generated locally and ignored by Git.

Historical 121 provisional checks were 116 unit + 5 Baker/dependency checks. The old absence-only unit assertion now skips because real 3A exists, giving 115 unit checks; the former 5-check gate is replaced by 117 real integration checks. The unit stage retains its provisional token to describe fixture-only proof scope; the combined wrapper emits final PASS only after real integration evidence passes.

## Real graph evidence

Every positive Graph below is produced in-process by official `Explorer.explore`; corridor additionally uses the official `BFSSolver.solve` facade. All levels pass real Baker and Static Validator. The public analyzer loads official `StateGraph.validate` and official AnalysisCode, without test substitution.

| Case | Nodes / edges / Goals | Analysis | Softlocks | Reset classification / count |
|---|---|---|---:|---|
| initial_goal | 1 / 0 / 1 | COMPLETE | 0 | RECOVERABLE_BY_RESET / 0 |
| corridor | 3 / 3 / 1 | COMPLETE | 0 | RECOVERABLE_BY_RESET / 0 |
| sink | 3 / 2 / 1 | COMPLETE | 1 | RECOVERABLE_BY_RESET / 1 |
| cycle | 4 / 4 / 1 | COMPLETE | 2 | RECOVERABLE_BY_RESET / 2 |
| multiple_goals | 4 / 6 / 2 | COMPLETE | 0 | RECOVERABLE_BY_RESET / 0 |
| no_goal | 1 / 0 / 0 | COMPLETE | 1 | NOT_RECOVERABLE_BY_RESET / 0 |
| partial | 3 / 2 / 1 | INCOMPLETE | null | UNKNOWN / null |
| custom_initial | 2 / 2 / 0 | COMPLETE | 2 | UNKNOWN / null |

- Corridor is a genuine two-action solution: Surface `floor/TOP` → MOVE → Surface `step/TOP` → SHIFT → Inner `exit/TOP`; the trace is replayed by formal SolutionTrace semantic validation through real Kernel.
- Sink branches from initial to Goal or one-way Shift into `inner_floor/TOP`, which has no outgoing edge. Its witness is the original single Shift edge.
- Cycle branches from initial to Goal or Inner `inner_floor/TOP` ↔ `inner_next/TOP`. The two trapped states have orientations 0 and 12. Both have exactly one outgoing edge to the other trapped state, so the cycle is closed. Both stay softlocks despite Reset recovery.
- Multiple Goals are different complete StateKeys on the same Goal face, with celestial slots `a` and `b`. A declared real mechanism enables both; all four states can reach a Goal. Reverse analysis must seed both terminal Goal states.
- Partial uses the cycle level and formal `SearchBudget.max_states=3`. Explorer returns BUDGET_EXCEEDED / MAX_STATES, `complete=false`, stop_reason=BUDGET. Three discovered states, two proven Goal-reaching states, one unknown `inner_floor` state and the found Goal SolutionTrace remain available. Softlock states/count remain null, not zero.
- Custom initial is taken from the actual cycle graph's Inner state and fed back to the real Explorer. The closed two-state graph lacks canonical spawn; Reset is UNKNOWN even though the level's separate spawn run proves solvable.
- A separate real FIRST_SHORTEST initial-Goal run verifies official EXHAUSTED complete closure and zero softlocks.
- Every real case checks immutable level/graph input, repeated deterministic logical output, sorted key sets, exact unique-record metrics and absence of Reset in generated actions and edges. Goal traces replay formally; softlock GraphPaths follow original predecessor edges.
- Negative-only copies corrupt reverse adjacency, node key or predecessor. Official Graph validation rejects them; the public analyzer preserves exact owner issues and returns ERROR. These copies are never used as positive completeness evidence.

## Semantics, budgets and Reset

Public API: `analyze(level: Dictionary, graph: Dictionary, budget: Dictionary) -> Dictionary`.

For a validated complete UNFILTERED graph:

```text
Softlock = ReachableFromInitial - CanReachAnyGoal
```

ReachableFromInitial is the owner-provided node set. Reverse traversal starts from every Goal and follows only supplied reverse adjacency. Complete no-Goal graphs classify every reachable state as softlock. The primary analysis never uses Reset.

AnalysisBudget remains the frozen `{max_nodes, max_edges, max_runtime_ms}` record, normally 10000/100000/0. Real search defaults are max_states10000, max_edges100000, max_depth-1, max_runtime_ms0, max_action_evaluations200000; policy is BFS / FULL_GRAPH / UNFILTERED with validation limits4096/100000. Only partial search lowers max_states to3.

Insufficient record capacity returns INCOMPLETE before owner validation, with zero checked counts and no unvalidated positive proof. Unit controlled-clock tests cover post-validation, during-reverse and final-report deadline exhaustion. Once validation succeeds, discovered evidence remains; proven Goal reachability is retained and remaining known states are UNKNOWN. Missing required complete metadata is malformed input ERROR; valid unknown exploration completeness is represented by complete=false. Invalid/filtered/error graphs cannot support a complete conclusion. Owner validation errors retain priority over simultaneous timeout.

Reset classification uses canonical `Records.initial_state(level)` and formal StateKey. Complete graph with spawn proven Goal-reachable gives RECOVERABLE_BY_RESET; spawn present and unable to reach Goal gives NOT_RECOVERABLE_BY_RESET; spawn absent or graph/reverse incomplete gives UNKNOWN. Reset never deletes a softlock, never enters ActionGenerator, and never adds an edge. A zero-softlock custom-initial graph may still have UNKNOWN Reset, covered by unit tests.

Metrics remain `{nodes_checked, edges_checked, elapsed_ms}`. Unique accepted graph records are counted once, not once per reverse visit. Logical result arrays sort full StateKey strings; witnesses sort by target key and preserve original edge indices. Wall-clock elapsed_ms is observational and excluded only from repeatability comparisons.

## TDD / review history

The prior algorithm phase retained RED→GREEN evidence: initial skeleton, initial-Goal admission boundary and final-report timeout regression. Unit graph doubles remain explicitly test-only, never a production fallback.

This integration phase changed tests and authored level inputs, not the algorithm. `real3a_expanded_01` exposed a fixture assuming three Surface supports permit a roll; the existing conservative Safety sweep prevents the intended path. The fixture was changed to the formal MOVE→SHIFT profile. The failure-path test also now guards a null trace. `real3a_expanded_02` exposed a test expectation sorting StringName values; cube/slot labels now convert to String before lexical sorting. Both issues are resolved by the fresh acceptance run.

Independent review also identified a unit fixture's impossible complete/FIRST_GOAL combination. It now uses EXHAUSTED, matching the formal owner, and a real FIRST_SHORTEST initial-Goal integration assertion covers that boundary. The coarse production consumer still delegates deep consistency to the owner. No algorithm rewrite or public-contract adjustment was needed.

## Duplicate BFS and ownership audit

3B production imports only its own result types, DATA, Records, StateKey and the real Graph/type owner. It has no StateExplorer/BFSSolver implementation, queue-based forward expansion, ActionGenerator invocation, Kernel graph construction or alternative Graph validator. The single `BFS` literal validates the frozen PolicyDescriptor.strategy; it is not a search implementation. The only traversal is a reverse stack plus stored predecessor-path reconstruction.

`git diff f34dd271 -- foundation/solver tests/foundation/solver docs/superpowers/specs` is empty. Production 3B hashes match the initial real-dependency run. Staged ownership and whitespace checks must pass before the authorized commit `feat: add foundation softlock analysis`, followed by push only to `origin/feat/foundation-softlock-analysis`. The resulting commit and verified remote/worktree state are reported in the final handoff; the report does not claim a commit before it exists.
