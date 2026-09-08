from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
h=Path(__file__).resolve().parent
source=Image.open(h/'source.png').convert('RGBA')
a=np.array(source)
key=(a[:,:,0]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,0].astype(float)*.7)
a[key,3]=0
a[~key,3]=255
source=Image.fromarray(a)
ids=['coffee_pot_closed','coffee_pot_steaming','mugs_full_pair','mugs_empty_pair','blanket_roll','blanket_folded','supplies_crate','lantern_warm']
heights=[16,18,10,10,12,12,20,14]
frames=[]
atlas=Image.new('RGBA',(256,128))
for i,id in enumerate(ids):
    x0=(i%4)*source.width//4
    x1=(i%4+1)*source.width//4
    y0=(i//4)*source.height//2
    y1=(i//4+1)*source.height//2
    region=source.crop((x0,y0,x1,y1))
    box=region.getbbox()
    assert box and box[0]>0 and box[1]>0 and box[2]<region.width and box[3]<region.height
    trim=region.crop(box)
    trim.save(h/f'{id}-trim.png')
    size=(round(trim.width*heights[i]/trim.height),heights[i])
    cell=Image.new('RGBA',(64,64))
    offset=(32-size[0]//2,61-size[1])
    cell.alpha_composite(trim.resize(size,Image.Resampling.NEAREST),offset)
    cell.save(h/f'{id}-whole-frame.png')
    x,y=(i%4)*64,(i//4)*64
    atlas.alpha_composite(cell,(x,y))
    frames.append({'id':id,'frame':i,'rect':[x,y,64,64],'source_rect':[x0+box[0],y0+box[1],box[2]-box[0],box[3]-box[1]],
        'size':list(size),'offset':list(offset),'status':'candidate',
        'use':'camp_detail_static','observation':'Generated blanket is folded, not fully laid out.' if i==5 else 'Whole prop or intact mug pair; no clipping.'})
atlas.save(h/'atlas.png')
atlas.resize((1024,512),Image.Resampling.NEAREST).save(h/'review.png')
meta={'version':1,'id':'camp_tea_kit','cell':[64,64],'anchor':[32,61],'atlas':'atlas.png','frames':frames,
    'source':'source.png','source_sha256':hashlib.sha256((h/'source.png').read_bytes()).hexdigest(),'prompt':'prompt.txt',
    'tool':'builtin image_gen','references':['kits/source/camp.png','kits/source/spirit-lantern-prop-v1.png'],
    'runtime_admitted':False,'animation_clips':{},
    'observation':'Eight actual campprops with matching warm material palette and elevated camera; mugsfull/empty remain wholepairs. Blanket requested laidflat arrived folded, labeled honestly.',
    'limitations':['No full laid blanket in this source.','Pot states are separately generated; do not claim pixel-identical animation.','Steam tint and small highlights simplify at native sizes.'],
    'processing':'Source magenta hue key including handleholes, wholeprop crop, individually declared worldscale10to20pxheight, nearest resize andpadding. No painted geometry or reconstructedparts.'}
(h/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
assert set(np.array(atlas)[:,:,3].flatten())<={0,255}
print('CAMP TEA PASS: 8wholeprops, binaryalpha256x128atlas, 64cells32,61anchor, 10to20pxrelativeheights')
