"""Preserve detailed whole poses without mislabeling repeated contacts as a cycle."""
from pathlib import Path
import hashlib,json,math
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
source_path=HERE/'source.png';source=Image.open(source_path).convert('RGBA');whole_images=[];frames=[]
intended=['near_forward_contact','near_support_passing','near_back_opposite_contact','far_support_passing']
observed=['near_forward_contact','near_support_low_passing_candidate','repeated_near_forward_contact','near_support_with_far_foot_trailing_candidate']
for i in range(4):
    col,row=i%2,i//2;region=[round(col*source.width/2),round(row*source.height/2),round((col+1)*source.width/2),round((row+1)*source.height/2)]
    im=source.crop(tuple(region));a=np.array(im);r=a[:,:,0].astype(int);g=a[:,:,1].astype(int);b=a[:,:,2].astype(int)
    bg=(r>=80)&(b>=70)&(b>r*.65)&(r>g*1.8)&(b>g*1.8)
    a[:,:,3]=np.where(bg|(a[:,:,3]<128),0,255);a[a[:,:,3]==0]=0
    im=Image.fromarray(a);bounds=im.getbbox();assert bounds
    whole=im.crop(bounds);whole.save(HERE/f'{i:02}-native.png');whole_images.append(whole)
    frames.append({'index':i,'requested_phase':intended[i],'observed_pose':observed[i],'source_region_xyxy':region,'source_alpha_bounds_xyxy':list(bounds),'native_size':list(whole.size),'native_image':f'{i:02}-native.png','native_rgba_sha256':hashlib.sha256(whole.tobytes()).hexdigest(),'source_sha256':sha(source_path),'phase_admitted':False,'duration_seconds_provisional':0.16})
atlas=Image.new('RGBA',(1024,256));native_cell=math.ceil((max(max(im.size) for im in whole_images)+32)/64)*64;native_atlas=Image.new('RGBA',(native_cell*2,native_cell*2))
for i,(whole,frame) in enumerate(zip(whole_images,frames)):
    w=round(whole.width*160/whole.height);detailed=Image.new('RGBA',(256,256));offset=[128-w//2,80]
    detailed.paste(whole.resize((w,160),Image.Resampling.NEAREST),tuple(offset));detailed.save(HERE/f'{i:02}-whole-frame.png');atlas.paste(detailed,(i*256,0))
    native_offset=[native_cell//2-whole.width//2,native_cell-16-whole.height];native_atlas.paste(whole,((i%2)*native_cell+native_offset[0],(i//2)*native_cell+native_offset[1]))
    frame.update({'atlas_rect':[i*256,0,256,256],'anchor':[128,240],'figure_height':160,'offset':offset,'alpha_bounds_xyxy':list(detailed.getbbox()),'rgba_sha256':hashlib.sha256(detailed.tobytes()).hexdigest(),'native_atlas_rect':[(i%2)*native_cell,(i//2)*native_cell,native_cell,native_cell],'native_anchor':[native_cell//2,native_cell-16]})
atlas.save(HERE/'atlas.png');atlas.resize((2048,512),Image.Resampling.NEAREST).save(HERE/'comparison.png');native_atlas.save(HERE/'atlas-native.png')
metadata={'id':'ada-detailed-east-v1','character':'ada_mercer','age':22,'outfit':'ada-summer-v1_tied_workshirt_shorts','status':'detailed_whole_pose_candidates_incomplete_cycle','texture':'atlas.png','cell':[256,256],'anchor':[128,240],'native_texture':'atlas-native.png','native_cell':[native_cell,native_cell],'facing':'east_front_oblique','source':source_path.relative_to(ROOT).as_posix(),'source_sha256':sha(source_path),'prompt':'prompt.txt','identity_reference':'kits/wardrobe/ada-summer-v1/tied_workshirt_shorts-native.png','identity_reference_sha256':sha(ROOT/'kits/wardrobe/ada-summer-v1/tied_workshirt_shorts-native.png'),'frames':frames,'clips':{'pose_0_contact':{'frames':[0],'fps':1,'loop':True},'pose_1_passing_candidate':{'frames':[1],'fps':1,'loop':True},'pose_2_repeated_contact':{'frames':[2],'fps':1,'loop':True},'pose_3_passing_candidate':{'frames':[3],'fps':1,'loop':True}},'walk_clip':None,'requested_timing':{'seconds_per_pose':0.16,'status':'provisional_only_no_complete_walk_clip'},'review':['Source generation retained intact. No correction generation was made after parent instructed extraction only.','Frames0and2 both show near leg leading screenright; frame2 does not supply opposite contact.','Frames1and3 both appear near-leg-supported with far foot behind; far-support phase not established.','Face/hair/goggles and outfit stay coherent; wrench remains on near visible hip. Anatomical handedness across missing reverse phase cannot be verified.','Frames are front-oblique rather than strict side profile. Native and160px images preserve readable faces, hands and outfit detail.','Linen-like shirt, brass goggles/buckles, leather toolbelt/boots fit WeirdWest materials; very short fitted shorts are a stylized period reinterpretation, not documented historical workwear.','No rendered game or motion test. No40px derivative.'],'provenance':{'tool':'builtin image_gen','successful_generations':1,'transforms':['magenta chromakey','wholefigure nativecrop','nativeatlas placement noresampling','160pxheight nearestderivative in256cells']}}
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
assert set(np.unique(np.array(atlas)[:,:,3])).issubset({0,255})
print('ADA DETAILED POSES PASS:4 nativewholefigures +160px256cell atlas; repeatedphases explicit; nowalkclip')
