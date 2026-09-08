"""Package retained whole figures for Actor without inventing missing animation phases."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PACKAGES = [
    ('kits/workcycles/ada-detailed-east-v1', 'ada_mercer', False),
    ('kits/workcycles/eleanor-detailed-east-v1', 'eleanor', False),
    ('kits/workcycles/ines-detailed-east-v1', 'ines_vale', False),
    ('kits/workcycles/ada-detailed-turnaround-v1', 'ada_mercer', True),
    ('kits/wardrobe/ines-period-turnaround-v1', 'ines_vale', True),
    ('kits/workcycles/ada-detailed-recovered-walk-v1', 'ada_mercer', False),
    ('kits/workcycles/eleanor-detailed-recovered-walk-v1', 'eleanor', False),
    ('kits/wardrobe/ines-high-angle-v1', 'ines_vale', False),
    ('kits/wardrobe/ada-high-angle-v1', 'ada_mercer', False),
    ('kits/wardrobe/eleanor-high-angle-v1', 'eleanor', False),
    ('kits/wardrobe/ines-high-angle-views-v1', 'ines_vale', False),
]


def build():
    total = 0
    for relative, character_id, endviews in PACKAGES:
        folder = ROOT / relative
        metadata_path = folder / 'metadata.json'
        metadata = json.loads(metadata_path.read_text(encoding='utf-8'))
        assert isinstance(metadata['age'], int) and metadata['age'] >= 18
        source_hashes = metadata.get('source_sha256')
        if source_hashes is None:
            for record in metadata['frames']:
                digest = hashlib.sha256((ROOT / record['source']).read_bytes()).hexdigest()
                assert digest == record['source_sha256']
                if 'local_raw_copy' in record:
                    assert hashlib.sha256((folder / record['local_raw_copy']).read_bytes()).hexdigest() == digest
        elif isinstance(source_hashes, dict):
            for filename, digest in source_hashes.items():
                assert hashlib.sha256((folder / filename).read_bytes()).hexdigest() == digest
        else:
            source_name = metadata.get('source', 'source.png')
            source_path = ROOT / source_name if source_name.startswith('kits/') else folder / source_name
            assert hashlib.sha256(source_path.read_bytes()).hexdigest() == source_hashes
        texture_name = metadata.get('texture', metadata.get('atlas', 'atlas.png'))
        texture_path = folder / texture_name
        atlas = Image.open(texture_path).convert('RGBA')
        assert set(atlas.getchannel('A').tobytes()) <= {0, 255}
        frames, anchors, clips = [], {}, {}
        for ordinal, record in enumerate(metadata.get('frames', [metadata])):
            rect = record.get('atlas_rect', record.get('atlas_rect_xywh', record.get('rect')))
            assert isinstance(rect, list) and len(rect) == 4 and all(type(n) is int for n in rect)
            x, y, width, height = rect
            assert x >= 0 and y >= 0 and width == height == 256
            assert x + width <= atlas.width and y + height <= atlas.height
            anchor = record.get('anchor', metadata['anchor'])
            assert len(anchor) == 2 and 0 <= anchor[0] < width and 0 <= anchor[1] < height
            image = atlas.crop((x, y, x + width, y + height))
            bounds = image.getbbox()
            assert bounds and bounds[3] - bounds[1] == 160
            observation = record.get('actual_facing', record.get('observed_facing', record.get('observed_pose', record.get('actual_phase', record.get('phase', record.get('status', 'unverified'))))))
            frames.append({'index': ordinal, 'atlas_rect': rect, 'observation': observation,
                           'rgba_sha256': hashlib.sha256(image.tobytes()).hexdigest()})
            anchors[str(ordinal)] = anchor
            name = 'idle_' + record['requested_facing'] if endviews else 'pose_%02d' % ordinal
            clips[name] = {'frames': [ordinal], 'fps': 1, 'loop': False}
        # Actor's required default is a held view, not a claimed idle performance.
        default = 1 if endviews else 0
        clips['idle'] = {'frames': [default], 'fps': 1, 'loop': False}
        recovered = metadata.get('id') == 'ada-detailed-recovered-walk-v1'
        if recovered:
            source_clip = metadata['clips']['walk_east_candidate']
            assert source_clip['admitted'] is False and source_clip['frames'] == [0, 1, 2, 3]
            clips['review_walk_east'] = {'frames': source_clip['frames'], 'fps': source_clip['fps'],
                                        'durations': source_clip['frame_durations'], 'loop': True,
                                        'admitted': False, 'purpose': 'manual sheet review only'}
        if 'review_clip' in metadata:
            source_clip = metadata['review_clip']
            assert metadata['runtime_admitted'] is False and source_clip['frames'] == [0, 1, 2, 3]
            clips['review_walk_east'] = {'frames': source_clip['frames'], 'fps': 6.25,
                                        'durations': source_clip['durations_seconds'], 'loop': True,
                                        'admitted': False, 'purpose': 'manual sheet review only'}
        spec = {
            'schema_version': 1, 'character_id': character_id, 'age': metadata['age'],
            'status': 'candidate_sheet_package', 'runtime_admitted': False,
            'usage': 'pose_reference_only' if folder.name == 'eleanor-detailed-recovered-walk-v1' else 'candidate_art',
            'texture': 'res://' + texture_path.relative_to(ROOT).as_posix(),
            'cell': [256, 256], 'anchor': metadata['anchor'], 'pixels_per_world_unit': 4,
            'directional': endviews, 'default_facing': 'southeast' if len(frames)==1 else 'east',
            'frames': frames, 'frame_anchors': anchors, 'clips': clips,
            'turn_transitions': {}, 'source_metadata': metadata_path.relative_to(ROOT).as_posix(),
            'source_metadata_sha256': hashlib.sha256(metadata_path.read_bytes()).hexdigest(),
            'texture_sha256': hashlib.sha256(texture_path.read_bytes()).hexdigest(),
            'limits': [
                'Not selected by the room or live character factory.',
                'No accepted walk cycle or turn tween. Any review sequence remains unadmitted.',
                'Default idle holds one source pose; it does not certify an idle animation.',
                'Only documented facings exist; camera and costume continuity still need work.',
            ],
        }
        assert not any(name.startswith('walk') for name in clips)
        (folder / 'actor-spec.json').write_text(json.dumps(spec, indent=2) + '\n', encoding='utf-8')
        total += len(frames)
    # Exact whole-cell comparison, without painting or resampling the new masters.
    trio = Image.new('RGBA', (768, 256))
    for index, name in enumerate(['eleanor', 'ada', 'ines']):
        master = Image.open(ROOT / f'kits/wardrobe/{name}-high-angle-v1/atlas.png').convert('RGBA')
        assert master.size == (256, 256)
        trio.paste(master, (index * 256, 0))
    trio.save(ROOT / 'kits/wardrobe/high-angle-master-trio.png')
    print(f'DETAILED ACTOR SPECS PASS: {len(PACKAGES)} packages, {total} real whole figures, source hashes, alpha, 160px figure size, pivots; zero admitted movement clips')


if __name__ == '__main__':
    build()
