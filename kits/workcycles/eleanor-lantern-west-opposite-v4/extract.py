from pathlib import Path
from PIL import Image
import numpy as np
import json, hashlib

here=Path(__file__).resolve().parent
raw=Image.open(here/'source.png').convert('RGBA')
a=np.array(raw)
key=(a[:,:,0]>190)&(a[:,:,1]<100)&(a[:,:,2]>190)
a[key,3]=0
rgba=Image.fromarray(a)
box=rgba.getbbox()
trim=rgba.crop(box)
trim.save(here/'trim-rgba.png')
size=(round(trim.width*40/trim.height),40)
small=trim.resize(size,Image.Resampling.NEAREST)
cell=Image.new('RGBA',(64,64))
offset=(32-size[0]//2,21)
cell.alpha_composite(small,offset)
cell.save(here/'whole-frame.png')
old=Image.open(here.parent/'eleanor-lantern-west-hand-v2'/'whole-frame.png').convert('RGBA')
passing=Image.open(here.parent/'eleanor-lantern-west-pass-v3'/'whole-frame.png').convert('RGBA')
comparison=Image.new('RGBA',(192,64))
for i,im in enumerate([old,passing,cell]): comparison.alpha_composite(im,(i*64,0))
comparison.resize((1152,384),Image.Resampling.NEAREST).save(here/'comparison.png')
record={'version':1,'status':'rejected_opposite_contact_same_lead','character':'eleanor','age':24,
        'direction':'west','carry_hand':'anatomical_right_far','near_hand':'anatomical_left_empty',
        'source':'source.png','source_sha256':hashlib.sha256((here/'source.png').read_bytes()).hexdigest(),
        'prompt':'prompt.txt','tool':'builtin image_gen','cell':[64,64],'anchor':[32,61],'body_height':40,
        'trim_xyxy':list(box),'resized_size':list(size),'cell_offset':list(offset),
        'comparison_order':['old contact','low passing','rejected opposite attempt'],
        'observation':'Correct far-hand lantern retained, but warm near boot still leads on screenleft; trailing screenright boot remains dark. Wider stride and skirt hem changed, requested leg swap did not occur.',
        'runtime_admitted':False,'animation_clips':{},
        'limitations':['Not the missing opposite contact. Do not insert into west walk cycle or call a completed loop.'],
        'transformation':'Magenta key, whole-character crop, nearest resize to40height, wholeframe padding; no body drawing or disconnected limb edits.'}
(here/'metadata.json').write_text(json.dumps(record,indent=2)+'\n')
print('ELEANOR WEST V4: source and transparent whole-frame retained; rejected as opposite contact (same leading leg)')
