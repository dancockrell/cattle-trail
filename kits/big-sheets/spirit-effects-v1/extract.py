from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
root=Path(__file__).resolve().parent
im=Image.open(root/'source.png').convert('RGBA'); w,h=im.size
names=['bell_swing','cold_embers_pulse','crow_shadow_flap','firefly_spiral']
notes=['Bell tilts from left to right, but ring and vapor silhouette drift; wrap has a direction jump.','Cold flame rises and recedes; stone shapes drift slightly across phases.','Wings spread, fold, then spread; folded phase differs in body scale and feathers.','Luminous ring changes mote positions, but not a proven continuous spiral trajectory; glow opacity is flattened by binary extraction.']
atlas=Image.new('RGBA',(2048,1024)); frames=[]; clips={}
for row,name in enumerate(names):
    sequence=[]
    for col in range(8):
        i=row*8+col
        # Fixed grid registration: no individual content recentering or scaling.
        x0=round(col*w/8); x1=round((col+1)*w/8); y0=round(row*h/4); y1=round((row+1)*h/4)
        bounds=[x0+4,y0+4,x1-4,y1-4]
        a=np.array(im.crop(bounds)); original_alpha=a[:,:,3].copy()
        a[:,:,3]=np.where(original_alpha>=128,255,0).astype('uint8'); a[a[:,:,3]==0,:3]=0
        native=Image.fromarray(a); native.save(root/f'{i:02}-native.png')
        cell=Image.new('RGBA',(256,256)); offset=[(256-(x1-x0))//2+4,(256-(y1-y0))//2+4]
        cell.paste(native,tuple(offset)); cell.save(root/f'{i:02}-whole-frame.png'); atlas.paste(cell,(col*256,row*256));sequence.append(cell)
        frames.append({'index':i,'row':row,'column':col,'requested_row':name,'requested_order':col,'verified_phase':None,'phase_status':'chronological_requested_order_not_motion_certified','source_cell_xyxy':[x0,y0,x1,y1],'source_bounds_xyxy':bounds,'native_image':f'{i:02}-native.png','native_size':list(native.size),'native_rgba_sha256':hashlib.sha256(native.tobytes()).hexdigest(),'atlas_rect':[col*256,row*256,256,256],'anchor':[128,128],'source_offset_in_cell':offset,'hold_seconds':0.125,'opaque_pixels':int((a[:,:,3]>0).sum())})
    sequence[0].save(root/f'{name}-review.png',save_all=True,append_images=sequence[1:],duration=125,loop=0,disposal=0,blend=0)
    clips[name]={'frames':list(range(row*8,row*8+8)),'holds_seconds':[0.125]*8,'loop':True,'timing_status':'authored_review_timing_not_source_timestamps','runtime_admitted':False,'observed_limits':notes[row],'preview':f'{name}-review.png'}
atlas.save(root/'atlas.png')
data={'schema_version':1,'id':'spirit-effects-v1','status':'generated_effect_sequences_candidates_unadmitted','generation':'built-in imagegen','source':'source.png','source_sha256':hashlib.sha256((root/'source.png').read_bytes()).hexdigest(),'source_dimensions':[w,h],'prompt':'prompt.txt','texture':'atlas.png','atlas_sha256':hashlib.sha256((root/'atlas.png').read_bytes()).hexdigest(),'columns':8,'rows':4,'cell':[256,256],'anchor':[128,128],'uniform_scale':1,'pixels_per_world_unit':4,'runtime_admitted':False,'transparency':'Source RGBA, binary alpha threshold 128; RGB retained for surviving pixels. No color key, redraw or resampling. Four source pixels inset removes generated border lines; full source retained. Low opacity glow lost by intentional binary-alpha conversion.','registration':'Fixed nominal grid cell centered within 256px cell. No per-pose bbox recentering; a one-pixel variation is possible from rounded source grid widths.','frames':frames,'animations':clips,'observed_limits':notes}
(root/'metadata.json').write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
print('Extracted',len(frames),'frames, 4 APNG previews; binary alpha',sorted(np.unique(np.array(atlas)[:,:,3]).tolist()))
