from pathlib import Path
import json,hashlib
import numpy as np
from scipy import ndimage
from PIL import Image
h=Path(__file__).resolve().parent
raw=Image.open(h/'source.png').convert('RGBA');a=np.array(raw)
key=(a[:,:,0]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,0].astype(float)*.7)
a[key,3]=0;a[~key,3]=255
labels,n=ndimage.label(~key,structure=np.ones((3,3)))
components=[]
for i,box in enumerate(ndimage.find_objects(labels),1):
    if box is None or np.count_nonzero(labels[box]==i)<1500:continue
    y,x=box;components.append((x.start,y.start,x.stop,y.stop))
assert len(components)==48,(len(components),components)
components.sort(key=lambda b:(b[1]+b[3])/2)
components=sum([sorted(components[i:i+8]) for i in range(0,48,8)],[])
rgba=Image.fromarray(a);rgba.save(h/'source-transparent.png')
atlas=Image.new('RGBA',(2048,1536));frames=[]
rows=['southeast_walk_requested','northeast_walk_requested','east_walk_requested','standing_turn_requested','care_lantern_actions','talk_emotes']
directions=['south_southeast','southwest_oblique','northwest','northwest','north','northeast','east_southeast','southeast']
for i,box in enumerate(components):
    crop=rgba.crop(box);crop.save(h/f'{i:02d}-native.png')
    assert crop.width<256 and crop.height<244
    offset=(128-crop.width//2,244-crop.height)
    x,y=(i%8)*256,(i//8)*256
    atlas.alpha_composite(crop,(x+offset[0],y+offset[1]))
    row=i//8
    observation='SE advancing pose; gaitphase unverified' if row==0 else 'NE rear advancing pose; gaitphase unverified' if row==1 else 'Right/east advancing pose; repeatednearlead apparent' if row==2 else directions[i%8] if row==3 else 'Wholebody care/mug/lantern pose; handwritten actionassignment required' if row==4 else 'Wholebody talk/gesture expression'
    frames.append({'index':i,'row':row,'column':i%8,'source_rect':[box[0],box[1],crop.width,crop.height],
        'atlas_rect':[x,y,256,256],'offset':list(offset),'native_size':[crop.width,crop.height],
        'requested_row':rows[row],'observation':observation,'status':'candidate','duration_seconds_provisional':.16})
atlas.save(h/'atlas.png')
ref=h.parents[1]/'wardrobe/eleanor-high-angle-v1/source.png'
meta={'version':1,'id':'eleanor_big_sheet_v1','character':'eleanor','age':24,'grid':[8,6],'figure_count':48,
    'source':'source.png','source_size':list(raw.size),'source_sha256':hashlib.sha256((h/'source.png').read_bytes()).hexdigest(),
    'reference':'kits/wardrobe/eleanor-high-angle-v1/source.png','reference_sha256':hashlib.sha256(ref.read_bytes()).hexdigest(),
    'prompt':'prompt.txt','tool':'builtin image_gen','cell':[256,256],'anchor':[128,244],'atlas':'atlas.png','frames':frames,
    'runtime_admitted':False,'animation_clips':{},'native_scaling':'None. Each crop retains generated source pixels exactly, no resized40pxsprites.',
    'observations':['48 actual complete figures produced in8x6layout.','SE/NE/E motion rows include repeatedlead and unsupportedphase sequences; not certified walks.','Turnrow repeatsNW and misses a clearW endpoint.','Care row includes a crouch and mug/lantern gestures; lastpose has no lantern, not requestedlanternrest.','Talking row offers distinctwave/point/hip/laugh/concern/welcome/nod candidates.'],
    'limitations':['Generator returned1448x1086 rather than requestedlargerresolution; nativefigures are roughly150to180pxhigh.','Outfit identity generallyconsistent; pose/handedness andsteporder requirecuration.','Rowintent neverconfersanimationapproval.'],
    'processing':'Magenta sourcebackground huekey;8connectedcomponent segmentation; completefigure nativecrops; wholefigurepadding in256cells. No drawing or limbassembly.'}
(h/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
assert set(np.array(atlas)[:,:,3].flatten())<={0,255}
print('ELEANOR BIG SHEET PASS:48wholefigures,8x6,2048x1536nativepixelatlas,256cells128244; no movementadmission')
