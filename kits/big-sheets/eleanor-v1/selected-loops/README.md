# Eleanor selected performances

Three timed performances selected from the existing fourth large sheet. Every cell uses one distinct whole source figure; no repeated endpoint, duplicated padding, body-part reconstruction, interpolation, repainting, or resampling. Run `python build.py` here to reproduce them.

| Performance | Source cells | Frames | Duration |
| --- | --- | --- | --- |
| Conversation | 24–31 | 8 | 2.00 seconds |
| Field care | 16–23 | 8 | 2.02 seconds |
| Standing idle | 0–3 | 4 | 1.40 seconds |

Each folder contains a transparent 256px-cell atlas, continuously looping APNG, labeled contact sheet, source hashes and exact rectangles, frame durations, and a loop definition. Native figure pixels remain intact, anchored at (128, 244). The timing is authored for these illustrated poses, not recovered video timing.

Conversation starts and finishes with lowered arms and includes greeting, explanation, pointing, laughter and settling. Care starts standing, kneels to apply a cloth dressing, then returns standing. Its descent and ascent lack intermediate poses. Idle excludes the later source row's larger stance change. All three retain generated contour and detail variation and remain explicit production candidates, not runtime-admitted animations or certified seamless motion.

The builder verifies source hashes, distinct selected figures, pixel identity after atlas assembly, and exact decoded APNG frames and timing. These checks prove preservation and playback definitions, not visual approval. No room rendering is needed for these artifacts.
