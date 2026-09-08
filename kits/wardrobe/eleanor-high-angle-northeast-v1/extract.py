from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
h=Path(__file__).resolve().parent
root=h.parents[2]
source=Image.open(h/'source.png').convert('RGBA');a=np.array(source)
key=(a[:,:,0]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,0].astype(float)*.7)
a[key,3]=0;a[~key,3]=255
rgba=Image.fromarray(a);box=rgba.getbbox()
assert box and min(box[:2])>0 and box[2]<source.width and box[3]<source.height
trim=rgba.crop(box);trim.save(h/'eleanor-native.png')
size=(round(trim.width*160/trim.height),160);offset=(128-size[0]//2,84)
cell=Image.new('RGBA',(256,256));cell.alpha_composite(trim.resize(size,Image.Resampling.NEAREST),offset)
cell.save(h/'atlas.png');cell.save(h/'native-preview.png');cell.resize((512,512),Image.Resampling.NEAREST).save(h/'preview-2x.png')
refs=[('identity_and_camera','kits/wardrobe/eleanor-high-angle-v1/eleanor-native.png')]
metadata={'version':1,'id':'eleanor_high_angle_northeast','age':24,'cell':[256,256],'anchor':[128,244],'body_height':160,
    'rect':[0,0,256,256],'source':'source.png','source_sha256':hashlib.sha256((h/'source.png').read_bytes()).hexdigest(),
    'source_rect':[box[0],box[1],box[2]-box[0],box[3]-box[1]],'size':list(size),'offset':list(offset),
    'prompt':'prompt.txt','references':[{'role':role,'path':p,'sha256':hashlib.sha256((root/p).read_bytes()).hexdigest()} for role,p in refs],
    'tool':'builtin image_gen','status':'high_angle_master_candidate','runtime_admitted':False,'animation_clips':{},'actual_facing':'northeast_rear_right',
    'actual_camera':'Rear-right/northeast: broad crown, back of shoulders and braid visible; camera elevated, torso less foreshortened than SE master. Full boot silhouette visible; exactdegrees notmeasured.',
    'identity':'Adult24 Eleanor chestnutbraid/creamwovenblouse/indigosplitridingskirtoveropaquebrownunderlayer/leatherboots/brasscompass.',
    'limitations':['Static master only; no turn/walk clip.','Feet at different depths; rear boot heel reads raised, so fully grounded neutral stance remains uncertain.','Costume remains period-inspired fantasy rather than reconstructed1870sdress.'],
    'processing':'Wholefigure sourcebackground huekey, fullnative transparentcrop, nearest160height padded256cell; no painting rigging or bodypart manipulation.'}
(h/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
assert set(np.array(cell)[:,:,3].flatten())<={0,255}
print('ELEANOR HIGH ANGLE PASS: fullnativecutout,160pxheight256cell128244, binaryalpha, crownshoulderbootplanesvisible')

