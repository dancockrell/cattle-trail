"""Extract single whole planted turn pose; preserve current endpoint pixels."""
from pathlib import Path
import json,hashlib
from PIL import Image
import numpy as np
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
p=HERE/'source.png';im=Image.open(p).convert('RGBA');a=np.array(im);r=a[:,:,0].astype(int);g=a[:,:,1].astype(int);b=a[:,:,2].astype(int)
bg=(r>=80)&(b>=70)&(b>r*.65)&(r>g*1.8)&(b>g*1.8)
a[:,:,3]=np.where(bg|(a[:,:,3]<128),0,255);a[a[:,:,3]==0]=0
im=Image.fromarray(a);bounds=im.getbbox();assert bounds
whole=im.crop(bounds);whole.save(HERE/'transparent-trim.png');w=round(whole.width*40/whole.height)
frame=Image.new('RGBA',(64,64));frame.paste(whole.resize((w,40),Image.Resampling.NEAREST),(32-w//2,21));frame.save(HERE/'whole-frame.png')
east=ROOT/'kits/workcycles/ada-mercer-idle-v1/east.png';northeast=ROOT/'kits/workcycles/ada-mercer-idle-v1/northeast.png'
atlas=Image.new('RGBA',(192,64))
for i,f in enumerate([Image.open(east).convert('RGBA'),frame,Image.open(northeast).convert('RGBA')]):atlas.paste(f,(i*64,0))
atlas.save(HERE/'comparison-atlas.png');atlas.resize((1152,384),Image.Resampling.NEAREST).save(HERE/'comparison.png')
metadata={'id':'ada-turn-east-northeast-v1','character':'ada_mercer','age':22,'status':'single_turn_candidate_not_admitted','texture':'whole-frame.png','cell':[64,64],'anchor':[32,61],'requested_facing':'east_northeast_intermediate','actual_facing':'pending_visual_inspection','facing_confidence':'pending','atlas_rect':[0,0,64,64],'source':p.relative_to(ROOT).as_posix(),'source_sha256':sha(p),'source_alpha_bounds_xyxy':list(bounds),'alpha_bounds_xyxy':list(frame.getbbox()),'rgba_sha256':hashlib.sha256(frame.tobytes()).hexdigest(),'comparison_order':['existing_east','candidate_bridge','existing_northeast'],'endpoint_sources':[{'path':east.relative_to(ROOT).as_posix(),'sha256':sha(east)},{'path':northeast.relative_to(ROOT).as_posix(),'sha256':sha(northeast)}],'clip':{'name':'turn_east_northeast_candidate','frames':[0],'duration_seconds':0.08,'loop':False,'timing':'provisional','admitted':False},'provenance':{'tool':'builtin image_gen','prompt':'prompt.txt','transforms':['magenta chroma key','wholefigure crop','nearestresize40pxheight','bottomcenteranchor32,61']},'validation':['Singlewholefigure, binary alpha and40pxheight checked.','No native motion or game test.']}
metadata['actual_facing']='east_front_oblique_endpoint_like'
metadata['facing_confidence']='high_not_an_intermediate'
metadata['status']='rejected_for_turn_bridge_retained_static_pose'
metadata['validation'].append('Compared existing E / new pose / existing NE at40pxheight. New torso still presents cream blouse and both front lapels like E; no side/back rotation. Planted complete pose is useful static reference but not admitted as turn bridge.')
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
print('ADA TURN EXTRACTION PASS: whole64pxcell,32/61anchor, unchangedendpointcomparison')
