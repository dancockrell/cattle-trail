# Ada production kit v2

Four new built-in image generations, 32 full-body cells each, retained at native 1774 x 887 source resolution. Four 2048 x 1024 transparent atlases use 256 x 256 cells with shared anchor (128, 244), scale 1, and 128 native whole-cell cutouts. Exact prompts and source hashes are recorded beside each sheet.

Ada is 22. Costume is a tucked ivory sleeveless blouse, one pair of full-length brown trousers, boots, simple belt; no waistcoat or stacked leg garments. Red braid and brass goggles retain her identity.

1. Locomotion: four directional rows. Opposing foot contacts remain incorrect in several rows. Not a finished walk.
2. Turns: four full-body rotation sets, including genuine rear/profile facings. Source order of some intended counterclockwise rows needs correction before use.
3. Mechanic: kneel/repair, wrench, hammer, pocket-watch actions. Distinct action stages with tool/return continuity still requiring review.
4. Social/camp: eight actions with four unique phases each: greeting, laugh, drink, offer cup, sit down, stand up, talk, listen. This incorporates the instruction to use only the frames an action needs instead of filling eight slots with repeated poses. Cup disappears in two source endpoints; those are not suitable for prop-continuous playback.

Every source was requested with real RGBA transparency on its first generation. The service nevertheless returned RGB with painted checkerboard. `build.py` removes only border-connected light neutral background, preserves all surviving RGB, does not paint or reconstruct bodies, and performs no scaling or bbox recentering. Enclosed checker remnants and fine pale edge residue can remain; these are review atlases, not admitted final runtime assets. No retries or duplicate-frame padding were used. Byte uniqueness is not a claim of unique gait phases.

No gameplay tests were run and no runtime actor was changed. All clips remain `runtime_admitted: false` pending actual sequence review; intended timing is 125 ms per source frame, with variable action length.
