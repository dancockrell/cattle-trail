from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
h=Path(__file__).resolve().parent
source=Image.open(h/'source.png').convert('RGBA')
a=np.array(source)
key=(a[:,:,0]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,0].astype(float)*.7)
a[key,3]=0
a[~key,3]=255
source=Image.fromarray(a)
atlas=Image.new('RGBA',(768,192))
frames=[]
names=['cream_offshoulder_split_skirt','brown_vest_riding_shorts','rust_offshoulder_hat','olive_blouse_tan_shorts']
for i,name in enumerate(names):
    x0=i*source.width//4
    part=source.crop((x0,0,(i+1)*source.width//4,source.height))
    box=part.getbbox()
    assert box and box[0]>0 and box[1]>0 and box[2]<part.width and box[3]<part.height
    trim=part.crop(box)
    trim.save(h/f'{name}-full-resolution.png')
    size=(round(trim.width*160/trim.height),160)
    offset=(96-size[0]//2,184-size[1])
    cell=Image.new('RGBA',(192,192))
    cell.alpha_composite(trim.resize(size,Image.Resampling.NEAREST),offset)
    cell.save(h/f'{name}-whole-frame.png')
    atlas.alpha_composite(cell,(i*192,0))
    frames.append({'id':name,'rect':[i*192,0,192,192],'source_rect':[x0+box[0],box[1],box[2]-box[0],box[3]-box[1]],'size':list(size),'offset':list(offset),'status':'high_detail_candidate'})
atlas.save(h/'atlas.png')
atlas.save(h/'native-preview.png')
atlas.resize((1536,384),Image.Resampling.NEAREST).save(h/'preview-2x.png')
ref=h.parents[1]/'character-families/rancher/master-v1.png'
meta={'version':1,'character':'eleanor','age':24,'family':'rancher','purpose':'static_summer_wardrobe_identity_study',
    'cell':[192,192],'anchor':[96,184],'body_height':160,'atlas':'atlas.png','frames':frames,
    'source':'source.png','source_sha256':hashlib.sha256((h/'source.png').read_bytes()).hexdigest(),
    'reference':'kits/character-families/rancher/master-v1.png','reference_sha256':hashlib.sha256(ref.read_bytes()).hexdigest(),
    'prompt':'prompt.txt','tool':'builtin image_gen','actual_facing':'southeast_oblique_front',
    'runtime_admitted':False,'animation_clips':{},
    'processing':'Source background magenta hue key, intact wholefigure trim, nearest-neighbor160pxheight in192cells. Full-resolution transparent trims retained. No drawing, rigging, recoloring or interpolation.',
    'observation':'Four intact adult24 Eleanor wardrobe candidates retain braid, boots and compass. Opaque tops, bare shoulders/midriff, shorts and split skirts provide requested PG13 summerstyle. Face/hands/clothes readable at160pixels.',
    'limitations':['User quality correction supersedes originally requested40px output; no40pxatlas produced.','Static wardrobe variations are not walk phases.','Camera remains more frontal than runtimehighangle.','Generated styling has more bust definition than minimal-bust brief; retained as candidate, not approved identity replacement.']}
(h/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
assert set(np.array(atlas)[:,:,3].flatten())<={0,255}
print('RANCHER SUMMER: 4highdetailwholefigures;160pxheight192cells96,184anchor; fullresolutiontrims preserved;binaryalpha')
