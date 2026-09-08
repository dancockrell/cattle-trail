## Current art production decision — 8 September 2026

All game artwork is 2D only: authored sprites, sprite animation, painted backgrounds, tiles, portraits and flat effects. Use the existing shared art folder at `C:/Users/Admin/Documents/Codex/shared-game-environment-library` for reusable 2D kits, with compatible perspective, pixel density, palette, anchors and animation metadata across Cattle Trail/Cattle Drive, DR Companion and Pirate Island. Preserve each game's characters, setting and gameplay identity.

Do not create, purchase, import, restore, archive for later reuse, or bake sprites from 3D models. Earlier model, rig, mesh, material, body-builder and six-month-resumption plans are retired. New generated artwork uses the user-authorized built-in image generator; no external paid generation APIs. Shared reuse does not make unreviewed art automatically approved.

Inspect true transparency, sequential poses, stable ground pivots, equipment handedness, native-size readability and actual motion before admission. Keep game state, navigation, combat rules, accessibility and persistence authoritative; changing artwork never changes legal actions. Existing engine API names and historical validation records may mention 3D without authorizing 3D artwork.

This is production authority, not a claim that every existing runtime or binary has been converted. Legacy-asset deletion is a separate operation: automatic review rejected deletion commands, so deletion remains unverified here. Do not restore those assets or present them as production options.

# Current working walk sheets

- **eleanor-east-v7**: near contact, near support/passing, opposite contact, opposite support/passing. New individual poses distinguish the warm near boot from the darker far boot. Transparent 64×64 cells with [32,61] ground anchors.
- **rider-east-v15**: v11 contact, v11 passing, v15 opposite grounded contact, v13 opposite passing. The final opposite contact has four horse legs after removing an erroneous middle foreleg. Transparent 96×96 cells, 62-pixel body-height target, source crops and anchors recorded.

Both are sheet-production candidates. They were inspected as adjacent drawings; no game was run for this pass. Timing is provisional and the working atlases do not replace the runtime catalog. Each directory records original sources, hashes, crop rectangles and whole-sprite scaling. Character parts were not independently cut, rigged or repainted during assembly.

Older rider-east-v13 is superseded because its opposite grounded contact was missing. Rider-east-v14 is rejected because its new contact contained an extra foreleg. Keep those as production evidence, never as a variation pool. The Windows export excludes this entire working directory.

## Additional sheet production

- rider-northern-turn-v1: four grounded/passing poses at NNW/NNE. The endpoint sheet compares new angles against existing NW/N/NE sprites. Main catalog frames 248–251 are selected for NW↔N and N↔NE. Runtime uses its catalog atlas and [47,93] anchors; this working atlas remains a separate extraction reference.
- eleanor-turn-v1: four whole poses approaching a rear view, 64×64 cells and [32,61] anchors. Requested angles and observed views are recorded separately. Working candidate only.
- rider-east-v16: eight-cell adjacency sheet interleaves four new attempts with v15 endpoints. These do not yet establish all four requested inbetweens. Keep v15 as the preferred working cycle. Individual frame files and original extraction identifiers are packaged.
- rustler-east-v5: four whole-body east cutouts, 64×64 cells and [32,61] anchors. Repeated lead contact and trouser-shading variation remain; preserve as candidate evidence, not a corrected runtime cycle.

Only static sheets were reviewed in this pass. Short rider bridge timings are provisional. Source/backend checks do not imply final animation acceptance.

## Single-pose endpoint follow-up

- rider-east-v17: contact A → one low inbetween → passing A, conditioned on the actual v15 source endpoints. Four whole horse legs remain; the foreleg approaches vertical support. Slight head-length drift remains. One candidate, not a complete gait.
- eleanor-east-v8: contact A → one low inbetween → passing A, with the same bag-free outfit and warm near/darker far boot identity. The new pose is closer to passing than an exact halfway drawing. One candidate, not a replacement walk strip.
- rustler-east-v6: attempted opposite contact conditioned on the v5 contact. Identity and gray trouser panels remain, but the leading-foot overlap repeats. Preserve the source and endpoint comparison as unadmitted evidence.

## Lanterns at the Ford production

- eleanor-lantern-v1: four whole lantern-carry poses E/NE/NW/S, 64×64 cells and [32,61] anchors. Existing outfit and a small brass lantern; grip/light sockets are recorded. NW appears to swap anatomical carrying hand and needs correction. Static poses do not provide lantern-carry walking coverage.
- crossing-spirit-v1: four spectral longhorn states, all with northeast body orientation: wary, agitated, listening and settled. Transparent 72×64 cells, [36,61] anchors. Separate static-state clips; not a walk animation. The palette stays pale turquoise, seafoam and ivory against the warm trail.

These two working kits support the authored adventure under construction. Neither is globally admitted or placed in the current playable room yet.

Lantern animation follow-up: eleanor-lantern-walk-v2 provides four whole east carry poses but repeats contact-like frames and lacks opposite passing, so it remains a working candidate. crossing-spirit-settle-v2 provides two new lower-head poses with exact original endpoints. The selected-preview atlas uses source frames 0→1→3, omitting the second new pose because it lowers beyond the final endpoint and would force an upward correction. Its short nonloop timings are provisional; neither working animation is a runtime replacement yet.

The new eleanor-lantern-opposite-v3 supplies a narrow opposite passing silhouette with warm near-boot crossover; it remains a working whole-character pose. spirit-lantern-prop-v1 supplies four standalone 14-pixel brass lantern states in 32�32 cells, grip [16,8]. The warm-flame whole prop is copied unchanged into assets/lantern/carried_lantern.png and carried on Eleanor's belt during the playable source encounter, preserving existing character pixels while carry cycles are repaired.
