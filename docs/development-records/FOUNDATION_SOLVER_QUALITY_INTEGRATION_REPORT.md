# FOUNDATION-3 — Solver & Quality Final Integration

2026-09-16 · `integration/foundation-3-solver-quality` · `E:/godot/worktrees/block-girl-foundation-3-integration`

```text
FOUNDATION_SOLVER_QUALITY_PASS
CONTRACT_MISMATCH: NONE
3A: PASS
3B: PASS
3C: PASS
3D: PASS
DEPENDENCY_PENDING: NONE
```

All ten acceptance gates pass. Final counted executions: **95,034 assertion checks, zero failures**, every final command exits 0. The old graphical regression is a fresh **83/83 PASS**. Earlier setup failures and the intermittent polish exit warning are retained below; neither is erased by the final green results.

## 1. Execution scope and baseline

The main worktree `E:/godot/若叶睦/方块少女-若叶睦` was clean on `feat/foundation-core`, at `69590f91e32c72103f885b32bb29e57eee36a0c3`. Initial status, worktree list, all branches and baseline log were checked. Neither requested integration branch nor worktree existed. A new isolated worktree was created from that exact baseline. Its pre-merge real FOUNDATION-2 headless regression passed 77 checks (`.godot/foundation-2-full/f3_base_headless`); this setup run is excluded from final totals.

Only normal merges were used. No rebase, squash, cherry-pick, copied feature implementation, PR, main/core merge, branch/worktree removal, FOUNDATION-4 or P-02 work occurred. The main worktree remains at the original baseline with zero changed files.

The implementation sequence followed the supplied final-integration requirements: audit history/contracts, merge A/B/C/D, audit ownership, add one four-owner test entry and wrapper, rerun owner and legacy suites, review, document, then commit/push only after every gate passes. There were no merge conflicts of any category.

## 2. Formal sources and pre-merge DAG audit

`git fetch origin` succeeded before resolving refs. Each local feature tip equaled its origin tracking tip. 3C was queried from Git, not inferred from a report.

| Source | Full commit | Official 3A is ancestor? |
| --- | --- | --- |
| 3A StateExplorer/BFS | `f34dd271adabcc4b724eb55b5fff1cb35f532e59` | self, exit 0 |
| 3B Softlock | `f41fa732bb6e1a0f4e0be3c703e5364bc9aab2e2` | yes, exit 0 |
| 3C Intent/Ablation | `70500cbf576e9f21c9238a7728916b41bd45b4e7` | no, exit 1 |
| 3D RuntimeParity | `e6f7083be9cccef05642a7fcdb7c9f3c2f5870b2` | yes, exit 0 |

Merge-base of core and each feature is `69590f91e32c72103f885b32bb29e57eee36a0c3`. Merge-base of A/B and A/D is the official 3A commit; A/C is the core baseline. 3D includes dependency merge `64a324b22ecca004b1f2bd408b276577c14e4b49`, whose parents are core baseline and official 3A. Thus its dependency is formal history. The retained historical stash on another worktree was neither applied nor removed.

## 3. Integration merge commits

| Merge | Full commit |
| --- | --- |
| 3A | `abb597c052a5d14f85c10b40b02734256cd4a807` |
| 3B | `6be02568bef42bf6f321c125ca95b53000451f4d` |
| 3C | `7922cf7e3eef140451ad5b962b0bdf305f615822` |
| 3D | `a2fddcbdf1325c059debf7a683f8417613031367` |

Each merge has the previous integration tip as first parent and the formal feature tip as second parent. Git recognized the shared 3A ancestry; no files were manually reimported. After merging, `git merge-base --is-ancestor <feature-tip> HEAD` exits 0 for all four sources.

Compact actual graph (full decorated audit in `.godot/foundation-3-final/git-graph.txt`):

```text
*   a2fddcb Merge 3D
|\
| * e6f7083 3D
| *   64a324b dependency merge
| |\
* | \   7922cf7 Merge 3C
|\ \ \
| * | | 70500cb 3C
| |/ /
* | |   6be0256 Merge 3B
|\ \ \
| * | | f41fa73 3B
| | |/
| |/|
* | | abb597c Merge 3A
|\| |
| |/
|/|
| * f34dd27 3A
|/
* 69590f9 frozen core baseline
```

## 4. Contract freeze audit

Both `2026-09-16-foundation-solver-quality-contracts.md` and `2026-09-13-foundation-puzzle-rule-kernel-contracts.md` were read before merging. Feature diffs against core did not alter either frozen spec, earlier specs, `foundation/contracts`, or any existing production owner. The integrated tree preserves those files exactly. No contract reconciliation or semantic relaxation was performed.

| Contract | Verified boundary |
| --- | --- |
| SolverStatus | SOLVED=0, PROVEN_UNSOLVABLE=1, BUDGET_EXCEEDED=2, ERROR=3 |
| SearchBudget | Five frozen fields; runtime 0 disables wall clock; depth -1 is unlimited |
| StateGraph / StateKey | `stategraph.v1`; complete full `statekey.v1` String identity |
| SolutionTrace | `solutiontrace.v1`, full initial/expected states, semantic actions, per-step global_kind |
| PuzzleIntent | Independent `puzzleintent.v1` sidecar; LevelDefinition remains 19 fields, PuzzleState six |
| MechanicTag | MOVE, WORLD_SHIFT, SURFACE_ROTATE, INNER_ROTATE, FACE_TRANSITION, LOCAL_GROUP_ROTATE, CELESTIAL_CHANGE, MECHANISM_TRIGGER, values 0..7 |
| Softlock | Reachable minus reverse-reachable from every Goal; incomplete conclusions null |
| ParityStatus | MATCH=0, DIVERGED=1, ERROR=2, INCOMPLETE=3 |
| Existing codes | ValidationCode and ActionRejectionCode unchanged; analysis codes remain 3A-owned |

The request's conceptual action count and bypass fields use the frozen wire names `total_actions` and `bypass_detected`; no aliases or extra schema fields were added.

## 5. Production ownership audit

`git diff <official-owner-commit> HEAD -- <owned-directory>` is empty for every row below. All prior production directories, gameplay/assets, project settings and frozen specs also match core. The only new implementation this integration adds is test orchestration/assertions.

| Owner | Inspection result |
| --- | --- |
| 3A `foundation/solver` | One FIFO in StateExplorer. BFSSolver is a thin call. Owns ActionGenerator, SearchRecords, Graph, Trace, types. All successful next states come from Kernel. |
| 3B `foundation/quality/softlock` | Reads Graph.validate, reverse adjacency and predecessor witnesses. No ActionGenerator, Kernel action evaluation, forward exploration or graph builder. Records/StateKey are used only for Reset recovery classification. |
| 3C `foundation/quality/intent` | Calls formal Solver/Trace. Classifier consumes Connectivity/Effects and completed Kernel records; it checks effect consistency without reproducing gameplay. No BFS, StateExplorer or trace builder. |
| 3D `foundation/parity` | Consumes formal Trace, Session, Presenter, StateKey, Validator and Goal. No Solver, Kernel rule implementation or StateGraph builder. |

No production path imports a tests-only fixture/double. Existing private test seams retain unit negative coverage; all final chain graph/trace sources are public production APIs. Source/ownership and ancestry evidence is recorded in `git-audit.json`.

## 6. Cross-module architecture and new tests

New entry: `tests/foundation/integration/test_solver_quality_integration.gd`; reproducible wrapper: `run_solver_quality_validation.ps1` in the same directory. Existing module tests are reused for focused fault and boundary coverage, rather than creating another rule engine.

```text
AuthoringReader / authored fixture -> Baker -> canonical LevelDefinition
  -> StaticValidator VALID -> Records.initial_state
  -> BFSSolver -> sole StateExplorer -> ActionGenerator -> real Kernel
  -> StateGraph / SolutionTrace
     -> SoftlockAnalyzer (same live FULL_GRAPH)
     -> PuzzleIntent / Ablation -> same Solver + whole-edge filter
     -> SolutionTrace.validate_semantics -> real Kernel replay
     -> RuntimeParity -> Session.request_action -> completion token
        -> one authoritative commit -> IDLE -> full statekey.v1 compare
```

Every new positive Runtime witness originates in BFSSolver. The test also replays surviving ablated witnesses through the original Runtime. It does not call fixture witness builders, inject a Kernel, construct a graph, or bypass public Session completion. Complete graph edge verification re-evaluates recorded candidates without implementing another search.

## 7. Solver and budget verification

The new chain verifies real preflight VALID, canonical hash, input immutability, four static MOVE candidates regardless of legality, and real Kernel results for every expanded non-Goal node. Only APPLIED+changed has an edge; REJECTED and unchanged results have none. Exact rejected/no-op/evaluation metrics are compared against those real calls. Reset is absent from the eight-kind domain, edges and traces.

SOLVED, complete PROVEN_UNSOLVABLE, BUDGET_EXCEEDED and ERROR are all rerun. New real-kernel capacity cases cover states=1, edges=0, depth=0 and action evaluations=1. Each partial graph produces Softlock INCOMPLETE with null states/count. Invalid content identity and real Validator INCOMPLETE stop before graph construction and perform zero action evaluations.

The fresh 3A suite covers all five budgets, including deterministic injected-clock tests for `max_runtime_ms`, preflight and last-return deadlines, capacity exactly full, depth edges back to visited nodes, found-Goal-but-incomplete requests, Kernel ERROR terminating search, and ERROR priority over concurrent timeout. Clock/algorithm doubles here are explicitly unit evidence; they are not the real four-owner integration proof.

## 8. StateGraph and trace verification

Public Graph.validate verifies full state keys, forward/reverse adjacency, first predecessor, BFS depth, Goal/expanded flags, complete and stop_reason. Goals are terminal. Fresh 3A tests preserve distinct direct/TRIGGER parallel semantic edges and reject unchanged self-loops. New edge accounting verifies every successful static candidate against the original full Kernel next_state/global_kind.

Traces retain full initial state/key, ordered actions, expected full state/key per step, global_kind, Goal key and `total_actions`; graph and trace descriptors match. Real semantic replay is required before cross-module Runtime replay. Forged witnesses preserve otherwise consistent keys/Goal but replace the first action with an illegal MOVE; structural validation succeeds while real semantic validation rejects them. Existing 3D also verifies first-divergence localization for a forged intermediate expected state.

## 9. Real softlock cases and complete chain results

All rows use real Baker/Validator, full unfiltered public Solver graphs, 3B analysis and 3C analysis. Every solved row then replays its actual Solver trace through 3D.

| Case | Nodes / edges | Softlocks | Trace actions |
| --- | ---: | ---: | ---: |
| required_shift | 6 / 10 | 0 | 1 |
| required_enter_celestial | 4 / 4 | 0 | 3 |
| multiple_celestial_entries | 4 / 6 | 0 | 2 |
| shift_bypass | 4 / 6 | 0 | 1 |
| optional_mechanism | 4 / 6 | 0 | 1 |
| initial_goal | 1 / 0 | 0 | 0 |
| corridor | 3 / 3 | 0 | 2 |
| sink | 3 / 2 | 1 | 1 |
| cycle | 4 / 4 | 2 | 1 |
| multiple_goals | 4 / 6 | 0 | 1 |
| no_goal | 1 / 0 | 1 | none; PROVEN_UNSOLVABLE |
| canonical runtime route | 5 / 7 | 0 | 3 |
| MOVE+ENTER FaceTransition | 2 / 1 | 0 | 1 |

Sink and cycle nodes remain softlocks despite RECOVERABLE_BY_RESET. No-Goal closure softlocks every reachable state; 3C returns BASELINE_UNSOLVABLE. Multiple Goals seed reverse analysis together. Existing 3B real partial fixture preserves an already-discovered Goal witness and unknown trap; custom-initial graph excluding spawn yields Reset UNKNOWN. Neither adds Reset edges.

## 10. Intent, classification, ablation and milestones

Intent validation and all eight MechanicTags are rerun. Existing real 3C fixtures exercise direct celestial action, TRIGGER wrapper and MOVE+ENTER through the same classifier and whole-edge filter. The new composite additionally locates the intermediate entry face even though its final player face differs; tags are exactly `[MOVE, FACE_TRANSITION, MECHANISM_TRIGGER]`.

Every new ablation case explicitly checks the requested disabled sets are present, then checks an unfiltered SOLVED baseline. Disabling required Shift, celestial change, route Move/Shift/Rotate or composite Move/FaceTransition/Trigger proves no solution under that filter. Required Shift bypass produces a semantically verified MECHANIC_BYPASS. Optional unused celestial mechanism never becomes a hard bypass; the existing 3C suite checks its WARNING advisory scope and forbidden disabled-set semantics.

The real six-evaluation ablation budget fixture obtains a SOLVED baseline but an incomplete ablated search: essential and bypass_detected remain null. No budget cutoff is interpreted as necessity. Surviving filtered witnesses remain legal under the original Kernel and match original Runtime.

Milestones stay SINGLE_TRACE. The composite's required MOVE and GOAL both match index 1; the missing optional celestial milestone is independent and does not advance/block the required cursor. TRACE_MATCH proves existence of that witness only. No all-path or all-shortest claim is made.

## 11. Runtime parity and graphical evidence

The canonical route is MOVE -> ROTATE_SURFACE -> SHIFT_WORLD; actual completion signals are `[local, global, global]`. Composite MOVE+ENTER has global_kind=FACE_TRANSITION but a local token, one action and one commit. Waiting follows `transition_started.is_global`, never MechanicTag or inferred effect labels.

Fresh 3D negative suites cover APPLIED exactly one commit, REJECTED zero commits, ERROR zero partial commits with upstream diagnostics, duplicate/missing commits, timeouts, stale generation/token, Reset cancellation, reentrant/new-session callbacks and non-spawn ERROR/3013. There is no arbitrary runtime state restoration API.

Graphical mode uses the production Presenter and natural Tween.finished completion. No test teleports a visual to claim animation success. StateKey is the authority; visuals are auxiliary. 3D transition/Goal screenshots were inspected: the intermediate ghost advances with commits=0 and stable source state; the final frame reports commits=3 and matched_steps=3. Fixture screenshots are explicitly supplementary; separate real Solver graphical replay and the four-owner graphical run supply actual solver-witness evidence.

## 12. Timer watchpoint

`HISTORICAL_TIMER_BEFORE_FIRST_TWEEN_UPDATE` remains a known watchpoint. An 80 ms SceneTree timer can expire in its creation frame before a Tween's first process/update; progress=0 at that sample need not mean a bad authoritative state or final visual. This integration did not change timers, waits, tolerances, animation duration, old assertions or production to mask that race.

The unmodified fresh FOUNDATION-2 graphical wrapper passed **83/83**, exit 0, Windows/D3D12, empty stderr, at `.godot/foundation-2-full/f3_final_f2_graphical`. The historical signature did not recur in this run. A green run satisfies this acceptance gate; it does not prove the historical sampling race is fixed.

## 13. Regression execution and evidence

Commands were taken from the final owner reports and inspected wrappers. All run from this integration worktree with Godot `4.7.2.stable.steam.ed1daf0bf`. The 3C wrapper omits its historical external `-SolverSourceRoot`: merged 3A already exists locally, and that option correctly refuses to replace a present dependency. Baker uses `-ValidatorSourceRoot E:/godot/worktrees/block-girl-foundation-3-integration` so its isolated test snapshot consumes this integrated tree.

Evidence records command, exit status, elapsed time, stdout/stderr, counts, failures and source hashes. Counts are executed assertions, not unique test cases; setup runs, repeated development runs, captures and unnumbered resource gates are excluded. Final aggregation is `.godot/foundation-3-final/final-matrix.json`. All final positive-stage stderr logs are empty. Baker's five intentional CLI rejections remain expected negative cases inside its exit-0 wrapper.

| Stage | Command | Exit | Checks | Failures | Elapsed (s) |
| --- | --- | ---: | ---: | ---: | ---: |
| 3a | `pwsh -NoProfile -File tests/foundation/solver/run_validation.ps1 -EvidenceName f3_final_3a` | 0 | 162 | 0 | 4.92 |
| 3b | `pwsh -NoProfile -File tests/foundation/quality/softlock/run_validation.ps1 -EvidenceName f3_final_3b` | 0 | 232 | 0 | 3.98 |
| 3c | `pwsh -NoProfile -File tests/foundation/quality/intent/run_validation.ps1 -EvidenceName f3_final_3c` | 0 | 1,052 | 0 | 20.21 |
| f1 | `pwsh -NoProfile -File tests/foundation/run_validation.ps1 -EvidenceName f3_final_f1` | 0 | 81,014 | 0 | 2.87 |
| kernel | `pwsh -NoProfile -File tests/foundation/rules/run_validation.ps1 -EvidenceName f3_final_kernel` | 0 | 645 | 0 | 14.68 |
| kernel_unit | `pwsh -NoProfile -File tests/foundation/rules/run_validation.ps1 -EvidenceName f3_final_kernel_unit -UnitDouble` | 0 | 844 | 0 | 11.02 |
| validator | `pwsh -NoProfile -File tests/foundation/validation/run_validation.ps1 -EvidenceName f3_final_validator` | 0 | 370 | 0 | 1.81 |
| kernel_safety | `pwsh -NoProfile -File tests/foundation/kernel_safety/run_validation.ps1 -EvidenceName f3_final_kernel_safety` | 0 | 161 | 0 | 3.21 |
| baker | `pwsh -NoProfile -File tests/foundation/level/run_validation.ps1 -EvidenceName f3_final_baker -ValidatorSourceRoot E:/godot/worktrees/block-girl-foundation-3-integration` | 0 | 210 | 0 | 9.13 |
| f2_headless | `pwsh -NoProfile -File tests/foundation/full_integration/run_validation.ps1 -EvidenceName f3_final_f2_headless -Headless` | 0 | 77 | 0 | 8.52 |
| 3d | `pwsh -NoProfile -File tests/foundation/parity/run_validation.ps1 -EvidenceName f3_final_3d` | 0 | 352 | 0 | 25.09 |
| runtime | `pwsh -NoProfile -File tests/foundation/runtime/run_validation.ps1 -EvidenceName f3_final_runtime` | 0 | 509 | 0 | 9.63 |
| f2_graphical | `pwsh -NoProfile -File tests/foundation/full_integration/run_validation.ps1 -EvidenceName f3_final_f2_graphical` | 0 | 83 | 0 | 9.26 |
| chain_logical | `pwsh -NoProfile -File tests/foundation/integration/run_solver_quality_validation.ps1 -EvidenceName chain_final_logical -Headless` | 0 | 970 | 0 | 29.76 |
| chain_graphical | `pwsh -NoProfile -File tests/foundation/integration/run_solver_quality_validation.ps1 -EvidenceName chain_final_graphical` | 0 | 970 | 0 | 33.95 |
| p01 | `tests/gameplay/run_p01_validation.ps1 -EvidenceName f3_final_p01_imported -IncludeRegressions` | 0 | 3,992 | 0 | 221.79 |
| cube | `Godot --path . --script res://tests/gameplay/test_cube_visual.gd --max-fps 60 -- --evidence-dir=.godot/foundation-3-final/supplement/cube` | 0 | 632 | 0 | 26.22 |
| sprite | `Godot --path . --script res://tests/gameplay/test_orientation_sprite_runtime.gd --max-fps 60 -- --evidence-dir=.godot/foundation-3-final/supplement/sprite` | 0 | 1,780 | 0 | 39.93 |
| polish | `Godot --path . --script res://tests/gameplay/test_p01_polish.gd --max-fps 60 -- --evidence-dir=.godot/foundation-3-final/supplement_closeout/polish` | 0 | 74 | 0 | 55.73 |
| pixels | `Godot --path . --script res://.godot/foundation-3-final/supplement_closeout/test_pixels.gd --max-fps 60 -- --evidence-dir=.godot/foundation-3-final/supplement_closeout/pixels` | 0 | 48 | 0 | 1.09 |
| sprite_assets | `bundled python tests/gameplay/test_orientation_sprite_assets.py` | 0 | 857 | 0 | 0.34 |
| **Total** | Final executions only | **0** | **95,034** | **0** | — |


`Godot` above denotes `D:/APP/steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`; bundled Python denotes `C:/Users/QCYM/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`. The Pixel copied script differs from the old source only in its evidence directory; original source SHA and reversal equality were checked. Its full command and actual copied-script path are retained in `supplement_closeout/execution.json`.

Stage breakdown: 3A=9+103+50; 3B=115+117; 3C=845+66+50+10+81; 3D=169+77+53+53. FOUNDATION-1=77,965+733+546+1,533+132+105. Runtime=330+63+116. P-01 wrapper=31+167+66+172+54+50+3,452, plus unnumbered input/resource gates and 107 tileset captures. Cube/sprite/assets/polish/pixels add 3,391 legacy checks, for **7,383 existing-system assertions**. Explicit-double suites retain their unit scope; final real-chain evidence does not rely on them.

## 14. Failed-first setup evidence

The first P-01 invocation (`f3_final_p01`) passed 31 state checks, then its graphical child timed out after 120 seconds. The first stderr error was missing `.godot/imported/*.ctex` textures in this fresh worktree; subsequent nil-object failures followed resource-load failure. No P-01 production/test/asset file differed from the baseline. The project had not undergone its initial full resource import.

The existing `--headless --editor --import` setup command completed exit 0, empty stderr. The unchanged P-01 wrapper was then rerun under a new evidence name. Failed logs were preserved, never overwritten. This is a worktree setup correction, not a relaxed test or business-code fix.

The host-default Python also lacked Pillow for the static sprite asset test. The bundled workspace Python, as used in the previous acceptance workflow, ran the unchanged script successfully: 857 checks. No packages or source were changed. The pixel regression's ignored copy changes only its hardcoded output directory, with reversible text equality checked, to avoid overwriting historical captures.

The first supplemental polish run passed all 74 assertions and exited 0, but stderr reported `4 ObjectDB instances were leaked at exit`; the strict local wrapper therefore marked that execution unsuccessful. The prior FOUNDATION-2 report already mentions historical ObjectDB exit warnings. A verbose diagnostic rerun passed 74/74 with empty stderr, so no leaked-object identity or specific root cause was established this time. This is recorded as an intermittent exit watchpoint, not declared fixed or conflated with the distinct timer/Tween watchpoint. The final counted polish run uses the original normal parameters; earlier failed/diagnostic executions remain under `supplement/` and are excluded from totals. No sleeps, assertions or production cleanup were changed.

Normal-parameter final polish: 74/74, exit 0, stderr empty, audio peak 0.0879635811 with three voices. Final pixels: 48/48, exit 0, stderr empty. Evidence is `supplement_closeout/`; no additional retry was needed after that normal run.

## 15. Review, final diff and context

An independent read-only reviewer inspected the new chain/wrapper, frozen contract and ownership boundaries. No critical or important finding. The requested-set assertion was added following its minor suggestion to prevent vacuous ablation loops; both final chain modes are run after that addition.

The initial cross-chain development run was 957/957. After adding 13 explicit requested-set assertions, final logical and graphical runs each passed **970/970**. Only those two final runs contribute 1,940 checks to the total.

This integration owns exactly the new test, its generated UID, wrapper and this report. The 89 inherited feature files remain in their normal merge history. No existing test assertion was removed or changed. `.godot`, logs, generated artifacts and screenshots remain ignored. No unrelated UID regeneration is included.

Final integration-owned diff (four added paths; zero production changes):

- `tests/foundation/integration/test_solver_quality_integration.gd`
- `tests/foundation/integration/test_solver_quality_integration.gd.uid`
- `tests/foundation/integration/run_solver_quality_validation.ps1`
- `docs/development-records/FOUNDATION_SOLVER_QUALITY_INTEGRATION_REPORT.md`

Full staged patch/stat and base-to-final stat are preserved in ignored final evidence. The base-to-final range contains 93 changed paths including inherited features; the closeout commit contains only these four paths.

This project has no `docs/context` directory and does not currently use CURRENT_CONTEXT.md/RESUME.md; none were invented. Required Obsidian method notes are written separately to `E:/obsdian/青澄的水泥房/方块娘/若叶睦/开发日志/2026-09-16-FOUNDATION-3求解器质量总集成.md`, preserving existing notes.

## 16. Deferred scope and limits

Deferred unchanged: A*, SAT/SMT, automatic level generation, Difficulty AI, Monte Carlo, heuristic search, all-shortest counts, strict all-path milestones, Editor heatmap, graph disk swap, non-spawn Runtime restore, parallel search optimization, FOUNDATION-4 and P-02. Complete graphs prove closure only under the frozen fail-safe Kernel; conservative Safety may reject physically plausible motion. Trace/Parity/Milestone evidence concerns the witnesses actually checked, not all possible routes or player experience.

## 17. Git closeout boundary

Only after final gate acceptance, commit the four integration-owned files with `test: validate foundation solver quality integration` and push `origin/integration/foundation-3-solver-quality`. The final commit's own hash cannot be embedded recursively in its contents; the final response and ignored `closeout.json` record the full hash, remote equality and clean status. Keep core/main and every feature worktree/branch intact. Stop here for human review of the later integration-to-core merge.

## 18. Final acceptance gates

| Gate | Result | Current-run evidence |
| --- | --- | --- |
| A: formal ancestry | PASS | Four official tips are ancestors; all local/origin source tips equal; ordinary merge parents retained |
| B: frozen contracts | PASS | Specs and existing contract/code owners unchanged; runtime and analysis schemas audited |
| C: no duplicated rules/search | PASS | Single StateExplorer FIFO; consumer source review; owner trees identical to formal commits |
| D: Solver -> Graph -> Softlock | PASS | Real live graphs for no-softlock, sink, cycle, multiple Goals, no Goal and partial cases |
| E: Solver -> Ablation | PASS | Unfiltered solved baseline, exact disabled sets, real necessary/bypass/optional/incomplete cases |
| F: Trace -> RuntimeParity | PASS | Actual Solver and filtered-witness traces, real semantic replay, logical and natural graphical completion |
| G: incomplete/budget semantics | PASS | Five budget reasons, error priority, null conclusions; no unsolvability from cutoff |
| H: Reset exclusion | PASS | No Reset candidates/edges/trace actions; independent recoverability and stale-token negative tests |
| I: fresh graphical green | PASS | Original 83/83 plus 3D real Presenter and new 970-check graphical chain |
| J: existing regressions | PASS | FOUNDATION-1/2 and full P-01/supplemental matrix all final green, no old source/test modifications |

Known watchpoints: historical timer-before-first-Tween-update; intermittent legacy polish ObjectDB exit warning (final clean, no root-cause/fix claim); fresh worktrees require resource import and sprite asset validation requires the bundled Pillow environment. No remaining dependency pending or contract mismatch.
