"""Select intact authored whole figures; no painted, mirrored or interpolated pixels."""
from pathlib import Path
import hashlib, json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import label, find_objects

OUT = Path(__file__).resolve().parent
SOURCE = OUT.parent / 'sheet04' / 'source-keyed.png'
raw = np.array(Image.open(SOURCE).convert('RGBA'))
labels, _ = label(raw[:, :, 3] > 0)
figures = []
for identifier, region in enumerate(find_objects(labels), 1):
    mask = labels[region] == identifier
    if mask.sum() > 10000:
        figures.append((region, identifier))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

manifest = {'schema_version': 1, 'character': 'Ines Vale', 'age': 23,
    'source': '../sheet04/source-keyed.png', 'source_sha256': sha(SOURCE),
    'raw_source_sha256': sha(SOURCE.with_name('source.png')),
    'runtime_admitted': False, 'cell': [320, 320], 'anchor': [160, 296],
    'method': 'Whole connected source figures, translated by boot support bounds; no scaling, mirroring, painting, interpolation or duplicated padding.',
    'clips': {}}
for name, row, holds, phases in [
    ('idle_breathe', 0, [260,180,180,220,260,180,180,220],
     ['settled','small rise','raised chest','settle','rest','small rise','raised chest','settle']),
    ('spirit_listen', 1, [320,160,180,240,220,280,180,300],
     ['rest','hand to charm','attend to charm','indicate direction','explain direction','listen','hand returns to charm','rest'])]:
    selected = sorted([(s,i) for s,i in figures if (s[0].start < 20 if row == 0 else 230 <= s[0].start <= 260)], key=lambda p:p[0][1].start)
    assert len(selected) == 8
    frames, records = [], []
    atlas = Image.new('RGBA', (320*8,320))
    contact = Image.new('RGB', (320*4,344*2), '#28242b')
    draw = ImageDraw.Draw(contact)
    for index, ((region, identifier), duration, phase) in enumerate(zip(selected,holds,phases)):
        block = raw[region].copy()
        block[labels[region] != identifier] = 0
        ys,xs = np.where(block[:,:,3] > 0)
        support_x = xs[ys >= block.shape[0]-16]
        pivot_x = int(round((int(support_x.min())+int(support_x.max()))/2))
        offset = [160-pivot_x,296-block.shape[0]]
        frame = Image.new('RGBA',(320,320))
        frame.paste(Image.fromarray(block),offset)
        assert np.count_nonzero(np.array(frame)[:,:,3]) == np.count_nonzero(block[:,:,3])
        frames.append(frame)
        atlas.paste(frame,(index*320,0))
        contact.paste(frame,((index%4)*320,(index//4)*344),frame)
        draw.text(((index%4)*320+8,(index//4)*344+322),f'{index+1}: {phase} ({duration} ms)',fill='white')
        records.append({'index': index, 'source_sheet_index': row*8+index,
            'source_rect_xyxy':[region[1].start,region[0].start,region[1].stop,region[0].stop],
            'component_id':identifier, 'source_pixel_count':int(np.count_nonzero(block[:,:,3])),
            'translation_xy':offset,'atlas_rect_xywh':[index*320,0,320,320],
            'duration_ms':duration,'phase':phase,
            'rgba_sha256':hashlib.sha256(frame.tobytes()).hexdigest()})
    assert len({r['rgba_sha256'] for r in records}) == 8
    atlas.save(OUT/f'{name}-atlas.png')
    contact.save(OUT/f'{name}-contact.png')
    frames[0].save(OUT/f'{name}-preview.png',save_all=True,append_images=frames[1:],duration=holds,loop=0,disposal=0,blend=0)
    decoded = Image.open(OUT/f'{name}-preview.png')
    assert decoded.n_frames == 8
    for i, frame in enumerate(frames):
        decoded.seek(i)
        assert decoded.convert('RGBA').tobytes() == frame.tobytes()
        assert decoded.info['duration'] == holds[i]
    manifest['clips'][name] = {'texture':f'{name}-atlas.png','preview':f'{name}-preview.png',
        'loop':True,'seconds':sum(holds)/1000,'facing':'southeast',
        'status':'selected_review_loop_not_runtime_admitted','frames':records,
        'atlas_sha256':sha(OUT/f'{name}-atlas.png'),
        'preview_sha256':sha(OUT/f'{name}-preview.png')}
(OUT/'metadata.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('Ines: two 8-frame loops; all 16 unique frames match source component pixels and APNG durations.')
