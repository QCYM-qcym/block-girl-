# TILESET_SPEC — frozen geometry v1

- Base tile: **32×16**. Logical footprint 1×1; local diamond vertices (0,-8),(16,0),(0,8),(-16,0). Projection of local 16×16 horizontal coordinates: screen=(x-z, (x+z)/2-h).
- Elevation increment: **8 native pixels**. Low wall 8, tall wall 24; pillar/arch 32. Raised platform top 8; ordinary exposed side 8; cliff 24. Floating platform top 8, slab depth 3, open air below.
- Atlas region: **64×96**, 8 columns. Pivot within every region: **(32,48)**, representing ground diamond center. Texture image is centered in Godot with texture_origin=(0,0); actual center alignment is verified in runtime. Structural origins never depend on skin or visible bounding box.
- TileSet: isometric, tile_size=(32,16), TILE_LAYOUT_DIAMOND_DOWN. Logical cell (i,j) center maps to (16(i-j),8(i+j)). All variants explicitly rendered with fixed screen upper-left light; never rotate finished PNGs.
- Directions: NE=-Z, SE=+X, SW=+Z, NW=-X. Stairs direction is ascent; edges direction is exposed side. Rotating geometry precedes projection/shading.
- Native pixel density: one output pixel equals one Sprite pixel at 1×. No supersampling, smooth scaling, dithering or alpha gradients. Floor uses pixel-center / half-open coverage to tessellate without outline seams.
- Walkable top materials continue to all tile edges. Structural side ornament stays off traversable silhouettes. Inner uses segmented surfaces, silver inserts and incised fractures; no secretly missing bridge collision. BRIDGE_BROKEN is a distinct non-walkable gap module in both worlds.
- Decorations are six independent overlay tiles in a separate atlas/source; use sparingly. Never bake vegetation into every floor.
- Basic obstruction polygons only on walls, pillar, support and arch piers. Walkable floors have no 2D obstruction polygons; traversal/elevation custom data describes their logical use. These resources do not implement a 3D or height-aware movement system.
- Ground layers z=-2; Y-sorted structural layers and character siblings at z=0, tile y_sort_origin=0; bridge/stair top placement uses explicit test elevation. On-top raised character needs elevated surface stratum (z=1). This is a documented placement contract, not a gameplay controller.
- Parity: identical logical ID across Surface/Inner MUST preserve footprint, elevation, origin, direction, walkable/collision/traversal semantics. A future world-exclusive road uses different logical IDs (EMPTY/GAP versus PATH); never reverse collision semantics behind the same visual ID.
- Project settings, Sprite PNGs and previous Sprite harness are preserved. PNG Lossless; mipmaps off; all test nodes explicitly Nearest, integer scale 1–4; no new reference resolution.

API references: [TileSetAtlasSource](https://docs.godotengine.org/en/stable/classes/class_tilesetatlassource.html), [TileData](https://docs.godotengine.org/en/stable/classes/class_tiledata.html), [TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html). Verify with installed Godot 4.7.2, not legacy import Filter fields.
