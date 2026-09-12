# P-01 issues and resolution

## P01-001 — remote/accessibility input ignored (fixed)

Observed during normal graphical keyboard acceptance: the game started correctly, but Windows Computer Use D/Right produced no movement. A temporary input observer showed D: keycode=68, physical_keycode=4194313 (Tab), unicode=100, pressed=true, echo=false; Right likewise had the logical Right code but physical Tab. The initial controller always preferred any nonzero physical code and discarded both events.

First reproduced in `tests/prototype/test_input.gd`: recognized logical D plus unmapped physical Tab must start and commit one real tile move. It exited 1 before the fix and 0 afterwards. The controller now prefers supported physical controls, otherwise falls back to event.keycode. Existing physical WASD layout support remains. Revalidated in the normal main-scene window through Windows Computer Use: arrow movement, WASD route, rejected switch, plate latch, opened door, 35-move/two-switch win, and R reset all observed. Diagnostic probe scripts were removed; raw diagnostic log is archived with acceptance evidence.

## P01-002 — completion animation evidence cut short (fixed)

Independent review found the first test returned at the exit's completion signal and reset while the player's longer celebration was still running. This was an evidence gap, not an observed gameplay failure. The final runtime test waits for the player animation too and requires all six `puzzle_complete` frames. Supplied assets and animation speeds are untouched.

## Limitations

- 2–5 minutes is a first-time discovery target, not a measured blind-user result. The documented route is 35 moves and two switches and can be executed much faster when known.
- No audio added. Existing subtle interaction/celebration feedback is supplemented by concise Chinese messages.
- One press per tile, no key-repeat movement, Undo, save, level selection or later-level mechanics.
- Godot 4.7.2 Windows/D3D12 is the tested environment. Other renderers, exports and OSes have not been tested.
