# Rich sprite-kit library

This is an expansion of the recovered Cattle Trail art, generated with the built-in image-generation tool using the original sheets as references. Press K in the game to browse it.

## Inspect and reuse

In the Godot game press **K** to open the kit browser, or launch the Windows build with **Open Sprite Kits.cmd**. Choose a family and clip, replay or pause its animation, and inspect the atlas beside the terrain-backed preview. The viewer reads the same manifest a game integration would use.

- `source/`: immutable generated sheets, including the rejected dense rider pilot.
- `atlases/`: transparent PNG atlases at defined runtime pixel sizes.
- `manifest.json`: measured extraction inventory, source hashes/crops/trims, atlas regions, ground anchors, requested directions, clip frames/rates/looping, and review state.
- `generation-jobs.json`: saved generation prompts and original reference index.
- `reviews/`: alpha review sheets and actual Godot captures.
- `validation.json`: structural checks; this is not an art approval certificate.
- `catalog-plan.json`: target coverage.

Rebuild with `python tools/extract_kits.py` from the project folder, then `python tools/validate_kits.py`. Requirements: Pillow, NumPy, SciPy. The extractor identifies actual empty gutters rather than assuming the generator obeyed its requested grid, removes magenta with a binary color key, and uses only nearest-neighbor reduction. One scale is applied across a sheet so effects do not resize the actor from pose to pose.

An idle clip may intentionally reuse the first walk pose. Such reuse does not increase the unique-frame count. Mirroring, duplicates, rejected pilot cells, and extra PNG exports also do not count toward richness.

## Direction and animation review

Directional names originally come from the requested generation job. The source can deviate: some north-requested cattle graze or rest poses turn back toward the camera, and some shooting poses aim diagonally rather than straight ahead. Treat those exceptions as documented source limitations.

Walk/trot/run strips contain four generated poses, not motion-captured or hand-drawn final cycles. Rest, medical, and reaction rows include distinct functional states that can need transition curation.

The grass/tree/rock/scrub/fence/camp families provide reusable source variation. Their native scale and upper-left lighting are tied to the same style references. The tree kit includes complementary canopy/trunk layers with shared anchors (their union reproduces the original silhouette); fences should be admitted with measured connectors before building collision-critical corrals.
