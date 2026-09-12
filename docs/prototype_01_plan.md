# Puzzle Prototype 01 Implementation Plan

Goal: ship the authorized playable loop and real Godot evidence.
Architecture: local state, player presentation/input, board assembly and scene coordinator, as specified in prototype_01_design.md.
Tech stack: installed Godot 4.7.2, GDScript, accepted res://production assets. Execute inline in the user's existing non-Git project.

- [x] State: create `tests/prototype/test_state.gd`, run `--headless --path <project> --script res://tests/prototype/test_state.gd` and observe failure. Create `prototype/puzzle_state.gd` with begin_move/finish_move, begin_switch/finish_switch, activate_plate, mark_door_open, finish_puzzle, reset; map cells and state remain local. Rerun for PASS including exhaustive reachability.
- [x] Runtime: create `tests/prototype/test_runtime.gd`, fail while playable scene is missing. Implement `prototype/player.gd`, `player.tscn`, `board.gd`, `puzzle_01.gd`, `puzzle_01.tscn`. Use accepted resource paths; normalize TileMap centers; drive existing door transition from plate latch, commit world/position only on animation_finished. Run headless import to catch parse errors, then graphical integration with real InputEventKey events and bounded phase waits.
- [x] Startup and user verification: change only run/main_scene in `project.godot`. Add `tests/prototype/run_validation.ps1` with bounded processes, separate state/graphical logs and nonzero failures. Run actual normal scene, use real keys to walk/switch/solve/reset, inspect screenshots and 960×640/1280×800/resized board fit. Preserve failures and fixes in evidence.
- [x] Delivery: compare baseline hashes, inspect final source for state/animation races and unintended dependencies, run full final validation, write `docs/PLAYABLE_PUZZLE_PROTOTYPE_01.md` with file list, solution, repeat commands, results and limitations. Copy user-facing report/screenshots/patch into Codex outputs. No changes under existing tests/visual or production.
