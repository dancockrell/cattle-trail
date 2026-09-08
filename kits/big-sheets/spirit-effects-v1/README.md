# Spirit effects sheet — candidate extraction

Four rows of eight independently depicted phases: spectral bell, cold embers, crow shadow, and fireflies. The complete original is preserved in `source.png`; extraction never paints, resizes, mirrors, or pads the sequence with copied frames.

`atlas.png` is 2048 × 1024 with 256 × 256 cells. Original nominal grid cells retain fixed registration, centered in each atlas cell, with a four-source-pixel border inset to remove generated grid lines. Anchor `[128,128]` is the fixed source-cell center, not a ground contact or bell suspension socket. Surviving RGB pixels are unchanged. Source alpha is thresholded at 128 to yield hard transparency; this intentionally removes diffuse glow. Metadata records each exact source rectangle and placement offset.

Each named `*-review.png` is an eight-frame APNG at 125 milliseconds per frame, looping for review. These are authored timing proposals, not timestamps from continuous motion. No row is certified as a polished motion loop or admitted to runtime. Bell angles do not wrap smoothly; embers retain some stone-contour drift; folded crow phases alter body proportions; firefly paths do not establish a coherent spiral. Static bell index 2, embers index 8 and crow index 16 retain clean recognizable complete silhouettes after extraction.

Run `python extract.py` from any directory to reproduce all derived images and metadata. Root production owns `prompt.txt` and must preserve the exact generation prompt there.
