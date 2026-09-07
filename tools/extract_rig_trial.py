"""Crop/key actual generated rig pieces; no painted or synthesized pixels."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
r=Path(__file__).resolve().parents[1]
p=r/'kits/source/rider-ne-rig-v1.png';im=Image.open(p).convert('RGBA')
names=['body','near_fore_upper','near_fore_lower','near_hind_upper','near_hind_lower','far_fore_upper','far_fore_lower','far_hind_upper','far_hind_lower']
out=r/'assets/rig-trial';out.mkdir(exist_ok=True)
parts={}
for i,name in enumerate(names):
 x=i%3;y=i//3
 box=[round(x*im.width/3)+4,round(y*im.height/3)+4,round((x+1)*im.width/3)-4,round((y+1)*im.height/3)-4]
 tile=im.crop(box);a=np.array(tile);rgb=a[:,:,:3].astype(int)
 key=(rgb[:,:,0]>150)&(rgb[:,:,2]>150)&(rgb[:,:,1]<130)
 a[:,:,3]=np.where(key,0,255)
 tile=Image.fromarray(a);trim=tile.getbbox();tile=tile.crop(trim)
 tile.save(out/(name+'.png'))
 parts[name]={'texture':'res://assets/rig-trial/'+name+'.png','source_rect':box,'trim':list(trim),'dimensions':list(tile.size)}
spec={'status':'rejected_by_user_do_not_integrate','source':str(p.relative_to(r)).replace('\\','/'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'processing':'Cell crop excludes white grid border; binary magenta key; alpha trim only. Runtime uses nearest textured parts.','parts':parts,'cycle_seconds':.96,'stride_pixels':18,'stance_fraction':.75,'landing_phases':{'near_hind':0,'near_fore':.25,'far_hind':.5,'far_fore':.75}}
(out/'rig.json').write_text(json.dumps(spec,indent=2)+'\n')
print('Extracted nine real pixel-art rig parts; gameplay unchanged')
