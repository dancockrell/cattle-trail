# The Cattle Trail method: approved art to a playable room

This method builds a game around a proven visual target, recovered production art, and one complete interaction loop. First make a small room look and feel like the approved reference in the actual engine. Expand the game only after that room earns visual acceptance.

The reusable part is the production discipline: preserve the approved sources, extract usable assets reproducibly, describe their animation contract explicitly, render them crisply in a fixed-view world, and prove play through that world. Other games keep their own setting, characters, mechanics, and identity. Converting a game to this method does not mean turning it into a Western or adopting cattle herding.

## 1. Lock the visual contract

Choose a small, explicit set of approved references: a style image, actor sheets, environment reference, and a short concept clip where available. Treat these as the visual authority. Write down the camera angle, scale of characters against scenery, palette, pixel density, edge treatment, environment density, animation cadence, and interface character.

For Cattle Trail, the target is modest pixel art, a fixed high three-quarter top-down view, warm Texas trail colors, readable mounted characters and cattle, textured scenery, and a Western interface. “More detailed” is not automatically better. Soft filtering, different proportions, or newly invented art can break continuity even when attractive in isolation.

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

`assets/sprites.json` is the runtime animation authority. Godot constructs its sprite animations from that manifest rather than maintaining a second handwritten frame list. The extraction recipe produces the manifest; changes belong in the recipe and regenerate together.

Current examples are:

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

Use a 2D world with perspective already drawn into the art. Cattle Trail renders a 640 × 360 world inside a Godot `SubViewport`, with actors sorted by their ground Y coordinate. The high three-quarter appearance comes from the art and staging. It does not require an orbiting 3D camera or animated camera movement.

Keep the world resolution stable, use nearest-neighbor texture filtering, and enlarge by whole-number scale factors when space permits. Build responsive interface controls around that viewport so resizing does not change actor proportions or world coordinates. Convert pointer positions back into world coordinates for click/tap movement.

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

A passing interaction check does not constitute visual acceptance. A good screenshot does not prove animation quality. Capture actual engine output at desktop and narrow layouts, including movement, overlap, lasso/shoot feedback, and completion. Compare composition, scale, palette, pixel treatment, animation, and UI readability against the reference. Fix visible drift before adding rooms or systems.

## 7. Current boundaries and migration deliverables

The reviewed source explicitly lacks true south-facing mounted frames; east and north reuse northeast artwork, and west mirrors it. The three cattle appearances now each use four extracted poses, but lack complete directional coverage. The shooting pose is not a complete action cycle. Ground is assembled from repeated concept-frame crops. These limitations require visual review and potentially additional approved production assets.

The current script also draws lasso and shot feedback using `Line2D`. These are procedural effects rather than extracted effects sprites, so they remain a gap against a strict requirement that all visible action art come from approved sheets. No claim of completed visual QA or user acceptance is made here.

When migrating another game, deliver the following in order:

1. A short visual contract and one-room gameplay specification.
2. Immutable approved sources and provenance.
3. A reproducible extraction recipe, transparent atlases, and source-of-truth metadata.
4. The fixed-view Godot room with real assets and a complete interaction loop.
5. Engine captures, interaction verification results, and an honest missing-art list.
6. A recorded visual decision, followed by a broader production plan only after acceptance.

Commit small coherent stages: source recovery, extraction and metadata, scene integration, interaction loop, and verified corrections. Each stage should be reviewable and recoverable. The room becomes the reference implementation for future rooms and conversions only when its appearance and behavior have been accepted.

## 8. Rich kits extend coverage while the room stays bounded

The expanded art brief adds complete kits for the existing seven actor families and connected grass, tree, rock, scrub, fence, and camp families. The planning baseline is 24 extracted actor frames. The revised allocation is 400 actor/prop frames and states, approximately 16.7 times that aggregate baseline, plus 96 environment modules. The first pass extracted 496 unique candidate cells and rendered all 13 families in Godot. This is measured extraction and playback, not production acceptance or completed connected terrain. See kits/DELIVERY.md for the remaining coverage and integration gaps.

Richness means useful directions, actions, and functional states. Duplicate cells, mirrors, repeated exports, and recolor padding do not count as new coverage. Each actor needs a coherent kit; unrelated props do not fill missing animation. Environment kits need matching edges, anchors, layers, and state pairs so they can compose into the same playable room.

See kits/PLAN.md for the bounded coverage allocation and admission order, and kits/catalog-plan.json for machine-readable goals. Maintain a separate measured delivery inventory. Generate, extract, inspect, animate in-engine, then admit and integrate. The same visual acceptance gate still applies: a large asset count does not authorize broader room or feature scope.
