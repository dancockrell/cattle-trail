# Rich-kit room integration — 2026-09-07

The default playable Clear Fork room uses selected rich-kit actors and scenery. Original assets remain preserved; `--original` runs the previous comparison room. The current 528-cell kit browser remains available with K.

## Measured runtime selection

`assets/room-art.json` is the default room's source of truth; `tools/curate_room.py` rebuilds it from the extraction catalog and original wagon metadata. Current selection contains 162 distinct actor frames (161 from expanded kits plus one original wagon), 30 distinct scenery variants, and 40 scenery placements. Only named selected clips are constructed by the room. Unused frames in the source atlas are not counted as integrated behavior.

The rider now also has northeast/northwest oblique sheets generated directly from the approved original rider reference, including planted, dust-free idle strips. The runtime chooses these angles on diagonal travel and starts in northeast idle. The northwest sheet's wrong-side extended lasso frame is excluded, with a correctly facing overhead hold in its place. Other oblique rider/cattle directions remain open work.

`assets/rider-anchors.json` measures shared per-clip body/hoof anchors. It corrects action-strip centering (up to eight native pixels in north shooting) without editing atlas pixels or cancelling motion within a strip. Rebuild with tools/align_rider.py before tools/curate_room.py. `tools/validate_room_art.py` checks selected frame bounds, anchors, event indices and terrain provenance. `--pose-review` renders stationary action/facing comparisons against the original approved rider.

- Rider: four requested facings for walk/idle, lasso and shoot. Short actions retain their pose until playback completes instead of being overwritten by movement every frame.
- Three cattle appearances: walk/idle in four facings. Graze/rest strips with known camera turns are excluded.
- Eleanor: directional walk/idle frames and two standing talk gestures. Bag-changing medical/camp strips are excluded.
- Rustler: directional walk/idle, including corrected north/west source sheets. Reaction strips are excluded.
- Scenery: grass, trees, rocks, scrub and camp variants use actual transparent atlas pixels. Tall props and actors share ground-anchor Y sorting; grass renders below hooves. Tree/rock foot circles provide collision data without visible geometric art. Fence connectivity is still excluded.

## Verification

Latest pass: action events are explicit in the selected sprite manifest. Shooting applies damage and the trace on the firing pose; lasso attachment waits for the extended-loop pose. Events fire once per action. The HUD shows remaining rope time. Movement cadence tracks actual travel, facing changes retain gait phase, and small diagonal changes use hysteresis. Wagon collision applies to cattle as well as the rider. Compact controls use two rows and are bounds-checked at 360/390-pixel widths.

`continuous-play.mp4` is a 31-second actual Godot recording that starts at the normal spawn, rides to Eleanor, clears the rustler, and gathers all six cattle. The controller is scripted, but it uses normal travel and public actions throughout with no actor teleports. The run passed its completion assertion. This provides stronger gameplay evidence than the isolated setup-based test, which is retained separately. Final anatomical/anchor consistency remains an art review task.

Godot 4.3 rendered the complete updated room. The integration test passed real target movement, four-direction selection, lasso action retention, action expiry, scenery contact resolution, dialogue, shooting, rustler clearance, cattle following, all-six settlement, cash completion and narrow layout. It caught a boundary collision defect, which was fixed and retested.

`room-desktop.png`, `room-complete.png` and `room-phone.png` are current engine screenshots. `room-playback.mp4` is a 16-second recording of the automated engine integration test: it deliberately moves the player to setup positions between scenarios, then uses actual herding/lasso following. It is not a claim of uninterrupted manual play.

## Visual assessment

The room now visibly contains the richer sprites, the original wagon and sampled interface textures. A new empty-ground derivative made from the approved concept replaces the repeated strip collage; its raw source, exact prompt, checksum and nearest reduction are preserved. It has irregular shoulders and continuous wagon ruts, with no characters baked into it. Trees were repositioned to keep new crowns inside the room; cattle starts were staggered. Nearest sampling and pixel snapping remain enabled.

This is an integrated visual-review build, not final art approval. Generated action cadence, foot contact and cross-facing proportions require further polish; cardinal sprite poses do not reproduce every diagonal in the approved concept. The field remains a single room with the same objective. No wider journey, economy or faction scope was added.
