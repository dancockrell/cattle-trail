"""Recover selected v6 poses directly from raw generations, never64px cells."""
from pathlib import Path
import json,hashlib,math,shutil
import numpy as np
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
v4_path=ROOT/'kits/workcycles/ada-master-east-walk-v4/metadata.json';v5_path=ROOT/'kits/workcycles/ada-master-east-contact-v5/metadata.json'
v4=json.loads(v4_path.read_text());v5=json.loads(v5_path.read_text())
definitions=[v4['frames'][0],v4['frames'][1],v5,v4['frames'][3]]
phases=['near_leg_contact','near_leg_support_passing','far_leg_contact_side_profile','far_leg_support_low_passing']
landmarks=[{'hip':[366,335],'near_foot':[461,532],'far_foot':[254,527],'near_hand':[278,343],'far_hand':[439,328]}, {'hip':[939,337],'near_foot':[979,532],'far_foot':[831,516],'near_hand':[900,346]}, {'hip':[630,816],'near_foot':[436,1201],'far_foot':[773,1203],'near_hand':[522,864],'far_hand':[735,796]}, {'hip':[620,570],'near_foot':[594,956],'far_foot':[651,992],'near_hand':[505,592],'far_hand':[704,534]}]
images=[];frames=[]
for i,d in enumerate(definitions):
    original=ROOT/d['source'];assert sha(original)==d['source_sha256'],'Source hash changed'
    local_name={0:'raw-contact-passing.png',1:'raw-contact-passing.png',2:'raw-opposite-contact.png',3:'raw-low-passing.png'}[i]
    shutil.copyfile(original,HERE/local_name)
    src=Image.open(original).convert('RGBA');region=d.get('source_region_xyxy',[0,0,src.width,src.height])
    a=np.array(src.crop(tuple(region)));r=a[:,:,0].astype(int);g=a[:,:,1].astype(int);b=a[:,:,2].astype(int)
    bg=(r>=80)&(b>=70)&(b>r*.65)&(r>g*1.8)&(b>g*1.8);a[:,:,3]=np.where(bg|(a[:,:,3]<128),0,255);a[a[:,:,3]==0]=0
    im=Image.fromarray(a);bounds=im.getbbox();assert bounds;whole=im.crop(bounds)
    assert whole.height>160,'Recovery must use native source larger than output'
    whole.save(HERE/f'{i:02}-native.png');images.append(whole)
    frames.append({'index':i,'phase':phases[i],'source':d['source'],'source_sha256':sha(original),'local_raw_copy':local_name,'source_region_xyxy':region,'source_alpha_bounds_in_region_xyxy':list(bounds),'native_size':list(whole.size),'native_image':f'{i:02}-native.png','native_rgba_sha256':hashlib.sha256(whole.tobytes()).hexdigest(),'landmarks_source_global_manual':landmarks[i],'landmarks_status':'manual sheet estimates, not geometry-derived anatomical proof','duration_seconds':0.16,'phase_admitted':False})
atlas=Image.new('RGBA',(1024,256));native_cell=math.ceil((max(max(im.size) for im in images)+32)/64)*64;native=Image.new('RGBA',(native_cell*2,native_cell*2))
for i,(whole,frame) in enumerate(zip(images,frames)):
    w=round(whole.width*160/whole.height);region=frame['source_region_xyxy'];bounds=frame['source_alpha_bounds_in_region_xyxy']
    hip_local=landmarks[i]['hip'][0]-region[0]-bounds[0];offset=[128-round(hip_local*w/whole.width),84]
    cell=Image.new('RGBA',(256,256));cell.paste(whole.resize((w,160),Image.Resampling.NEAREST),tuple(offset));cell.save(HERE/f'{i:02}-whole-frame.png');atlas.paste(cell,(i*256,0))
    transformed={name:[offset[0]+round((point[0]-region[0]-bounds[0])*w/whole.width),offset[1]+round((point[1]-region[1]-bounds[1])*160/whole.height)] for name,point in landmarks[i].items()}
    native.paste(whole,((i%2)*native_cell+native_cell//2-whole.width//2,(i//2)*native_cell+native_cell-16-whole.height))
    frame.update({'atlas_rect':[i*256,0,256,256],'anchor':[128,244],'figure_height':160,'offset':offset,'landmarks_cell_manual':transformed,'alpha_bounds_xyxy':list(cell.getbbox()),'rgba_sha256':hashlib.sha256(cell.tobytes()).hexdigest(),'native_atlas_rect':[(i%2)*native_cell,(i//2)*native_cell,native_cell,native_cell]})
atlas.save(HERE/'atlas.png');atlas.resize((2048,512),Image.Resampling.NEAREST).save(HERE/'preview.png');native.save(HERE/'atlas-native.png')
metadata={'id':'ada-detailed-recovered-walk-v1','character':'ada_mercer','age':22,'outfit':'original brown jacket cream blouse olive trousers','status':'raw_recovered_detailed_candidate_not_admitted','texture':'atlas.png','cell':[256,256],'anchor':[128,244],'figure_height':160,'native_texture':'atlas-native.png','native_cell':[native_cell,native_cell],'frames':frames,'clips':{'walk_east_candidate':{'frames':[0,1,2,3],'fps':6.25,'frame_durations':[0.16,0.16,0.16,0.16],'loop':True,'admitted':False}},'provenance':{'method':'Recover v6 selected sequence from raw generation sources','imagegen_calls':0,'inputs_exclude':['64pxcells','40pxsprites','coarsev6atlas'],'source_metadata':[{'path':v4_path.relative_to(ROOT).as_posix(),'sha256':sha(v4_path)},{'path':v5_path.relative_to(ROOT).as_posix(),'sha256':sha(v5_path)}],'transforms':['sameexistingmagenta key','wholefigure nativecrop preserved','hiphorizontal alignment andgroundbaseline','nearest downsample native to160pxheight only','no bodyparts/limbshape edits']},'review':['Original complete jacket/trousers outfit intentionally retained.','Ground silhouette bottom aligned244; hip center aligned128 using manual source landmarks. No limb normalization.','Corrected opposite contact and lowpassing are selected from existing rawimages; candidate phase labels are not motion approval.','No runtime edits or game tests.']}
hip_y=[f['landmarks_cell_manual']['hip'][1] for f in frames]
metadata['registration']={'method':'wholefigure translation: horizontal pelvis projection128 and lower silhouette ground244','measured_hip_y':hip_y,'remaining_hip_y_spread':max(hip_y)-min(hip_y),'frame_anchors':[[128,244]]*4,'note':'Equal160pxheight and groundalignment cannot remove differing anatomical proportions; no vertical body-part normalization applied.'}
metadata['review'].extend(['Inspected160pxpreview: faces and equipment readable; frame2 has fuller face/torso and frame3 smaller head/longer lower-body appearance than contact0.','Near-support passing1 still has a rear lifted foot rather than a tight mid-pass; recovered unchanged from approvedselection, not relabeled motion-perfect.','Opposite contact2 changes near/far leg overlap but arm counter-swing is not fully opposed. Exact same wholebody candidates retained.'])
(HERE/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
assert set(np.unique(np.array(atlas)[:,:,3])).issubset({0,255})
print('ADA RAW RECOVERY PASS:4 native poses downsampled160px, no40px inputs/noimagegen, hipgroundalignedcandidate')
