## Current art production decision — 8 September 2026

All game artwork is 2D only: authored sprites, sprite animation, painted backgrounds, tiles, portraits and flat effects. Use the existing shared art folder at `C:/Users/Admin/Documents/Codex/shared-game-environment-library` for reusable 2D kits, with compatible perspective, pixel density, palette, anchors and animation metadata across Cattle Trail/Cattle Drive, DR Companion and Pirate Island. Preserve each game's characters, setting and gameplay identity.

Do not create, purchase, import, restore, archive for later reuse, or bake sprites from 3D models. Earlier model, rig, mesh, material, body-builder and six-month-resumption plans are retired. New generated artwork uses the user-authorized built-in image generator; no external paid generation APIs. Shared reuse does not make unreviewed art automatically approved.

Inspect true transparency, sequential poses, stable ground pivots, equipment handedness, native-size readability and actual motion before admission. Keep game state, navigation, combat rules, accessibility and persistence authoritative; changing artwork never changes legal actions. Existing engine API names and historical validation records may mention 3D without authorizing 3D artwork.

This is production authority, not a claim that every existing runtime or binary has been converted. Legacy-asset deletion is a separate operation: automatic review rejected deletion commands, so deletion remains unverified here. Do not restore those assets or present them as production options.

# The Cattle Trail method: approved art to a playable room

This method builds a game around a proven visual target, recovered production art, and complete interaction loops. The initial one-room scope has been superseded by the user's authorization to build out gameplay, relationships and backend systems while improving character sheets. Continue that production in parallel, using Clear Fork as the reference room. Asset admission and final visual acceptance remain explicit; broader development is not a claim that the room or its animation has passed those gates.

The reusable part is the production discipline: preserve the approved sources, extract usable assets reproducibly, describe their animation contract explicitly, render them crisply in a fixed-view world, and prove play through that world. Other games keep their own setting, characters, mechanics, and identity. Converting a game to this method does not mean turning it into a Western or adopting cattle herding.

## 1. Lock the visual contract

Choose a small, explicit set of approved references: a style image, actor sheets, environment reference, and a short concept clip where available. Treat these as the visual authority. Write down the camera angle, scale of characters against scenery, palette, pixel density, edge treatment, environment density, animation cadence, and interface character.

For Cattle Trail, the current target is detailed hard-pixel character art, a fixed high three-quarter top-down view, warm Texas trail colors, readable mounted characters and cattle, textured scenery, and a Western interface. Preserve native whole-figure sources and build new masters around 160 pixels of figure height in 256-pixel cells, with each actual pivot recorded. The rejected 40-pixel master target is historical, not the new production standard. Four source pixels per logical world unit retain a 40-world-unit character footprint while preserving the detailed source texture. Follow [the character visual contract](design/CHARACTER-VISUAL-CONTRACT.md) for scale and period wardrobe authority. Soft filtering, inconsistent proportions or camera drift remain defects regardless of detail.

The approved 15-second clip establishes appearance and motion intent. Generated video is not evidence of working controls, consistent animation frames, collision, or playable rules. Those must be demonstrated in Godot.

## 2. Recover and preserve the actual art

Locate the original conversation assets or the creation that used them. Preserve the downloaded originals in `source/`, with their origin, dimensions, role, and cryptographic checksums. Keep style guides even when no runtime pixels are extracted from them. A guide helps judge consistency; it is not necessarily a sprite atlas.

Cattle Trail's recovered collection includes two sprite/production sheets, a style guide, the concept video, and its start frame. `source/PROVENANCE.md` identifies the recovery and explains source limitations. `assets/sprites.json` records SHA-256 checksums for the source media.

Treat originals as immutable production evidence. Make extraction changes in the recipe, regenerate the outputs, and review the difference. Do not quietly retouch an original or replace an approved character with a convenient substitute. Record any separately approved replacement as a new source revision.

## 3. Turn source pixels into a reproducible asset contract

A generated sheet is not automatically a production atlas. Labels may promise frames that are absent; subjects can overlap; transparency may contain haze; poses can vary in size and alignment.

Use a deterministic extraction recipe. Cattle Trail's `tools/extract_assets.py` crops the actual sheets, applies traced subject masks where necessary, removes low-opacity background with a binary alpha threshold, trims transparent margins, reduces with nearest-neighbor sampling, and places subjects into uniform transparent cells. Terrain and interface textures are sampled from the approved concept start frame. The recipe does not generate replacement drawings.

For every sprite, retain:

- Original source identity and checksum, crop bounds, and any polygon mask.
- Alpha cleanup rule, trim bounds, and source-to-runtime scale.
- Atlas file, cell size, frame rectangles, and ground-contact anchor.
- Named clips, exact frame order, playback rate, and looping behavior.
- Available directions, permitted mirroring, and explicitly missing poses.

In this recipe, source crops use left/top/right/bottom coordinates with the right and bottom excluded. Atlas rectangles use x/y/width/height. Keeping that distinction explicit prevents extraction mistakes.

The original comparison room uses `assets/sprites.json`. Expanded extraction uses `kits/manifest.json`; the default playable room uses `assets/room-art.json`, rebuilt by `tools/curate_room.py`. Godot constructs animations from that selected manifest rather than a second handwritten frame list. Measured rider clip anchors come from `assets/rider-anchors.json`, rebuilt by `tools/align_rider.py`. Changes belong in these recipes and regenerate together.

Historical examples from the original 24-frame comparison room are:

| Actor | Cell | Ground anchor | Defined motion |
|---|---|---|---|
| Mounted rider | 64 × 80 | 32, 78 | Four ride frames at 7 fps |
| Longhorn | 58 × 50 | 29, 48 | Four walk frames at 5 fps |
| Cream/spotted cattle | 58 × 50 | 29, 48 | Four extracted walk poses each at 5 fps |
| Eleanor | 36 × 48 | 18, 46 | Three source frames; idle/talk sequences |
| Rustler | 40 × 48 | 20, 46 | Idle, two-frame walk, one shooting pose |
| Wagon | 112 × 72 | 56, 70 | One idle pose |

An anchor represents the actor's position on the ground. Consistent anchors let animation change without the actor jumping vertically and let depth sorting use meaningful foot positions. Frame counts describe available artwork, not a claim that every cycle is production complete.

## 4. Build the fixed-view world in Godot 4

Use a 2D world with perspective already drawn into the art. Cattle Trail retains a 640 × 360 logical world, with actors sorted by their ground Y coordinate. Its Godot `SubViewport` renders at display density: the integer display scale, clamped from one to four, multiplies both viewport dimensions and the canvas transform. This preserves logical positions, collisions, sockets and pointer coordinates while allowing detailed textures to reach the display. The high three-quarter appearance comes from the art and staging; no orbiting camera is needed.

Keep logical world dimensions stable and use nearest-neighbor filtering. Actor metadata can declare `pixels_per_world_unit: 4`; a 160-pixel figure then occupies 40 world units. Source-space pivots and sockets use that same transform. A 2× desktop display shows approximately 80 pixels of figure height; a 4× display can preserve the full 160. Responsive controls remain outside the viewport, and pointer positions convert back to logical world coordinates. Render-density support does not automatically admit candidate art.

The present layout uses fractional nearest-neighbor reduction on screens too narrow for the native world. That fits the whole room but can drop source pixels unevenly. It is a documented compromise requiring visual inspection; nearest-neighbor alone does not guarantee equal-sized pixels at every display size.

Use actual admitted textures for visible actors and scenery. Hidden collision shapes and interaction ranges can be simple geometry; visible geometry must not substitute for missing characters, props, or terrain. Inspect movement as well as stills for unstable edges, anchor jitter, overlap errors, and texture seams.

## 5. Prove one complete loop

Choose the smallest room that demonstrates the game's identity. Include the real player avatar, a meaningful target, one relationship or obstacle, readable feedback, an achievable outcome, and reset/replay.

Cattle Trail's room is organized around mounted movement, talking to Eleanor, moving cattle through proximity pressure or lasso following, clearing a rustler through lasso or shooting, and gathering six cattle for a reward. The HUD reflects room state. These interactions make the artwork part of a playable environment.

For another game, substitute its own representative loop: inspect and repair one machine, conduct one trade, resolve one encounter, or move one shipment. Keep existing useful rules where possible, and connect them to the new presentation through explicit state and actions. Avoid rebuilding the entire simulation merely to demonstrate the visual method.

DOS simulation, Oregon Trail, and tycoon games can inform later depth: resources, time, travel consequences, relationships, or economic decisions. This method supports that direction, but those larger systems are not delivered by the present room.

## 6. Admit assets and accept the room through separate gates

| Gate | Required evidence |
|---|---|
| Source admission | Correct approved originals, provenance, dimensions, and checksums. |
| Extraction admission | Reproducible output; intact silhouettes; clean transparency; consistent scale/anchors; no neighboring subjects or labels accidentally included. |
| Animation admission | Every referenced frame exists; timings and mirroring are declared; motion is viewed; missing coverage stays visible in the record. |
| Playable proof | Controls, interactions, feedback, objective, and reset work in the running engine. |
| Visual acceptance | Engine screenshots and movement capture compared against the approved clip; user accepts the room's visual bar. |

A passing interaction check does not constitute visual acceptance. A good screenshot does not prove animation quality. Final visual review requires actual engine output at desktop and narrow layouts, including movement, overlap, lasso/shoot feedback, and completion. Compare composition, scale, palette, pixel treatment, animation, and UI readability against the reference. During the currently authorized sheet-production pass, inspect sheets directly and use focused backend checks without repeated in-game captures; gameplay expansion may continue while visual gaps remain explicitly recorded.

## 7. Current boundaries and migration deliverables

The recovered original comparison art lacks full directional movement and uses repeated concept-frame terrain crops. The current default room selects named actor clips and scenery variants from the expanded library, includes eight-way rider and cattle coverage with frame-timed rider effects, and uses an empty-ground derivative of the approved concept. It has passed continuous scripted play without actor teleports. Ground and foliage were simplified toward the approved reference; planted idle and walking poses are compared together against the original sprites in the engine. Extraction counts do not imply that these visual requirements are complete. Consult ROOM-INTEGRATION.md and the selected manifest for current counts and implementation evidence.

The current script draws connecting rope and brief shot feedback using `Line2D`, synchronized to actual rider action frames. These are effects alongside real actor sprites; they do not substitute for characters or scenery. A project that requires entirely sprite-based effects should record that separate art requirement. No claim of final user visual acceptance is made here.

When migrating another game, deliver the following in order:

1. A short visual contract and one-room gameplay specification.
2. Immutable approved sources and provenance.
3. A reproducible extraction recipe, transparent atlases, and source-of-truth metadata.
4. The fixed-view Godot room with real assets and a complete interaction loop.
5. Engine captures, interaction verification results, and an honest missing-art list.
6. A recorded visual decision and an explicit broader production plan; current Cattle Trail gameplay expansion is already authorized, while individual asset and room acceptance remain separate.

Commit small coherent stages: source recovery, extraction and metadata, scene integration, interaction loop, and verified corrections. Each stage should be reviewable and recoverable. The room becomes the reference implementation for future rooms and conversions only when its appearance and behavior have been accepted.

## 8. Rich kits extend coverage while the room stays bounded

The expanded art brief adds complete kits for the existing seven actor families and connected grass, tree, rock, scrub, fence, and camp families. The planning baseline is 24 extracted actor frames. The revised allocation is 400 actor/prop frames and states, approximately 16.7 times that aggregate baseline, plus 96 environment modules. The first pass extracted 496 unique candidate cells and rendered all 13 families in Godot. This is measured extraction and playback, not production acceptance or completed connected terrain. See kits/DELIVERY.md for the remaining coverage and integration gaps.

Richness means useful directions, actions, and functional states. Duplicate cells, mirrors, repeated exports, and recolor padding do not count as new coverage. Each actor needs a coherent kit; unrelated props do not fill missing animation. Environment kits need matching edges, anchors, layers, and state pairs so they can compose into the same playable room.

See kits/PLAN.md for the historical bounded coverage allocation and admission order, and kits/catalog-plan.json for machine-readable goals. Maintain a separate measured delivery inventory. Generate, extract and inspect sheets, then perform the needed motion review before admission and integration. A large asset count does not establish visual acceptance; current broader gameplay scope comes from the user's later authorization, not that count.

## 9. Reusable extraction and direction checks

`tools/sprite_grid.py` supports arbitrary grid dimensions without assuming every generator produced four columns and four rows. For example, a three-by-two troop board uses `--columns 3 --rows 2`. It writes unscaled transparent cells and records source hashes, grid rectangles, trims, component-removal counts and cut warnings. Keep `--min-component-pixels 1` when single-pixel detached effects matter. The default five-pixel filter preserves Cattle Trail's existing extraction behavior. Importing the helper has no file-writing side effects, and its CLI refuses to overwrite a populated output directory.

The helper was checked against Cattle Trail's four-by-four rider sheet (sixteen crops identical to the established extractor) and Pirate Island's three-by-two troop sheet (six candidate crops, no gutter warnings). This proves extraction compatibility, not art admission. Each destination game keeps its own palette, character identities and reference authority.

Compare stationary and moving poses for the same direction side by side. This caught north cattle walks that actually faced northeast, south walks whose camera was too steep, and east/west rider idles that turned away from their walking angle. A correctly sized cell with a valid animation name can still depict the wrong direction. Preserve those candidates with their source record, create narrowly targeted replacements, and select the corrected clips explicitly rather than silently relabeling them.

Use per-clip ground/body anchors rather than centering each frame independently. Independent centering can erase intentional recoil or introduce foot sliding. Keep idle poses planted and free of travel dust; preserve gait phase when changing direction; apply gameplay effects on a declared animation frame. Rich kits become reusable when they carry these contracts together with their actual pixels.

## Planted actions and per-direction release evidence

The eight-direction cast repair separates actor pixels from the single runtime rope. Record hand sockets in each atlas cell and a neck socket on each target; animate wind, release, flight, attachment and recovery from those points. A planted horse must stop world translation throughout its action, then resume queued travel. Do not copy event ordinals blindly: the southwest sheet visibly opens its hand at ordinal 3, while the seven other admitted cast sequences use ordinal 4. Native review computes each release time from its own frame durations and verifies visible flight before attachment, then low-hand recovery. See cast-eight-directions.mp4 and assets/sequence-curation.json.

This method does not certify locomotion: the current walk candidates still have support-phase and sliding defects. Separate candidate count, event correctness, native visual inspection and final room acceptance.
# Current extension: character ownership and playable relationships

Latest production instruction: repair sprite sheets directly and use agents for production, with no repeated in-game testing during pose correction. When a generated cycle repeats its leading leg, commission the missing opposite contact as a single whole-pose edit, then the missing passing pose. Assemble an ordered working atlas with source references before runtime admission. A requested phase label is not proof of the drawing's leg identity. Source-only working sheets live in kits/workcycles and do not silently replace shipped clips.

Assign one owner to each recurring character. The owner retains identity references and produces whole-pose movement, action and turn candidates; the integrator alone admits exact frames into the shared runtime. Missing phases may be generated as bounded in-between poses, then measured and compared with their endpoints. Do not derive acceptance from requested phase names.

Keep companion simulation independent of presentation. In this build, companion_state.gd owns recruitment, distinct relationship progression, one-time adventure events, madness, recovery and versioned save migration. companion_room.gd supplies proximity, control transfer, actual activities, speech and room persistence. The player completes a short task as Eleanor before the separate optional romance choice. Headless state checks are paired with a native recording of actual walking and interactions.

Attached effects also need occlusion review. The lasso lead and far neck arc now draw behind actor bodies; only the near neck arc crosses the cattle sprite. Test every target-facing direction, not just every throwing direction: those are different coverage requirements.

## Authored turns and recoverable state

Define a turn as a short whole-pose bridge between two real facing clips. Record grounded and passing variants, measured anchor and hand sockets, and a finite hold. The scheduler preserves elapsed gait phase, allows a new direction to replace the pending bridge, and cancels immediately for an action. Missing bridges use the existing destination clip. Northern rider connections currently cover NW↔N and N↔NE only; do not infer full turn coverage.

Store side comments as event content while preserving stable saved beat IDs. Trigger them from completed gameplay actions, with priorities and one-time history controlling repetition. Presentation content must not advance relationship state by itself.

Save recovery must validate the whole snapshot before mutating live state. A parseable but invalid primary file should fall back to a valid backup. Run validators on a copy so validation cannot rewrite the returned save. Clear pending turns, actions and effects when restoration succeeds. These backend contracts can be checked without launching a room during a sheet-production pass.

## Master characters and batch identities

The character-family production method now lives in `design/character-family-method.md`. Build detailed recurring masters, derive complete adult identity variants, and retain exact atlas/anchor/provenance records. Author gait and turn sequences separately; a batch of different women is never a walk cycle. The production factory creates repeatable names and relationships from real visual IDs and keeps rejected art out of previews.

Resolved generated characters must be saved as full records, not reconstructed from a current catalog seed at load time. Keep a per-character activity ledger to prevent duplicate rewards after retry or restore. Resolve perks from authored IDs, active assignments and shared caps; never load arbitrary perk power from character data. Preview sprite candidates stay outside ordinary game saves.
