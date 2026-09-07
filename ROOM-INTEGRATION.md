# Clear Fork room integration — 2026-09-08

The default room uses 315 distinct actor frames, including the recovered original wagon, and 30 scenery variants in 40 placements. The source library contains 720 extracted candidate cells across 13 families. These are separate counts; extraction is not animation acceptance. Press K for the candidate browser. Original comparison art remains available with --original.

assets/room-art.json is the selected runtime authority. tools/curate_room.py builds it from kits/manifest.json, original wagon metadata, measured rider anchors and assets/sequence-curation.json. Exact source hashes, crop rectangles, frame regions, clip orders, timings and sockets remain traceable.

## Current presentation

Fixed high-three-quarter camera; 640×360 world; nearest filtering and pixel snapping; warm Texas ground; real rider, cattle, Eleanor, rustler, wagon and scenery sprites. The ground-v3 and trees-v2 sources replace noisy earlier derivatives with broader tonal clusters. Earlier sources remain preserved. HUD text dates the opening to May 12, 1872.

GAME-DESIGN.md now establishes the adult Weird West harem-romance RPG identity. Companion control, relationship adventures, perks, universal madness, spirits and machinery are designed foundations, not implemented systems in this room.

## Sequence repair

The user's explicit critique of the lasso and cycles is an open acceptance requirement. Auditing every rider direction showed that source row order did not establish coherent gait or cast sequences.

- Rider and three cattle appearances have eight-way selected poses. Corrected cardinal cattle strips fix north-facing direction and south camera mismatch.
- Only the northeast rider has the new sequence-first proof: eight walk frames and eight clean-hand lasso poses, with individual durations.
- The northeast rope has one engine-drawn construction: hand-attached wind-up, cast, visible flight, neck catch and low-hand recovery. No rope is baked into these replacement actor frames.
- Rope effects use frame-local hand sockets and direction-specific cattle neck sockets. The steer follows farther behind the mount with eased approach.
- Other rider lasso directions remain legacy candidates; overhead winding is not a complete cast, and known wrong-side extensions remain excluded.
- The new northeast walk improves identity and pose progression, but hoof contact and the 143→144 support transition remain under review. phase_order_verified stays false.

## Evidence

The full rendered gameplay test passed movement, facing selection, action retention, frame-event effects, collision, Eleanor, rustler clearance, lasso following, all-six settlement, completion cash and 360/390-pixel control bounds.

continuous-play.mp4 is a fresh 31-second actual engine recording from normal spawn through complete objective, with normal travel/actions and no actor teleports. It is scripted input, not manual play.

sequence-review.mp4 isolates the northeast repair: three moving walk cycles over fixed ground, two stationary cycles and three lasso casts. Assertions verify visible flight before catch, a loop/tether and low-hand recovery. This is a visual review mode and deliberately resets the rider between the movement and action sections.

room-desktop.png, room-complete.png and room-phone.png are fresh full-room engine captures. Earlier room-playback.mp4, pose-review.mp4 and herd-review.mp4 remain historical comparison evidence; they do not show every latest change.

## Remaining gate

Finish physical walk sequencing, extend the proven action method across required directions, inspect close-range leading/overlap in actual motion, and verify the final Windows build against those corrected assets. The larger journey and relationship gameplay remain outside this room milestone. No final visual approval is claimed.
