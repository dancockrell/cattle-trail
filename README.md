# Cattle Trail — Clear Fork

A real Godot 4.3 playable room using the original Cattle Trail sprite sheets and the approved concept video's scenery pixels. This is the one-room visual and interaction proof, not the full cattle-drive simulation.

## Play

Launch `build/CattleTrail.exe` on Windows, or import `project.godot` in Godot 4.3 and press F6 on `scenes/room.tscn` (F5 runs the project).

- **WASD / arrow keys:** ride. **Click or tap ground:** ride to that point.
- **E / Space / Talk:** speak with Eleanor near the wagon.
- **L / Lasso:** catch a nearby steer for seven seconds, then lead it east. At close range, the same action can disarm the rustler.
- **F / Shoot:** fire at the rustler within 190 world pixels. Two hits drive him away. Six rounds available; the lasso remains usable when ammunition runs out.
- **R / Reset:** restart the room.

Speak with Eleanor, clear the rustler, and gather all six cattle in the east clearing. Approach cattle from behind to push them, or lasso a stray and lead it. Cattle settle in the east gathering area after the rustler has gone. Clear Fork completes only when all three conditions are satisfied.

## Art authority

`source/PROVENANCE.md` records recovered sources. `assets/sprites.json` is the runtime source of truth for every atlas, original crop, mask polygon, frame rectangle, foot anchor, frame sequence, playback speed, and looping rule. `tools/extract_assets.py` rebuilds all atlases and room textures from the immutable source images. It needs Python, Pillow, and NumPy.

The seven atlases contain 24 extracted frames. The rider and each of three cattle appearances have four source poses; Eleanor has three; the rustler has four; the wagon has one. The human sheet's printed frame counts are not treated as evidence that those frames exist.

No replacement character drawings are used. Actor sprites, scenery, and the wood/paper interface come from the original assets. The rope and brief shot trace are simple runtime line effects, not replacements for actor art or claims of a finished lasso/shoot animation set.

## Reusable method

The expanded library contains 496 extracted candidates across 13 families. Press **K** in the game or use **Open Sprite Kits.cmd** to inspect them in Godot. See `kits/DELIVERY.md` for measured coverage, `kits/manifest.json` for exact metadata, and `kits/overview.png` for the visual inventory. The gameplay room continues to use the original 24-frame baseline while the new kits undergo visual curation.

See `METHOD.md` for the agent-authored conversion method for other games: approved visual reference → preserved sources → reproducible sprite extraction → exact metadata → one playable Godot room → actual visual and interaction verification → acceptance before expansion.

## Validation and present limits

`VALIDATION.md` separates tested behavior, inspected renders, and remaining art limitations. The room has fixed high three-quarter 2D presentation, nearest filtering, binary alpha, pixel snapping, integer world enlargement, and responsive interface placement. Narrow phone windows reduce the complete world with nearest filtering; that preserves hard edges but cannot preserve equal integer pixel sizes.

Only the original northeast mounted direction exists. West is mirrored, and north/south movement retains that pose. All cattle appearances use four extracted poses during movement, but true four-direction coverage is absent. These limitations are intentionally exposed, not filled with invented art. The broad source style is present, but complete directional animation and final scene-art acceptance remain outstanding. Do not expand into the larger journey, economy, towns, or relationship simulation before the room meets the visual bar.

## Reproduce checks

1. `python tools/extract_assets.py`
2. `godot --headless --path . --editor --import --quit`
3. `godot --path . -- --qa` — opens an actual rendered game, tests public actions, and captures desktop/completion/phone screenshots. The test moves the player to interaction setup positions, but leads cattle into the goal using the real lasso-following loop rather than teleporting cattle.
4. `godot --headless --path . --export-release Windows build/CattleTrail.exe`

The Windows export includes runtime assets and scripts, excluding raw video, source sheets, documents, and extraction tools. Keep this source project to edit or rebuild the game.
