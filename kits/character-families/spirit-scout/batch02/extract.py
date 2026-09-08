"""Extract complete generated figures; never paint or recombine anatomy."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
source = HERE / 'source.png'
image = Image.open(source).convert('RGBA')
pixels = np.array(image)
# Generated uniform magenta chroma field, including near-magenta edge pixels.
rgb = pixels[:, :, :3].astype(int)
key = (rgb[:, :, 0] > 80) & (rgb[:, :, 2] > 80) & (rgb[:, :, 1] < rgb[:, :, 0] * .70) & (rgb[:, :, 1] < rgb[:, :, 2] * .70)
pixels[key] = 0
pixels[~key, 3] = 255
clean = Image.fromarray(pixels)
atlas = Image.new('RGBA', (256, 256))
variants = []
for i in range(16):
    row, col = divmod(i, 4)
    # Observed empty gutters: the generated rows are slightly nonuniform.
    rows = [0, 320, 610, 900, 1254]
    cols = [0, 320, 640, 950, 1254]
    assert image.size == (1254,1254), 'Reinspect source gutters if size changes'
    box = (cols[col], rows[row], cols[col+1], rows[row+1])
    cell = clean.crop(box)
    bounds = cell.getbbox()
    assert bounds, f'Empty variant {i}'
    figure = cell.crop(bounds)
    width = round(figure.width * 40 / figure.height)
    assert width < 60, f'Invalid wide figure {i}'
    small = figure.resize((width, 40), Image.Resampling.NEAREST)
    frame = Image.new('RGBA', (64, 64))
    frame.paste(small, (32 - width // 2, 21))
    frame.save(HERE / f'spirit_scout_{i+17:02}.png')
    atlas.paste(frame, (col * 64, row * 64))
    variants.append({'id':f'spirit_scout_{i+17:02}', 'rect':[col*64,row*64,64,64], 'age':23+(i%4), 'status':'candidate', 'pose':'idle', 'direction':'southeast', 'source_cell':list(box), 'source_trim_bounds':list(bounds), 'frame':f'kits/character-families/spirit-scout/batch02/spirit_scout_{i+17:02}.png', 'animations':{'idle':{'frames':[i],'fps':0,'loop':False}}})
atlas.save(HERE / 'atlas.png')
atlas.resize((1024,1024),Image.Resampling.NEAREST).save(HERE / 'atlas-review.png')
metadata = {'schema_version':1,'id':'spirit-scout-batch02','family':'spirit-scout','master_name':'Ines Vale','master_age':23,'master_image':'kits/character-families/spirit-scout/master-v1.png','variant_sheet':'kits/character-families/spirit-scout/batch02/source.png','atlas':'kits/character-families/spirit-scout/batch02/atlas.png','cell_size':[64,64],'anchor':[32,61],'variants':variants,'generation':{'tool':'builtin image_gen','date':'2026-09-08','model':'not exposed by tool','master_prompt':'../master.prompt.txt','variant_prompt':'prompt.txt'},'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'master_sha256':hashlib.sha256((HERE.parent/'master-v1.png').read_bytes()).hexdigest(),'transform':'4x4 whole-cell extraction, magenta chroma key, whole-figure trim, nearest neighbor scale to40px height, baseline61; no body repaint or recombination','admission':'candidate static idle art; no walk or turn cycle; not shipped runtime','master_limitations':['Costume reference is a soft illustration with opaque gradient backdrop, not runtime art.']}
(HERE/'family.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
assert len(variants)==16
assert set(np.unique(np.array(atlas)[:,:,3])).issubset({0,255})
print('SPIRIT SCOUT EXTRACTION PASS: 16 complete figure cells, 64x64, anchor32,61, binary alpha; candidate idle art only')

