"""Whole-figure chroma extraction and phase metadata; no painted or rigged parts."""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def key(im):
    a=np.array(im.convert('RGBA')); r=a[:,:,0].astype(int); g=a[:,:,1].astype(int); b=a[:,:,2].astype(int)
    bg=(r>=80)&(b>=70)&(b>r*.65)&(r>g*1.8)&(b>g*1.8)
    a[:,:,3]=np.where(bg|(a[:,:,3]<128),0,255);a[a[:,:,3]==0]=0
    return Image.fromarray(a)
source=Image.open(HERE/'source.png').convert('RGBA')
sheet=Image.new('RGBA',(256,64));frames=[]
phases=['contact_near_forward','low_pass_near_support','contact_near_back_candidate','opposite_pass_far_support_candidate']
for i in range(4):
    col,row=i%2,i//2
    region=[round(col*source.width/2),round(row*source.height/2),round((col+1)*source.width/2),round((row+1)*source.height/2)]
    raw=key(source.crop(tuple(region)))
    input_name='source.png'
    if i==2 and (HERE/'pose-transfer.png').exists():
        raw=key(Image.open(HERE/'pose-transfer.png'));input_name='pose-transfer.png';region=[0,0,raw.width,raw.height]
    if i==3 and (HERE/'low-pass-corrected.png').exists():
        raw=key(Image.open(HERE/'low-pass-corrected.png'));input_name='low-pass-corrected.png';region=[0,0,raw.width,raw.height]
    bounds=raw.getbbox(); assert bounds
    whole=raw.crop(bounds);width=round(whole.width*40/whole.height)
    frame=Image.new('RGBA',(64,64));frame.paste(whole.resize((width,40),Image.Resampling.NEAREST),(32-width//2,21))
    frame.save(HERE/f'{i:02}-whole-frame.png');sheet.paste(frame,(i*64,0))
    frames.append({'index':i,'phase':phases[i],'atlas_rect':[i*64,0,64,64],'anchor':[32,61],'source':(HERE/input_name).relative_to(ROOT).as_posix(),'source_sha256':sha(HERE/input_name),'source_region_xyxy':region,'source_alpha_bounds_xyxy':list(bounds),'alpha_bounds_xyxy':list(frame.getbbox()),'duration_seconds':0.16,'duration_status':'provisional','rgba_sha256':hashlib.sha256(frame.tobytes()).hexdigest()})
sheet.save(HERE/'atlas.png');sheet.resize((1536,384),Image.Resampling.NEAREST).save(HERE/'comparison.png')
metadata={'id':'ada-master-east-walk-v4','character':'ada_mercer','age':22,'texture':'atlas.png','cell':[64,64],'anchor':[32,61],'facing':'east','frames':frames,'clips':{'walk_east_candidate':{'frames':[0,1,2,3],'fps':6.25,'loop':True,'admitted':False}},'status':'working_phase_candidates_not_runtime','generation_tool':'builtin image_gen','transforms':['magenta chroma key with binary alpha','wholefigure bounds crop','nearest sampling to40pxheight','anchor placement32,61'],'review':['Identity and complete four bodies inspected on sheet.','Phase0/2 arm swing reverses, but leg depth remains insufficiently distinct for confident opposite-contact admission.','Single opposite-contact correction repeated foreground-leg ambiguity and changed arm swing; retained as rejected.','Timing and anchors remain provisional; no game run or motion approval.']}
anchors=[{'near_foot':[43,60],'far_foot':[24,60],'near_hand':[25,45],'far_hand':[38,43]}, {'near_foot':[39,60],'far_foot':[24,57],'near_hand':[31,46],'far_hand':[35,44]}, {'near_foot':[23,60],'far_foot':[42,60],'near_hand':[37,43],'far_hand':[28,45]}, {'near_foot':[38,53],'far_foot':[29,60],'near_hand':[25,44],'far_hand':[35,42]}]
for frame, points in zip(frames,anchors):
    frame['attachment_points_provisional']=points
    frame['attachment_status']='manual sheet estimate, leg identity not admitted'
frames[3]['attachment_points_provisional']={'near_foot':[31,59],'far_foot':[35,61],'near_hand':[27,43],'far_hand':[37,40]}
metadata['review'].append('Raised opposite-pass preserved separately; selected low-pass correction has the near leg crossing in front and airborne boot just above supporting sole. Opposite-contact ambiguity still blocks complete-cycle admission.')
metadata['review']=[line for line in metadata['review'] if not line.startswith('Phase0/2')]
metadata['review'][-1]='Raised opposite-pass preserved separately; selected low-pass correction has the near leg crossing in front and airborne boot just above supporting sole.'
metadata['review'].append('Pose-transfer from Eleanor v7 selected for contact2: near warm boot trails screenleft, far darker boot leads screenright. Lower-body phase is clearer, but face/torso rotated more front-oblique and proportions drift from the other three side views; candidate cycle remains unadmitted.')
metadata['pose_transfer_reference']={'path':'kits/source/eleanor-east-opposite-contact-v7.png','sha256':sha(ROOT/'kits/source/eleanor-east-opposite-contact-v7.png'),'role':'whole pose topology authority'}
frames[2]['attachment_points_provisional']={'near_foot':[25,60],'far_foot':[40,60],'near_hand':[27,47],'far_hand':[41,43]}
frames[2]['phase_confidence']='clear near-rear/far-forward contact; camera continuity unresolved'
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
print('ADA WALK EXTRACTION PASS:4 whole candidates, binary alpha,40pxheight; not admitted as verified cycle')
