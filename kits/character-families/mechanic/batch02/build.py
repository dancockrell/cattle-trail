"""Extract whole sprites; no painting, rigging, recoloring, or invented animation."""
from pathlib import Path
import hashlib
import json
from PIL import Image
import numpy as np
from scipy.ndimage import label, find_objects

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def rel(path): return path.relative_to(ROOT).as_posix()

source = HERE / 'source.png'
im = Image.open(source).convert('RGBA')
source_pixels = np.array(im)
rgb = source_pixels[:, :, :3].astype(int)
# Generated source has a magenta background. Remove this chroma matte,
# preserving the raw image and the character colors without repainting.
matte = (rgb[:, :, 0] >= 80) & (rgb[:, :, 2] >= 70) & (rgb[:, :, 2] > rgb[:, :, 0] * 0.65) & (rgb[:, :, 0] > rgb[:, :, 1] * 1.8) & (rgb[:, :, 2] > rgb[:, :, 1] * 1.8)
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
    frame.save(HERE / f'mechanic_{i+17:02}.png')
    atlas.paste(frame, (col * 64, row * 64))
    variants.append({'id': f'mechanic_{i+17:02}', 'rect': [col * 64, row * 64, 64, 64], 'age': 21 + i % 4, 'status': 'candidate', 'specialty': specialty, 'facing': 'southeast', 'source_region_xyxy': list(box), 'source_alpha_bounds_in_region_xyxy': list(bounds), 'alpha_bounds_xyxy': list(frame.getbbox()), 'image': rel(HERE / f'mechanic_{i+17:02}.png'), 'clips': {'idle_southeast': {'frames': [0], 'fps': 1, 'loop': True}}, 'motion_status': 'static_only_no_walk_or_turn_frames'})
atlas.save(HERE / 'atlas.png')
atlas.resize((1024, 1024), Image.Resampling.NEAREST).save(HERE / 'atlas-preview.png')
family = {'id': 'mechanic-batch02', 'family': 'mechanic', 'version': 1, 'master_image': rel(HERE.parent / 'master.png'), 'variant_sheet': rel(source), 'atlas': rel(HERE / 'atlas.png'), 'cell_size': [64, 64], 'anchor': [32, 61], 'variants': variants, 'provenance': {'tool': 'builtin image_gen', 'model': 'not exposed by tool', 'generated_date': '2026-09-08', 'source_reference': 'kits/source/ada-mercer-idle-v1.png', 'source_reference_sha256': sha(ROOT / 'kits/source/ada-mercer-idle-v1.png'), 'master_sha256': sha(HERE.parent / 'master.png'), 'variants_sha256': sha(source), 'master_prompt': rel(HERE.parent / 'master-prompt.txt'), 'variants_prompt': rel(HERE / 'prompt.txt'), 'transforms': ['equal 4x4 cell crop', 'generated alpha threshold >=128, no RGB repaint', 'whole-sprite alpha-bound crop', 'nearest resize to 40 pixels tall', 'bottom center placement anchor 32,61']}, 'admission': {'runtime': False, 'status': 'candidate_static_family', 'notes': ['Generated raw sources retain original alpha and full resolution.', 'All 16 are distinct static identities, never animation frames.', 'No native motion or in-game testing performed.']}}
family['provenance']['transforms'][0] = 'magenta background and fringe key: R>=80,B>=70,B>0.65R,R>1.8G,B>1.8G; whole connected silhouette bounds'
family['provenance']['correction_prompt'] = rel(HERE / 'fix-prompt.txt')
family['provenance']['rejected_source'] = rel(HERE / 'source-clipped-rejected.png')
family['admission']['notes'].append('First attempt clipped bottom-row feet and is preserved as rejected; source is the corrected layout generation, magenta keyed transparent derivative.')
(HERE / 'family.json').write_text(json.dumps(family, indent=2) + '\n', encoding='utf-8')
assert len(variants) == 16
assert set(np.unique(np.array(atlas)[:, :, 3])).issubset({0, 255})
print('MECHANIC FAMILY PASS: 16 whole static sprites, 64px cells, 32/61 anchors, binary alpha; no animation claim')
