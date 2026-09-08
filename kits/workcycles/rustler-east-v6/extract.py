from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent.parent / 'source' / 'rustler-east-opposite-v6.png'
source = Image.open(SOURCE).convert('RGBA')
pixels = np.array(source)
rgb = pixels[:, :, :3].astype(np.int16)
key = ((rgb[:, :, 0] - rgb[:, :, 1]) > 50) & ((rgb[:, :, 2] - rgb[:, :, 1]) > 50)
pixels[key] = [0, 0, 0, 0]
pixels[~key, 3] = 255
rgba = Image.fromarray(pixels)
trim = rgba.getbbox()
assert trim is not None
whole = rgba.crop(trim)
scale = 40 / whole.height
size = (round(whole.width * scale), 40)
sprite = whole.resize(size, Image.Resampling.NEAREST)
cell = Image.new('RGBA', (64, 64))
offset = ((64 - size[0]) // 2, 21)
cell.paste(sprite, offset)
cell.save(HERE / 'opposite-candidate.png')
cell.save(HERE / 'atlas.png')
original = Image.open(HERE.parent / 'rustler-east-v5' / 'frame-00.png').convert('RGBA')
endpoints = Image.new('RGBA', (128, 64))
endpoints.paste(original, (0, 0))
endpoints.paste(cell, (64, 0))
endpoints.save(HERE / 'endpoint-atlas.png')
review = Image.new('RGB', (768, 440), '#383b38')
draw = ImageDraw.Draw(review)
for i, (picture, label) in enumerate([(original, 'V5 contact reference'), (cell, 'V6 requested opposite: not verified')]):
    enlarged = picture.resize((384, 384), Image.Resampling.NEAREST)
    review.paste(enlarged, (i * 384, 0), enlarged)
    draw.text((i * 384 + 10, 400), label, fill='white')
review.save(HERE / 'endpoint-contact-sheet.png')
metadata = {'schema_version': 1, 'status': 'candidate_repeated_contact_not_admitted', 'family': 'rustler',
    'actual_facing': 'east', 'source': 'kits/source/rustler-east-opposite-v6.png',
    'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'source_dimensions': list(source.size),
    'source_trim_ltrb': list(trim), 'texture': 'atlas.png', 'cell': [64, 64], 'anchor': [32, 61],
    'atlas_rect_xywh': [0, 0, 64, 64], 'scale': scale, 'scaled_size': list(size), 'offset': list(offset),
    'alpha': 'binary, magenta key R-G>50 and B-G>50, transparent RGB zero', 'resampling': 'nearest',
    'whole_body': True, 'detached_parts': False, 'opposite_contact_verified': False,
    'endpoint_reference': {'source': 'kits/source/rustler-east-v5.png', 'source_cell': 0,
        'reference_crop_ltrb': [0, 0, 627, 627], 'sprite': '../rustler-east-v5/frame-00.png'},
    'endpoint_atlas': {'texture': 'endpoint-atlas.png', 'size': [128, 64],
        'frames': [{'role': 'reference', 'rect': [0, 0, 64, 64]}, {'role': 'candidate', 'rect': [64, 0, 64, 64]}]},
    'inspection': 'Same identity, gray lower trouser panels and east heading preserved, but visible leg overlap/leading foot and arm positions remain substantially the same as reference. The requested opposite contact was not achieved. No animation is defined.'}
(HERE / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
assert set(np.unique(np.array(cell)[:, :, 3])).issubset({0, 255})
print(json.dumps({'source': list(source.size), 'trim': trim, 'cell': [64, 64], 'anchor': [32, 61], 'body_height': 40}))
