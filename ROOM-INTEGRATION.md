# Rich-kit room integration — 2026-09-07

The default playable Clear Fork room now uses selected rich-kit actors and scenery. Original assets remain preserved; `--original` runs the previous comparison room. The full 496-cell kit browser remains available with K.

## Measured runtime selection

`assets/room-art.json` is the default room's source of truth; `tools/curate_room.py` rebuilds it from the extraction catalog and original wagon metadata. Selection contains 131 distinct actor frames (130 from expanded kits plus one original wagon), 30 distinct scenery variants, and 40 scenery placements. Only named selected clips are constructed by the room. Unused frames in the source atlas are not counted as integrated behavior.

- Rider: four requested facings for walk/idle, lasso and shoot. Short actions retain their pose until playback completes instead of being overwritten by movement every frame.
- Three cattle appearances: walk/idle in four facings. Graze/rest strips with known camera turns are excluded.
- Eleanor: directional walk/idle frames and two standing talk gestures. Bag-changing medical/camp strips are excluded.
- Rustler: directional walk/idle, including corrected north/west source sheets. Reaction strips are excluded.
- Scenery: grass, trees, rocks, scrub and camp variants use actual transparent atlas pixels. Tall props and actors share ground-anchor Y sorting; grass renders below hooves. Tree/rock foot circles provide collision data without visible geometric art. Fence connectivity is still excluded.

## Verification

Godot 4.3 rendered the complete updated room. The integration test passed real target movement, four-direction selection, lasso action retention, action expiry, scenery contact resolution, dialogue, shooting, rustler clearance, cattle following, all-six settlement, cash completion and narrow layout. It caught a boundary collision defect, which was fixed and retested.

`room-desktop.png`, `room-complete.png` and `room-phone.png` are current engine screenshots. `room-playback.mp4` is a 16-second recording of the automated engine integration test: it deliberately moves the player to setup positions between scenarios, then uses actual herding/lasso following. It is not a claim of uninterrupted manual play.

## Visual assessment

The room now visibly contains the richer sprites, the original wagon and sampled interface textures. A new empty-ground derivative made from the approved concept replaces the repeated strip collage; its raw source, exact prompt, checksum and nearest reduction are preserved. It has irregular shoulders and continuous wagon ruts, with no characters baked into it. Trees were repositioned to keep new crowns inside the room; cattle starts were staggered. Nearest sampling and pixel snapping remain enabled.

This is an integrated visual-review build, not final art approval. Generated action cadence, foot contact and cross-facing proportions require further polish; cardinal sprite poses do not reproduce every diagonal in the approved concept. The field remains a single room with the same objective. No wider journey, economy or faction scope was added.
