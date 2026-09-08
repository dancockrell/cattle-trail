"""Package whole atlas cells and readable static review sheets without editing poses."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]


def package(name):
    folder = ROOT / 'kits/workcycles' / name
    metadata_path = folder / 'metadata.json'
    metadata = json.loads(metadata_path.read_text(encoding='utf-8'))
    atlas = Image.open(folder / metadata.get('atlas', 'atlas.png')).convert('RGBA')
    frames = metadata['frames']
    width, height = metadata['cell']
    scale = 3
    review = Image.new('RGB', (len(frames) * width * scale, height * scale + 48), (101, 111, 60))
    draw = ImageDraw.Draw(review)
    font = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 14)
    for ordinal, frame in enumerate(frames):
        x, y, w, h = frame['atlas_rect']
        cell = atlas.crop((x, y, x + w, y + h))
        # Earlier extraction records used temporary cell filenames. Preserve that
        # identifier as provenance, and point file at an actual packaged cell.
        filename = f'frame-{ordinal:02}.png'
        if frame.get('file') != filename:
            frame['extraction_cell_identifier'] = frame.get('file')
        frame['file'] = filename
        cell.save(folder / filename)
        enlarged = cell.resize((width * scale, height * scale), Image.Resampling.NEAREST)
        review.paste(enlarged, (ordinal * width * scale, 40), enlarged)
        label = frame.get('label', frame.get('heading', frame.get('pose', f'pose {ordinal}')))
        draw.text((ordinal * width * scale + 6, 8), f'{ordinal}: {label}', fill=(250, 233, 191), font=font)
    review.save(folder / 'review-sheet.png')
    metadata_path.write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf-8')
    print(f'{name}: {len(frames)} whole frame files and static review sheet')


if __name__ == '__main__':
    for name in ['rider-east-v16', 'eleanor-turn-v1']:
        package(name)
