# Ines selected role loops

Two eight-frame loops use the existing sheet04 artwork. They are actual distinct whole figures, not duplicated padding or new generated frames. The 2560×320 atlases preserve native source pixels in 320×320 cells; figures remain approximately 240 pixels high. The larger cell protects extended hands. APNG previews use the same exact RGBA frames and per-frame timing listed in metadata.

`idle_breathe` runs for 1.68 seconds. It has a stable planted stance, small chest/head/garment variations and a close final-to-first pose. The breathing phase names are editorial interpretations of very subtle changes, not proof of a correctly drawn physiological cycle. Several drawings are extremely similar; no frame is pixel-identical, but distinct hashes alone do not establish meaningful animation richness.

`spirit_listen` runs for 1.88 seconds: rest, touch the charm, attend, indicate a direction, explain, listen, return the hand, rest. The final and initial poses both have lowered arms, so the loop closes at a compatible pose. It is a readable sequence of held gestures, not smooth continuous motion: the hand-to-point and point-to-ear changes still need intermediate artwork. Face, garment and torso width drift is visible. It can also be treated as a short one-shot interaction by disabling loop in a consumer.

The existing regular-grid extraction cut neighboring figures and included unrelated fragments. This selection instead identifies each large connected character component in the full keyed source. Its entire connected foreground is retained and translated according to the bottom boot support span, without scaling or reconstructing anatomy. Metadata records exact source rectangles, connected component ids, translations, source pixel counts and hashes. Source alpha still contains bright edge remnants and enclosed checkerboard fragments; these are preserved rather than silently painted out. Ground registration is an automatic boot-span estimate, not anatomical approval.

The lantern row repeats its leading leg and is deliberately not declared a walk cycle. No selected clip is admitted to runtime. The next useful art work is clean alpha and coherent intermediate arm poses, followed by direct loop inspection; no in-game testing was used here.

Rebuild: `python kits/big-sheets/ines-v1/selected-loops/build.py`. The builder verifies eight unique frames per clip, retained source foreground counts, exact decoded APNG frame pixels and exact holds. Original sheets are untouched.
