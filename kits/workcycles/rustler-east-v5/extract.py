"""Deterministic whole-sprite extraction; no generated or redrawn body parts."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent.parent / 'source' / 'rustler-east-v5.png'
image = Image.open(SOURCE).convert('RGBA')
pixels = np.array(image)
rgb = pixels[:, :, :3].astype(np.int16)
key = ((rgb[:, :, 0] - rgb[:, :, 1]) > 50) & ((rgb[:, :, 2] - rgb[:, :, 1]) > 50)
pixels[key] = [0, 0, 0, 0]
pixels[~key, 3] = 255
rgba = Image.fromarray(pixels)
w, h = rgba.size
boxes = [(c * w // 2, r * h // 2, (c + 1) * w // 2, (r + 1) * h // 2) for r in range(2) for c in range(2)]
crops = []
for box in boxes:
    region = rgba.crop(box)
    trim = region.getbbox()
    if trim is None:
        raise ValueError('Empty source cell')
    crops.append((region.crop(trim), trim))
scale = 40 / max(crop.height for crop, _ in crops)
atlas = Image.new('RGBA', (256, 64), (0, 0, 0, 0))
contact = Image.new('RGB', (1024, 340), '#383b38')
draw = ImageDraw.Draw(contact)
frames = []
for index, ((crop, trim), box) in enumerate(zip(crops, boxes)):
    size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    sprite = crop.resize(size, Image.Resampling.NEAREST)
    cell = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
    offset = ((64 - size[0]) // 2, 61 - size[1])
    cell.paste(sprite, offset)
    cell.save(HERE / f'frame-{index:02}.png')
    atlas.paste(cell, (index * 64, 0))
    enlarged = cell.resize((256, 256), Image.Resampling.NEAREST)
    contact.paste(enlarged, (index * 256, 20), enlarged)
    draw.text((index * 256 + 12, 282), f'Frame {index}: ' + ('contact-like' if index % 2 == 0 else 'narrow stance'), fill='white')
    frames.append({'index': index, 'source_cell_ltrb': list(box), 'trim_ltrb_in_source_cell': list(trim),
        'source_row': index // 2, 'source_col': index % 2, 'atlas_rect_xywh': [index * 64, 0, 64, 64],
        'anchor': [32, 61], 'scaled_size': list(size), 'cell_offset': list(offset),
        'whole_frame_sha256': hashlib.sha256(cell.tobytes()).hexdigest()})
atlas.save(HERE / 'atlas.png')
contact.save(HERE / 'contact-sheet.png')
metadata = {'schema_version': 1, 'status': 'candidate_not_admitted', 'family': 'rustler', 'direction': 'east',
    'source': 'kits/source/rustler-east-v5.png', 'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'source_dimensions': [w, h], 'source_grid': [2, 2], 'texture': 'atlas.png', 'atlas_size': [256, 64],
    'cell': [64, 64], 'anchor': [32, 61], 'anchor_meaning': 'Ground baseline, cell-local pixels, y down',
    'processing': {'key_rule': 'R-G > 50 and B-G > 50', 'alpha': 'binary 0/255, zero RGB under transparency',
        'scale': scale, 'scale_policy': 'One common scale to maximum whole-body height 40px; nearest neighbor only',
        'body_parts': 'Whole source sprites only; no detached limbs or painted reconstruction'},
    'frames': frames,
    'clip': {'name': 'walk_east_candidate', 'frames': [0, 1, 2, 3], 'durations_seconds': [0.14] * 4,
        'loop_proposed': True, 'phase_order_verified': False, 'runtime_admitted': False},
    'inspection': {'whole_bodies': True, 'consistent_east_heading': True,
        'limitations': ['Frames0/2 repeat similar lead-leg contact silhouettes rather than demonstrating opposite contact.',
            'Lower trouser colors shift gray in contact-like poses and brown in narrow poses.',
            'Frame1/3 do not clearly establish opposite passing-leg identity. Coherent walking correction remains unproven.']}}
(HERE / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
assert set(np.unique(np.array(atlas)[:, :, 3])).issubset({0, 255})
assert len({f['whole_frame_sha256'] for f in frames}) == 4
print(json.dumps({'frames': len(frames), 'source_size': [w, h], 'atlas_size': list(atlas.size), 'scale': scale}))
