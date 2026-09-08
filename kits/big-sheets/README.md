# Full sprite-sheet production

Open `index.html` for the offline workshop. It shows each complete transparent atlas and plays its rows from the actual extracted cells. Pause, step frames, adjust preview speed, or open the original source, prompt and metadata. Row repetition is an inspection aid; it does not make an incomplete gait a completed loop.

This batch contains four independently generated sheets for each of Ada, Eleanor and Ines: 48 figures in the first mixed sheet and 32 in each of the following three sheets, totaling 144 per character and 432 character cells. The environment sheet adds 64 grass, flower, shrub, cactus, rock, deadwood and sapling items. A separate 32-frame spirit-effects sheet adds spectral bells, cold embers, crow shadows and circling lights. There are fourteen original sheets and 528 extracted cells in total. No copied padding or recolored duplicates were added to reach those counts.

The four-sheet character sets cover directional walking, running, turn poses and character-specific actions. The first sheet was already underway when the user specified full action loops, so its mixed turn/emote rows remain pose banks. Some generated walking rows still repeat the leading leg. Those rows do not yet satisfy the requested complete-cycle contract. Selected role loops are packaged separately under each character's `selected-loops` folder with exact source indices, timings and seam observations.

Each source was generated with the built-in image tool using the retained character master or approved environment reference. Exact prompts and source hashes accompany the sheets. Original native crops remain available. All atlas cells are 256 by 256 pixels; individual extraction metadata records whether a uniform nearest-neighbor scale was applied. Transparency cleanup is explicit because the generator returned baked backgrounds. Candidate art has not replaced the room's actors.

Regenerate the workshop with `python tools/build_big_sheet_workshop.py`. Metadata and extraction scripts remain the source of truth; HTML previews do not redefine frame order, timing, pivots or asset admission.

The spirit-effects folder includes four eight-frame previews, fixed cell registration and exact source hashes. Its hard-alpha extraction removes generated grid lines without resampling. Loop seams and shape drift remain documented; the new effects are production candidates and have not been placed in the room.
