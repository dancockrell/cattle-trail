"""Validate extracted whole-character families and publish a production catalog.

Does not generate, draw, recolor, rescale or admit art. Source family records own
their visual review; this checks paths, hashes, alpha, cells and stable IDs.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
BANK = ROOT / 'kits/character-families'


def source_path(value):
    if not isinstance(value, str):
        raise ValueError('A source path must be a string')
    path = (ROOT / value.removeprefix('res://')).resolve()
    if not path.is_relative_to(ROOT) or not path.is_file():
        raise ValueError(f'Missing or external source: {value}')
    return path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build():
    families, variants, ids = [], [], set()
    for record in sorted(BANK.rglob('family.json')):
        family = json.loads(record.read_text(encoding='utf-8-sig'))
        master = source_path(family['master_image'])
        sheet = source_path(family['variant_sheet'])
        atlas_path = source_path(family['atlas'])
        atlas = Image.open(atlas_path)
        assert atlas.mode == 'RGBA', f'{record}: expected RGBA atlas'
        cell = family['cell_size']
        anchor = family['anchor']
        assert len(cell) == len(anchor) == 2
        assert all(type(n) is int and n > 0 for n in cell)
        assert all(type(n) is int and 0 <= n < cell[i] for i, n in enumerate(anchor))
        used = set()
        for item in family['variants']:
            visual_id = item['id']
            assert isinstance(visual_id, str) and visual_id and visual_id not in ids
            ids.add(visual_id)
            assert type(item['age']) is int and item['age'] >= 18
            rect = item['rect']
            assert len(rect) == 4 and all(type(n) is int for n in rect)
            x, y, w, h = rect
            assert [w, h] == cell and x >= 0 and y >= 0
            assert x+w <= atlas.width and y+h <= atlas.height
            assert (x, y) not in used
            used.add((x, y))
            crop = atlas.crop((x, y, x+w, y+h))
            assert crop.getbbox(), f'Empty sprite: {visual_id}'
            assert set(crop.getchannel('A').tobytes()) <= {0, 255}, f'Soft alpha: {visual_id}'
            status = item.get('status', 'candidate')
            assert status in ('candidate', 'approved', 'rejected')
            if status == 'rejected':
                continue
            variants.append({
                **item, 'family': item.get('family', family['id'].removesuffix('-batch02')), 'status': status,
                'atlas': 'res://' + atlas_path.relative_to(ROOT).as_posix(),
                'anchor': anchor, 'animation_status': 'static_identity_only',
                'pixel_sha256': hashlib.sha256(crop.tobytes()).hexdigest(),
            })
        families.append({
            'id': family['id'], 'record': record.relative_to(ROOT).as_posix(),
            'master_image': master.relative_to(ROOT).as_posix(), 'master_sha256': digest(master),
            'variant_sheet': sheet.relative_to(ROOT).as_posix(), 'sheet_sha256': digest(sheet),
            'atlas': atlas_path.relative_to(ROOT).as_posix(), 'atlas_sha256': digest(atlas_path),
            'cell_size': cell, 'anchor': anchor, 'count': len(family['variants']),
        })
    assert families, 'No extracted family records found'
    result = {'version': 1, 'status': 'production_catalog_not_room_population',
              'families': families, 'variants': variants,
              'counts': {'families': len({v['family'] for v in variants}),
                         'master_images': len({f['master_sha256'] for f in families}),
                         'batches': len(families), 'static_variants': len(variants),
                         'approved': sum(v['status'] == 'approved' for v in variants),
                         'animation_clips': 0}}
    (BANK / 'catalog.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(f"CHARACTER CATALOG PASS: {result['counts']['master_images']} masters, {len(families)} batches, {len(variants)} static variants; alpha, cells, hashes and adult ages checked")


if __name__ == '__main__':
    build()
