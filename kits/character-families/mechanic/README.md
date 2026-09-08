# Mechanic character family

Ada Mercer, age 22, is the identity and craft reference. Her master contains front-oblique, rear-oblique and side standing views, a wrench stance, a crouched repair action, and enlarged goggles, belt, regulator and gloves. Keep her auburn braid, brass goggles, brown leather jacket, cream blouse and olive trousers when producing Ada herself.

The family expands the profession into distinct adult identities rather than recoloring Ada. Each variant keeps brass tools, sturdy boots, an engineering belt and warm outlined art. Hair, skin, garment construction, silhouette and equipment vary together. The summer batch uses confident opaque cropped workwear, shorts and short jackets at upper PG13.

`family.json` describes the first 16 identities. `batch02/family.json` describes identities 17–32. Both use 64×64 cells, bottom-center anchor (32,61), and complete figures scaled to 40 pixels tall using nearest sampling. Each identity has only a static idle frame. These are not walk cycles, turn sequences, or layered body rigs.

Raw generation, prompts, keyed transparent derivatives and individual whole-sprite files are retained. Rebuild with `python kits/character-families/mechanic/build.py` and `python kits/character-families/mechanic/batch02/build.py`. The first generator baked a pale checkerboard; the helper keys its neutral matte. The second used magenta. Neither helper paints characters or creates anatomy. Candidate status remains explicit until integrated scene review; no rendered game test was performed in this production pass.

For new animation work, select one individual character as the reference, preserve identity and tool placement, generate whole-character contact/passing poses for one direction at a time, and record phase order. Do not pass the entire family sheet to a performance generator or turn sixteen different women into an animation clip.
