# Puzzle Prototype 01 — 另一个世界

Scope authorized by the 2026-09-12 user request. Implement directly in this existing non-Git project; no new repository or copied asset tree.

## Design

One independent scene at `res://prototype/puzzle_01.tscn`, made the F5 main scene. A local RefCounted state owns world, logical cell, action phase, latched plate, door readiness and completion. A local player controller handles physical keys and accepted SpriteFrames, and a board assembles accepted TileSets and mechanism scenes. No autoload, event bus, reusable level framework, persistence, undo or extra mechanics.

The same player occupies one cell in Surface or Inner. Moves commit at the end of the supplied 6-frame roll. Switches keep the same coordinate, validate target ground and gate, play the current skin's full world_switch, then replace the skin. Busy input is ignored. Reset immediately cancels the current animation/action and restores all state, including door animation and exit. No coroutine can commit an old action after Reset.

The Inner plate charges on first arrival, visibly presses, then latches active after interaction. It opens the Surface door permanently until Reset. Door passage stays blocked until its existing opening animation finishes. The Surface exit becomes ready then, activates on settled arrival and completes only after its supplied completion animation. Completed state stops movement/switch but permits Reset.

Map is a small isometric island: Surface has a broken approach at (6,7); Inner restores that route and leads to the plate at (2,1). Inner continues to the shared landing (10,6). Surface alone supplies the final northern corridor, door (10,3), and exit (10,1). A short starting overlook and an Inner side spur allow discovery without a large maze. All coordinates zero-based. Designed for a first-time 2–5 minute discovery; scripted speed is not a human completion-time measurement.

## Asset contracts

Read production Sprite manifest/runtime report, TileSet spec/report/issues, mechanism spec/report/issues and all three runtime acceptance reports. All are PASS. Reuse original files without edits. Sprite 24×24, offset (0,-9), native roll 18 fps, switch 12 fps; map 32×16 DIAMOND_DOWN with normalized layer position (-16,-8); use `layer.position + map_to_local(cell)`. Explicit Nearest, integer board scale and rounded motion. Gate traverses local Z only. Ground below player; gate Y-sorted with player. Different roads are different cells/EMPTY, never changed collision semantics on a shared tile ID.

Grid logic is authoritative. Existing mechanism scenes supply their original visuals, animation transitions and public state methods; Area2D monitoring is disabled in these local instances because this prototype commits occupancy at logical arrival rather than continuous physical overlap. Production scripts/scenes remain untouched.

## Controls and feedback

W/Up = NE (local -Z), D/Right = SE (+X), S/Down = SW (+Z), A/Left = NW (-X). Space switches. R resets. One press = one tile; OS key repeat ignored. Small Chinese HUD shows current world, controls, plate/door state and context feedback. H gives a progressive hint. No UI framework. Window uses native canvas coordinates and integer board scaling on resize.

## Validation

First write/run failing state tests, implement state and rerun. Write/run failing scene integration test before adding rendering/controller. Validate legal path, missing ground, closed/opening door, switch rejection, repeat/busy input, all four roll names, same-cell switch, plate persistence, exit eligibility/completion and Reset during every phase. Exhaustively search reachable settled states for solvability without Reset. Run actual graphical Godot 4.7.2 Forward Plus/D3D12 and save GPU screenshots plus structured assertions. Use Windows Computer Use for real keyboard smoke/playthrough and Reset. Compare SHA256 of all existing production and tests/visual files to the pre-work baseline. Report human timing as unmeasured unless a blind playtest occurs.
