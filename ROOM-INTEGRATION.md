# Clear Fork room integration — 2026-09-08

The default room uses 322 distinct actor frames, including the recovered original wagon, and 30 scenery variants in 40 placements. The source library contains 776 extracted candidate cells across 13 families. These are separate counts; extraction is not animation acceptance. Press K for the candidate browser. Original comparison art remains available with --original.

assets/room-art.json is the selected runtime authority. tools/curate_room.py builds it from kits/manifest.json, original wagon metadata, measured rider anchors and assets/sequence-curation.json. Exact source hashes, crop rectangles, frame regions, clip orders, timings and sockets remain traceable.

## Current presentation

Fixed high-three-quarter camera; 640×360 world; nearest filtering and pixel snapping; warm Texas ground; real rider, cattle, Eleanor, rustler, wagon and scenery sprites. The ground-v3 and trees-v2 sources replace noisy earlier derivatives with broader tonal clusters. Earlier sources remain preserved. HUD text dates the opening to May 12, 1872.

GAME-DESIGN.md now establishes the adult Weird West harem-romance RPG identity. Companion control, relationship adventures, perks, universal madness, spirits and machinery are designed foundations, not implemented systems in this room.

## Sequence repair

The user's explicit critique of the lasso and cycles is an open acceptance requirement. Auditing every rider direction showed that source row order did not establish coherent gait or cast sequences.

- Rider and three cattle appearances have eight-way selected poses. Corrected cardinal cattle strips fix north-facing direction and south camera mismatch.
- The northeast walk has an eight-frame sequence candidate. All eight casts now use clean-hand sequence strips with individual durations.
- These eight casts use one engine-drawn construction: hand-attached wind-up, cast, visible flight, neck catch and low-hand recovery. No rope is baked into these replacement actor frames.
- Rope effects use frame-local hand sockets and direction-specific cattle neck sockets. The steer follows farther behind the mount with eased approach.
- All legacy lasso strips are superseded in the room. Southwest uses its visibly earlier open-hand release rather than a copied ordinal.
- The new northeast walk improves identity and pose progression, but hoof contact and the 143→144 support transition remain under review. phase_order_verified stays false.

## Evidence

The full rendered gameplay test passed movement, facing selection, action retention, frame-event effects, collision, Eleanor, rustler clearance, lasso following, all-six settlement, completion cash and 360/390-pixel control bounds.

continuous-play.mp4 is a 33-second four-cast-build actual engine recording from normal spawn through complete objective, with normal travel/actions and no actor teleports. It is scripted input, not manual play.

sequence-review.mp4 isolates the northeast repair: three moving walk cycles over fixed ground, two stationary cycles and three lasso casts. Assertions verify visible flight before catch, a loop/tether and low-hand recovery. This is a visual review mode and deliberately resets the rider between the movement and action sections.

room-desktop.png, room-complete.png and room-phone.png are fresh full-room engine captures. Earlier room-playback.mp4, pose-review.mp4 and herd-review.mp4 remain historical comparison evidence; they do not show every latest change.

The mount now stops actual travel during planted casts and resumes queued movement after recovery. A focused assertion verifies both behaviors. cast-eight-directions.mp4 renders all eight corrected casts with flight-before-catch checks. stride-sequence-comparison.mp4 compares the previous gait, the lower-leg edit's row order, and a curated order at the same diagnostic stride; the edit remains outside normal gameplay selection.

## Remaining gate

Finish physical walk sequencing, inspect close-range leading/overlap in actual motion, and verify the final Windows build against those corrected assets. The larger journey and relationship gameplay remain outside this room milestone. No final visual approval is claimed.
