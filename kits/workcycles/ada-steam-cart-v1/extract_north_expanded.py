from pathlib import Path
import json,hashlib
from PIL import Image
import numpy as np
h=Path(__file__).resolve().parent
im=Image.open(h/'north-expanded-source.png').convert('RGBA')
a=np.array(im)
key=(a[:,:,0]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,0].astype(float)*.7)
a[key,3]=0
a[~key,3]=255
im=Image.fromarray(a)
box=im.getbbox()
assert box[0]>100 and box[1]>100 and im.width-box[2]>100 and im.height-box[3]>100
trim=im.crop(box)
trim.save(h/'north-expanded-trim.png')
meta=json.loads((h/'metadata.json').read_text())
height=meta['frames'][1]['size'][1]
size=(round(trim.width*height/trim.height),height)
offset=(48-size[0]//2,90-size[1])
cell=Image.new('RGBA',(96,96))
cell.alpha_composite(trim.resize(size,Image.Resampling.NEAREST),offset)
cell.save(h/'north-expanded-whole-frame.png')
old=Image.open(h/'atlas.png').convert('RGBA')
assert old.size == (480,96), 'First five-frame atlas must remain unchanged'
atlas=Image.new('RGBA',(576,96))
atlas.alpha_composite(old,(0,0))
atlas.alpha_composite(cell,(480,0))
atlas.save(h/'atlas-v2.png')
atlas.resize((1728,288),Image.Resampling.NEAREST).save(h/'review-v2.png')
record={'id':'occupied_north_corrected','frame':5,'actual_facing':'north','status':'candidate',
    'rect':[480,0,96,96],'source':'north-expanded-source.png','size':list(size),'offset':list(offset),
    'source_rect':[box[0],box[1],box[2]-box[0],box[3]-box[1]],
    'observation':'Whole goggles, hat and axle tips restored with generous margins. Rear tailgate, axle and platform replace incorrect visible boiler. Both crew backs retained. Thin chimney is visible between crew.'}
meta['frames'].append(record)
meta['atlas']='atlas-v2.png'
meta['source_sha256']['north-expanded-source.png']=hashlib.sha256((h/'north-expanded-source.png').read_bytes()).hexdigest()
meta['prompts'].append('north-expanded-prompt.txt')
meta['limitations']=['Original north frame1 remains rejected; corrected north frame5 is the candidate replacement.','Static heading images only, no wheel cycle or turn animation.','East/west requested views are actual southeast/southwest.','Thin chimney remains between adults; large rear boiler continuity error removed.']
(h/'metadata-v2.json').write_text(json.dumps(meta,indent=2)+'\n')
assert atlas.crop((0,0,480,96)).tobytes()==old.tobytes()
assert set(np.array(atlas)[:,:,3].flatten()) <= {0,255}
print('NORTH EXPANDED PASS: complete margins, whole crew and axle; appendedframe5; first5pixel-exact unchanged; binaryalpha')
