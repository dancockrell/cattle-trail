# Master characters and whole-sprite families

The production unit is a richly defined adult character, with a readable face, silhouette, hair, clothing construction, equipment, handedness and personality. Three initial masters support rancher, mechanic and spirit-scout families. Eleanor remains a healer in gameplay; her frontier clothing provides the rancher family's visual reference, not a change of her role.

Each master has a detailed reference sheet. Its batch sheet supplies sixteen **different people**, each one a complete sprite. Those cells are identity variants, never sequential animation frames. Clothing, hair, face, palette and tools can vary together in authored combinations. We do not attach generated legs and arms to a common torso.

## Wardrobe direction

All romance characters are clearly adults, generally 18–24. Art should convey healthy, active, slim adults with restrained bust proportions, charm and confident self-expression. Follow [CHARACTER-VISUAL-CONTRACT.md](CHARACTER-VISUAL-CONTRACT.md) for the current wardrobe authority, especially its 1870s fabrics, construction and cuts: woven linen and cotton, fitted waistcoats and bodices, brass buttons, hand ties, leather boots, riding skirts and opaque riding drawers or breeches. Express daring coverage through tied or shortened blouses, bare shoulders and midriffs, open cropped jackets, short hems and split riding skirts. Earlier halter/shorts studies establish the accepted coverage level, not permission for contemporary gym tops, stretch fabrics, modern zippers or denim cutoffs. Characters choose how much skin they show; variation includes both covered and more revealing outfits. PG-13 is the intended tone, not a formal rating certification. Keep intimate areas opaquely covered and poses nonexplicit. Their jobs, interests and humor remain visible in their designs.

## Repeatable production

1. Preserve a detailed master sheet, exact prompt and source hashes.
2. Derive a separated 4×4 batch from that master at a fixed high three-quarter camera, warm Texas palette and matching light direction. Give every row its own clothing/equipment theme; vary faces and hair within it.
3. Preserve complete native transparent figures. New detailed masters use approximately 160 pixels of figure height in 256×256 cells, with actual anchors recorded per asset (normally 128,244) and four source pixels per logical world unit. The earlier 64×64 cells and 40-pixel figures remain historical preview artifacts; the user rejected that coarse production target. Use nearest-neighbor only when scale conversion is required.
4. Inspect the sixteen figures together. Check adult proportions, feet, clothing coverage, tool attachment, silhouette and consistent camera. Record cut warnings and imperfect results. A generated sheet is a candidate until reviewed; an attractive master does not approve every derivative automatically.
5. The catalog binds each stable visual ID to its exact atlas rectangle, age, anchor, family and provenance. The character factory assigns repeatable names and personality records from world seed + visual ID, without repeating art within a requested roster.
6. Take selected characters through separate authored directional and motion kits: contact, low passing, opposite contact, opposite passing, turns and role actions. A static batch does not meet that animation requirement. Preserve timing and hand/tool anchors per clip.

The same method transfers to another game by replacing the camera, scale, palette, master identities, wardrobe and job vocabulary. Keep the complete-figure extraction, identity IDs, explicit admission and animation contracts.

## Continuous-motion extraction experiment

Independent generated poses have repeatedly changed body volume or repeated the leading leg. The Ada continuous-walk experiment therefore preserves a single five-second source video and extracts chronological whole figures for sheet inspection. Its generation record stores the exact master, prompt, model, source hashes and cost. It is an experiment, not evidence of a usable loop or a change to the default generation policy below.

Keep native decoded frames and timestamps. Apply one scale and registration transform across the sequence so that body bob, planted feet and genuine size changes remain visible; independently fitting each frame to a target height would hide instability. Review contact, support, passing and opposite contact from the observed timeline before selecting a loop. Do not label a repeated pose as its missing opposite phase. Keep source chronology distinct from any later selected frame order, and retain exact durations and rejected spans. No in-game capture is needed for this production review.

## Delivery boundaries

`kits/character-families/` holds source masters, generated batches, extracted candidates and provenance. The batch catalog is production data; candidates are excluded from release export. `scripts/character_factory.gd` can generate production-preview rosters explicitly, but its default selects approved art only. New perks are design identifiers until a gameplay system implements their effects. This production pass does not silently spawn a crowd into Clear Fork or replace Eleanor/Ada's existing motion.
