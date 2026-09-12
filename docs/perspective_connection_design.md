# Perspective Connection Tech Prototype — BUGFIX ROUND 1 baseline

Current core: **Move · Shift · Rotate · Solve** / 移动 · 切换世界 · 重构视角 · 空间解谜. Characters share Cube Movement, World State, Perspective Reconstruction and Spatial Mechanisms. This technical fixture remains separate from the pre-existing P-01. The user's 2026-09-12 bugfix specification replaces the earlier two-view/Surface-only fixture acceptance.

## Movement Constitution v2

Held WASD/arrows drive consecutive complete 0.32-second grid rolls without OS repeat. Release finishes the current roll then stops. Last pressed direction wins; no diagonals. Cell and integer cube orientation commit together after a full 90-degree roll. Focus loss clears held input. Reset cancels movement, Shift, rotation and drag state. Orientation has exactly 24 proper integer rotations and one physical local +Z face; it never gates puzzle eligibility.

## Perspective Input Constitution v1 — four-view correction

Gameplay state is integer NORTH=0, EAST=1, SOUTH=2, WEST=3. E/right drag advances +1 modulo 4; Q/left drag advances -1 modulo 4. Keyboard and drag both call request_rotate_left/right. A drag gesture requests at most one step, even if very long. Horizontal displacement must be >=60 window pixels and dominate vertical displacement at release; otherwise rebound. Preview uses the drag direction and at most 12% of one step. Snap is 0.4 seconds; rebound is 0.18 seconds.

The signed transition step is separate from the committed index. Cube presentation observes `(current + signed_step * progress) * PI/2`, so WEST→NORTH advances 90 degrees rather than reversing 270 degrees. Gameplay never uses accumulated floating angles. During preview/snap Move, Shift, traversal and additional rotation are locked. Link recalculation occurs after discrete commit. During cube rolling both rotation inputs are rejected.

| View | W / Up | D / Right | S / Down | A / Left |
|---|---|---|---|---|
| NORTH | world N | world E | world S | world W |
| EAST | world E | world S | world W | world N |
| SOUTH | world S | world W | world N | world E |
| WEST | world W | world N | world E | world S |

In the current isometric presentation these screen directions are NE/up-right, SE/down-right, SW/down-left, NW/up-left. Each settled mapping is tested with real Godot input and measured screen displacement. Rotate preserves cell, world and CubeOrientation; Shift preserves cell, Perspective and CubeOrientation.

## Perspective Connection Constitution v1 — Inner correction

Explicit authored A_east at node (4,2), outward East, and B_west at node (10,2), outward West. Both elevations are 0. Entry and exit movement directions are East; reverse movement is West. This fixture explicitly allows worlds [SURFACE,INNER] and perspective [EAST]. World restrictions remain configurable per link: tests cover Surface-only, Inner-only and both.

The same view projection is used for floor placement and anchor validation. A connection needs the authored pair, known nodes, enabled state, allowed view/world, optional anchor world restrictions, matching cardinal directions, equal elevation and endpoint distance <=1 native pixel. At 2×/3× this is 2/3 window pixels. Nodes never disappear when an edge disables. Connectivity.neighbor queries the current active link each time; there is no player neighbor cache. Cached link state stays unchanged mid-rotation, but neighbor queries reject all traversal while rotating.

Debug F3 displays the actual current projected endpoints/distance, allowed world/view, direction/elevation checks, cached link active state, accessible graph edge, and player traversal readiness. During rotation the cached reason is explicitly marked committed while the graph edge is unavailable due to rotation lock. At non-anchor nodes or during a roll the readiness line explains why the player cannot yet traverse.

## Four stable 2D presentations

For world grid (x,z), discrete view transforms are (x,z), (z,-x), (-x,-z), (-z,x); isometric projection is (16(x-z),8(x+z)). Only platform B in EAST has authored presentation translation (-5,0) before projection; other views use zero. The fixture reframes each discrete map to stay inside the game area and interpolates this framing during transitions. Textures themselves keep nearest filtering, integer display scale and zero texture rotation.

A has x=0..4,z=0..4 (25 nodes). B has x=11..12,z=1..3 plus its sole entrance (10,2), 7 nodes. Only the authored one-cell entrance touches A in EAST. In all other views the 5-cell logical gap is visibly open. On the active edge the cube rolls one projected cell and commits its logical node from (4,2) to (10,2) only on landing.

**Boundary:** this is authored piecewise 2D reconstruction, not a single rigid camera claim. A tilted orthographic camera is injective on a same-height plane, so the separated endpoints cannot coincide through camera rotation alone. A future 3D renderer needs a separately validated projection/layout policy; no 3D work is performed here.

## Sprite audit remains unchanged

**CUBE_FACE_VISUAL_AUDIT_FAIL / VISUAL_ASSET_REWORK_REQUIRED.** production/sprites/asset_manifest.md:81 defines landing face reset in all four accepted rolls. Those resources met the old baseline but cannot represent persistent physical face orientation. They remain untouched. A temporary six-face projected debug cube uses one local +Z face marker and proper face culling; skin changes recolor the same oriented cube. Production floor atlases are reused unchanged. Formal sprite rework is a separate future task.

## Run and reproduce

Open `res://tests/gameplay/perspective_connection_tech_test.tscn`, F6. F5 still runs the old P-01. Hold WASD/arrows, Space Shift, Q/E Rotate, left mouse horizontal drag Rotate, R Reset, F3 Debug.

Inner traversal: R, Space, D four cells, W two cells, E. At (4,2), EAST/INNER the overlay must show ACTIVE, Graph Edge PRESENT and Player Can Traverse YES. W crosses to (10,2); Q returns NORTH, link disables and A cannot cross back. E returns EAST; S crosses back. Shift in either direction preserves cell, pose and view.

`tests/gameplay/run_validation.ps1 -EvidenceName <new_name> -IncludeRegressions` runs the 66-check logic suite, new bugfix graphical suite, previous 54-check graphical suite and original P-01/Sprite/Tileset/Mechanism suites. Existing evidence names are protected; the legacy tileset sample is byte-preserved around its auto-saving harness. The old restrictive-world check now explicitly configures Surface-only; the old left-drag assertion expects NORTH→WEST. Other legacy coverage is retained.

Repository: GIT_REPOSITORY_NOT_INITIALIZED; no initialization/push. Change groups and fresh evidence are documented in PERSPECTIVE_CONNECTION_TECH_PROTOTYPE_REPORT.md. Finish this bugfix round, then wait for user playtesting; no next puzzle, GitHub baseline, sprite production or broader framework.