"""Extract a continuous generated performance without inventing poses or tweens.

Run only after source.mp4 exists. Raw decoded frames and native whole cutouts are
retained. All frames share one source-coordinate registration and one scale.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

HERE = Path(__file__).resolve().parent
FPS = 12
CELL = 256
ANCHOR = (128, 244)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def make_review_candidate(run: Path, source: Path) -> None:
    """Select a chronological source interval without changing any cell pixels."""
    metadata_path = run / 'metadata.json'
    metadata = json.loads(metadata_path.read_text(encoding='utf-8'))
    frames = metadata['frames']
    if len(frames) < 37:
        raise ValueError('Candidate selection24..35 and closure36 require37frames.')
    destination = run / 'candidate-24-35'
    destination.mkdir(exist_ok=True)
    selected = frames[24:36]
    cells = [Image.open(run / f['cell_image']).convert('RGBA') for f in selected]
    atlas = Image.new('RGBA', (1024, 768))
    contact = Image.new('RGB', (1024, 834), '#282622')
    draw = ImageDraw.Draw(contact)
    for i, (cell, frame) in enumerate(zip(cells, selected)):
        x, y = (i % 4) * 256, (i // 4) * 256
        atlas.paste(cell, (x, y))
        contact.paste(cell, (x, (i // 4) * 278), cell)
        draw.text((x + 5, (i // 4) * 278 + 259), f'{frame["index"]:03d}  {frame["time_seconds"]:.3f}s', fill='#f5e4b9')
    atlas.save(destination / 'atlas.png')
    contact.save(destination / 'contact-sheet.png')
    durations = [round((i + 1) * 1000 / FPS) - round(i * 1000 / FPS) for i in range(12)]
    cells[0].save(destination / 'timeline.apng', format='PNG', save_all=True, append_images=cells[1:],
                  duration=durations, loop=0, disposal=0, blend=0)
    closure = Image.open(run / frames[36]['cell_image']).convert('RGBA')
    comparison = Image.new('RGBA', (768, 256))
    for i, cell in enumerate([cells[0], cells[-1], closure]):
        comparison.paste(cell, (i * 256, 0))
    comparison.save(destination / 'closure-24-35-36.png')
    ffprobe = shutil.which('ffprobe')
    probe = None
    if ffprobe:
        result = subprocess.run([ffprobe, '-v', 'error', '-show_entries',
                                 'format=duration:stream=avg_frame_rate,duration,nb_frames', '-of', 'json', str(source)],
                                text=True, capture_output=True, timeout=30, check=True)
        probe = json.loads(result.stdout)
    metadata['source_probe'] = probe
    metadata['endpoint_review'] = {'last_sample_index': 60, 'last_sample_time_seconds': frames[-1]['time_seconds'],
                                   'last_equals_previous_decoded_png': frames[-1]['raw_sha256'] == frames[-2]['raw_sha256'],
                                   'last_equals_first_decoded_png': frames[-1]['raw_sha256'] == frames[0]['raw_sha256'],
                                   'note': 'Source is121frames at24fps,5.041667s. Sample5.000 is within source, not assumed extra duplicate endpoint.'}
    metadata_path.write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    actor_frames = [{'atlas_rect': [i % 4 * 256, i // 4 * 256, 256, 256], 'anchor': [128, 244],
                     'source_frame': f['index'], 'timestamp_seconds': f['time_seconds'], 'duration_seconds': 1 / 12,
                     'source_cell_sha256': f['cell_sha256']} for i, f in enumerate(selected)]
    spec = {'texture': 'atlas.png', 'cell': [256, 256], 'anchor': [128, 244], 'pixels_per_world_unit': 4,
            'default_facing': 'southeast', 'frames': actor_frames,
            'clips': {'idle_southeast': {'frames': [0], 'fps': 1, 'loop': True},
                      'review_walk_southeast': {'frames': list(range(12)), 'fps': 12, 'loop': True, 'admitted': False}},
            'status': 'review_candidate_not_runtime_admitted', 'source_frame_indices': list(range(24, 36)),
            'source_video_sha256': metadata['source_sha256'], 'registration': 'Exact existing extracted cells; no changes',
            'review': ['Chronological one-second selection2.000..2.917; not arbitrary pose reordering.',
                       'Visible alternating leg silhouettes and passing positions; exact anatomical phase names remain unassigned.',
                       'Frame36 approximately returns toward24pose but pixel-identical closure not claimed.',
                       'No source-edge-contact frames in selected interval.'],
            'closure': {'comparison_order': [24, 35, 36], 'first_equals_closure_rgba': cells[0].tobytes() == closure.tobytes(),
                        'next_source_frame': 36}}
    (destination / 'actor-spec.json').write_text(json.dumps(spec, indent=2) + '\n', encoding='utf-8')
    (destination / 'selection.json').write_text(json.dumps({'source_frame_indices': list(range(24, 36)),
        'frame_durations_seconds': [1 / 12] * 12, 'apng_durations_ms': durations, 'phase_labels': None,
        'source_metadata': '../metadata.json', 'duration_seconds': 1, 'admitted': False}, indent=2) + '\n', encoding='utf-8')
    print(f'REVIEW CANDIDATE READY: {destination / "contact-sheet.png"}')


def key_whole(image: Image.Image) -> tuple[Image.Image, tuple[int, int, int, int]]:
    """Chroma extraction only; no paint, closing, hole filling or limb assembly."""
    rgba = np.array(image.convert('RGBA'))
    rgb = rgba[:, :, :3].astype(np.int16)
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    magenta = ((red >= 80) & (blue >= 70) & (blue > red * .65)
               & (red > green * 1.8) & (blue > green * 1.8))
    foreground = (~magenta) & (rgba[:, :, 3] >= 128)
    labels, count = ndimage.label(foreground)
    if not count:
        raise ValueError('Frame contains no non-magenta subject.')
    sizes = np.bincount(labels.ravel())
    sizes[0] = 0
    largest = int(sizes.max())
    # Discard isolated codec specks only. Keep every substantial disconnected
    # piece in the original position, including hands, hair and attached tools.
    minimum = max(8, math.ceil(largest * .0005))
    keep = sizes >= minimum
    keep[0] = False
    visible = keep[labels]
    rgba[:, :, 3] = np.where(visible, 255, 0)
    rgba[~visible] = 0
    result = Image.fromarray(rgba)
    bounds = result.getbbox()
    if bounds is None:
        raise ValueError('Chroma extraction produced an empty figure.')
    return result, bounds


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=HERE / 'source.mp4')
    parser.add_argument('--ffmpeg', default=shutil.which('ffmpeg'))
    args = parser.parse_args()
    source = args.source.resolve()
    if not source.is_file():
        parser.error(f'Waiting for video: {source}. No extraction has run.')
    if not args.ffmpeg:
        parser.error('ffmpeg is unavailable.')
    video_hash = sha(source)
    run = HERE / 'extracted' / video_hash[:16]
    if (run / 'metadata.json').exists():
        print(f'Already extracted this source: {run / "metadata.json"}')
        make_review_candidate(run, source)
        return
    raw_dir, native_dir, cell_dir = (run / name for name in ('raw', 'native', 'cells'))
    for directory in (raw_dir, native_dir, cell_dir):
        directory.mkdir(parents=True, exist_ok=True)
    command = [str(args.ffmpeg), '-hide_banner', '-nostdin', '-y', '-i', str(source),
               '-an', '-sn', '-vf', f'fps={FPS}:start_time=0,showinfo',
               '-fps_mode', 'passthrough', str(raw_dir / '%05d.png')]
    result = subprocess.run(command, text=True, capture_output=True, timeout=300)
    (run / 'decode.log').write_text(result.stderr, encoding='utf-8')
    if result.returncode:
        raise RuntimeError(f'ffmpeg failed; see {run / "decode.log"}')
    timestamps = {}
    for match in re.finditer(r'\bn:\s*(\d+)\s+pts:\s*(-?\d+)\s+pts_time:\s*([-+\d.eE]+)', result.stderr):
        timestamps[int(match[1])] = {'pts': int(match[2]), 'pts_time': float(match[3])}
    paths = sorted(raw_dir.glob('*.png'))
    if not paths:
        raise RuntimeError('ffmpeg returned no decoded frames.')
    if len(timestamps) != len(paths):
        raise RuntimeError('Decoded frame/timestamp count mismatch; refusing inferred timestamp labels.')
    frames = []
    source_size = None
    for index, path in enumerate(paths):
        image = Image.open(path).convert('RGBA')
        if source_size is None:
            source_size = image.size
        if image.size != source_size:
            raise ValueError('Video frame dimensions changed.')
        keyed, bounds = key_whole(image)
        native = keyed.crop(bounds)
        native_path = native_dir / path.name
        native.save(native_path)
        frames.append({'index': index, 'time_seconds': timestamps[index]['pts_time'],
                       'filter_pts': timestamps[index]['pts'], 'sample_time_exact': f'{index}/{FPS}',
                       'raw_image': path.relative_to(run).as_posix(), 'raw_sha256': sha(path),
                       'source_bounds_xyxy': list(bounds), 'native_size': list(native.size),
                       'native_image': native_path.relative_to(run).as_posix(),
                       'native_rgba_sha256': hashlib.sha256(native.tobytes()).hexdigest(),
                       'touches_source_edge': bounds[0] == 0 or bounds[1] == 0 or bounds[2] == image.width or bounds[3] == image.height,
                       'phase': None, 'phase_status': 'not_yet_visually_reviewed'})
    union = [min(f['source_bounds_xyxy'][0] for f in frames), min(f['source_bounds_xyxy'][1] for f in frames),
             max(f['source_bounds_xyxy'][2] for f in frames), max(f['source_bounds_xyxy'][3] for f in frames)]
    max_height = max(f['native_size'][1] for f in frames)
    # One transform for the entire performance: preserve vertical bob, foot
    # travel and silhouette-volume changes. Never center each frame separately.
    scale = min(160 / max_height, 240 / (union[2] - union[0]), 232 / (union[3] - union[1]))
    reference_x = (union[0] + union[2]) / 2
    reference_ground_y = union[3]
    cells = []
    columns = 8
    rows = math.ceil(len(frames) / columns)
    atlas = Image.new('RGBA', (columns * CELL, rows * CELL))
    contact = Image.new('RGB', (columns * CELL, rows * (CELL + 22)), '#282622')
    draw = ImageDraw.Draw(contact)
    font = ImageFont.load_default()
    for frame in frames:
        native = Image.open(run / frame['native_image']).convert('RGBA')
        box = frame['source_bounds_xyxy']
        size = (max(1, round(native.width * scale)), max(1, round(native.height * scale)))
        offset = (round(ANCHOR[0] + (box[0] - reference_x) * scale),
                  round(ANCHOR[1] + (box[1] - reference_ground_y) * scale))
        if offset[0] < 0 or offset[1] < 0 or offset[0] + size[0] > CELL or offset[1] + size[1] > CELL:
            raise ValueError('Registered subject would be clipped by output cell.')
        cell = Image.new('RGBA', (CELL, CELL))
        cell.paste(native.resize(size, Image.Resampling.NEAREST), offset)
        index = frame['index']
        cell_path = cell_dir / f'{index + 1:05d}.png'
        cell.save(cell_path)
        x, y = index % columns * CELL, index // columns * CELL
        atlas.paste(cell, (x, y))
        contact.paste(cell, (x, index // columns * (CELL + 22)), cell)
        draw.text((x + 5, index // columns * (CELL + 22) + CELL + 3),
                  f'{index:03d}  {frame["time_seconds"]:.3f}s', font=font, fill='#f5e4b9')
        frame.update({'cell_image': cell_path.relative_to(run).as_posix(), 'atlas_rect': [x, y, CELL, CELL],
                      'anchor': list(ANCHOR), 'offset': list(offset), 'scaled_size': list(size),
                      'alpha_bounds_xyxy': list(cell.getbbox()), 'cell_sha256': sha(cell_path),
                      'duration_seconds': 1 / FPS})
        cells.append(cell)
    atlas.save(run / 'atlas.png')
    contact.save(run / 'contact-sheet.png')
    # This replays extracted frames only, not a manufactured or approved loop.
    durations = [round((i + 1) * 1000 / FPS) - round(i * 1000 / FPS) for i in range(len(cells))]
    cells[0].save(run / 'timeline.apng', format='PNG', save_all=True, append_images=cells[1:],
                  duration=durations, loop=1, disposal=0, blend=0)
    metadata = {'id': 'ada-continuous-walk-v1', 'status': 'extracted_unreviewed_not_admitted',
                'source_video': str(source), 'source_sha256': video_hash, 'source_dimensions': list(source_size),
                'sampling_fps': FPS, 'sampling': 'ffmpeg fps sample selection; no optical flow or generated interpolation',
                'timestamp_basis': 'showinfo timestamps on sampled output timebase; sample_time_exact is n/12 seconds',
                'fps_filter_caveat': 'fps filter may repeat decoded source frames if input rate is below12; repeats are retained',
                'frame_count': len(frames), 'cell': [CELL, CELL], 'anchor': list(ANCHOR),
                'uniform_scale': scale, 'requested_max_figure_height': 160,
                'actual_max_figure_height': max(f['scaled_size'][1] for f in frames),
                'source_union_xyxy': union, 'source_registration_origin': [reference_x, reference_ground_y],
                'registration': 'one source-coordinate transform for all frames; ground uses lowest valid subject pixel across sequence',
                'registration_limits': 'No per-frame recentering or body normalization. Camera motion, translation and bob remain visible.',
                'chroma_key': 'R>=80,B>=70,B>.65R,R>1.8G,B>1.8G; binaryalpha; tiny isolated codec components omitted',
                'atlas': 'atlas.png', 'contact_sheet': 'contact-sheet.png', 'inspection_timeline': 'timeline.apng',
                'timeline_note': 'Chronological source-performance inspection only; loop=1. Not a seamless-loop claim.',
                'frames': frames, 'source_edge_contact_frames': [f['index'] for f in frames if f['touches_source_edge']],
                'clips': {}, 'phase_admission': False,
                'provenance': {'command': command, 'figure_edits': 'none; no painting, limb rebuilding or interpolation'}}
    (run / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    print(f'CONTINUOUS EXTRACTION READY: {len(frames)} sampled frames; inspect {run / "contact-sheet.png"}')
    make_review_candidate(run, source)


if __name__ == '__main__':
    main()
