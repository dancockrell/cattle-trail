from pathlib import Path
from PIL import Image
import numpy as np
import json,hashlib
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
def keyed(path):
    image=Image.open(path).convert('RGBA')
    a=np.array(image)
    key=(a[:,:,0]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,0].astype(float)*.7)
    a[key,3]=0
    a[~key,3]=255
    return Image.fromarray(a)
source=keyed(HERE/'source.png')
crops=[]
for i in range(4):
    x,y=(i%2)*source.width//2,(i//2)*source.height//2
    part=source.crop((x,y,x+source.width//2,y+source.height//2))
    box=part.getbbox()
    assert box and box[0]>0 and box[1]>0 and box[2]<part.width and box[3]<part.height
    crop=part.crop(box)
    crops.append((crop,[x+box[0],y+box[1],box[2]-box[0],box[3]-box[1]]))
scale=64/max(c.height for c,_ in crops)
atlas=Image.new('RGBA',(480,96))
frames=[]
directions=['southeast','north','south','southwest']
for i,(crop,rect) in enumerate(crops):
    size=(round(crop.width*scale),round(crop.height*scale))
    cell=Image.new('RGBA',(96,96))
    offset=(48-size[0]//2,90-size[1])
    cell.alpha_composite(crop.resize(size,Image.Resampling.NEAREST),offset)
    cell.save(HERE/f'{directions[i]}-whole-frame.png')
    crop.save(HERE/f'{directions[i]}-trim.png')
    atlas.alpha_composite(cell,(i*96,0))
    frames.append({'id':'occupied_'+directions[i],'frame':i,'actual_facing':directions[i],
        'source_rect':rect,'rect':[i*96,0,96,96],'size':list(size),'offset':list(offset),
        'status':'candidate' if i!=1 else 'rejected_mechanical_continuity',
        'observation':'Two complete seated adults, whole cart.' if i!=1 else 'Crew faces away but boiler remains on camera side; inconsistent with front boiler in other views. Do not admit as north runtime direction.'})
empty=keyed(HERE/'empty-source.png')
box=empty.getbbox()
empty=empty.crop(box)
empty.save(HERE/'empty-trim.png')
# Match parked chassis width to occupied southeast, rather than matching shorter empty height.
width=frames[0]['size'][0]
size=(width,round(empty.height*width/empty.width))
cell=Image.new('RGBA',(96,96))
offset=(48-size[0]//2,90-size[1])
cell.alpha_composite(empty.resize(size,Image.Resampling.NEAREST),offset)
cell.save(HERE/'empty-southeast-whole-frame.png')
atlas.alpha_composite(cell,(384,0))
frames.append({'id':'empty_southeast','frame':4,'actual_facing':'southeast','rect':[384,0,96,96],
    'source_rect':[box[0],box[1],box[2]-box[0],box[3]-box[1]],'size':list(size),'offset':list(offset),
    'status':'candidate','observation':'Two empty seats, no crew; chassis width matches occupied southeast. Cushion construction differs slightly.'})
atlas.save(HERE/'atlas.png')
atlas.resize((1920,384),Image.Resampling.NEAREST).save(HERE/'review.png')
sources={name:hashlib.sha256((HERE/name).read_bytes()).hexdigest() for name in ['source.png','empty-source.png']}
meta={'version':1,'id':'ada_steam_cart','cell':[96,96],'anchor':[48,90],'atlas':'atlas.png',
    'frames':frames,'source_sha256':sources,'prompts':['prompt.txt','empty-prompt.txt'],'tool':'builtin image_gen',
    'reference_paths':['kits/source/ada-mercer-idle-v1.png','kits/source/rider-v1.png'],
    'crew':[{'id':'ada_mercer','age':22,'role':'driver'},{'id':'trail_boss','adult':True,'age_note':'Explicit adult in prompt; exact age not specified','role':'passenger'}],
    'runtime_admitted':False,'animation_clips':{},
    'processing':'Whole-vehicle crop, source-magenta hue key including wheel gaps, binaryalpha, uniform occupied sheet scale to max64high, nearestresampling, footbaseline90. Empty matched to SE chassis width. No body or vehicle part reconstruction.',
    'limitations':['Diagonal east/west requests produced southeast/southwest, recorded honestly.','North has mechanical continuity error and is rejected.','Static heading images only, no wheel loop or turn animation.','Empty seat design varies slightly; candidates require root selection.']}
(HERE/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
assert set(np.array(atlas)[:,:,3].flatten())<={0,255}
print('STEAM CART: 4 occupied views + 1 empty; 96cells anchor48,90; north continuity rejected; no motion claim')

