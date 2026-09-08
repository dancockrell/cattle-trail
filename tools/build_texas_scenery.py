"""Copy sixteen inspected whole Texas sprites without resampling or repainting."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / 'kits/big-sheets/texas-environment-v1'
INDICES = [0, 1, 3, 6, 8, 9, 11, 16, 17, 18, 22, 24, 26, 29, 40, 42]
# Small cover at outer margins; none changes collision or the central routes.
PLACEMENTS = [
    (0, 22, 169), (1, 18, 245), (2, 39, 312), (3, 75, 333),
    (4, 114, 330), (5, 152, 340), (6, 194, 327), (7, 234, 338),
    (8, 277, 330), (9, 307, 345), (10, 349, 333), (0, 384, 342),
    (1, 425, 334), (2, 470, 344), (3, 511, 333), (4, 553, 341),
    (5, 598, 332), (6, 618, 270), (7, 620, 234), (8, 619, 198),
    (9, 619, 156), (10, 608, 94), (11, 561, 84), (12, 485, 82),
    (13, 331, 81), (14, 236, 84), (15, 171, 81), (11, 25, 121),
]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build():
    metadata = json.loads((KIT / 'metadata.json').read_text(encoding='utf-8'))
    assert digest(KIT / 'source.png') == metadata['source_sha256']
    clean = Image.open(KIT / 'transparent-source.png').convert('RGBA')
    atlas = Image.new('RGBA', (1024, 1024))
    frames = []
    for ordinal, index in enumerate(INDICES):
        item = metadata['items'][index]
        native_path = KIT / item['native_file']
        assert digest(native_path) == item['native_sha256']
        native = Image.open(native_path).convert('RGBA')
        assert native.tobytes() == clean.crop(item['source_figure_xyxy']).tobytes()
        assert native.width <= 256 and native.height <= 244
        assert set(native.getchannel('A').getdata()) <= {0, 255}
        x, y = ordinal % 4 * 256, ordinal // 4 * 256
        offset = (128 - native.width // 2, 244 - native.height)
        atlas.paste(native, (x + offset[0], y + offset[1]))
        assert atlas.crop((x + offset[0], y + offset[1], x + offset[0] + native.width, y + offset[1] + native.height)).tobytes() == native.tobytes()
        frames.append({'id': item['id'], 'source_index': index, 'category': item['category'],
                       'region': [x, y, 256, 256], 'anchor': [128, 244],
                       'native_size': list(native.size), 'native_offset': list(offset),
                       'source_figure_xyxy': item['source_figure_xyxy'],
                       'source_native': str(native_path.relative_to(ROOT)).replace('\\', '/'),
                       'source_native_sha256': digest(native_path)})
    target = ROOT / 'assets/texas-scenery.png'
    atlas.save(target)
    placements = []
    for ordinal, x, y in PLACEMENTS:
        frame = frames[ordinal]
        width, height = frame['native_size']
        left = x + (frame['native_offset'][0] - 128) / 4
        top = y - height / 4
        assert 0 <= left and left + width / 4 <= 640 and 0 <= top and y <= 360
        placements.append({'family': 'texas_groundcover', 'frame': ordinal,
                           'texture': 'res://assets/texas-scenery.png',
                           'region': frame['region'], 'anchor': frame['anchor'],
                           'position': [x, y], 'pixels_per_world_unit': 4,
                           'ground_cover': True, 'collision_radius': 0,
                           'source_frame_id': frame['id']})
    result = {'schema_version': 1, 'status': 'selected_for_room_review',
              'source': 'kits/big-sheets/texas-environment-v1/source.png',
              'source_sha256': metadata['source_sha256'],
              'cleaned_source': 'kits/big-sheets/texas-environment-v1/transparent-source.png',
              'cleaned_source_sha256': digest(KIT / 'transparent-source.png'),
              'texture': 'res://assets/texas-scenery.png', 'texture_sha256': digest(target),
              'texture_size': [1024, 1024], 'pixels_per_world_unit': 4,
              'method': 'Inspected whole native crops copied byte-exactly into fixed cells; no resampling, repainting or invented variants. Nearest runtime sampling.',
              'selection_note': 'Sixteen small grasses, flowers, shrubs and stones. Twenty-eight outer-margin placements, zero new collision. Source inspection is separate from final room acceptance.',
              'frames': frames, 'placements': placements}
    (ROOT / 'assets/texas-scenery.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(f'TEXAS SCENERY PASS: {len(frames)} exact whole crops; {len(placements)} bounded non-colliding placements')
    return result

if __name__ == '__main__':
    build()
