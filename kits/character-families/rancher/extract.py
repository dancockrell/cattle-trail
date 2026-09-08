"""Deterministic whole-character key, trim and nearest-neighbor atlas assembly."""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).resolve().parent
source = HERE / 'variants-v1.png'
raw = Image.open(source).convert('RGBA')
a = np.array(raw)
key = (a[:,:,0] > a[:,:,1].astype(float)*1.7) & (a[:,:,2] > a[:,:,1].astype(float)*1.7) & (a[:,:,2] > a[:,:,0].astype(float)*0.7)
seed = np.zeros_like(key)
seed[0,:] = key[0,:]
seed[-1,:] = key[-1,:]
seed[:,0] = key[:,0]
seed[:,-1] = key[:,-1]
connected = ndimage.binary_propagation(seed, mask=key)
# Include same source-background hue inside enclosed arm/torso gaps.
key = connected | key
foreground = ~key
labels, count = ndimage.label(foreground)
objects = ndimage.find_objects(labels)
components = []
for i, box in enumerate(objects, 1):
    if box is None or np.count_nonzero(labels[box] == i) < 2000:
        continue
    y, x = box
    components.append((x.start, y.start, x.stop, y.stop))
assert len(components) == 16, components
components.sort(key=lambda b: (round((b[1]+b[3])/2 / (raw.height/4)), b[0]))
# Row grouping by vertical centers, then horizontal position avoids irregular padding.
components.sort(key=lambda b: (b[1]+b[3])/2)
components = sum([sorted(components[i:i+4]) for i in range(0,16,4)], [])
a[key,3] = 0
a[~key,3] = 255
keyed = Image.fromarray(a)
atlas = Image.new('RGBA', (256,256))
variants = []
for i, box in enumerate(components):
    crop = keyed.crop(box)
    crop.save(HERE / f'rancher-{i+1:02d}-trim.png')
    size = (round(crop.width * 40 / crop.height), 40)
    sprite = crop.resize(size, Image.Resampling.NEAREST)
    x, y = (i%4)*64, (i//4)*64
    atlas.alpha_composite(sprite, (x+32-size[0]//2,y+61-size[1]))
    variants.append({'id':f'rancher_{i+1:02d}','rect':[x,y,64,64],'age':24,
                     'status':'candidate','facing':'southeast','pose':'idle',
                     'source_rect':[box[0],box[1],box[2]-box[0],box[3]-box[1]],
                     'scaled_size':list(size),'romance_status':'unassigned'})
atlas.save(HERE/'atlas.png')
atlas.resize((1024,1024),Image.Resampling.NEAREST).save(HERE/'atlas-review.png')
prefix = 'kits/character-families/rancher/'
record = {'id':'rancher','master_image':prefix+'master-v1.png',
          'variant_sheet':prefix+'variants-v1.png','atlas':prefix+'atlas.png',
          'cell_size':[64,64],'anchor':[32,61],'variants':variants,
          'animation_clips':{'idle':{'frame_count':1,'loop':False}},
          'tool':'builtin image_gen','reference':'kits/source/eleanor-lantern-v1.png',
          'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
          'processing':'Border-connected magenta hue key R>1.7G B>1.7G B>0.7R, alpha binary; whole-character trim; nearest resize to height40; foot anchor32,61',
          'review':'Sixteen intact differentiated adult rancher sprites; PG13 wardrobe. Static identity candidates only. Master has opaque painted background and is reference-only. Source is smoother and more frontal than runtime; nearest downsample inspected, no animation or in-game approval.'}
(HERE/'family.json').write_text(json.dumps(record,indent=2)+'\n')
assert set(np.array(atlas)[:,:,3].flatten()) <= {0,255}
print('RANCHER: 16 whole-character variants; 256x256 binary-alpha atlas; 64px cells, 32,61 anchor; no animation claim')



