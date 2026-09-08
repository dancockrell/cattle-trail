from pathlib import Path
from PIL import Image
import numpy as np
import json,hashlib
h=Path(__file__).resolve().parent
raw=Image.open(h/'source.png').convert('RGBA')
a=np.array(raw)
key=(a[:,:,0]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,0].astype(float)*.7)
a[key,3]=0
a[~key,3]=255
im=Image.fromarray(a)
crops=[]
rects=[]
for i in range(2):
    x0=i*im.width//2
    part=im.crop((x0,0,(i+1)*im.width//2,im.height))
    b=part.getbbox()
    assert b[0]>20 and b[1]>20 and b[2]<part.width-20 and b[3]<part.height-20
    crop=part.crop(b)
    crop.save(h/f'phase-{i}-trim.png')
    crops.append(crop)
    rects.append([x0+b[0],b[1],b[2]-b[0],b[3]-b[1]])
scale=64/max(c.height for c in crops)
atlas=Image.new('RGBA',(192,96))
cells=[]
for i,crop in enumerate(crops):
    size=(round(crop.width*scale),round(crop.height*scale))
    cell=Image.new('RGBA',(96,96))
    cell.alpha_composite(crop.resize(size,Image.Resampling.NEAREST),(48-size[0]//2,90-size[1]))
    cell.save(h/f'phase-{i}-whole-frame.png')
    atlas.alpha_composite(cell,(i*96,0))
    cells.append(np.array(cell))
atlas.save(h/'atlas.png')
atlas.resize((1152,576),Image.Resampling.NEAREST).save(h/'comparison.png')
# Upper region excludes wheel centers: differing pixels here falsify an exact wheel-only edit.
mask=(cells[0][:60,:,3]>0)|(cells[1][:60,:,3]>0)
changed=np.any(cells[0][:60]!=cells[1][:60],axis=2)&mask
record={'version':1,'id':'ada_steam_cart_wheel_v1','status':'candidate_nonwheel_drift','direction':'southeast',
    'source':'source.png','source_sha256':hashlib.sha256((h/'source.png').read_bytes()).hexdigest(),
    'reference':'kits/workcycles/ada-steam-cart-v1/southeast-trim.png','prompt':'prompt.txt','tool':'builtin image_gen',
    'cell':[96,96],'anchor':[48,90],'body_height':64,'atlas':'atlas.png','frames':[{'id':f'phase_{i}','rect':[i*96,0,96,96],'source_rect':r} for i,r in enumerate(rects)],
    'upper_body_changed_pixels':int(changed.sum()),'upper_body_visible_union_pixels':int(mask.sum()),
    'runtime_admitted':False,'animation_clips':{},
    'observation':'Both wholecart poses have consistent overall footprint and visible spokes. Right pose adds small steam puffs, but crew clothing, Ada hands and body pixel clusters differ. Spokes change subtly rather than proving a clean directional quarterturn.',
    'limitations':['Two-frame source experiment; not a verified wheel loop.','Generated phase0 itself changes source style/detail slightly.','Upperbody pixel comparison detects nonwheel drift.','Binary key removes source-background contamination; steam edges are provisional.'],
    'processing':'Wholevehicle crop, magenta hue key, common nearest scale to64height, padding; no wheel rotation code, no detached components.'}
(h/'metadata.json').write_text(json.dumps(record,indent=2)+'\n')
print('CART WHEEL CANDIDATE: 2wholeframes; upperbody changed %d/%d pixels; no loop admission' %(changed.sum(),mask.sum()))
