# Rich sprite library — measured delivery

2026-09-07. First extraction and engine-preview pass complete. Production visual admission and integration of the expanded kits into the gameplay room remain incomplete.

| Family | Unique extracted cells | Candidate coverage |
|---|---:|---|
| Mounted rider | 64 | Walk, trot, lasso, shoot; four requested facings |
| Longhorn | 64 | Walk, run, graze, rest; four requested facings |
| Cream cattle | 64 | Same action allocation, independently generated poses |
| Spotted cattle | 64 | Same action allocation, independently generated poses |
| Eleanor | 64 | Walk, talk, medical, camp; four requested facings |
| Rustler | 64 | Walk, run, shoot, react; corrected west/north sources |
| Wagon | 16 | Direction and functional-state variants |
| Grass | 16 | Tufts, flowers, density and ground-cover variation |
| Trees | 16 | Silhouette, species and maturity variation |
| Rocks | 16 | Boulders, strata, rubble and clusters |
| Scrub | 16 | Cactus, yucca, brush, logs and stumps |
| Fence | 16 | Runs, gates, ends, posts and broken states |
| Camp | 16 | Bedding, shelter, storage, cooking and trail equipment |
| **Total** | **496** | **400 actor/prop cells plus 96 environment cells** |

The original baseline contains 24 extracted actor/prop frames. The expanded actor/prop extraction is 400 / 24 = 16.67 times that aggregate baseline. This measures distinct extracted pixels, not 16.67 times accepted gameplay coverage. No duplicate cells, mirrored copies, idle reuse, tree-layer exports, or rejected generation attempts inflate the count.

## Delivered

Preserved original references and concept video; 13 transparent family atlases; exact manifest regions, bottom-center ground anchors, source crops/trims/checksums, scale and clip definitions; binary alpha and nearest sampling; 16 complementary canopy/trunk layer pairs; per-family review sheets; actual Godot playback captures; a browsable Godot kit viewer; and the existing playable original-art room.

The dense rider pilot and two wrong-facing rustler sheets remain preserved and explicitly excluded. West/north rustler v2 sheets replace those directions in the manifest.

## Verification and outstanding work

Structural validation passed for all 496 unique cells and 13 families. Godot 4.3 loaded every family, checked clip indices, and rendered animation previews. These are implementation checks, not production art approval.

Some north-requested cattle graze/rest poses turn toward the camera. Eleanor's bag attachment/hand varies. Generated pose strips require gait, anatomy, silhouette, scale and event-timing curation. Direction fields retain the generation request and must not be interpreted as verified facing for every action. Some shooting and reaction poses face diagonally.

Grass/fence variants are decorative assets; seamless tiling, measured connectors, collision footprints and gate passability have not been authored. Tree layers use an exact horizontal split of existing pixels; unseen trunk art is absent. Camp variants provide useful props, but do not fulfill every originally planned matched state pair.

No expanded kit family is recorded as production-admitted. The 496 cells are available in the kit viewer; the gameplay room still uses the 24 original extracted frames. Its narrow original facing coverage remains visible. The requested final visual bar and full conversion of the room to curated rich kits are therefore still open. Keep the room/feature scope fixed while addressing those gaps.
