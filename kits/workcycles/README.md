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
