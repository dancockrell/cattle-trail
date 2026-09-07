# Northeast walking repair experiment

REJECTED BY USER, 2026-09-08: “not working, probably a bad idea.” Stop this cutout approach. Preserve the files only as rejected experimental evidence; do not integrate, extend, export as production art, or recommend it as the approved method. It never replaced the room's selected walk animation.

The V7 generated eight-frame edit again repeats the foreleg pattern: zero-based 0→1→2 and 4→5→6 each raise, extend and raise the prominent fore hoof. Independent inspection found no defensible whole-cycle permutation. `stride-v7-comparison.mp4` preserves the native comparison against V5 and curated V6. V7 remains outside the gameplay kit count.

The next experiment uses nine actual generated pixel-art parts: mounted torso and eight upper/lower leg pieces. `kits/source/rider-ne-rig-v1.png` and its exact prompt are preserved. `tools/extract_rig_trial.py` crops inside the generated white grid borders, removes magenta with binary alpha and trims the pieces without painting pixels. `assets/rig-trial/rig.json` records the source hash and every crop.

`scripts/rig_trial.gd` assembles those source textures with nearest filtering. A 0.96-second cycle travels 18 world pixels. Each hoof spends 75% of its cycle in support, moving backward locally at precisely the mount's forward world speed, then recovers with a low lift. Landings are staggered near hind, near fore, far hind, far fore. The standalone `tools/rig_review.gd` checks that all four planted world-contact tracks remain constant and records six cycles over fixed ground. The 640×360 world is enlarged by nearest sampling, like the actual room.

The first equal-length 2D joint solver produced excessive bending in the foreshortened view. The current trial uses small projected joint offsets and draws attachment overlaps beneath the torso. `rig-trial.mp4` is the revised engine render.

Rejection lesson: mathematical contact correctness did not preserve convincing anatomy or the approved sprite appearance. This is not an open polish task for the cutout approach. The room still needs coherent whole-sprite animation; no other facing, cattle rig or runtime replacement is implied.
