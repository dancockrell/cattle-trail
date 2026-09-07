# Local validation evidence

Godot 4.3 stable, Windows, OpenGL compatibility renderer on NVIDIA RTX 4070.

Latest continuation: the default rich-kit room also passed the full rendered objective test, four-facing selection, action retention/expiry and tree/rock contact checks. Current captures and room-playback.mp4 show this updated room. See ROOM-INTEGRATION.md for the 131-frame/30-variant selection and remaining art limits.

- Original room: actual rendered integration checks passed for mounted movement, Eleanor conversation, ammo/shoot interaction, rustler clearance, lasso following, six cattle settling, completion/cash, reset and narrow layout. The test places the player at setup positions; cattle follow the actual lasso movement loop into the goal.
- Captures: room-desktop.png, room-complete.png and room-phone.png are actual Godot screenshots.
- Rich library: tools/validate_kits.py passed 13 families and 496 unique RGBA cells, checking binary alpha, nonempty padded bounds, anchors, clip indices/rates, original source checksums and exact tree-layer reconstruction.
- Godot kit QA: all 13 families and 496 cells loaded; clip definitions constructed and preview playback rendered. Per-family captures are under kits/reviews/godot-*.png.
- Windows release: exported locally with original gameplay and the rich-kit viewer. Build and source validation do not imply user visual approval.

See kits/DELIVERY.md for explicit generated-art, direction, connectivity and integration limitations. No full-game scope has been added. Git commits are local; no remote publication or push is claimed.
