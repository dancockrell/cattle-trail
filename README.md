## Current art production decision — 8 September 2026

All game artwork is 2D only: authored sprites, sprite animation, painted backgrounds, tiles, portraits and flat effects. Use the existing shared art folder at `C:/Users/Admin/Documents/Codex/shared-game-environment-library` for reusable 2D kits, with compatible perspective, pixel density, palette, anchors and animation metadata across Cattle Trail/Cattle Drive, DR Companion and Pirate Island. Preserve each game's characters, setting and gameplay identity.

Do not create, purchase, import, restore, archive for later reuse, or bake sprites from 3D models. Earlier model, rig, mesh, material, body-builder and six-month-resumption plans are retired. New generated artwork uses the user-authorized built-in image generator; no external paid generation APIs. Shared reuse does not make unreviewed art automatically approved.

Inspect true transparency, sequential poses, stable ground pivots, equipment handedness, native-size readability and actual motion before admission. Keep game state, navigation, combat rules, accessibility and persistence authoritative; changing artwork never changes legal actions. Existing engine API names and historical validation records may mention 3D without authorizing 3D artwork.

This is production authority, not a claim that every existing runtime or binary has been converted. Legacy-asset deletion is a separate operation: automatic review rejected deletion commands, so deletion remains unverified here. Do not restore those assets or present them as production options.

# Cattle Trail — Clear Fork

A real Godot 4.3 playable room using recovered Cattle Trail art plus rich sprite and terrain derivatives generated from those approved references. This is the one-room visual and interaction proof for an adult harem-romance Weird West RPG. GAME-DESIGN.md defines the current identity: alternate1870s, spirits, steampunk machinery and playable-companion romance adventures. Those larger systems are design contracts, not implemented gameplay.

## Play

Launch `build/CattleTrail.exe` on Windows, or import `project.godot` in Godot 4.3 and press F6 on `scenes/room.tscn` (F5 runs the project).

- **WASD / arrow keys:** ride. **Click or tap ground:** ride to that point.
- **E / Space / Talk:** speak with Eleanor near the wagon.
- **L / Lasso:** catch a nearby steer for eighteen seconds, then lead it east. At close range, the same action can disarm the rustler.
- **F / Shoot:** fire at the rustler within 190 world pixels. Two hits drive him away. Six rounds available; the lasso remains usable when ammunition runs out.
- **R / Reset:** restart the room.
- **Tab / Companion:** after recruiting Eleanor, switch into her cattle-calming adventure; switch back to pause it without losing progress.
- **G / Rest:** share recovery time at the wagon after her adventure. Her Steady Company perk adds 3 player recovery; rest cannot be repeatedly farmed.
- **H / Flirt:** a separate optional courting beat with Eleanor after the adventure. Recruitment and recovery do not require romance.
- **F5 / F9:** save or restore the outfit. Companion milestones also save automatically; opening the game restores that save. Reset starts a fresh room and clears it.

Speak with Eleanor, clear the rustler, and gather all six cattle in the east clearing. Approach cattle from behind to push them, or lasso a stray and lead it. Cattle settle in the east gathering area after the rustler has gone. Clear Fork completes only when all three conditions are satisfied.

Then ride back to Eleanor and Talk to invite her into the outfit. Choose Companion to play her: walk close to three different cattle and Talk to steady them, then return to the wagon and Talk. Trust, optional courting and shared rest are separate steps. Eleanor is 24. Her current activity uses the real room sprites and does not yet implement the larger spirit-lantern encounter described in the design.

## Art authority

`source/PROVENANCE.md` records recovered sources. `assets/sprites.json` defines the original comparison art; `kits/manifest.json` defines expanded extraction; `assets/room-art.json` defines the selected default room. These record original crops, frame rectangles, ground anchors, sequences, speeds and looping. Rebuild the original assets with `tools/extract_assets.py`, expanded atlases with `tools/extract_kits.py`, then the default room selection with `tools/curate_room.py`. Requirements are Python, Pillow, NumPy and SciPy.

The seven atlases contain 24 extracted frames. The rider and each of three cattle appearances have four source poses; Eleanor has three; the rustler has four; the wagon has one. The human sheet's printed frame counts are not treated as evidence that those frames exist.

No geometric actor stand-ins are used. The original wagon and wood/paper interface are recovered art; selected actor and scenery sprites are reference-derived expansions. The ground derivative has preserved source and prompt metadata. Rope and shot traces remain runtime line effects alongside the selected rider action poses.

## Reusable method

The expanded library currently contains 948 extracted candidates across 13 families. Press **K** in the game or use **Open Sprite Kits.cmd** to inspect them in Godot. The default room now uses 330 selected actor frames and 30 scenery variants in 40 placements, including eight-way rider/cattle poses, corrected cardinal facing strips and the first northeast sequence repair. `assets/room-art.json` defines that selection; `ROOM-INTEGRATION.md` records its checks and remaining visual limits. Use `--original` to run the previous 24-frame comparison room.

See `METHOD.md` for the agent-authored conversion method for other games: approved visual reference → preserved sources → reproducible sprite extraction → exact metadata → one playable Godot room → actual visual and interaction verification → acceptance before expansion.

## Validation and present limits

`VALIDATION.md` separates tested behavior, inspected renders, and remaining art limitations. The room has fixed high three-quarter 2D presentation, nearest filtering, binary alpha, pixel snapping, integer world enlargement, and responsive interface placement. Narrow phone windows reduce the complete world with nearest filtering; that preserves hard edges but cannot preserve equal integer pixel sizes.

The default room has eight-way selected rider/cattle movement. The northeast rider uses a compact four-pose walk selected from V8, with playback matched to the slower travel pace. All eight directions now use clean-hand lasso sequences with timed rope flight, neck attachment and recovery. Southwest releases at ordinal 3; the other directions release at ordinal 4. These are engine-reviewed replacements; final visual acceptance remains separate. Known grazing turns and bag-changing poses are excluded. A continuous empty-ground derivative replaces the earlier repeated terrain strips. The user's sequence critique remains an open visual gate. Valid direction labels and more frames do not prove a closed gait. The original comparison mode retains its limited northeast/mirrored poses. Final scene-art acceptance remains outstanding. The latest user instruction authorizes expanding gameplay following GAME-DESIGN.md while walk and turn repairs continue in parallel.

## Reproduce checks

1. `python tools/extract_assets.py`
2. `godot --headless --path . --editor --import --quit`
3. `godot --path . -- --qa` — opens an actual rendered game, tests public actions, and captures desktop/completion/phone screenshots. The test moves the player to interaction setup positions, but leads cattle into the goal using the real lasso-following loop rather than teleporting cattle.
4. `godot --headless --path . --export-release Windows build/CattleTrail.exe`

The Windows export includes runtime assets and scripts, excluding raw video, source sheets, documents, and extraction tools. Keep this source project to edit or rebuild the game.

Source follow-up: trail time now advances during play at one game minute per real second, and shared-rest availability shows its remaining trail minutes. Saves preserve this time. The Windows executable still predates these source changes.

## Lantern crossing in the current source

After completing Eleanor's three-cattle calming activity, return to the wagon as the trail boss and choose Companion [Tab]. Eleanor takes a real brass lantern prop to the pale crossing spirit. Talk beside it to settle it, then Talk again to begin guiding. Talk beside each of three stranded cattle and lead it east past the spirit; reaching the arrival area with that steer earns progress. Return to the wagon and Talk after all three cross. Completion grants 10 trust once and does not choose romance.

Companion pauses the encounter and returns control at the wagon; choosing it there resumes the checkpoint. Loading preserves physical positions and guided cattle IDs; Talk beside the current steer to reacquire following. The source uses the existing dry trail crossing, not a newly painted water ford. Eleanor's lantern hangs from her belt during existing walking clips while full carrying cycles are repaired. This source integration passed isolated controller checks, not a new rendered gameplay run; the Windows binary remains older.

## Master character production

The source now includes three detailed master references and 96 extracted adult character variants (32 rancher, 32 mechanic, 32 spirit-scout appearances). Open `kits/character-families/index.html` for the offline workshop. Exact prompts, transparent atlases, anchors, provenance and deterministic preview character records are included. These static candidates are separate from the room’s existing animation sets. The repeatable method is in `design/character-family-method.md`.

Ada and her actual steam walker sprites are now connected after the lantern crossing: Talk to Ada, retrieve the wagon regulator, vent pressure, install it, then close the valves at stable pressure and test. Successful repair exposes a separate Invite action. This source change passed isolated controller checks; the Windows executable remains older.

Generated-companion source support now includes full resolved identity persistence, separate recruitment/relationship/assignment, and one-time activity rewards. Authored perks respect assignment and stacking caps. Eleanor’s existing rest bonus remains 3; future admitted rancher recruits add 2 seconds each to cattle leading, capped at 4 extra seconds. Candidate art stays in the offline workshop.


## Ada's cart outing in the source

After repairing the walker and inviting Ada, board the cart on the lower trail withTalk[E]. Inspect, then useL/F/G to toggle valvesA/B/C. OpenA/C and closeB; Etests the routing. Drive through the three brasslanterns in order, return to the cartstop, and Talk to finish. Tabpauses; Board resumes the saveddrivingpoint. A separate optionalKiss[H] appears beside the cart aftercompletion.

This source feature uses five selectedrealcart sprites, including an emptyparkedview. It was checked without rendering thegame; the packagedWindows executable still predates these sourcechanges.
