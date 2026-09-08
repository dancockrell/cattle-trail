# Clear Fork room integration — 2026-09-08

The default room uses 326 distinct actor frames, including the recovered original wagon, and 30 scenery variants in 40 placements. The source library contains 936 extracted candidate cells across 13 families. These are separate counts; extraction is not animation acceptance. Press K for the candidate browser. Original comparison art remains available with --original.

assets/room-art.json is the selected runtime authority. tools/curate_room.py builds it from kits/manifest.json, original wagon metadata, measured rider anchors and assets/sequence-curation.json. Exact source hashes, crop rectangles, frame regions, clip orders, timings and sockets remain traceable.

## Current presentation

Fixed high-three-quarter camera; 640×360 world; nearest filtering and pixel snapping; warm Texas ground; real rider, cattle, Eleanor, rustler, wagon and scenery sprites. The ground-v3 and trees-v2 sources replace noisy earlier derivatives with broader tonal clusters. Earlier sources remain preserved. HUD text dates the opening to May 12, 1872.

GAME-DESIGN.md now establishes the adult Weird West harem-romance RPG identity. Companion control, relationship adventures, perks, universal madness, spirits and machinery are designed foundations, not implemented systems in this room.

## Sequence repair

The user's explicit critique of the lasso and cycles is an open acceptance requirement. Auditing every rider direction showed that source row order did not establish coherent gait or cast sequences.

- Rider and three cattle appearances have eight-way selected poses. Corrected cardinal cattle strips fix north-facing direction and south camera mismatch.
- The northeast walk uses V8 source poses1–4, with0.14/0.11/0.11/0.14-second durations at24px/sec reference speed. All eight casts now use clean-hand sequence strips with individual durations.
- These eight casts use one engine-drawn construction: hand-attached wind-up, cast, visible flight, neck catch and low-hand recovery. No rope is baked into these replacement actor frames.
- Rope effects use frame-local hand sockets and direction-specific cattle neck sockets. The steer follows farther behind the mount with eased approach.
- All legacy lasso strips are superseded in the room. Southwest uses its visibly earlier open-hand release rather than a copied ordinal.
- The compact northeast selection removes the earlier V5 support transition from gameplay. Its12-pixel nominal stride is an estimate; phase_order_verified stays false until contact anatomy is established.

## Evidence

The full rendered gameplay test passed movement, facing selection, action retention, frame-event effects, collision, Eleanor, rustler clearance, lasso following, all-six settlement, completion cash and 360/390-pixel control bounds.

continuous-play.mp4 is an80-second actual engine recording from normal spawn through the complete objective at the revised riding pace, with normal travel/actions and no actor teleports. It includes the current speech and reaction integration. It is scripted input, not manual play.

sequence-review.mp4 isolates the northeast repair: three moving walk cycles over fixed ground, two stationary cycles and three lasso casts. Assertions verify visible flight before catch, a loop/tether and low-hand recovery. This is a visual review mode and deliberately resets the rider between the movement and action sections.

room-desktop.png, room-complete.png and room-phone.png are fresh full-room engine captures. Earlier room-playback.mp4, pose-review.mp4 and herd-review.mp4 remain historical comparison evidence; they do not show every latest change.

The mount now stops actual travel during planted casts and resumes queued movement after recovery. A focused assertion verifies both behaviors. cast-eight-directions.mp4 renders all eight corrected casts with flight-before-catch checks. stride-sequence-comparison.mp4 compares the previous gait, the lower-leg edit's row order, and a curated order at the same diagnostic stride; the edit remains outside normal gameplay selection.

## Remaining gate

Finish physical walk sequencing, inspect close-range leading/overlap in actual motion, and verify the final Windows build against those corrected assets. The larger journey and relationship gameplay remain outside this room milestone. No final visual approval is claimed.

## Neck wrap and parallel production update

The catch now tightens a directional neck wrap rather than drawing a complete ellipse over the animal. Its far arc renders behind the actual cattle sprite; its near arc joins the lead at the closest side. Northeast attachment moved from jaw-side [47,36] to neck [44,38]. Eight-direction catch review and full gameplay QA pass; visual review remains distinct. rope-wrap-review.mp4 records the current wrap construction and adjusted socket.

The latest 40 candidates add 16 longhorn states, 16 grass/plant clusters and 8 whole rider walk poses. Longhorn bottom rows actually face SE/SW and are catalogued accordingly. The room uses the new grass clusters; the state and walk candidates are available in the kit browser.

## Action-time comments and character reactions

Four once-per-room speech beats now appear during existing actions: Eleanor introduction, first cattle catch, rustler retreat and completion. One warm speech panel follows its speaker, with bounded placement, text-based duration and priority; no modal dialogue pause. Narrow layout places a low-speaker bubble over the lower verge and allocates separate space for journal/objective text. Core instructions remain in the journal.

Eleanor holds the existing bag-free frame4 between comments. The northwest mounted greeting uses source frames221→229→221 for0.8 seconds. Rustler clearance holds actual southwest recoil79 and surrender75 for0.85 seconds, then starts the existing eastward escape. Character-owned selection records are in assets/curation/. The actor API accepts an explicit clip name so a southwest reaction works with the rustler's existing four-direction locomotion. These held poses do not certify a new walk cycle.

speech-room.png, speech-phone.png and reaction-room.png are engine captures. The dedicated review verifies desktop/phone bounds, continued movement and reaction-before-flee behavior; full room QA also passes.

## Travel and stride integration

Mounted travel is32worldpx/sec, reduced from96. Walk playback scales against24px/sec reference speed rather than72; the compact NE cycle has a12-pixel nominal stride, with an8–16pixel estimate range recorded in assets/curation/rider-walk.json. Actions retain their own timing. Rustler escape now uses selected run_east frames4–7 at48px/sec, rather than walking at105. Its24-pixel nominal running stride remains a tuning estimate. Both selections are now used in gameplay.

The lead window is18seconds to support travel at the revised pace. When the rider enters the gathering area, the trailing target is clamped into its interior so a steer can settle instead of stopping just outside its lower boundary. Full gameplay QA passes at this pace. stride-matched-review.mp4 renders three translated and two stationary compact cycles plus all eight cast directions.
# Current gameplay extension

After the six-cattle objective, returning to Eleanor invites her into the outfit. Tab/Companion transfers control to her for a three-cattle calming activity; Talk works at close range, and returning to the wagon finishes it. Switching away pauses progress. A separate optional Flirt starts courting. Shared rest at camp restores up to 13 player madness (10 base plus 3 Steady Company) and 10 Eleanor madness, with a daily cooldown. Each progression event is recorded once. The save includes the active actor, room positions, cattle, resources and companion history; reset clears it.

The user now authorizes building out the design while animation repair continues. The full spirit-lantern encounter, travel, procedural companions and machines remain future work. Current art selection remains 326 actor frames; inventory is 944 extracted candidates plus an unextracted four-pose northern turn source. The rider uses v10 northwest grounded phases, and Eleanor uses the bag-free v5 east walk. The lasso's attached lead and rear neck arc are behind bodies, with only the near neck wrap in front.
