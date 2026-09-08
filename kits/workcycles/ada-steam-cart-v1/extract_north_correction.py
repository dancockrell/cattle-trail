from pathlib import Path
import json,hashlib
from PIL import Image
import numpy as np
h=Path(__file__).resolve().parent
im=Image.open(h/'north-correction-source.png').convert('RGBA')
a=np.array(im)
key=(a[:,:,0]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,1].astype(float)*1.7)&(a[:,:,2]>a[:,:,0].astype(float)*.7)
a[key,3]=0
a[~key,3]=255
im=Image.fromarray(a)
box=im.getbbox()
trim=im.crop(box)
trim.save(h/'north-correction-trim.png')
meta=json.loads((h/'metadata.json').read_text())
height=meta['frames'][1]['size'][1]
size=(round(trim.width*height/trim.height),height)
cell=Image.new('RGBA',(96,96))
offset=(48-size[0]//2,90-size[1])
cell.alpha_composite(trim.resize(size,Image.Resampling.NEAREST),offset)
cell.save(h/'north-correction-whole-frame.png')
old=Image.open(h/'north-whole-frame.png').convert('RGBA')
review=Image.new('RGBA',(192,96))
review.alpha_composite(old,(0,0))
review.alpha_composite(cell,(96,0))
review.resize((768,384),Image.Resampling.NEAREST).save(h/'north-correction-review.png')
record={'id':'occupied_north_correction','status':'candidate_clipped_source_edges','runtime_admitted':False,
        'actual_facing':'north','cell':[96,96],'anchor':[48,90],'size':list(size),'offset':list(offset),
        'source':'north-correction-source.png','source_sha256':hashlib.sha256((h/'north-correction-source.png').read_bytes()).hexdigest(),
        'prompt':'north-correction-prompt.txt','observation':'Rear round boiler removed; wooden tailgate, axle and platform visible. Thin chimney rises between adults; source crops goggles/hat top and axle tips at image edges.',
        'limitations':['Cannot certify full uncropped wholevehicle from this source.','Chimney appears between bodies rather than aboveheads.','Held outside main five-frame atlas pending margin correction or explicit root selection.'],
        'transformation':'Magenta hue key, wholeframe trim, nearest rescale to match oldnorthheight, padding. No rebuilding clipped parts.'}
(h/'north-correction-metadata.json').write_text(json.dumps(record,indent=2)+'\n')
print('NORTH CORRECTION: boiler location repaired; source edge clipping remains; held outside original atlas')
