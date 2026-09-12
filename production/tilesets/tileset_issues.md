# Tileset issue log

- T-001 BLOCKER — initial 64×64 atlas region has only 16 pixels below pivot (32,48), clipping 24px cliffs and supports. Found in geometry/bounds inspection before Godot import. Root cause: storage region shorter than combined up/down height language. Fix: region 64×96, keep pivot (32,48), origin becomes (0,0). Logical 32×16 footprint unchanged. Verify all alpha bounds have transparent outer padding.
- T-002 INFO — project default Linear; keep explicit Nearest on TileMapLayer/test root. No global settings change.
- T-003 MAJOR — first graphical run exposed Godot DIAMOND_DOWN map_to_local(0,0)=(16,8). Gallery/test pose anchor assumed zero, placing comparison characters off center. Fix fixture layers at (-16,-8), and character placement uses layer position + map_to_local. Preserve actual TileSet center semantics and document the Godot offset.
- T-004 MAJOR — first paired demo at 4x clipped rightmost floating platform. Change only paired overview to 3x; separate complete 1x–4x fixtures remain unchanged. Reverify full viewport visibility.
- T-005 MINOR — small vine, wall vine and platform edge plant initially share one silhouette. Give them distinct stem length/branch and base-cluster treatments before delivery; keep overlay pivots and collision semantics identical across skins.
