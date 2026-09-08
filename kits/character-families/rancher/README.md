# Rancher character family

Generated with the built-in image generation tool on 2026-09-08, using Eleanor's existing lantern sheet as identity and style input. The master is a complex costume and equipment reference with four complete bodies and detail studies. It is not an animation or transparent runtime asset; the generator returned an opaque backdrop.

The second generation derives sixteen different adult (24-year-old) ranchers from that master. Outfits express the user's PG13 direction through opaque cropped and tied tops, bare shoulders and midriffs, shorts and slit skirts. Each is an independent identity, not a gait phase. Actual observed facing is southeast, somewhat more frontal than the requested elevated camera. All remain candidate assets pending visual admission.

`extract.py` reproducibly locates sixteen whole bodies, removes the magenta source-background hue, including enclosed gaps between arms and body, trims each intact sprite and scales with nearest-neighbor to 40 pixels high. It places feet at (32,61) in 64x64 cells. Atlas size is 256x256, alpha is strictly 0 or 255. `family.json` records source rectangles, output rectangles, age, anchor, processing, SHA256 and status. No limbs are drawn, rigged, interpolated or assembled.

Both raw sources and exact prompts are retained. `atlas-review.png` is a nearest-neighbor enlarged atlas inspected for complete silhouettes, wardrobe variation and magenta fringe removal. Fine master detail is lost at runtime size; this is a static batch basis and provides no walk/turn clips or in-engine validation. Master source was generated as exec-c91ba896-99c9-4759-81c9-e3da4d44956c.png; variants as exec-1771a6a7-fd04-4991-b9b9-1d958c4e4070.png. Model/version and credit usage were not exposed by the tool.

Second batch: "batch02/" adds sixteen darker-skinned adult ranchers with braided, coiled and loose hair, varied hats, embroidered garments, turquoise jewellery and equipment belts. Its separate family.json identifies rancher_17 through rancher_32. Raw generation: exec-3b36ba11-e467-468f-b2bb-fd11b913d058.png. Inspected the complete source sheet and enlarged native atlas. No motion or runtime admission claim.

