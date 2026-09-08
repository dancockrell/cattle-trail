from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent.parent / 'source' / 'crossing-spirit-v1.png'
source = Image.open(SOURCE).convert('RGBA')
pixels = np.array(source)
rgb = pixels[:, :, :3].astype(np.int16)
key = ((rgb[:, :, 0] - rgb[:, :, 1]) > 50) & ((rgb[:, :, 2] - rgb[:, :, 1]) > 50)
pixels[key] = [0, 0, 0, 0]
pixels[~key, 3] = 255
rgba = Image.fromarray(pixels)
w, h = source.size
boxes = [(c*w//2, r*h//2, (c+1)*w//2, (r+1)*h//2) for r in range(2) for c in range(2)]
crops = []
for box in boxes:
    region = rgba.crop(box)
    trim = region.getbbox()
    assert trim is not None
    crops.append((region.crop(trim), trim))
scale = 38 / max(crop.height for crop, _ in crops)
atlas = Image.new('RGBA', (288, 64))
review = Image.new('RGB', (1152, 310), '#38483d')
draw = ImageDraw.Draw(review)
states = ['wary', 'agitated', 'listening', 'settled']
frames = []
for i, ((crop, trim), box) in enumerate(zip(crops, boxes)):
    size = (round(crop.width*scale), round(crop.height*scale))
    offset = ((72-size[0])//2, 61-size[1])
    cell = Image.new('RGBA', (72, 64))
    cell.paste(crop.resize(size, Image.Resampling.NEAREST), offset)
    cell.save(HERE / (states[i] + '.png'))
    atlas.paste(cell, (i*72, 0))
    enlarged = cell.resize((288, 256), Image.Resampling.NEAREST)
    review.paste(enlarged, (i*288, 0), enlarged)
    draw.text((i*288+16, 273), f'{i}: {states[i]} / NE', fill='white')
    frames.append({'index': i, 'state': states[i], 'actual_body_facing': 'northeast', 'anchor': [36, 61],
        'source_row': i//2, 'source_col': i%2, 'source_cell_ltrb': list(box), 'trim_ltrb_in_cell': list(trim),
        'atlas_rect_xywh': [i*72, 0, 72, 64], 'scaled_size': list(size), 'cell_offset': list(offset),
        'rgba_sha256': hashlib.sha256(cell.tobytes()).hexdigest()})
atlas.save(HERE / 'atlas.png')
review.save(HERE / 'contact-sheet.png')
metadata = {'schema_version': 1, 'status': 'source_candidate_not_globally_admitted', 'character': 'crossing_spirit',
    'encounter': 'Lanterns at Ford', 'source': 'kits/source/crossing-spirit-v1.png',
    'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'source_dimensions': [w, h],
    'reference': 'kits/source/longhorn-rear-v3.png', 'source_grid': [2, 2], 'texture': 'atlas.png',
    'atlas_size': [288, 64], 'cell': [72, 64], 'anchor': [36, 61], 'frames': frames,
    'clips': {name: {'frames': [i], 'fps': 1, 'loop': False, 'presentation': 'static state hold'} for i, name in enumerate(states)},
    'processing': {'key': 'R-G>50 and B-G>50', 'alpha': 'binary0/255; transparent pixels all RGBAzero',
        'shared_scale': scale, 'max_whole_sprite_height': 38, 'resampling': 'nearest',
        'whole_sprite_only': True, 'detached_limbs_or_redrawing': False},
    'inspection': {'direction': 'Northeast body orientation in all four states; head turns slightly to communicate emotion.',
        'states': ['Guarded standing', 'Head raised, mouth open, low forehoof lift', 'Head cocks and neck relaxes', 'Lowered head, calm stance'],
        'anatomy': 'Whole cattle silhouettes with complete hooves, tail and horn contours; settled far horn partly occluded by head angle.',
        'palette': 'Pale turquoise/seafoam/ivory with dark teal edges; opaque source silhouette for optional runtime alpha.',
        'not_a_walk_cycle': True}}
(HERE / 'metadata.json').write_text(json.dumps(metadata, indent=2)+'\n', encoding='utf-8')
assert set(np.unique(np.array(atlas)[:, :, 3])).issubset({0, 255})
assert len({frame['rgba_sha256'] for frame in frames}) == 4
print(json.dumps({'source': [w,h], 'atlas': list(atlas.size), 'cell': [72,64], 'anchor': [36,61], 'states': states}))
