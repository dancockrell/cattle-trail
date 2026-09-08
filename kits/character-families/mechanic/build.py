"""Extract whole sprites; no painting, rigging, recoloring, or invented animation."""
from pathlib import Path
import hashlib
import json
from PIL import Image
import numpy as np
from scipy.ndimage import label, find_objects

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def rel(path): return path.relative_to(ROOT).as_posix()

source = HERE / 'variants.png'
im = Image.open(source).convert('RGBA')
source_pixels = np.array(im)
rgb = source_pixels[:, :, :3].astype(int)
# Generated source has a baked pale checkerboard. Remove this neutral matte,
# preserving the raw image and the character colors without repainting.
matte = (rgb.min(2) >= 210) & (rgb.max(2) - rgb.min(2) <= 12)
source_pixels[:, :, 3] = np.where(matte | (source_pixels[:, :, 3] < 128), 0, 255)
source_pixels[source_pixels[:, :, 3] == 0] = 0
labels, _ = label(source_pixels[:, :, 3] > 0)
sizes = np.bincount(labels.ravel())
objects = [box for index, box in enumerate(find_objects(labels), 1) if sizes[index] > 1000]
assert len(objects) == 16, f'Expected 16 silhouettes, got {len(objects)}'
objects.sort(key=lambda box: (int(((box[0].start + box[0].stop) / 2) / (im.height / 4)), box[1].start))
im = Image.fromarray(source_pixels)
im.save(HERE / 'variants-transparent.png')
atlas = Image.new('RGBA', (256, 256))
specialties = ['boiler', 'clockmaker', 'rail_fitter', 'turbine', 'armorer', 'pump', 'precision', 'walker', 'gauge', 'saddle', 'repair_scout', 'dynamo', 'waterworks', 'clockwork_handler', 'foundry', 'spirit_machine']
variants = []
for i, specialty in enumerate(specialties):
    col, row = i % 4, i // 4
    ys, xs = objects[i]
    box = (xs.start, ys.start, xs.stop, ys.stop)
    crop = im.crop(box)
    pix = np.array(crop)
    pix[:, :, 3] = np.where(pix[:, :, 3] >= 128, 255, 0)
    pix[pix[:, :, 3] == 0] = 0
    crop = Image.fromarray(pix)
    bounds = crop.getbbox()
    assert bounds, f'Empty cell {i}'
    whole = crop.crop(bounds)
    width = round(whole.width * 40 / whole.height)
    assert width <= 54, f'Unexpected width {i}: {width}'
    sprite = whole.resize((width, 40), Image.Resampling.NEAREST)
    frame = Image.new('RGBA', (64, 64))
    frame.paste(sprite, (32 - width // 2, 21))
    frame.save(HERE / f'mechanic_{i+1:02}.png')
    atlas.paste(frame, (col * 64, row * 64))
    variants.append({'id': f'mechanic_{i+1:02}', 'rect': [col * 64, row * 64, 64, 64], 'age': 20 + i % 5, 'status': 'candidate', 'specialty': specialty, 'facing': 'southeast', 'source_region_xyxy': list(box), 'source_alpha_bounds_in_region_xyxy': list(bounds), 'alpha_bounds_xyxy': list(frame.getbbox()), 'image': rel(HERE / f'mechanic_{i+1:02}.png'), 'clips': {'idle_southeast': {'frames': [0], 'fps': 1, 'loop': True}}, 'motion_status': 'static_only_no_walk_or_turn_frames'})
atlas.save(HERE / 'atlas.png')
atlas.resize((1024, 1024), Image.Resampling.NEAREST).save(HERE / 'atlas-preview.png')
family = {'id': 'mechanic', 'version': 1, 'master_image': rel(HERE / 'master.png'), 'variant_sheet': rel(source), 'atlas': rel(HERE / 'atlas.png'), 'cell_size': [64, 64], 'anchor': [32, 61], 'variants': variants, 'provenance': {'tool': 'builtin image_gen', 'model': 'not exposed by tool', 'generated_date': '2026-09-08', 'source_reference': 'kits/source/ada-mercer-idle-v1.png', 'source_reference_sha256': sha(ROOT / 'kits/source/ada-mercer-idle-v1.png'), 'master_sha256': sha(HERE / 'master.png'), 'variants_sha256': sha(source), 'master_prompt': rel(HERE / 'master-prompt.txt'), 'variants_prompt': rel(HERE / 'variants-prompt.txt'), 'transforms': ['equal 4x4 cell crop', 'generated alpha threshold >=128, no RGB repaint', 'whole-sprite alpha-bound crop', 'nearest resize to 40 pixels tall', 'bottom center placement anchor 32,61']}, 'admission': {'runtime': False, 'status': 'candidate_static_family', 'notes': ['Generated raw sources retain original alpha and full resolution.', 'All 16 are distinct static identities, never animation frames.', 'No native motion or in-game testing performed.']}}
family['provenance']['transforms'][0] = 'pale neutral checker matte keyed: min RGB >=210 and channel range <=12; whole connected silhouette bounds'
family['admission']['notes'].append('Raw variant generator returned an opaque checkerboard; keyed transparent derivative reviewed. Pale neutral highlights may be affected by matte key.')
(HERE / 'family.json').write_text(json.dumps(family, indent=2) + '\n', encoding='utf-8')
assert len(variants) == 16
assert set(np.unique(np.array(atlas)[:, :, 3])).issubset({0, 255})
print('MECHANIC FAMILY PASS: 16 whole static sprites, 64px cells, 32/61 anchors, binary alpha; no animation claim')
