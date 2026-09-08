from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
h=Path(__file__).resolve().parent
def keyimage(path):
    im=Image.open(path).convert('RGBA');a=np.array(im)
    key=(a[:,:,0]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,0].astype(float)*.7)
    a[key,3]=0;a[~key,3]=255
    return Image.fromarray(a)
source=keyimage(h/'source.png')
atlas=Image.new('RGBA',(1024,256));frames=[]
observed=['near_leading_contact','near_support_passing','repeated_near_leading_contact','near_swing_far_support_candidate']
def makecell(trim):
    size=(round(trim.width*160/trim.height),160)
    offset=(128-size[0]//2,244-size[1])
    cell=Image.new('RGBA',(256,256))
    cell.alpha_composite(trim.resize(size,Image.Resampling.NEAREST),offset)
    return cell,size,offset
for i in range(4):
    x0=i*source.width//4
    part=source.crop((x0,0,(i+1)*source.width//4,source.height));box=part.getbbox()
    assert box and box[0]>0 and box[1]>0 and box[2]<part.width and box[3]<part.height
    trim=part.crop(box);trim.save(h/f'frame-{i}-full-resolution.png')
    cell,size,offset=makecell(trim);cell.save(h/f'frame-{i}-whole.png');atlas.alpha_composite(cell,(i*256,0))
    frames.append({'frame':i,'rect':[i*256,0,256,256],'actual_phase':observed[i],
        'status':'rejected_opposite_contact' if i==2 else 'candidate','size':list(size),'offset':list(offset),
        'source_rect':[x0+box[0],box[1],box[2]-box[0],box[3]-box[1]],'provisional_duration_seconds':0.16})
atlas.save(h/'atlas.png');atlas.save(h/'native-preview.png')
corr=keyimage(h/'opposite-contact-correction.png');corr=corr.crop(corr.getbbox());corr.save(h/'correction-full-resolution.png')
cell,_,_=makecell(corr);cell.save(h/'correction-whole.png')
compare=Image.new('RGBA',(512,256));compare.alpha_composite(Image.open(h/'frame-2-whole.png'),(0,0));compare.alpha_composite(cell,(256,0));compare.save(h/'correction-comparison.png')
meta={'version':1,'character':'eleanor','age':24,'cell':[256,256],'anchor':[128,244],'body_height':160,
    'atlas':'atlas.png','frames':frames,'status':'incomplete_cycle_repeated_contact','runtime_admitted':False,'animation_clips':{},
    'source_sha256':{n:hashlib.sha256((h/n).read_bytes()).hexdigest() for n in ['source.png','opposite-contact-correction.png']},
    'prompts':['prompt.txt','opposite-contact-prompt.txt'],'tool':'builtin image_gen',
    'reference':'kits/wardrobe/rancher-summer-v1/cream_offshoulder_split_skirt-full-resolution.png',
    'actual_facing':'southeast_oblique_right','outfit':'Cream opaque offshoulder tied blouse, split indigo skirt over opaque brown shorts, chestnut braid, brass compass, leather western boots.',
    'observation':'Contact panels0and2 repeat bright nearleg leading screenright. Panel1 narrows to supportingbrightleg with darklegbentbehind. Panel3 bends nearleg across far support. Single targeted oppositecontact correction also retained same brightnearlead and is rejected.',
    'limitations':['Missing verified opposite contact; no full loop or east-side camera claim.','Timing0.16s is provisional perpose only, not an admitted orderedclip.','Period-inspired blouse skirt leather andbrass; short underlayer/cropped blouse are deliberate fantasywardrobe rather than verified1870s costume. No petticoat edge is visible.','Correction slightly redesigns face and body rendering.'],
    'processing':'Wholebody source key, fullresolution transparenttrims, nearest160height,256cellpadding; no detachedrig, compositedlegs or mirror.'}
(h/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
assert set(np.array(atlas)[:,:,3].flatten())<={0,255}
print('DETAILED ELEANOR: four160pxwholeposes + retainedcorrection; oppositecontact unresolved; no loopadmission')
