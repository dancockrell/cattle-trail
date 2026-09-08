"""Extract eight intact facing studies; no limb edits or invented tween frames."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_propagation

BASE = Path(__file__).resolve().parent
DIRECTIONS = ['south', 'southeast', 'east', 'northeast', 'north', 'northwest', 'west', 'southwest']
source = Image.open(BASE / 'source.png').convert('RGBA')
native = []
for index in range(8):
    column, row = index % 4, index // 4
    region = (round(column * source.width / 4), round(row * source.height / 2),
              round((column + 1) * source.width / 4), round((row + 1) * source.height / 2))
    pixels = np.array(source.crop(region))
    rgb = pixels[:, :, :3].astype(int)
    neutral = (rgb.max(2) - rgb.min(2) < 22) & (rgb.min(2) > 165)
    seeds = np.zeros(neutral.shape, dtype=bool)
    seeds[0, :] = neutral[0, :]
    seeds[-1, :] = neutral[-1, :]
    seeds[:, 0] = neutral[:, 0]
    seeds[:, -1] = neutral[:, -1]
    background = binary_propagation(seeds, mask=neutral)
    pixels[:, :, 3] = np.where(background, 0, 255)
    cut = Image.fromarray(pixels)
    bounds = cut.getbbox()
    assert bounds and bounds[0] > 0 and bounds[1] > 0 and bounds[2] < cut.width and bounds[3] < cut.height, (index, bounds)
    trim = cut.crop(bounds)
    trim.save(BASE / f'frame-{index:02d}-native.png')
    native.append((trim, [region[0] + bounds[0], region[1] + bounds[1], trim.width, trim.height]))

scale = 160 / max(trim.height for trim, _ in native)
atlas = Image.new('RGBA', (1024, 512))
frames, cells = [], []
for index, (trim, source_rect) in enumerate(native):
    size = (round(trim.width * scale), round(trim.height * scale))
    offset = (128 - size[0] // 2, 244 - size[1])
    cell = Image.new('RGBA', (256, 256))
    cell.alpha_composite(trim.resize(size, Image.Resampling.NEAREST), offset)
    cell.save(BASE / f'frame-{index:02d}.png')
    cells.append(cell)
    ax, ay = index % 4 * 256, index // 4 * 256
    atlas.alpha_composite(cell, (ax, ay))
    frames.append({'index': index, 'facing': DIRECTIONS[index], 'source_rect': source_rect,
                   'atlas_rect': [ax, ay, 256, 256], 'anchor': [128, 244], 'offset': list(offset),
                   'native_sha256': hashlib.sha256((BASE / f'frame-{index:02d}-native.png').read_bytes()).hexdigest()})
atlas.save(BASE / 'atlas.png')
cells[0].save(BASE / 'rotation-review.png', save_all=True, append_images=cells[1:], duration=220, loop=0, disposal=0, blend=0)
limits = [
    'Eight held facings, not a walk cycle or approved interpolated turn.',
    'Braid placement and accessory side vary; no tween or continuity approval.',
    'Border-connected checker removal protects white blouse; enclosed checker remnants may remain.',
    'Common nearest scale and bottom registration are static review alignment, not proven foot lock.',
    'Camera elevation is shallower than the intended high three-quarter room camera.'
]
metadata = {'schema_version': 1, 'id': 'eleanor_turn_v4', 'character_id': 'eleanor', 'age': 24,
            'source': 'source.png', 'source_size': list(source.size),
            'source_sha256': hashlib.sha256((BASE / 'source.png').read_bytes()).hexdigest(),
            'earlier_source': 'source-earlier.png',
            'earlier_source_sha256': hashlib.sha256((BASE / 'source-earlier.png').read_bytes()).hexdigest(),
            'atlas': 'atlas.png', 'cell': [256, 256], 'anchor': [128, 244], 'pixels_per_world_unit': 4,
            'uniform_scale': scale, 'frames': frames, 'runtime_admitted': False,
            'status': 'eight_facing_static_review', 'animation_clips': {}, 'limitations': limits,
            'processing': 'Border-connected neutral checker key; intact native cutouts; one nearest-neighbor scale; no repainting, mirroring, or limb reconstruction.',
            'rotation_review': {'file': 'rotation-review.png', 'frames': list(range(8)), 'duration_ms_per_frame': 220,
                                'purpose': 'Inspect facing continuity; this preview is not an admitted gameplay animation.'}}
(BASE / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
spec = {'schema_version': 1, 'character_id': 'eleanor', 'age': 24, 'status': 'static_facing_review',
        'runtime_admitted': False, 'usage': 'candidate_art',
        'texture': 'res://kits/wardrobe/eleanor-turn-v4/atlas.png',
        'cell': [256, 256], 'anchor': [128, 244], 'pixels_per_world_unit': 4,
        'directional': True, 'default_facing': 'southeast',
        'frames': [{'index': frame['index'], 'atlas_rect': frame['atlas_rect']} for frame in frames],
        'clips': {f'idle_{direction}': {'frames': [index], 'fps': 1, 'loop': False} for index, direction in enumerate(DIRECTIONS)},
        'turn_transitions': {}, 'limits': limits,
        'texture_sha256': hashlib.sha256((BASE / 'atlas.png').read_bytes()).hexdigest()}
spec['clips']['idle'] = {'frames': [1], 'fps': 1, 'loop': False}
(BASE / 'actor-spec.json').write_text(json.dumps(spec, indent=2) + '\n')
assert set(np.unique(np.array(atlas)[:, :, 3])) <= {0, 255}
assert len({frame['native_sha256'] for frame in frames}) == 8
print('Eight unique intact facings extracted; binary alpha; static clips only.')
