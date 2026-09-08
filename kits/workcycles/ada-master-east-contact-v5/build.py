"""Extract whole camera-repaired contact candidate. No body-part compositing."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
source=HERE/'source.png';target=ROOT/'kits/workcycles/ada-master-east-walk-v4/pose-transfer.png'
im=Image.open(source).convert('RGBA');a=np.array(im);r=a[:,:,0].astype(int);g=a[:,:,1].astype(int);b=a[:,:,2].astype(int)
bg=(r>=80)&(b>=70)&(b>r*.65)&(r>g*1.8)&(b>g*1.8)
a[:,:,3]=np.where(bg|(a[:,:,3]<128),0,255);a[a[:,:,3]==0]=0
im=Image.fromarray(a);bounds=im.getbbox();assert bounds
whole=im.crop(bounds);whole.save(HERE/'transparent-trim.png');w=round(whole.width*40/whole.height)
frame=Image.new('RGBA',(64,64));frame.paste(whole.resize((w,40),Image.Resampling.NEAREST),(32-w//2,21));frame.save(HERE/'whole-frame.png')
old=Image.open(ROOT/'kits/workcycles/ada-master-east-walk-v4/02-whole-frame.png').convert('RGBA')
atlas=Image.new('RGBA',(128,64));atlas.paste(old,(0,0));atlas.paste(frame,(64,0));atlas.save(HERE/'comparison-atlas.png');atlas.resize((1024,512),Image.Resampling.NEAREST).save(HERE/'comparison.png')
metadata={'id':'ada-master-east-contact-v5','character':'ada_mercer','age':22,'texture':'whole-frame.png','cell':[64,64],'anchor':[32,61],'atlas_rect':[0,0,64,64],'phase':'opposite_contact_near_leg_back','facing':'east_side_profile','status':'improved_camera_contact_candidate_not_admitted','source':source.relative_to(ROOT).as_posix(),'source_sha256':sha(source),'edit_target':target.relative_to(ROOT).as_posix(),'edit_target_sha256':sha(target),'prompt':'prompt.txt','source_alpha_bounds_xyxy':list(bounds),'alpha_bounds_xyxy':list(frame.getbbox()),'rgba_sha256':hashlib.sha256(frame.tobytes()).hexdigest(),'attachment_points_provisional':{'near_foot':[25,60],'far_foot':[41,60],'near_hand':[28,46],'far_hand':[37,43]},'duration_seconds':0.16,'timing':'provisional','comparison_order':['v4_pose_transfer_contact2','v5_camera_repair'],'review':['One visible eye and right-facing nose; torso cream panel narrowed and outer jacket shoulder widened. Camera is closer to the side walk frames.','Near thigh still trails screenleft and far boot leads screenright, preserving contact topology.','Generator redrew lower-body pixels and brightened leading boot despite requested exact preservation; this is not pixel-identical lower-half transfer.','Candidate only, no native motion or game tests.'],'provenance':{'tool':'builtin image_gen','attempts':1,'transforms':['magenta key','wholefigure crop','nearestresize40pxheight','64cell bottomanchor32,61']}}
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
assert set(np.unique(np.array(frame)[:,:,3])).issubset({0,255})
print('ADA CONTACT V5 PASS: whole64cell binaryalpha, camera-repair comparison; candidate')
