"""Lossless sheet-only playback of retained four-pose review sequences; no game launch."""
from pathlib import Path
import hashlib
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
for name in ['ada-detailed-recovered-walk-v1', 'eleanor-detailed-recovered-walk-v1']:
    folder = ROOT / 'kits/workcycles' / name
    spec = json.loads((folder / 'actor-spec.json').read_text(encoding='utf-8'))
    clip = spec['clips']['review_walk_east']
    assert clip['admitted'] is False and spec['runtime_admitted'] is False
    atlas = Image.open(ROOT / spec['texture'].removeprefix('res://')).convert('RGBA')
    frames = []
    for index in clip['frames']:
        x, y, width, height = spec['frames'][index]['atlas_rect']
        frames.append(atlas.crop((x, y, x+width, y+height)))
    times = [round(seconds * 1000) for seconds in clip['durations']]
    target = folder / 'walk-review.png'
    frames[0].save(target, save_all=True, append_images=frames[1:],
                   duration=times, loop=0, disposal=1, blend=0)
    restored = Image.open(target)
    assert restored.n_frames == len(frames)
    hashes = []
    for index, frame in enumerate(frames):
        restored.seek(index)
        assert restored.convert('RGBA').tobytes() == frame.tobytes()
        assert round(restored.info['duration']) == times[index]
        hashes.append(hashlib.sha256(frame.tobytes()).hexdigest())
    (folder / 'walk-review.json').write_text(json.dumps({
        'format': 'animated_png', 'source': 'actor-spec.json', 'texture': 'walk-review.png',
        'frames': clip['frames'], 'frame_rgba_sha256': hashes, 'duration_ms': times,
        'runtime_admitted': False, 'usage': spec['usage'],
        'note': 'Lossless whole-cell playback for sheet work; not movement or art approval.',
    }, indent=2) + '\n', encoding='utf-8')
print('MOTION PREVIEWS PASS: two lossless four-pose APNGs, exact RGBA pixels and 160ms frame holds; no game rendering')
