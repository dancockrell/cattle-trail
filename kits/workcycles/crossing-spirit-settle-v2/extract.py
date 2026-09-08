from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

HERE=Path(__file__).resolve().parent
SOURCE=HERE.parent.parent/'source'/'crossing-spirit-settle-v2.png'
source=Image.open(SOURCE).convert('RGBA')
pixels=np.array(source)
rgb=pixels[:,:,:3].astype(np.int16)
key=((rgb[:,:,0]-rgb[:,:,1])>50)&((rgb[:,:,2]-rgb[:,:,1])>50)
pixels[key]=[0,0,0,0]
pixels[~key,3]=255
rgba=Image.fromarray(pixels)
frames=[Image.open(HERE.parent/'crossing-spirit-v1'/'listening.png').convert('RGBA')]
records=[{'index':0,'role':'original_listening','source':'kits/source/crossing-spirit-v1.png','source_index':2,'preserved_endpoint_pixels':True}]
scale=0.065
for i in range(2):
    box=(i*source.width//2,0,(i+1)*source.width//2,source.height)
    region=rgba.crop(box); trim=region.getbbox(); assert trim is not None
    crop=region.crop(trim)
    size=(round(crop.width*scale),round(crop.height*scale))
    cell=Image.new('RGBA',(72,64))
    offset=((72-size[0])//2,61-size[1])
    cell.paste(crop.resize(size,Image.Resampling.NEAREST),offset)
    frames.append(cell)
    records.append({'index':i+1,'role':'new_lowering_'+str(i+1),'source':'kits/source/crossing-spirit-settle-v2.png','source_cell_ltrb':list(box),'trim_ltrb_in_cell':list(trim),'scale':scale,'scaled_size':list(size),'offset':list(offset)})
frames.append(Image.open(HERE.parent/'crossing-spirit-v1'/'settled.png').convert('RGBA'))
records.append({'index':3,'role':'original_settled','source':'kits/source/crossing-spirit-v1.png','source_index':3,'preserved_endpoint_pixels':True})
atlas=Image.new('RGBA',(288,64));review=Image.new('RGB',(1152,310),'#38483d');draw=ImageDraw.Draw(review)
for i,(cell,record) in enumerate(zip(frames,records)):
    cell.save(HERE/f'frame-{i:02}.png');atlas.paste(cell,(i*72,0))
    preview=cell.resize((288,256),Image.Resampling.NEAREST);review.paste(preview,(i*288,0),preview)
    draw.text((i*288+10,273),f'{i}: '+record['role'],fill='white')
    record.update({'atlas_rect_xywh':[i*72,0,72,64],'anchor':[36,61],'rgba_sha256':hashlib.sha256(cell.tobytes()).hexdigest()})
atlas.save(HERE/'atlas.png');review.save(HERE/'contact-sheet.png')
metadata={'schema_version':1,'status':'candidate_transition_pending_visual_admission','character':'crossing_spirit','actual_body_facing':'northeast','source':'kits/source/crossing-spirit-settle-v2.png','source_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'source_dimensions':list(source.size),'source_grid':[2,1],'texture':'atlas.png','atlas_size':[288,64],'cell':[72,64],'anchor':[36,61],'frames':records,'clip':{'name':'listen_to_settle','frames':[0,1,2,3],'durations_seconds':[0.18,0.16,0.18,0.4],'loop':False,'sequence_verified':False},'processing':{'alpha':'binary0/255, zeroRGBA magenta-keyed pixels','resampling':'nearest','new_frames_shared_scale':scale,'scale_basis':'Approximate native hind-hoof separation matching original endpoints; endpoints retain exact existing pixels.','no_detached_parts':True},'inspection':{'new_pose_order':'Left then right lowers the head progressively.','limitations':['The second new pose lowers the head slightly beyond the original final settled endpoint; final transition may have a small upward correction.','New head faces somewhat more toward the viewer; body remains northeast.','New far horn remains visible while original settled far horn is occluded. Native visual admission is pending.']}}
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
assert set(np.unique(np.array(atlas)[:,:,3])).issubset({0,255})
print(json.dumps({'source':list(source.size),'atlas':list(atlas.size),'frames':len(frames)}))
