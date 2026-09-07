# Rich sprite library — measured delivery

2026-09-08. Current manifest: 936 extracted candidates across 13 families: rider 244; longhorn 124; cream 108; spotted 108; Eleanor 104; rustler 88; wagon 16; grass, trees and rocks 32 each; scrub, fence and camp 16 each. The room selects 322 actor frames and 30 scenery variants in 40 placements. Recent parallel production added 136 sprites. Additional character states remain browser candidates; selected new scenery is visible in the room. The table below preserves the historical 496-cell first pass.

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

No full expanded family is recorded as production-admitted. All 496 cells remain available in the kit viewer. The default gameplay room now selects 130 expanded actor frames, one original wagon frame, and 30 scenery variants in 40 placements through assets/room-art.json. Known cattle graze/rest turns and Eleanor medical/camp attachment changes are excluded from gameplay. This selected integration passed engine checks; final visual acceptance remains open. Keep the room/feature scope fixed while addressing those gaps.
