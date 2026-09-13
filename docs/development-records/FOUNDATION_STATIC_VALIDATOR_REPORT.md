# FOUNDATION-2B Static Validator Report

FOUNDATION_STATIC_VALIDATOR_PASS

CONTRACT_MISMATCH: NONE

## Workspace and baseline

- Workspace: `E:\godot\worktrees\block-girl-foundation-validator`
- Branch: `feat/foundation-static-validator`
- HEAD before/after: `b7fd6ae9cfa1961a4ca52bb977d66e87903fcec5` (FOUNDATION-2.0 execution contract freeze).
- Integrated FOUNDATION-1 baseline: `f04f009`; no contract synchronization or feature-branch merge was needed.
- Read the architecture design, core contracts v1.1, execution contracts v1 and the dedicated Static Validator plan.
- No public contract, first-wave implementation, P-01, other worktree, Kernel, Baker, Runtime or Solver changes. No commit/push/merge.

## Files

| File | Responsibility |
|---|---|
| `foundation/validation/validation_types.gd` | Frozen ValidationStatus / SafetyStatus only |
| `foundation/validation/safety_queries.gd` | Shared stable-body and conservative motion Safety |
| `foundation/validation/static_validator.gd` | Static profiles, full finite domain, budgets, owner query orchestration |
| `tests/foundation/validation/validation_fixture.gd` | Canonical minimal level and test factories |
| `tests/foundation/validation/test_safety_queries.gd` | State, motion, concurrency, failure and overflow regressions |
| `tests/foundation/validation/test_static_validator.gd` | Static errors, full-domain cases, budget and ordering regressions |
| `tests/foundation/validation/run_validation.ps1` | Hidden-process verification, logs, real dependency hashes and counts |
| Six corresponding `.gd.uid` files | Godot-generated resource identities |
| This report and dedicated implementation plan | Evidence and completed progress |

## Actual verification

Godot: `4.7.2.stable.steam.ed1daf0bf`.

| Suite | Checks | Failures | Exit |
|---|---:|---:|---:|
| Shared Safety | 199 | 0 | 0 |
| Static Validator | 171 | 0 | 0 |
| **FOUNDATION-2B** | **370** | **0** | **0** |
| Orientation regression | 77,965 | 0 | 0 |
| DATA contracts regression | 733 | 0 | 0 |
| StateKey regression | 546 | 0 | 0 |
| Spatial regression | 1,533 | 0 | 0 |
| Celestial / Lighting regression | 132 | 0 | 0 |
| FOUNDATION integration regression | 105 | 0 | 0 |
| **FOUNDATION-1 regression** | **81,014** | **0** | **0** |

Final commands:

```powershell
& ./tests/foundation/validation/run_validation.ps1 -EvidenceName static_validator_final_20260913
& ./tests/foundation/run_validation.ps1 -EvidenceName static_validator_foundation_regression_20260913
```

Evidence (ignored local build output, preserved):

- `.godot/foundation-2b-validation/static_validator_final_20260913/results.json`: baseline HEAD, SHA-256 of all real production dependencies including 2B, per-suite counts/exit codes, `failures=[]`.
- `.godot/foundation-2b-validation/static_validator_final_20260913/*.stdout.log` / `*.stderr.log`: both stderr files empty; no SCRIPT ERROR / ERROR / FAIL markers.
- `.godot/foundation-1-validation/static_validator_foundation_regression_20260913/`: six full regression logs and exit records.
- Earlier `validator_baseline_20260913` first-wave regression passed before implementation.

### RED / GREEN and review evidence

- `.godot/validator_initial_red`: missing Static implementation assertion, exit1.
- `.godot/validator_behavior_red`: 87 assertions against the API skeleton, expected static/profile/budget failures, exit1.
- `.godot/validator_green_attempt2`: initial 130-check GREEN after correcting invalid test construction (StringName unknown key, non-overflowing pivot, and DATA phase expectations).
- `.godot/validator_domain_red`, `validator_review_red`: nonwalkable-world Lighting completeness, duplicate Celestial edges and canonical transition code regressions fail before fixes.
- `.godot/validator_domain_green`: 166-check GREEN after real owner-query fixes.
- `.godot/foundation-2b-validation/edge_order_red`: numeric rotation-edge ordering assertion fails; subsequent Static stage GREEN after numeric comparator.
- `.godot/validator_mixed_sort_red` → `validator_mixed_sort_green`: heterogeneous malformed domain ordering fails then passes with transitive type-aware sorting.
- `.godot/validator_recursive_red`: cyclic invalid metadata caused an engine SCRIPT ERROR despite exit0; the final wrapper rejects such output. Bounded canonical traversal fixes this in the final clean run.
- `.godot/foundation-2b-safety/`: initial state/motion RED evidence, penetration RED176/1 → GREEN193/0, review RED199/5 → GREEN199/0.
- Independent read-only reviews found and verified the Celestial/profile issues, Shift unswept-change loophole, structural-issue loss on overflow, and FaceTransition early-UNPROVEN masking. All were fixed with negative regressions before final verification.

## ValidationCode coverage

No ValidationCode aliases, duplicates or ActionRejectionCode values were added. Static issues are checked to remain below 2000.

| Canonical code(s) | Exercised semantic |
|---|---|
| 1000 INVALID_TYPE | Wrong typed field/options; recursive invalid metadata |
| 1001 UNKNOWN_FIELD | Undeclared exit alias, motion field |
| 1002 MISSING_FIELD | Missing Spawn; invalid options |
| 1003 INVALID_ENUM | Invalid compatibility |
| 1004 INVALID_ID | Invalid identifier |
| 1005 DUPLICATE_ID | Duplicate Cube and Celestial directed edge |
| 1006 INVALID_REFERENCE | Spawn/Goal/Mechanism refs, self-reference mismatch, cross-Cube transition |
| 1007 VERSION_MISMATCH | Unsupported schema |
| 1100 OFF_LATTICE | Odd Cube center |
| 1101 INVALID_ORIENTATION | Invalid orientation/domain |
| 1103 INVALID_FACE | Invalid local Face |
| 1105 ARITHMETIC_OVERFLOW | Player center/body, Shared transforms, pivot and conservative swept bounds |
| 1200 SAME_WORLD_CUBE_OVERLAP | Initial and noninitial Group state overlaps; cross-layer overlap remains legal |
| 1201 SEALED_WALKABLE_FACE | Initial/noninitial internal face; preserved with actual player penetration |
| 1202 INVALID_GROUP | Cross-layer ownership |
| 1203 INVALID_ROTATION_EDGE | Incorrect compose target, spin/path endpoint and pose |
| 1204 PLAYER_UNSAFE | Nonwalkable support; actual body penetration after rotation |
| 1300 INVALID_CELESTIAL_REFERENCE | Undefined Slot |
| 1302 LIGHT_SOURCE_INVALID | Noninitial Slot inside entity; layer with no walkable faces |
| 1401 AMBIGUOUS_SHIFT_MAPPING | Full official candidate resolution and Static propagation boundary |
| 1501 MULTIPLE_GLOBAL_MUTATIONS | Multiple ENTER effects |
| 1502 INVALID_ACTION | World declaration pair, immutable mechanism profile, unsupported bound effect, ENTER chains, malformed geometric effect |
| 1600 VALIDATION_BUDGET_EXCEEDED | Configuration/query caps; INVALID priority retains incomplete diagnostic |
| 1601 VALIDATION_INCOMPLETE | Endpoint-valid but conservative sweep cannot prove separation |

There are 24 distinct exercised codes in the Static suite. Automatically derived frame/anchor errors (1102/1104) remain owned by the real Spatial boundary and are propagated unchanged if returned; LevelDefinition has no author-supplied frame/anchor fields. The full Spatial regression is included above. No Shift permission codes, busy rejection codes or new 2000-range action codes are generated by this validator.

**Ambiguity scope:** production always calls `collect_mapping_candidates` then `resolve_mapping`; NONE is normal, UNIQUE is inspected for the first-version ENTER-target profile, AMBIGUOUS/ERROR preserve all original issues. No light/blocked filtering is applied. Two coincident walkable targets on valid first-version lattice Cubes already violate Cube overlap or internal-face sealing. Therefore the independent ambiguity regression supplies a clearly labeled complete synthetic candidate collection to the real Mapping resolver, then exercises Static's propagation boundary. It does not fabricate a valid ambiguous level or install a production Mapping double.

## Stable Safety interface

```text
Safety.validate_state(level: Dictionary, state: Dictionary) -> Dictionary
Safety.validate_motion(level: Dictionary, before: Dictionary, after: Dictionary, action: Dictionary) -> Dictionary
Safety.validate_concurrent_motion(level: Dictionary, before: Dictionary, after_local: Dictionary,
    after_global: Dictionary, local_action: Dictionary, global_action: Dictionary) -> Dictionary

SafetyResult = {status, issues}
SafetyStatus = SAFE(0), UNSAFE(1), UNPROVEN(2), ERROR(3)
```

- Stable center2 = derived FaceAnchor.position2 + normal; body is center2 ±1. Integer open-interior intersection rejects same-layer penetration; supporting contact is legal; the other layer is ignored.
- DATA → checked Spatial snapshot → structural and player diagnoses. A failed/overflow snapshot never proceeds to body or overlap queries. Valid geometric snapshots can report both sealed faces and PLAYER_UNSAFE.
- Body/pivot/transport/enclosure arithmetic uses int64 scalar intermediates and checks int32 logical bounds. No float epsilon, wrap, clamp, approximate collision, or animation sampling. Original structural issues survive a later overflow.
- World/Group rotations use formal Math and resolved carriers. Internal rigid members keep relative separation; all relevant stationary entities and non-carried player are checked.
- Roll uses the actual support edge and only exempts the two proven coplanar equal-height support Cubes. Other bodies participate in conservative clearance checks.
- FaceTransition validates the entire declared path and endpoint before clearance: outward to radius4, quarter-turn about resolved Cube center, then inward. Unrelated entities are never exempt. Intermediate nonwalkable sides are supported by the explicit transport profile.
- Concurrent carried roll encloses the complete local sweep then the global sweep; outside-Group roll stays in Shared Space; other-world/Celestial motion reduces to ordinary roll. The specified `(4,4,4)` obstruction cannot pass because both serial paths happen to be safe.
- Geometrically inconsistent Shift endpoints cannot conceal World/Group rotation. This checks only physical consistency, never Mapping, Shadow or ShiftPermission.
- Static declared Group edges use a syntactically valid probe provenance ID. Safety checks geometric references but deliberately does not require a triggering mechanism's existence/permission. No test adapter is installed in production.
- Queries own returned collections and never modify caller LevelDefinition or states. Kernel can consume these interfaces without importing the full validator.

## Full domain, ordering and budgets

```text
StaticValidator.validate(level, {max_configurations: positive int, max_checks: positive int})
  -> {status, issues, configurations_checked, checks_performed}
ValidationStatus = VALID(0), INVALID(1), INCOMPLETE(2)
```

A mixed-radix cursor visits World states × all Group states × all Slots without materializing or multiplying the product. A `24^20` Group-domain regression finishes within a one-configuration budget. This is static enumeration, not reachability search.

Shape/profile checks and real Celestial definition validation precede configuration queries. Spawn's declared pose/location is checked in the initial state; other probes use each walkable Face and canonical pose0. Goal support is checked for every valid geometric configuration, including a nonwalkable Goal. Real Spatial validates all Cubes/Faces; Lighting is queried for every Face, including nonwalkable layers; Mapping is queried for walkable sources; all declared World/Group edges and valid FaceTransition paths receive shared Safety checks. Invalid geometry is reported before attempting Mapping.

Worlds sort by layer; entities/Slots by ID; state/delta/intent sets numerically; edges by numeric from/delta/to or Slot from/to; ID sets by ID. Semantic `slot_order` and `rotation_steps` preserve order. Sorting uses copies, preserves duplicates for diagnosis, and gives DATA stable indexed paths. Malformed heterogeneous arrays use a transitive ordering. All issue lists follow path/code/entity ordering; deterministic generation breaks equal-key ties. Per-configuration context is appended in a new `details.static_configuration` field without replacing upstream fields/details.

Every top-level semantic query and attempted configuration consumes its budget before running. No wall-clock time determines logical status. Only completed, error-free validation returns VALID. Budget/uncertain sweep yields INCOMPLETE; any proven error wins as INVALID while retaining incomplete diagnostics. This PASS is module verification, not proof that a level is solvable, and INCOMPLETE cannot be treated as Bake approval.

## Git diff / ownership audit

Expected pending changes: 14 new owned files (six GDScript files, their six UIDs, wrapper and report), plus only the dedicated plan progress update. New files remain untracked; no staging or commit was performed. Plain `git diff` therefore shows the tracked plan; `git status --short --untracked-files=all` enumerates implementation files. Full unstaged/untracked review and whitespace evidence are saved under `.godot/foundation-2b-validation/` after final scope verification.
