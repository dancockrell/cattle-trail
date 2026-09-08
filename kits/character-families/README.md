# Cattle Trail character families

Three detailed masters now produce **96 actual static character appearances** across six batches: 32 ranchers, 32 mechanics and 32 spirit scouts. Each master was generated from existing project sprite references with the built-in image tool; all original outputs, exact prompts, correction prompts and extraction helpers are retained in its family folder.

Open `index.html` for the offline character workshop: master references, all 96 transparent sprite cards, family filters and searchable names/personality. `catalog.json` records every atlas rectangle, anchor, adult age, status and pixel hash. `preview-roster.json` binds these actual visuals to deterministic character records; changing the catalog order does not change identities.

Atlas contract: six 256×256 RGBA atlases, 16 whole figures each, 64×64 cells, foot anchor32,61,40pixel character height. No duplicated limbs or generated tween rigs. The production pass includes daring opaque cropped/tied tops, bare shoulders and midriffs, fitted shorts, slit skirts, boots and working equipment while keeping every character clearly adult and nonexplicit.

All96 are static candidates; none has been presented as a complete walk/turn kit or automatically added to the room. Master references contain richer and softer detail than final pixel sprites. Camera matching and detailed sprite cleanup remain part of art admission. Rejected clipped sources remain preserved but are not catalog entries. Candidate art is excluded from release export.

Rebuild in order:

1. Run the per-family extraction helpers after any source revision.
2. Run `python tools/build_character_catalog.py` from the project root.
3. Run `python tools/verify_godot.py character-roster` to export actual preview character records without rendering a game.
4. Run `python tools/build_character_gallery.py`.

Structural validation checked 96 distinct IDs, adult ages, exact rectangles, anchors, binary alpha, source/atlas/pixel hashes and JSON-to-Godot roster production. Separate factory fixtures checked stable identity, no repeated art, rejected-art exclusion and data isolation. No rendered room test or Windows rebuild was performed for this pass.
