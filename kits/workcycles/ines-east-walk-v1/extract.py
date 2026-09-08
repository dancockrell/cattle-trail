"""Preserve every whole-character pose as a keyed, aligned candidate bank."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image

HERE=Path(__file__).resolve().parent
sources=[('source.png',(0,0,627,627),'near-contact'),('source.png',(627,0,1254,627),'near-support-passing'),('source.png',(0,627,627,1254),'repeated-near-contact'),('source.png',(627,627,1254,1254),'probable-far-support-passing'),('opposite-contact-rejected.png',None,'repair-repeated-near-contact'),('opposite-contact-focused.png',None,'focused-repeated-near-contact')]
atlas=Image.new('RGBA',(64*6,64))
records=[]
for i,(file,box,phase) in enumerate(sources):
    image=Image.open(HERE/file).convert('RGBA')
    if box: image=image.crop(box)
    a=np.array(image)
    rgb=a[:,:,:3].astype(int)
    key=(rgb[:,:,0]>80)&(rgb[:,:,2]>80)&(rgb[:,:,1]<rgb[:,:,0]*.7)&(rgb[:,:,1]<rgb[:,:,2]*.7)
    a[key]=0
    a[~key,3]=255
    image=Image.fromarray(a)
    bounds=image.getbbox()
    assert bounds
    figure=image.crop(bounds)
    width=round(figure.width*40/figure.height)
    assert 1<width<62
    small=figure.resize((width,40),Image.Resampling.NEAREST)
    frame=Image.new('RGBA',(64,64))
    frame.paste(small,(32-width//2,21))
    output=f'pose-{i:02d}.png'
    frame.save(HERE/output)
    atlas.paste(frame,(i*64,0))
    records.append({'index':i,'source':file,'source_sha256':hashlib.sha256((HERE/file).read_bytes()).hexdigest(),'source_rect_xyxy':box,'trim_bounds_xyxy':list(bounds),'image':output,'atlas_rect_xywh':[i*64,0,64,64],'anchor':[32,61],'observed_phase':phase,'status':'candidate' if i in [0,1,3] else 'rejected_for_opposite_contact_slot','duration_ms_provisional':160 if i in [0,1,3] else None})
atlas.save(HERE/'candidate-bank.png')
atlas.resize((1536,256),Image.Resampling.NEAREST).save(HERE/'candidate-bank-review.png')
metadata=json.loads((HERE/'metadata.json').read_text())
metadata['texture']='candidate-bank.png'
metadata['cell']=[64,64]
metadata['anchor']=[32,61]
metadata['extracted_candidates']=records
metadata['animations']={}
metadata['focused_repair_attempt']={'source':'opposite-contact-focused.png','prompt':'focused-edit.prompt.txt','status':'rejected_for_opposite_contact_slot','reason':'Near warm leg still leads forward after edit from isolated whole-character input; preserved as a whole candidate image, not used to fill missing phase.'}
metadata['transform']='Magenta key, complete-figure trim, nearest-neighbor whole-figure resize to40px, baseline61; no painting, limb rig or recombination'
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
assert set(np.unique(np.array(atlas)[:,:,3])).issubset({0,255})
print('INES CANDIDATE BANK PASS: six whole poses preserved, 64px cells, binaryalpha; no fabricated loop')
