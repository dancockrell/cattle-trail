# Cattle Trail — Clear Fork

A real Godot 4.3 playable room using recovered Cattle Trail art plus rich sprite and terrain derivatives generated from those approved references. This is the one-room visual and interaction proof, not the full cattle-drive simulation.

## Play

Launch `build/CattleTrail.exe` on Windows, or import `project.godot` in Godot 4.3 and press F6 on `scenes/room.tscn` (F5 runs the project).

- **WASD / arrow keys:** ride. **Click or tap ground:** ride to that point.
- **E / Space / Talk:** speak with Eleanor near the wagon.
- **L / Lasso:** catch a nearby steer for seven seconds, then lead it east. At close range, the same action can disarm the rustler.
- **F / Shoot:** fire at the rustler within 190 world pixels. Two hits drive him away. Six rounds available; the lasso remains usable when ammunition runs out.
- **R / Reset:** restart the room.

Speak with Eleanor, clear the rustler, and gather all six cattle in the east clearing. Approach cattle from behind to push them, or lasso a stray and lead it. Cattle settle in the east gathering area after the rustler has gone. Clear Fork completes only when all three conditions are satisfied.

## Art authority

`source/PROVENANCE.md` records recovered sources. `assets/sprites.json` defines the original comparison art; `kits/manifest.json` defines expanded extraction; `assets/room-art.json` defines the selected default room. These record original crops, frame rectangles, ground anchors, sequences, speeds and looping. Rebuild the original assets with `tools/extract_assets.py`, expanded atlases with `tools/extract_kits.py`, then the default room selection with `tools/curate_room.py`. Requirements are Python, Pillow, NumPy and SciPy.

The seven atlases contain 24 extracted frames. The rider and each of three cattle appearances have four source poses; Eleanor has three; the rustler has four; the wagon has one. The human sheet's printed frame counts are not treated as evidence that those frames exist.

No geometric actor stand-ins are used. The original wagon and wood/paper interface are recovered art; selected actor and scenery sprites are reference-derived expansions. The ground derivative has preserved source and prompt metadata. Rope and shot traces remain runtime line effects alongside the selected rider action poses.

## Reusable method

The expanded library contains 496 extracted candidates across 13 families. Press **K** in the game or use **Open Sprite Kits.cmd** to inspect them in Godot. The default room now uses 131 selected actor frames and 30 scenery variants in 40 placements. `assets/room-art.json` defines that selection; `ROOM-INTEGRATION.md` records its checks and remaining visual limits. Use `--original` to run the previous 24-frame comparison room.

See `METHOD.md` for the agent-authored conversion method for other games: approved visual reference → preserved sources → reproducible sprite extraction → exact metadata → one playable Godot room → actual visual and interaction verification → acceptance before expansion.

## Validation and present limits

`VALIDATION.md` separates tested behavior, inspected renders, and remaining art limitations. The room has fixed high three-quarter 2D presentation, nearest filtering, binary alpha, pixel snapping, integer world enlargement, and responsive interface placement. Narrow phone windows reduce the complete world with nearest filtering; that preserves hard edges but cannot preserve equal integer pixel sizes.

The default room now has four-way selected movement and rider action clips from the expanded kit. Known grazing turns and bag-changing poses are excluded. A continuous empty-ground derivative replaces the earlier repeated terrain strips. Animation cadence and cross-facing proportions still need polish. The original comparison mode retains its limited northeast/mirrored poses. Final scene-art acceptance remains outstanding; do not expand into the larger journey, economy, towns or relationship simulation before the room meets the visual bar.

## Reproduce checks

1. `python tools/extract_assets.py`
2. `godot --headless --path . --editor --import --quit`
3. `godot --path . -- --qa` — opens an actual rendered game, tests public actions, and captures desktop/completion/phone screenshots. The test moves the player to interaction setup positions, but leads cattle into the goal using the real lasso-following loop rather than teleporting cattle.
4. `godot --headless --path . --export-release Windows build/CattleTrail.exe`

The Windows export includes runtime assets and scripts, excluding raw video, source sheets, documents, and extraction tools. Keep this source project to edit or rebuild the game.
