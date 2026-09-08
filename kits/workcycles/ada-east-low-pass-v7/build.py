"""Extract low-pass whole figure; preserve older source for direct comparison."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
p=HERE/'source.png';target=ROOT/'kits/workcycles/ada-master-east-walk-v4/01-whole-frame.png'
im=Image.open(p).convert('RGBA');a=np.array(im);r=a[:,:,0].astype(int);g=a[:,:,1].astype(int);b=a[:,:,2].astype(int)
bg=(r>=80)&(b>=70)&(b>r*.65)&(r>g*1.8)&(b>g*1.8)
a[:,:,3]=np.where(bg|(a[:,:,3]<128),0,255);a[a[:,:,3]==0]=0
im=Image.fromarray(a);bounds=im.getbbox();assert bounds
whole=im.crop(bounds);whole.save(HERE/'transparent-trim.png');w=round(whole.width*40/whole.height)
frame=Image.new('RGBA',(64,64));frame.paste(whole.resize((w,40),Image.Resampling.NEAREST),(32-w//2,21));frame.save(HERE/'whole-frame.png')
atlas=Image.new('RGBA',(128,64));atlas.paste(Image.open(target).convert('RGBA'),(0,0));atlas.paste(frame,(64,0));atlas.save(HERE/'comparison-atlas.png');atlas.resize((1024,512),Image.Resampling.NEAREST).save(HERE/'comparison.png')
metadata={'id':'ada-east-low-pass-v7','character':'ada_mercer','age':22,'texture':'whole-frame.png','cell':[64,64],'anchor':[32,61],'atlas_rect':[0,0,64,64],'phase':'low_pass_near_support','facing':'east_side_profile','status':'low_pass_candidate_not_admitted','source':p.relative_to(ROOT).as_posix(),'source_sha256':sha(p),'edit_target':target.relative_to(ROOT).as_posix(),'edit_target_sha256':sha(target),'prompt':'prompt.txt','source_alpha_bounds_xyxy':list(bounds),'alpha_bounds_xyxy':list(frame.getbbox()),'rgba_sha256':hashlib.sha256(frame.tobytes()).hexdigest(),'attachment_points_provisional':{'hip':[33,47],'near_ankle':[32,59],'near_foot':[35,61],'far_foot':[30,59],'near_hand':[33,46]},'timing':{'duration_seconds':0.16,'status':'provisional'},'comparison_order':['v4_near_support','v7_low_pass'],'review':['Support ankle now nearly vertically under hip; foot separation narrowed. Far boot remains low behind near shin.','Head and torso remain side-facing. Actual exposed far-boot extent at40pxheight is small and overlaps support leg.','Generator changed toolbelt silhouette into larger rear pouch; hanging wrench no longer clearly identifiable. Candidate not automatically installed.','Single image edit and sheet inspection only; no game tests.'],'provenance':{'tool':'builtin image_gen','attempts':1,'transforms':['magenta key','wholefigure crop','nearest40pxheight','64cell anchor32,61']}}
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
assert set(np.unique(np.array(frame)[:,:,3])).issubset({0,255})
print('ADA LOW PASS V7 PASS: whole40pxfigure64cell binaryalpha, comparison retained')
