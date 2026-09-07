# First rich sprite library — bounded production plan

Status: planned coverage targets. This document is not an inventory of delivered, extracted, or accepted artwork.

The first rich library expands the seven existing actor families and adds six connected environment kits. The baseline is 24 extracted actor frames. The actor target is 400 candidate frames/states, approximately 16.7 times that aggregate baseline, plus at least 96 environment modules. Individual families receive coverage according to their gameplay needs; a single-frame wagon does not need the same animation count as a mounted rider.

“16×” means useful coverage: actions, directions, transitions, functional states, and environment connections. Recoloring, duplicating cells, mirroring existing poses, or exporting the same frame in multiple atlases does not increase the admitted count. Each existing actor must become a coherent kit. More unrelated props cannot compensate for missing ride, walk, lasso, or facing coverage.

## Targets and clip coverage

Requested directions are east, west, north, and south within the high three-quarter presentation. Actual frame facing must be inspected; requests are not verified coverage. The first extraction uses four poses per action row and reuses the first walk pose for idle.

| Family | Goal | Coverage allocation |
|---|---:|---|
| Mounted rider | 64 | Per direction: walk 4, trot 4, lasso 4, shoot 4 |
| Longhorn | 64 | Per direction: walk 4, run 4, graze 4, rest 4 |
| Cream cattle | 64 | Same complete action coverage as longhorn |
| Spotted cattle | 64 | Same complete action coverage as longhorn |
| Eleanor | 64 | Per direction: walk 4, talk 4, medical 4, camp 4 |
| Rustler | 64 | Per direction: walk 4, run 4, shoot 4, react 4 |
| Wagon | 16 | Four directions × rest, loaded, open supply access, repair needed |
| **Actor total** | **400** | **16.7× the 24-frame aggregate baseline** |

The actor sheet must preserve character identity, costume, proportions, lighting, and ground-contact scale across all frames. Lasso and shooting sequences need readable anticipation, action, and recovery within their allocation. The counts are a planning constraint, not permission to invent a smooth cycle from unrelated poses. Timings and action-event frames are finalized after extraction and motion review.

Wagon states must meaningfully change visible content or silhouette. Cattle appearances need genuine pose coverage, not three copies counted only because their colors differ. Each appearance remains a separate runtime family because the room already uses it.

## Connected environment kits

| Kit | Minimum goal | Required coverage |
|---|---:|---|
| Grass | 16 | Four density patches, four path edges, four corners, four sparse/trampled variants |
| Trees | 16 | Four silhouettes, each with whole tree, matching trunk/foreground and canopy layers, plus stump state |
| Rocks | 16 | Four size/silhouette groups, each isolated, paired, clustered, and broken |
| Scrub | 16 | Four silhouettes, each sparse, full, dry, and trampled |
| Fence | 16 | Four directional runs, four corners, two ends, two junctions, two gate directions with open/closed states |
| Camp | 16 | Functional pairs for bedroll, crate, barrel, fire, cooking rig, hitching post, shelter, and trough |
| **Environment minimum** | **96** | **Connected kits that compose into the same room** |

Tree layers must share anchors. Fence ends must connect, and gates must expose a usable opening. Grass boundaries must tile without obvious seams. Camp pairs must represent useful states within one coherent set rather than a random assortment of camping props. Mark whether each module is decorative, blocks movement, allows movement underneath, or provides an interaction.

## Production and admission order

1. Preserve the approved references and create new source records for generated expansions. Keep the original recovered art identifiable.
2. Generate coverage in manageable sheets with legible, separated cells. Check the visible frame content before assuming a requested grid was produced.
3. Extract deterministically into transparent atlases. Record exact crop/mask/trim, output cell, anchor, source scale, and source checksum.
4. Build a measured inventory separate from this plan. Every target family begins planned; rejected, missing, extracted, and admitted are different states.
5. Review every cell at native size and enlarged nearest-neighbor scale. Reject missing limbs, identity changes, overlapping subjects, labels, background haze, and incoherent poses.
6. Play animation strips in Godot. Check ground anchors, facing, action readability, loops, and event timing.
7. Integrate only admitted assets into the existing room, then capture engine movement and desktop/narrow layouts against the approved concept.
8. Keep room and feature scope fixed until visual acceptance. Rich art production does not authorize extra rooms or simulation features.

The first practical priority is directional rider/cattle motion and the room's actual actions. Environment richness follows the same palette, scale, and perspective. Exhaustive counts without a convincing room do not complete the milestone.

## Deliverables and handoff

- Original expansion sheets, source provenance, and checksums.
- Transparent actor atlases and connected environment modules.
- Exact runtime manifest and named animation clips, including unfilled coverage.
- Cell review sheets and actual engine motion/room captures.
- A measured delivery report distinguishing planned, extracted, admitted, and integrated counts.
- The one playable room, with a recorded visual review outcome.
- After the requested work is finished, an urgent method/priorities message to DR Companion and Pirate Island Work.

The reusable method is documented in ../METHOD.md. catalog-plan.json contains these targets in machine-readable form. Neither file asserts that the target counts or visual acceptance have been achieved.

## First extraction status

496 unique cells extracted: 400 actors/props plus 96 scenery variants. See DELIVERY.md for measured results. Connected grass/fence systems, approved gait cycles, and interaction footprints remain unfulfilled admission requirements. Generated decorative variety does not complete these requirements. Tree layers are exact complementary splits; they do not invent hidden trunk pixels and do not count as extra variants.
