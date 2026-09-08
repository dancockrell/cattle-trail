# Character visual production contract

Authority: the user's September 8 rejection of the coarse Ada walk sheet and request for richer adult wardrobe variants. This supersedes the earlier 40-pixel figure target for new master production.

## Detail and scale

Preserve original generated sources and native transparent whole-figure crops. Build new detailed character candidates around 160 pixels of figure height in 256-pixel cells, recording the actual foot pivot per asset. This is a production experiment, not an approved replacement game scale. Never enlarge a 40-pixel sprite and call it a detailed master.

Faces, hands, boots, garment construction, hair and signature equipment must remain legible. Use deliberate pixel clusters, warm Texas colors and the established high three-quarter camera. No smoothing. Judge both original crops and the atlas; avoid reducing away the very details being reviewed.

The trail remains 640 by 360 logical world units. The renderer now draws at the displayed integer density, up to four output pixels per world unit, rather than always rasterizing through a 640-pixel texture. Actor metadata can declare `pixels_per_world_unit: 4`: a 160-pixel figure then occupies 40 world units without discarding its source texture. Anchors and sockets are source pixels; movement, collision and fallback sockets remain world units. A standard 2x desktop display shows 80 pixels of figure height; a 4x display preserves the full 160. Phone reduction necessarily shows less detail. This support does not admit unreviewed candidate art or establish visual acceptance. Current work produces sheets without repeated game captures.

## Wardrobe direction

All romance characters are explicitly adult, predominantly 18–24. Their appearance is slim, healthy, active and small-chested, with individual faces and confident bearing. Daring, self-chosen clothing is an active production direction: bare shoulders, midriffs, open backs, short hems, side slits, tied opaque tops and open cropped jackets. Use opaque coverage and ordinary relaxed, expressive poses. PG-13 is the intended creative tone, not a certified rating.

Keep the women recognizable through hair, palette, signature tools and accessories. Vary complete outfits coherently for work, warm-weather travel and camp; clothing does not alter consent, recruitment or perk strength. Avoid making every woman the same costume with different colors.

The user's Lara Croft comparison establishes athletic adult adventure appeal and confidence, not modern clothing or a copied character design. Keep the 1870s visible through woven linen and cotton, fitted vests and bodices, brass buttons, ties, leather belts, worn boots and riding skirts. Short skirts, split hems and petticoat edges are welcome alongside short riding breeches. Express the daring coverage through shortened hems, tied blouses, rolled sleeves, open necklines and adventurous tailoring. Earlier halter/shorts studies establish coverage, not historical authenticity; avoid generic contemporary gym tops, stretch fabrics, modern zippers or denim cutoffs.

## Period identity with Weird West freedom

The September 8 period reminder reinforces an 1870s foundation without requiring museum reconstruction. Fantastical tailoring and steampunk equipment belong to this world's own makers. Keep visible construction legible: woven cloth, seams, lacing, buttons, buckles, layered leather and repaired hems. Use these materials to achieve the already accepted adult adventure coverage. Mechanical accessories should connect to a character's work or supernatural practice.

For the next wardrobe variants, Eleanor can wear a short split riding skirt over opaque riding drawers with a tied linen blouse; Ada can wear a fitted waistcoat, rolled blouse sleeves and a shortened leather tool apron over riding breeches; Ines can wear an asymmetric wrapped trail skirt with an opaque tied blouse and a patterned shoulder shawl. These are production examples, not newly approved outfits. Preserve each woman's identity, adult proportions and readable silhouette through movement. Skirt openings and walking poses must retain opaque coverage across every frame.

## Master before variants before motion

The user's latest production unit is four full sprite sheets per character, with unique newly drawn artwork and complete action-specific sequences. Do not substitute single-pose generations, copied padding, recolored duplicates or miscellaneous pose banks for this requirement. Organize each motion row as an explicit cycle with its required contact, support, passing and opposite phases; record the intended direction and action before generation. A generated row that repeats the leading leg remains incomplete even when every cell differs pixel-for-pixel. The first large-sheet batch under `kits/big-sheets/` supplies four new source sheets for each of Eleanor, Ada and Ines; its observed sequence limitations remain separate from this target.

Build a few detailed masters, then derive wardrobe and identity variants from their retained references. A wardrobe sheet contains alternative static states, never consecutive walk frames. Each extracted state records source hash, crop, cell, pivot, adult identity, outfit ID and admission status.

For movement, preserve the accepted master detail across near contact, near passing, opposite contact and opposite passing. Equipment, limb depth, planted foot and body volume must agree before extending the cycle. Retain failed attempts outside runtime selection. The coarse Ada east walk v6 is rejected as a production basis following the user's screenshot feedback; its source remains for provenance.

## Accepted wardrobe reference

Production efficiency correction: sheet width is not an animation length. Use only distinct required poses per action. Two different four-pose actions may share an eight-column row. Reuse existing neutral/return frames through frame-index metadata rather than generating them again. Do not generate reverse turn poses when reversing an existing compatible sequence suffices. A repeated four-pose half is not an eight-phase walk; preserve the existing useful poses and target only the missing opposite contacts.

Latest proportion and garment correction: keep adult figures visibly slender with small, understated busts. The fuller Eleanor thighs and chest were rejected. Use fewer garments with clear construction and only one leg garment: a skirt OR trousers, not a skirt layered over trousers or shorts. Eleanor's current candidate is a tucked blouse, one blue walking-slit skirt and boots; Ada should use one pair of fitted trousers with a blouse. Earlier cropped-blouse/ambiguous-shorts Eleanor and the subsequent waistcoat/skirt-over-trousers revision are superseded. This does not revoke the broader adult PG13 styling range or make all characters wear the same outfit.

The user explicitly accepted the four Ines summer outfits on September 8 as the general clothing level for the adult cast. Reference: `kits/wardrobe/spirit-scout-summer-v1/source.png`. This accepts clothing coverage and styling; it does not certify animation, game-camera alignment or every body proportion. Preserve this reference for future master and variant prompts.

## Engine metadata and recovered motion

`frame_anchors` may override a clip pivot for a specific global atlas frame. Pivot precedence is frame, then clip, then default; returning to an ordinary frame restores its default. Source-space sockets follow the same sprite transform, including complete-figure reflection. Legacy assets default to one source pixel per world unit. Explicit static facing sets can use real idle views without fabricated walking clips.

The older Ada v6 sequence was rejected at its coarse presentation size, but its corrected source contact remained available at full resolution. `kits/workcycles/ada-detailed-recovered-walk-v1` extracts those original whole figures at 160 pixels, with pelvis registration and raw provenance. This recovers detail; it does not resolve body-volume differences or certify the motion. Its explicitly named review clip retains the provisional four-phase sequence for sheet work.

## Elevated master pass

The `ada-high-angle-v1`, `eleanor-high-angle-v1` and `ines-high-angle-v1` wardrobe folders preserve new detailed southeast camera candidates. They show more crown, shoulder and boot upper surfaces than the earlier eye-level turnaround studies. They are camera references for production, not a measured 40-degree calibration or user-approved room replacement. Ines's additional northeast view is distinct; its companion east attempt remains front-oblique and must not be renamed as a correct profile.

The recovered Eleanor sequence is a pose guide only: its larger raw sources retain coarse original clusters. Larger output dimensions alone are not evidence of added detail. Keep that geometry reference distinct from the newly generated detailed masters. Ada low-pass v2 made only a slight proportion change and remains unselected.

Action clips now share one elapsed-time clock for pose sampling and their release event. Frame holds determine both; listeners read sockets from the release frame even if a display hitch skips over it. This engine contract improves event reliability without certifying an art sequence.
