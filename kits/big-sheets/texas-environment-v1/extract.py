"""Extract the actual 64 environment figures; preserve native pixels and sources."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).resolve().parent
source = HERE / 'source.png'
im = Image.open(source).convert('RGBA')
rgb = np.array(im)[:, :, :3].astype(int)
# The generated transparency is baked checkerboard. Remove only neutral light
# regions connected to the image border, leaving enclosed rock shading intact.
neutral = (rgb.max(2)-rgb.min(2) <= 18) & (rgb.min(2) >= 145)
labels, _ = ndimage.label(neutral)
outside = np.unique(np.concatenate([labels[0], labels[-1], labels[:,0], labels[:,-1]]))
outside = outside[outside != 0]
background = np.isin(labels, outside)
# Vegetation/deadwood have enclosed checkerboard holes between branches. Their
# warm highlights are chromatic. Retain enclosed neutral shading only in rocks.
background[:791] |= neutral[:791]
background[922:] |= neutral[922:]
rgba = np.array(im)
rgba[:, :, 3] = np.where(background, 0, 255)
rgba[background] = 0
clean = Image.fromarray(rgba)
clean.save(HERE/'transparent-source.png')
rows = [0,155,307,467,616,791,922,1065,1262]
categories = ['dry_grass','mixed_grass','flowers','shrubs','cactus_yucca','rocks','deadwood','saplings']
atlas = Image.new('RGBA',(2048,2048))
records=[]
(HERE/'native').mkdir(exist_ok=True)
for row in range(8):
    for col in range(8):
        index=row*8+col
        box=(round(col*im.width/8),rows[row],round((col+1)*im.width/8),rows[row+1])
        cell=clean.crop(box)
        bound=cell.getbbox()
        if bound is None: raise ValueError(f'Empty item {index}')
        figure=cell.crop(bound)
        if max(figure.size)>244: raise ValueError(f'Unexpected oversize {index}')
        target=HERE/'native'/f'{categories[row]}-{col+1:02}.png'
        figure.save(target)
        x=128-figure.width//2;y=244-figure.height
        atlas.paste(figure,(col*256+x,row*256+y))
        records.append({'id':f'{categories[row]}_{col+1:02}','index':index,
            'category':categories[row],'source_cell_xyxy':box,
            'source_figure_xyxy':[box[0]+bound[0],box[1]+bound[1],box[0]+bound[2],box[1]+bound[3]],
            'native_file':target.relative_to(HERE).as_posix(),'native_size':figure.size,
            'native_sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
            'atlas_rect':[col*256,row*256,256,256],'anchor':[128,244],
            'scale':1,'status':'candidate','runtime_admitted':False})
atlas.save(HERE/'atlas.png')
(HERE/'metadata.json').write_text(json.dumps({'schema_version':1,'source':'source.png',
    'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
    'source_size':im.size,'reference':'source/concept-start.jpg',
    'generation':'built-in imagegen','requested_items':64,'extracted_items':64,
    'transparency':'neutral checkerboard keyed globally for vegetation/deadwood, border-connected only for rocks; binary alpha',
    'texture':'atlas.png','cell':[256,256],'source_scale':1,'runtime_admitted':False,
    'items':records},indent=2)+'\n',encoding='utf-8')
print('EXTRACTED: 64 native environment items, no resizing, exact source crops and anchors')
