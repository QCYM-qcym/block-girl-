# Generation and normalization provenance

Built-in imagegen was used, not API/CLI. Original concept reference:
`E:/Study/方块娘项目/若叶睦/photo/Codex 图像 2026年9月11日 20_34_19.png`.

Draft originals are retained in the source production directory under `preview/imagegen_drafts/`; they are **DRAFT_REFERENCE_ONLY**, not GODOT_READY. The generated logical grid was not exactly 16×16 and contained soft color variation. Normalization therefore uses a fixed16×16 grid, explicit 8-color base palette, small pixel corrections for eyes/mouth, shared UV and fixed frame geometry. Final rendered PNGs use a finite shaded palette and binary alpha, verified separately from raw drafts.

## Mutsumi prompt

Create ONE flat square pixel-art material tile for the single FRONT physical face of Wakaba Mutsumi's rolling cube. The attached concept sheet is identity/style reference ONLY. Output ONLY one square, orthographic straight-on face texture, fills image edge to edge, NO cube perspective, NO sheet, NO multiple poses, NO text, NO frame, NO background props, NO neck/body/clothes/limbs. Design it on a strict 16 by 16 logical pixel grid enlarged with perfectly square sharp blocks, no anti-aliasing. Muted sage green hair covering upper 6 rows and framing left/right edges, pale gray-green face occupying center lower portion, restrained tiny two dark calm eyes with muted warm gray-gold iris pixels, very small neutral mouth. Quiet delicate expression not exaggerated cute. Low saturation 8-12 colors only. Side-swept minimal bangs provide recognizable orientation. No equipment, hair clip optional omit for simplicity. Entire square opaque material, no transparent holes, no shadows or lighting gradient: physical shading will be added by engine. Focus on face readability at 16px. This is the material tile, not a final game sprite.

## Mortis prompt

Generate a matched MORTIS skin version of this flat square pixel-art material tile. Use the reference as exact composition guide for the ONE physical FRONT face of the cube, same flat square coverage, hair framing and facial feature position. NO cube perspective, NO body/neck/clothes, NO sheet, NO text. Pale silver-gray hair with cold gray-green shadows, pale nearly neutral gray face, dark blue-gray tiny restrained eyes more emotionally unreadable than reference, very small closed neutral mouth. Add just a subtle restrained violet mask-like accent near one eye, NOT cracks, NOT scars, not horror. Muted palette 8-12 colors, keep light overall (not dark monster), no blood, no giant grin, no neon. Strict 16 by 16 logical pixel grid enlarged with clean square blocks and no anti-aliasing. Entire image is one opaque square texture edge-to-edge, no background. This is a texture source needing subsequent pixel normalization, not a full sprite.

## Reproduction

`tests/gameplay/export_sprite_orientations.gd` exports the existing Godot CubeOrientation states; no second movement/pose logic was created. `tests/gameplay/build_orientation_sprites.py` performs the deterministic cleanup and offline 2D face projection. Stable sprites are generated and validated before `--transitions` is permitted.

Baked projection is x=8(X-Z), y=(32(X+Z)-80Y)/9, preserving the debug observer direction (1,.8,1) with the old formal16×16 rest silhouette. Pixel centers are sampled without antialiasing. Screen bottom is normalized to the unchanged pivot/baseline; no per-frame runtime offset or collider resizing occurs. This is an in-place pixel roll animation; existing movement supplies the grid displacement.

The five unmarked physical faces use the same flat hair material and symmetric borders. Only FACE_FRONT contains character texture. First stable test caught unequal U/V border widths, which created16 appearances instead of13; symmetric borders restored the intended equivalence. The corrected stable atlas passed74 checks before transition production. Complete artifacts passed857 checks, and formal GPU runtime passed1780 checks.
